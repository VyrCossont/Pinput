//! Convenience wrappers for Buttplug.io objects.

use crate::error::Error;
use crate::gamepad::{PinputGamepad, PinputGamepadButtons, PinputGamepadFlags};
use buttplug::client::{ButtplugClient, ButtplugClientDevice, ButtplugClientEvent, VibrateCommand};
use buttplug::core::connector::{ButtplugRemoteClientConnector, ButtplugWebsocketClientTransport};
use buttplug::core::message::serializer::ButtplugClientJSONSerializer;
use buttplug::core::message::ActuatorType;
use buttplug::util::in_process_client;
use futures::{Stream, StreamExt};
use std::cmp::{max, Ordering};
use std::collections::BTreeSet;
use std::sync::{Arc, Mutex};
use tokio::runtime::Runtime;

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
                let num_vibes = device.num_vibration_actuators();
                println!("Buttplug device connected: {device:?}, {num_vibes} vibration actuators");
                devices.insert(HapticDevice::new(device));
            }
        } else {
            println!("Buttplug device set mutex poisoned!");
        }

        rt.block_on(client.start_scanning())?;
        let event_stream = client.event_stream();
        rt.spawn(handle_client_events(event_stream, devices.clone()));
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
        let num_vibes = haptic_device.device.num_vibration_actuators();
        if num_vibes > 0 {
            gamepad.flags.insert(PinputGamepadFlags::HAS_RUMBLE);
        } else {
            println!(
                "Buttplug device {} does not support vibration",
                haptic_device.device.name()
            );
        }

        // TODO: battery and charging state
        gamepad.battery = 0;

        // Buttplug doesn't currently support buttons/sensors, so zero out the inputs.
        // TODO: add sensor support to upstream
        gamepad.buttons = PinputGamepadButtons::default();
        gamepad.left_trigger = 0;
        gamepad.right_trigger = 0;
        gamepad.left_stick_x = 0;
        gamepad.left_stick_y = 0;
        gamepad.right_stick_x = 0;
        gamepad.right_stick_y = 0;

        // Vibrators only past this point.
        if num_vibes == 0 {
            return;
        }

        // If we have exactly two vibrator actuators, map them directly.
        // Otherwise, set them all to the largest rumble value.
        let vibrate_command = if num_vibes == 2 {
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

async fn handle_client_events<S>(mut event_stream: S, devices: Arc<Mutex<BTreeSet<HapticDevice>>>)
where
    S: Stream<Item = ButtplugClientEvent> + Unpin,
{
    while let Some(event) = event_stream.next().await {
        match event {
            ButtplugClientEvent::DeviceAdded(device) => {
                let num_vibes = device.num_vibration_actuators();
                println!("Buttplug device added: {device:?}, {num_vibes} vibration actuators");
                if let Ok(mut devices) = devices.lock() {
                    devices.insert(HapticDevice::new(device));
                } else {
                    println!("Buttplug device set mutex poisoned!");
                }
            }
            ButtplugClientEvent::DeviceRemoved(device) => {
                println!("Buttplug device removed: {device:?}");
                if let Ok(mut devices) = devices.lock() {
                    devices.remove(&HapticDevice::new(device));
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

/// Convenience methods for Buttplug devices.
trait ButtplugClientDeviceExt {
    fn num_vibration_actuators(&self) -> usize;
}

impl ButtplugClientDeviceExt for ButtplugClientDevice {
    fn num_vibration_actuators(&self) -> usize {
        self.message_attributes()
            .scalar_cmd()
            .as_ref()
            .map(|cmds| {
                cmds.iter()
                    .filter(|cmd| *cmd.actuator_type() == ActuatorType::Vibrate)
                    .count()
            })
            .unwrap_or(0)
    }
}

/// Buttplug device wrapper.
/// `Eq`/`Ord` assumes we'll never try to compare two different devices that exist simultaneously
/// but have the same device manager index, because how would that even happen?
#[derive(Debug, Clone)]
pub struct HapticDevice {
    device: Arc<ButtplugClientDevice>,
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
    pub fn new(device: Arc<ButtplugClientDevice>) -> Self {
        Self { device }
    }
}
