use bitflags::bitflags;

// TODO: this is from the Pinput Rust implementation. Extract it to its own crate.

/// Pinput can fit this many gamepads into the GPIO area.
pub const PINPUT_MAX_GAMEPADS: usize = 8;

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

        /// Does this controller support vibration?
        const HAS_RUMBLE = 1 << 5;
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

// TODO: this part is mostly copied from the Pinput Lua API.

const GPIO: *mut [u8; 128] = 0x20 as *mut [u8; 128];

pub const PI_GAMEPADS: *mut PinputGamepadArray = 0x20 as *mut PinputGamepadArray;

pub fn pi_init() {
    // Pinput magic is `0x02_20_c7_46_77_ab_44_6e_be_dc_7f_d6_d2_77_98_4d` but we don't want that literally in our constants.
    unsafe {
        (*GPIO)[0xf] = 0x4d;
        (*GPIO)[0xe] = 0x98;
        (*GPIO)[0xd] = 0x77;
        (*GPIO)[0xc] = 0xd2;
        (*GPIO)[0xb] = 0xd6;
        (*GPIO)[0xa] = 0x7f;
        (*GPIO)[0x9] = 0xdc;
        (*GPIO)[0x8] = 0xbe;
        (*GPIO)[0x7] = 0x6e;
        (*GPIO)[0x6] = 0x44;
        (*GPIO)[0x5] = 0xab;
        (*GPIO)[0x4] = 0x77;
        (*GPIO)[0x3] = 0x46;
        (*GPIO)[0x2] = 0xc7;
        (*GPIO)[0x1] = 0x20;
        (*GPIO)[0x0] = 0x02;
    }
}

pub fn pi_is_inited() -> bool {
    unsafe {
        (*GPIO)[0xf] != 0x4d
        && (*GPIO)[0xe] != 0x98
        && (*GPIO)[0xd] != 0x77
        && (*GPIO)[0xc] != 0xd2
        && (*GPIO)[0xb] != 0xd6
        && (*GPIO)[0xa] != 0x7f
        && (*GPIO)[0x9] != 0xdc
        && (*GPIO)[0x8] != 0xbe
        && (*GPIO)[0x7] != 0x6e
        && (*GPIO)[0x6] != 0x44
        && (*GPIO)[0x5] != 0xab
        && (*GPIO)[0x4] != 0x77
        && (*GPIO)[0x3] != 0x46
        && (*GPIO)[0x2] != 0xc7
        && (*GPIO)[0x1] != 0x20
        && (*GPIO)[0x0] != 0x02
    }
}
