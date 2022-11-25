#[cfg(target_os = "linux")]
use caps;
use chrono::Duration;
use ctrlc;
use process_memory::Memory;
use sdl2;
use sdl2::{GameControllerSubsystem, JoystickSubsystem};
use std::cmp::min;
#[cfg(target_os = "linux")]
use std::env;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::channel;
use std::sync::Arc;
use timer::Timer;

mod constants;
mod error;
mod gamepad;
#[cfg(feature = "haptics")]
mod haptic_subsystem;
mod runtime_connection;

use crate::constants::{FRAME_DURATION_MS, PINPUT_MAGIC, PINPUT_MAX_GAMEPADS, SCAN_INTERVAL_MS};
use crate::error::Error;
use crate::gamepad::{sync_gamepad, PinputGamepadArray, SdlGamepad};
use crate::haptic_subsystem::HapticSubsystem;
use crate::runtime_connection::RuntimeConnection;

/// Look for a runtime with Pinput magic until we either find it or are killed.
fn scan_for_runtime_connection(keep_going: Arc<AtomicBool>) -> Result<RuntimeConnection, Error> {
    let (timer_tx, timer_rx) = channel();
    let timer = Timer::new();
    let _timer_guard = Some(timer.schedule_repeating(
        Duration::milliseconds(SCAN_INTERVAL_MS),
        move || {
            timer_tx
                .send(())
                .expect("we should always be able to send timer ticks")
        },
    ));
    while keep_going.load(Ordering::Relaxed) {
        timer_rx.recv()?;
        match RuntimeConnection::try_new() {
            Ok(runtime_connection) => return Ok(runtime_connection),
            Err(err) => println!("Failed to connect to a runtime: {:#?}", err),
        }
    }
    Err(Error::KilledByCtrlC)
}

/// Sync SDL gamepads with the runtime until the runtime quits or we are killed.
fn run_gamepad_loop(
    keep_going: &Arc<AtomicBool>,
    joystick_subsystem: &JoystickSubsystem,
    game_controller_subsystem: &GameControllerSubsystem,
    haptic_subsystem: &HapticSubsystem,
    runtime_connection: &RuntimeConnection,
) -> Result<(), Error> {
    let (timer_tx, timer_rx) = channel();
    let timer = Timer::new();
    let _timer_guard = Some(timer.schedule_repeating(
        Duration::milliseconds(FRAME_DURATION_MS),
        move || {
            timer_tx
                .send(())
                .expect("we should always be able to send timer ticks")
        },
    ));

    let mut gamepads: PinputGamepadArray;
    let mut sdl_gamepads: [Option<SdlGamepad>; PINPUT_MAX_GAMEPADS] = Default::default();
    while keep_going.load(Ordering::Relaxed) {
        timer_rx.recv()?;

        // Updates the state of all game controllers.
        // We could also run the SDL event loop, which would call this automatically.
        game_controller_subsystem.update();

        let magic = match runtime_connection.gpio_as_uuid.read() {
            Ok(magic) => magic,
            Err(err) => {
                // Failure here probably indicates that the runtime quit.
                println!(
                    "Failed to read from {}: {:#}",
                    runtime_connection.flavor, err
                );
                return Ok(());
            }
        };
        if magic == PINPUT_MAGIC {
            gamepads = PinputGamepadArray::default();
        } else {
            gamepads = match runtime_connection.gpio_as_gamepads.read() {
                Ok(gamepads) => gamepads,
                Err(err) => {
                    // Failure here probably indicates that the runtime quit.
                    println!(
                        "Failed to read from {}: {:#}",
                        runtime_connection.flavor, err
                    );
                    return Ok(());
                }
            }
        }

        // Handle gamepads.
        let sdl_num_joysticks = game_controller_subsystem
            .num_joysticks()
            .map_err(|s| Error::SdlStringError(s))?;
        for gamepad_index in 0..min(sdl_num_joysticks as usize, PINPUT_MAX_GAMEPADS) {
            if sdl_gamepads[gamepad_index].is_none() {
                let sdl_gamepad_index = gamepad_index as u32;
                if !game_controller_subsystem.is_game_controller(sdl_gamepad_index) {
                    continue;
                }
                let mut game_controller = game_controller_subsystem.open(sdl_gamepad_index)?;

                // There's no way to test for rumble support other than by trying it.
                // TODO: this will be fixed in SDL 2.0.18, with `SDL_GameControllerHasRumble`.
                let has_rumble = game_controller.set_rumble(1, 1, 0).is_ok();
                println!(
                    "{} {} rumble.",
                    game_controller.name(),
                    if has_rumble {
                        "supports"
                    } else {
                        "doesn't support"
                    }
                );

                sdl_gamepads[gamepad_index] = Some(SdlGamepad {
                    joystick: joystick_subsystem.open(sdl_gamepad_index)?,
                    game_controller,
                    has_rumble,
                });
            }

            let mut gamepad = &mut gamepads[gamepad_index];
            if let Some(sdl_gamepad) = &mut sdl_gamepads[gamepad_index] {
                sync_gamepad(sdl_gamepad, &mut gamepad)?;
            }
        }

        // Put haptic devices at the end of the list after gamepads.
        // TODO: this doesn't make a ton of sense as is since adding gamepads will renumber haptics.
        // TODO: when fixed, remember to zero out vibe info for Pinput gamepads past the last connected vibe.
        let haptic_devices = haptic_subsystem.devices();
        let gamepad_indexes = sdl_num_joysticks as usize
            ..min(
                sdl_num_joysticks as usize + haptic_devices.len(),
                PINPUT_MAX_GAMEPADS,
            );
        for (gamepad_index, haptic_device) in gamepad_indexes.zip(haptic_devices) {
            haptic_subsystem.sync_haptic_device(&haptic_device, &mut gamepads[gamepad_index]);
        }

        match runtime_connection.gpio_as_gamepads.write(&gamepads) {
            Ok(_) => (),
            Err(err) => {
                // Failure here probably indicates that the runtime quit.
                println!(
                    "Failed to write from {}: {:#}",
                    runtime_connection.flavor, err
                );
                return Ok(());
            }
        }
    }
    Err(Error::KilledByCtrlC)
}

#[cfg(target_os = "linux")]
fn check_prerequisites() -> Result<(), Error> {
    if caps::has_cap(
        None,
        caps::CapSet::Effective,
        caps::Capability::CAP_SYS_PTRACE,
    )? {
        Ok(())
    } else {
        eprintln!("Pinput is missing the CAP_SYS_PTRACE capability!");
        eprintln!(
            "Please run this command and restart Pinput: sudo setcap cap_sys_ptrace+ep {}",
            env::current_exe()?.to_string_lossy()
        );
        Err(Error::MissingPrerequisites)
    }
}

#[cfg(target_os = "macos")]
fn check_prerequisites() -> Result<(), Error> {
    // TODO: need to be root or in an entitled binary to do this on macOS
    // https://dev.to/jasonelwood/setup-gdb-on-macos-in-2020-489k
    Ok(())
}

#[cfg(not(any(target_os = "linux", target_os = "macos")))]
fn check_prerequisites() -> Result<(), Error> {
    Ok(())
}

fn main() -> Result<(), Error> {
    check_prerequisites()?;

    let keep_going = Arc::new(AtomicBool::new(true));
    let keep_going_ctrlc = keep_going.clone();
    ctrlc::set_handler(move || keep_going_ctrlc.store(false, Ordering::Relaxed))?;

    // Using the Windows raw input joystick driver breaks XInput devices on Windows.
    // https://github.com/MysteriousJ/Joystick-Input-Examples#rawinput suggests that raw input
    // needs a window to function, which we don't currently create.
    sdl2::hint::set("SDL_JOYSTICK_RAWINPUT", "0");

    let sdl_context = sdl2::init().map_err(|s| Error::SdlStringError(s))?;
    let joystick_subsystem = sdl_context
        .joystick()
        .map_err(|s| Error::SdlStringError(s))?;
    let game_controller_subsystem = sdl_context
        .game_controller()
        .map_err(|s| Error::SdlStringError(s))?;
    let haptic_subsystem = HapticSubsystem::new()?;

    // TODO: treat `KilledByCtrlC` as a normal exit.
    loop {
        let runtime_connection = scan_for_runtime_connection(keep_going.clone())?;
        println!(
            "connected: {}, PID {}",
            runtime_connection.flavor, runtime_connection.pid
        );
        run_gamepad_loop(
            &keep_going,
            &joystick_subsystem,
            &game_controller_subsystem,
            &haptic_subsystem,
            &runtime_connection,
        )?;
    }
}
