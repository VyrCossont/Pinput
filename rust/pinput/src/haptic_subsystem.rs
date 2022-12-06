//! Convenience wrappers for Buttplug.io objects.

use crate::error::Error;
use crate::gamepad::{PinputGamepad, PinputGamepadButtons, PinputGamepadFlags};
use buttplug::client::{
    ButtplugClient, ButtplugClientDevice, ButtplugClientDeviceEvent, ButtplugClientEvent,
    VibrateCommand,
};
use buttplug::core::connector::{ButtplugRemoteClientConnector, ButtplugWebsocketClientTransport};
use buttplug::core::message::serializer::ButtplugClientJSONSerializer;
use buttplug::core::message::{ActuatorType, ButtplugCurrentSpecServerMessage, SensorType};
use buttplug::util::in_process_client;
use futures::{Stream, StreamExt};
use std::cmp::{max, Ordering};
use std::collections::BTreeSet;
use std::ops::RangeInclusive;
use std::sync::atomic::Ordering::SeqCst;
use std::sync::atomic::{AtomicI32, AtomicU8};
use std::sync::{Arc, Mutex};
use tokio::runtime::Runtime;
use tokio::time;
use tokio::time::Duration;

/// Buttplug client wrapper.
/// Not a real SDL subsystem like gamepads or joysticks,
/// but we do some tracking here to keep a list of currently attached devices.
/// Also wraps a Tokio runtime (until we rewrite Pinput as a proper async app).
/// TODO: handle device disconnection by reserving slots in a Vec<Option<HapticDevice>> or something
pub struct HapticSubsystem {
    rt: Arc<Runtime>,
    // TODO: we might be able to get rid of this and just use the client's device list.
    devices: Arc<Mutex<BTreeSet<HapticDevice>>>,
}

impl HapticSubsystem {
    pub fn new(haptics_server: Option<String>) -> Result<Self, Error> {
        let rt = Arc::new(Runtime::new()?);
        let client_name = "Pinput";
        let client = (if let Some(address) = haptics_server {
            rt.block_on(async move {
                let connector = ButtplugRemoteClientConnector::<
                    ButtplugWebsocketClientTransport,
                    ButtplugClientJSONSerializer,
                >::new(
                    ButtplugWebsocketClientTransport::new_insecure_connector(&address),
                );
                let client = ButtplugClient::new(client_name);
                if let Err(e) = client.connect(connector).await {
                    println!("Buttplug client connection failed! {e:?}");
                    return Err(Error::ButtplugClientError(e));
                }
                Ok(client)
            })
        } else {
            rt.block_on(async move {
                let client = in_process_client(client_name, false).await;
                Ok(client)
            })
        })?;

        let devices = Arc::new(Mutex::new(BTreeSet::new()));
        if let Ok(mut devices) = devices.lock() {
            for device in client.devices() {
                devices.insert(HapticDevice::new(rt.clone(), device));
            }
        } else {
            println!("Buttplug device set mutex poisoned!");
        }

        rt.block_on(client.start_scanning())?;
        let event_stream = client.event_stream();
        rt.spawn(handle_client_events(
            rt.clone(),
            event_stream,
            devices.clone(),
        ));
        let haptic_subsystem = Self { rt, devices };
        Ok(haptic_subsystem)
    }

    pub fn devices(&self) -> Vec<HapticDevice> {
        if let Ok(devices) = self.devices.lock() {
            devices.clone().into_iter().collect()
        } else {
            println!("Buttplug device set mutex poisoned!");
            Vec::new()
        }
    }

    /// Exposes up to two vibration motors, assumed to be low and high frequency respectively.
    pub fn sync_haptic_device(&self, haptic_device: &HapticDevice, gamepad: &mut PinputGamepad) {
        // Declare that we are a haptic device.
        gamepad.flags = PinputGamepadFlags::default();
        gamepad.flags.insert(PinputGamepadFlags::HAPTIC_DEVICE);

        // TODO: don't assume device is connected
        gamepad.flags.insert(PinputGamepadFlags::CONNECTED);

        // Report vibration capability.
        if haptic_device.num_vibes > 0 {
            gamepad.flags.insert(PinputGamepadFlags::HAS_RUMBLE);
        }

        // Report battery. Buttplug doesn't support charging state.
        gamepad.battery = if let Some(battery_level) = &haptic_device.battery_level {
            gamepad.flags.insert(PinputGamepadFlags::HAS_BATTERY);
            battery_level.load(SeqCst)
        } else {
            0
        };

        // Zero out the inputs.
        let mut buttons = PinputGamepadButtons::default();
        gamepad.left_trigger = 0;
        gamepad.right_trigger = 0;
        gamepad.left_stick_x = 0;
        gamepad.left_stick_y = 0;
        gamepad.right_stick_x = 0;
        gamepad.right_stick_y = 0;
        let mut axis_index = 0usize;
        // We can't have unaligned references to these packed fields.
        let axis_mappings: [fn(&mut PinputGamepad, i16); 4] = [
            |g, v| g.left_stick_x = v,
            |g, v| g.left_stick_y = v,
            |g, v| g.right_stick_x = v,
            |g, v| g.right_stick_y = v,
        ];
        let mut button_index = 0usize;
        let button_mappings = [
            PinputGamepadButtons::A,
            PinputGamepadButtons::B,
            PinputGamepadButtons::X,
            PinputGamepadButtons::Y,
        ];
        for ((input_type, ranges), input) in haptic_device
            .input_props
            .iter()
            .zip(haptic_device.inputs.iter())
        {
            for (range, v) in ranges.iter().zip(input) {
                let scaled = (v.load(SeqCst) as f64 - *range.start() as f64)
                    / (*range.end() as f64 - *range.start() as f64);
                match *input_type {
                    SensorType::Button => {
                        if button_index >= button_mappings.len() {
                            continue;
                        }
                        if scaled >= 0.5 {
                            buttons.insert(button_mappings[button_index]);
                        }
                        button_index += 1;
                    }
                    SensorType::Pressure => {
                        if axis_index >= axis_mappings.len() {
                            continue;
                        }
                        axis_mappings[axis_index](
                            gamepad,
                            (scaled * (i16::MAX as f64 - i16::MIN as f64) + i16::MIN as f64) as i16,
                        );
                        axis_index += 1;
                    }
                    _ => {}
                }
            }
        }
        gamepad.buttons = buttons;

        // Vibrators only past this point.
        if haptic_device.num_vibes == 0 {
            return;
        }

        // If we have exactly two vibrator actuators, map them directly.
        // Otherwise, set them all to the largest rumble value.
        let vibrate_command = if haptic_device.num_vibes == 2 {
            VibrateCommand::SpeedVec(
                [gamepad.lo_freq_rumble, gamepad.hi_freq_rumble]
                    .into_iter()
                    .map(|r| r as f64 / u8::MAX as f64)
                    .collect(),
            )
        } else {
            VibrateCommand::Speed(
                max(gamepad.lo_freq_rumble, gamepad.hi_freq_rumble) as f64 / u8::MAX as f64,
            )
        };
        let future = haptic_device.device.vibrate(&vibrate_command);
        self.rt.spawn(async move {
            if let Err(e) = future.await {
                println!("Buttplug client error: {e:?}");
            }
        });
    }
}

async fn handle_client_events<S>(
    rt: Arc<Runtime>,
    mut event_stream: S,
    devices: Arc<Mutex<BTreeSet<HapticDevice>>>,
) where
    S: Stream<Item = ButtplugClientEvent> + Unpin,
{
    while let Some(event) = event_stream.next().await {
        match event {
            ButtplugClientEvent::DeviceAdded(device) => {
                if let Ok(mut devices) = devices.lock() {
                    devices.insert(HapticDevice::new(rt.clone(), device));
                } else {
                    println!("Buttplug device set mutex poisoned!");
                }
            }
            ButtplugClientEvent::DeviceRemoved(device) => {
                println!("Buttplug device removed: {device:?}");
                if let Ok(mut devices) = devices.lock() {
                    devices.retain(|h| h.device != device);
                } else {
                    println!("Buttplug device set mutex poisoned!");
                }
            }
            ButtplugClientEvent::ServerDisconnect => {
                println!("Buttplug server disconnected");
                return;
            }
            ButtplugClientEvent::Error(e) => {
                println!("Buttplug error: {e:?}");
            }
            _ => {}
        }
    }
}

/// Buttplug device wrapper.
/// `Eq`/`Ord` assumes we'll never try to compare two different devices that exist simultaneously
/// but have the same device manager index, because how would that even happen?
#[derive(Debug, Clone)]
pub struct HapticDevice {
    device: Arc<ButtplugClientDevice>,
    num_vibes: usize,
    battery_level: Option<Arc<AtomicU8>>,
    input_props: Vec<(SensorType, Vec<RangeInclusive<u32>>)>,
    inputs: Arc<Vec<Vec<AtomicI32>>>,
}

impl Eq for HapticDevice {}

impl PartialEq<Self> for HapticDevice {
    fn eq(&self, other: &Self) -> bool {
        self.device.index() == other.device.index()
    }
}

impl PartialOrd<Self> for HapticDevice {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        self.device.index().partial_cmp(&other.device.index())
    }
}

impl Ord for HapticDevice {
    fn cmp(&self, other: &Self) -> Ordering {
        self.device.index().cmp(&other.device.index())
    }
}

impl HapticDevice {
    pub fn new(rt: Arc<Runtime>, device: Arc<ButtplugClientDevice>) -> Self {
        let num_vibes = if let Some(scalar_cmds) = device.message_attributes().scalar_cmd() {
            scalar_cmds
                .iter()
                .filter(|cmd| *cmd.actuator_type() == ActuatorType::Vibrate)
                .count()
        } else {
            0
        };

        let mut battery_level = None;
        if let Some(sensors) = device.message_attributes().sensor_read_cmd() {
            if sensors
                .iter()
                .find(|sensor| *sensor.sensor_type() == SensorType::Battery)
                .is_some()
            {
                battery_level = Some(Arc::new(AtomicU8::new(u8::MAX)));
                rt.spawn(monitor_battery(device.clone(), battery_level.clone()));
            }
        }

        // Only supported sensors count, and we total up the number of reported values inside a sensor.
        let mut num_sensors = 0usize;
        let mut input_props = vec![];
        let mut inputs = vec![];
        if let Some(sensors) = device.message_attributes().sensor_subscribe_cmd() {
            for sensor in sensors.iter().filter(|sensor| {
                vec![SensorType::Button, SensorType::Pressure].contains(sensor.sensor_type())
            }) {
                let ranges = sensor.sensor_range().clone();
                num_sensors += ranges.len();
                input_props.push((*sensor.sensor_type(), ranges));
                let mut input = vec![];
                for range in sensor.sensor_range() {
                    // TODO: sensor ranges and sensor data have different types, bug qdot about it
                    input.push(AtomicI32::new(*range.start() as i32));
                }
                inputs.push(input);
            }
        }
        let inputs = Arc::new(inputs);
        if num_sensors > 0 {
            rt.spawn(handle_device_events(device.clone(), inputs.clone()));
        }

        println!(
            "Buttplug device added: {device:?}, {num_vibes} vibration actuators, {num_sensors} sensors"
        );

        Self {
            device,
            num_vibes,
            battery_level,
            input_props,
            inputs,
        }
    }
}

async fn monitor_battery(device: Arc<ButtplugClientDevice>, battery_level: Option<Arc<AtomicU8>>) {
    let mut interval = time::interval(Duration::from_millis(1000));
    loop {
        interval.tick().await;
        match device.battery_level().await {
            Ok(level) => {
                if let Some(battery_level) = &battery_level {
                    battery_level.store((level * u8::MAX as f64) as u8, SeqCst);
                }
            }
            Err(e) => {
                println!("Ending battery monitor task due to error: {e:?}");
                return;
            }
        }
    }
}

async fn handle_device_events(device: Arc<ButtplugClientDevice>, inputs: Arc<Vec<Vec<AtomicI32>>>) {
    let mut event_stream = device.event_stream();
    for (sensor_index, sensor) in (0..).zip(
        device
            .message_attributes()
            .sensor_subscribe_cmd()
            .as_ref()
            .expect(
                "Shouldn't fail, we already checked for sensors in the HapticDevice constructor",
            )
            .iter()
            .filter(|sensor| {
                vec![SensorType::Button, SensorType::Pressure].contains(sensor.sensor_type())
            }),
    ) {
        let sensor_type = *sensor.sensor_type();
        if let Err(e) = device.subscribe_sensor(sensor_index, sensor_type).await {
            println!("Couldn't subscribe to {sensor_type} sensor at index {sensor_index}: {e:?}");
        }
    }
    while let Some(event) = event_stream.next().await {
        if let ButtplugClientDeviceEvent::Message(
            ButtplugCurrentSpecServerMessage::SensorReading(ref reading),
        ) = event
        {
            for (i, v) in reading.data().iter().enumerate() {
                inputs[reading.sensor_index() as usize][i].store(*v, SeqCst);
            }
        }
    }
}
