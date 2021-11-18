use bitflags::bitflags;
use sdl2::controller::{Axis, Button, GameController};
use sdl2::joystick::{Joystick, PowerLevel};

use crate::constants::{FRAME_DURATION_MS, PINPUT_MAX_GAMEPADS};
use crate::error::Error;

bitflags! {
    /// Gamepad informational flags.
    #[derive(Default)]
    pub struct PinputGamepadFlags: u8 {
        /// This gamepad is connected.
        const CONNECTED = 1 << 0;

        /// This gamepad has a battery.
        /// If this is true, the `battery` field and the `Charging` flag may be non-zero.
        const HAS_BATTERY = 1 << 1;

        /// This gamepad is currently charging its battery.
        const CHARGING = 1 << 2;

        /// Does this controller have a usable guide button?
        /// Not all Apple-supported gamepads have a guide button,
        /// and versions of Pinput on other platforms might not have access to them
        /// (XInput on Windows, for example).
        const HAS_GUIDE_BUTTON = 1 << 3;

        /// Does this controller have a misc or touchpad-click button?
        const HAS_MISC_BUTTON = 1 << 4;
    }
}

impl From<PowerLevel> for PinputGamepadFlags {
    fn from(power_level: PowerLevel) -> Self {
        match power_level {
            PowerLevel::Wired | PowerLevel::Unknown => Self::empty(),
            _ => Self::HAS_BATTERY,
        }
    }
}

bitflags! {
    /// Flags indicating which buttons are currently pressed.
    /// Same as <https://docs.microsoft.com/en-us/windows/win32/api/xinput/ns-xinput-xinput_gamepad>
    /// with the addition of guide and misc buttons in the two unused bits.
    #[derive(Default)]
    pub struct PinputGamepadButtons: u16 {
        const DPAD_UP = 1 << 0;
        const DPAD_DOWN = 1 << 1;
        const DPAD_LEFT = 1 << 2;
        const DPAD_RIGHT = 1 << 3;

        const START = 1 << 4;
        const BACK = 1 << 5;

        const LEFT_STICK = 1 << 6;
        const RIGHT_STICK = 1 << 7;

        const LEFT_BUMPER = 1 << 8;
        const RIGHT_BUMPER = 1 << 9;

        const GUIDE = 1 << 10;
        /// We map both SDL `Misc1` and `Touchpad` to this.
        /// No current controllers have both buttons, and they're in approximately the same spot.
        const MISC = 1 << 11;

        const A = 1 << 12;
        const B = 1 << 13;
        const X = 1 << 14;
        const Y = 1 << 15;
    }
}

#[derive(thiserror::Error, Debug)]
pub enum PinputGamepadButtonsError {
    #[error("Unsupported SDL button: {0:#?}")]
    Unsupported(Button),
}

impl TryFrom<Button> for PinputGamepadButtons {
    type Error = PinputGamepadButtonsError;

    fn try_from(button: Button) -> Result<Self, Self::Error> {
        match button {
            Button::A => Ok(Self::A),
            Button::B => Ok(Self::B),
            Button::X => Ok(Self::X),
            Button::Y => Ok(Self::Y),
            Button::Back => Ok(Self::BACK),
            Button::Guide => Ok(Self::GUIDE),
            Button::Start => Ok(Self::START),
            Button::Misc1 => Ok(Self::MISC),
            Button::LeftStick => Ok(Self::LEFT_STICK),
            Button::RightStick => Ok(Self::RIGHT_STICK),
            Button::LeftShoulder => Ok(Self::LEFT_BUMPER),
            Button::RightShoulder => Ok(Self::RIGHT_BUMPER),
            Button::DPadUp => Ok(Self::DPAD_UP),
            Button::DPadDown => Ok(Self::DPAD_DOWN),
            Button::DPadLeft => Ok(Self::DPAD_LEFT),
            Button::DPadRight => Ok(Self::DPAD_RIGHT),
            Button::Touchpad => Ok(Self::MISC),
            button => Err(Self::Error::Unsupported(button)),
        }
    }
}

/// Structure representing a gamepad to PICO-8.
/// Based on <https://docs.microsoft.com/en-us/windows/win32/api/xinput/ns-xinput-xinput_gamepad>
/// and <https://docs.microsoft.com/en-us/windows/win32/api/xinput/ns-xinput-xinput_vibration>
/// but prefixed with controller flags and a battery meter, and with smaller rumble types to fit
/// into a convenient size (16 bytes). All fields are written to PICO-8,
/// except for the rumble fields, which are read from PICO-8.
#[repr(C, packed)]
#[derive(Copy, Clone, Debug, Default)]
pub struct PinputGamepad {
    pub flags: PinputGamepadFlags,
    /// 0 for empty or not present, max value for fully charged.
    pub battery: u8,
    pub buttons: PinputGamepadButtons,

    pub left_trigger: u8,
    pub right_trigger: u8,

    pub left_stick_x: i16,
    pub left_stick_y: i16,

    pub right_stick_x: i16,
    pub right_stick_y: i16,

    /// Output from PICO-8.
    pub lo_freq_rumble: u8,
    /// Output from PICO-8.
    pub hi_freq_rumble: u8,
}

/// Fill GPIO with gamepads.
pub type PinputGamepadArray = [PinputGamepad; PINPUT_MAX_GAMEPADS];

/// There's no convenient way to iterate over an enum,
/// but fortunately this one doesn't change very often.
const SDL_GAME_CONTROLLER_BUTTONS: [Button; 17] = [
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
    Button::Misc1,
    Button::Touchpad,
];

/// SDL has two subsystems for accessing parts of the same device.
pub struct SdlGamepad {
    /// Used to check the power level.
    pub joystick: Joystick,
    /// Used for everything else.
    pub game_controller: GameController,
    /// Can this gamepad rumble? We can only test by trying it.
    pub rumble_capable: bool,
}

pub fn sync_gamepad(sdl_gamepad: &mut SdlGamepad, gamepad: &mut PinputGamepad) -> Result<(), Error> {
    let game_controller = &mut sdl_gamepad.game_controller;
    let joystick = &sdl_gamepad.joystick;

    if !game_controller.attached() {
        *gamepad = PinputGamepad::default();
        return Ok(())
    }

    // Set rumble effects, if we can.
    // Some devices (Xbox model 1708 on macOS over Bluetooth is one) don't support rumble;
    // others need hints like `SDL_JOYSTICK_HIDAPI_PS4_RUMBLE` to be set, plus testing.
    if sdl_gamepad.rumble_capable {
        game_controller.set_rumble(
            ((gamepad.lo_freq_rumble as f64) / (u8::MAX as f64) * (u16::MAX as f64)) as u16,
            ((gamepad.hi_freq_rumble as f64) / (u8::MAX as f64) * (u16::MAX as f64)) as u16,
            FRAME_DURATION_MS as u32
        ).err().into_iter().for_each(|err| {
            sdl_gamepad.rumble_capable = false;
            println!("{} doesn't support rumble: {}", game_controller.name(), err);
        });
    }

    // Read gamepad capabilities and power level.
    gamepad.flags = PinputGamepadFlags::default();
    gamepad.flags.insert(PinputGamepadFlags::CONNECTED);
    let mapping = game_controller.mapping();
    if mapping.contains("guide:") {
        gamepad.flags.insert(PinputGamepadFlags::HAS_GUIDE_BUTTON);
    }
    if mapping.contains("misc1:") || mapping.contains("touchpad:") {
        gamepad.flags.insert(PinputGamepadFlags::HAS_MISC_BUTTON);
    }
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
            if let Ok(button) = PinputGamepadButtons::try_from(button) {
                buttons.insert(button);
            }
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
    gamepad.left_trigger = (game_controller.axis(Axis::TriggerLeft) / 0x81) as u8;
    gamepad.right_trigger = (game_controller.axis(Axis::TriggerRight) / 0x81) as u8;

    Ok(())
}
