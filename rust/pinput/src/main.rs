use ctrlc;
use sdl2;
use sdl2::controller::{Axis, Button};
use sdl2::joystick::PowerLevel;
use std::cmp::min;
use std::sync::Arc;
use std::sync::mpsc::channel;
use std::sync::atomic::{AtomicBool, Ordering};
use timer::Timer;
use chrono::Duration;
use process_memory::Memory;

mod pico8_connection;
mod constants;
mod gamepad;

use constants::{PINPUT_MAGIC, PINPUT_MAX_GAMEPADS};
use pico8_connection::Pico8Connection;
use gamepad::{PinputGamepadFlags, PinputGamepadButtons, PinputGamepadArray};

#[derive(thiserror::Error, Debug)]
enum Error {
    #[error("SDL error: {0}")]
    SdlStringError(String),

    #[error("SDL error: {0}")]
    SdlError(#[from] sdl2::IntegerOrSdlError),

    #[error("PICO-8 connection error")]
    Pico8Connection(#[from] pico8_connection::Error),

    #[error("Ctrl-C handler error")]
    CtrlC(#[from] ctrlc::Error),

    #[error("channel error")]
    RecvError(#[from] std::sync::mpsc::RecvError),

    #[error("I/O error")]
    IOError(#[from] std::io::Error),
}

/// There's no convenient way to iterate over an enum,
/// but fortunately this one doesn't change very often.
const SDL_GAME_CONTROLLER_BUTTONS: [Button; 15] = [
    Button::A,
    Button::B,
    Button::X,
    Button::Y,
    Button::Back,
    Button::Guide,
    Button::Start,
    Button::LeftStick,
    Button::RightStick,
    Button::LeftShoulder,
    Button::RightShoulder,
    Button::DPadUp,
    Button::DPadDown,
    Button::DPadLeft,
    Button::DPadRight,
];

fn main() -> Result<(), Error> {
    let keep_going = Arc::new(AtomicBool::new(true));
    let keep_going_ctrlc = keep_going.clone();
    ctrlc::set_handler(move || keep_going_ctrlc.store(false, Ordering::Relaxed))?;

    let sdl_context = sdl2::init()
        .map_err(|s| Error::SdlStringError(s))?;
    let joystick_subsystem = sdl_context.joystick()
        .map_err(|s| Error::SdlStringError(s))?;
    let game_controller_subsystem = sdl_context.game_controller()
        .map_err(|s| Error::SdlStringError(s))?;
    let num_joysticks = game_controller_subsystem.num_joysticks()
        .map_err(|s| Error::SdlStringError(s))?;
    let num_gamepads = (0..num_joysticks)
        .map(|i| game_controller_subsystem.is_game_controller(i))
        .filter(|x| *x)
        .count();
    println!(
        "Hello, world! Found {} joysticks including {} gamepads",
        num_joysticks,
        num_gamepads
    );

    // TODO: handle getting disconnected when the process dies,
    //  and reconnecting when a new one shows up.
    let pico8_connection = Pico8Connection::try_new()?;
    println!("connected: {:#?}", pico8_connection);

    let frame_duration = Duration::microseconds(16667);
    let (timer_tx, timer_rx) = channel();
    let timer = Timer::new();
    let _timer_guard = Some(timer.schedule_repeating(
        frame_duration,
        move || timer_tx.send(())
            .expect("we should always be able to send timer ticks")
    ));

    let mut gamepads: PinputGamepadArray;
    while keep_going.load(Ordering::Relaxed) {
        timer_rx.recv()?;

        let magic = pico8_connection.gpio_as_uuid.read()?;
        if magic == PINPUT_MAGIC {
            gamepads = PinputGamepadArray::default();
        } else {
            gamepads = pico8_connection.gpio_as_gamepads.read()?;
        }

        let sdl_num_joysticks = game_controller_subsystem.num_joysticks()
            .map_err(|s| Error::SdlStringError(s))?;
        for gamepad_index in 0..min(sdl_num_joysticks as usize, PINPUT_MAX_GAMEPADS) {
            let joystick_index = gamepad_index as u32;
            if !game_controller_subsystem.is_game_controller(joystick_index) {
                continue;
            }

            // TODO: should we be getting joysticks by index or by `SDL_JoystickInstanceID`?
            // TODO: should we be opening them every frame or just once?
            let joystick = joystick_subsystem.open(joystick_index)?;
            let mut game_controller = game_controller_subsystem.open(joystick_index)?;
            let gamepad = &mut gamepads[gamepad_index];

            // TODO: test rumble
            game_controller.set_rumble(
                ((gamepad.lo_freq_rumble as f64) / (u8::MAX as f64) * (u16::MAX as f64)) as u16,
                ((gamepad.hi_freq_rumble as f64) / (u8::MAX as f64) * (u16::MAX as f64)) as u16,
                frame_duration.num_milliseconds() as u32
            )?;

            // Read gamepad capabilities and power level.
            gamepad.flags = PinputGamepadFlags::default();
            gamepad.flags.insert(PinputGamepadFlags::CONNECTED);
            // The SDL game controller API allows access to the Guide button, in theory.
            // TODO: does this work with XInput controllers on Windows?
            gamepad.flags.insert(PinputGamepadFlags::HAS_GUIDE_BUTTON);
            // SDL doesn't currently have a way to tell if a gamepad is charging.
            let power_level = joystick.power_level()?;
            gamepad.flags.insert(PinputGamepadFlags::from(power_level));
            match power_level {
                PowerLevel::Low => {
                    gamepad.battery = u8::MAX / 3;
                },
                PowerLevel::Medium => {
                    gamepad.battery = u8::MAX / 3 * 2;
                },
                PowerLevel::Full => {
                    gamepad.battery = u8::MAX;
                },
                _ => {
                    gamepad.battery = 0;
                },
            }

            // Read gamepad buttons.
            // Temporary variable used to avoid an unaligned access.
            let mut buttons = PinputGamepadButtons::default();
            for button in SDL_GAME_CONTROLLER_BUTTONS {
                if game_controller.button(button) {
                    buttons.insert(PinputGamepadButtons::from(button))
                }
            }
            gamepad.buttons = buttons;

            // Read gamepad axes (including triggers).
            // Note that SDL Y axes are upside-down compared to XInput:
            // <https://github.com/libsdl-org/SDL/blob/9130f7c/src/joystick/windows/SDL_xinputjoystick.c#L462-L465>
            gamepad.left_stick_x = game_controller.axis(Axis::LeftX);
            gamepad.left_stick_y = !game_controller.axis(Axis::LeftY);
            gamepad.right_stick_x = game_controller.axis(Axis::RightX);
            gamepad.right_stick_y = !game_controller.axis(Axis::RightY);
            gamepad.left_trigger = (game_controller.axis(Axis::TriggerLeft) / 0x80) as u8;
            gamepad.right_trigger = (game_controller.axis(Axis::TriggerRight) / 0x80) as u8;
        }

        pico8_connection.gpio_as_gamepads.write(&gamepads)?;
    }

    Ok(())
}
