use bitflags::bitflags;
use sdl2::controller::Button;
use sdl2::joystick::PowerLevel;

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
    /// with the addition of a guide button in the lowest unused bit.
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

        /// Does not correspond to any actual button.
        const RESERVED = 1 << 11;

        const A = 1 << 12;
        const B = 1 << 13;
        const X = 1 << 14;
        const Y = 1 << 15;
    }
}

impl From<Button> for PinputGamepadButtons {
    fn from(button: Button) -> Self {
        match button {
            Button::A => Self::A,
            Button::B => Self::B,
            Button::X => Self::X,
            Button::Y => Self::Y,
            Button::Back => Self::BACK,
            Button::Guide => Self::GUIDE,
            Button::Start => Self::START,
            Button::LeftStick => Self::LEFT_STICK,
            Button::RightStick => Self::RIGHT_STICK,
            Button::LeftShoulder => Self::LEFT_BUMPER,
            Button::RightShoulder => Self::RIGHT_BUMPER,
            Button::DPadUp => Self::DPAD_UP,
            Button::DPadDown => Self::DPAD_DOWN,
            Button::DPadLeft => Self::DPAD_LEFT,
            Button::DPadRight => Self::DPAD_RIGHT,
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
pub type PinputGamepadArray = [PinputGamepad; 8];
