#[cfg(feature = "buddy-alloc")]
mod alloc;
mod gamepad;
mod wasm4;
use gamepad::*;
use wasm4::*;

/// WASM-4 `text()` actually expects ASCII with some nonstandard escapes, not UTF-8.
fn btext(t: &[u8], x: i32, y: i32) {
    let extd_ascii_text = unsafe {
        std::str::from_utf8_unchecked(t)
    };
    text(extd_ascii_text, x, y);
}

fn draw_dpad_btn(label: &[u8], x: i32, y: i32, pressed: bool) {
    let r: i32 = 5;
    if pressed {
        unsafe { *DRAW_COLORS = 3 }
    } else {
        unsafe { *DRAW_COLORS = 2 }
    }
    btext(label, x - r + 2, y - r + 2);
}

fn draw_dpad(gp: PinputGamepad) {
    let x: i32 = 50;
    let y: i32 = 110;
    let d: i32 = 10;
    // `{gp.buttons}` removes a soon-to-be-illegal unaligned access to a packed struct field.
    // left
    draw_dpad_btn(b"\x84", x - d, y, {gp.buttons}.contains(PinputGamepadButtons::DPAD_LEFT));
    // right
    draw_dpad_btn(b"\x85", x + d, y, {gp.buttons}.contains(PinputGamepadButtons::DPAD_RIGHT));
    // up
    draw_dpad_btn(b"\x86", x, y - d, {gp.buttons}.contains(PinputGamepadButtons::DPAD_UP));
    // down
    draw_dpad_btn(b"\x87", x, y + d, {gp.buttons}.contains(PinputGamepadButtons::DPAD_DOWN));
}

fn draw_action_btn(label: &str, x: i32, y: i32, pressed: bool) {
    let r: i32 = 5;
    unsafe { *DRAW_COLORS = 0x20 }
    oval(x - r, y - r, 2 * r as u32, 2 * r as u32);
    if pressed {
        unsafe { *DRAW_COLORS = 3 }
    } else {
        unsafe { *DRAW_COLORS = 2 }
    }
    text(label, x - r + 2, y - r + 2);
}

fn draw_action_pad(gp: PinputGamepad) {
    let x: i32 = 110;
    let y: i32 = 110;
    let d: i32 = 10;
    // `{gp.buttons}` removes a soon-to-be-illegal unaligned access to a packed struct field.
    draw_action_btn("X", x - d, y, {gp.buttons}.contains(PinputGamepadButtons::X));
    draw_action_btn("B", x + d, y, {gp.buttons}.contains(PinputGamepadButtons::B));
    draw_action_btn("Y", x, y - d, {gp.buttons}.contains(PinputGamepadButtons::Y));
    draw_action_btn("A", x, y + d, {gp.buttons}.contains(PinputGamepadButtons::A));
}

fn draw_analog_stick(center_x: i32, center_y: i32, stick_x: i16, stick_y: i16) {
    let big_r: i32 = 20;
    let small_r: i32 = 5;
    unsafe { *DRAW_COLORS = 0x20 }
    oval(center_x - big_r, center_y - big_r, 2 * big_r as u32, 2 * big_r as u32);
    let thumb_x = ((stick_x as i32) * big_r) / -(i16::MIN as i32);
    let thumb_y = -((stick_y as i32) * big_r) / -(i16::MIN as i32);
    unsafe { *DRAW_COLORS = 0x33 }
    oval(center_x - small_r + thumb_x, center_y - small_r + thumb_y, 2 * small_r as u32, 2 * small_r as u32);
}

fn draw_big_btn(label: &str, x: i32, y: i32, pressed: bool) {
    let r: i32 = 9;
    unsafe { *DRAW_COLORS = 0x20 }
    oval(x - r, y - r, 2 * r as u32, 2 * r as u32);
    if pressed {
        unsafe { *DRAW_COLORS = 3 }
    } else {
        unsafe { *DRAW_COLORS = 2 }
    }
    text(label, x - r + 2, y - r + 6);
}

fn draw_analog_sticks(gp: PinputGamepad) {
    let x: i32 = 80;
    let y: i32 = 70;
    let d: i32 = 30;
    let click_d: i32 = 65;
    draw_analog_stick(x - d, y, gp.left_stick_x, gp.left_stick_y);
    draw_analog_stick(x + d, y, gp.right_stick_x, gp.right_stick_y);
    draw_big_btn("LS", x - click_d, y, {gp.buttons}.contains(PinputGamepadButtons::LEFT_STICK));
    draw_big_btn("RS", x + click_d, y, {gp.buttons}.contains(PinputGamepadButtons::RIGHT_STICK));
}

#[rustfmt::skip]
const RUMBLE_LEFT: [u8; 8] = [
    0b00010011,
    0b00100100,
    0b01001001,
    0b01010011,
    0b01010011,
    0b01001001,
    0b00100100,
    0b00010011,
];

#[rustfmt::skip]
const RUMBLE_RIGHT: [u8; 8] = [
    0b11001000,
    0b00100100,
    0b10010010,
    0b11001010,
    0b11001010,
    0b10010010,
    0b00100100,
    0b11001000,
];

fn draw_triggers(gp: PinputGamepad) {
    let x: i32 = 80;
    let y: i32 = 30;
    let d: i32 = 30;
    let rx: i32 = 40;
    let ry: i32 = 10;
    let click_d: i32 = 65;

    // trigger values
    let lt_x: u32 = (({ gp.left_trigger } as u32) * (rx as u32)) / (u8::MAX as u32);
    let rt_x: u32 = (({ gp.right_trigger } as u32) * (rx as u32)) / (u8::MAX as u32);
    unsafe { *DRAW_COLORS = 3 }
    rect(x - d - (rx / 2), y - (ry / 2), lt_x, ry as u32);
    rect(x + d - (rx / 2) + (rx - (rt_x as i32)), y - (ry / 2), rt_x, ry as u32);

    // trigger frames
    unsafe { *DRAW_COLORS = 0x20 }
    rect(x - d - (rx / 2), y - (ry / 2), rx as u32, ry as u32);
    rect(x + d - (rx / 2), y - (ry / 2), rx as u32, ry as u32);

    // rumble indicators
    if {gp.flags}.contains(PinputGamepadFlags::HAS_RUMBLE) {
        if lt_x > 0 {
            unsafe { *DRAW_COLORS = 0x30 }
        } else {
            unsafe { *DRAW_COLORS = 0x20 }
        }
        blit(&RUMBLE_LEFT, x - 8, y - 4, 8, 8, BLIT_1BPP);

        if rt_x > 0 {
            unsafe { *DRAW_COLORS = 0x30 }
        } else {
            unsafe { *DRAW_COLORS = 0x20 }
        }
        blit(&RUMBLE_RIGHT, x, y - 4, 8, 8, BLIT_1BPP);
    }

    // bumpers
    draw_big_btn("LB", x - click_d, y, {gp.buttons}.contains(PinputGamepadButtons::LEFT_BUMPER));
    draw_big_btn("RB", x + click_d, y, {gp.buttons}.contains(PinputGamepadButtons::RIGHT_BUMPER));
}

#[rustfmt::skip]
const HOUSE: [u8; 8] = [
    0b00000000,
    0b00111000,
    0b01111100,
    0b11111110,
    0b01010100,
    0b01011100,
    0b00000000,
    0b00000000,
];

#[rustfmt::skip]
const STAR: [u8; 8] = [
    0b00000000,
    0b00010000,
    0b00111000,
    0b11111110,
    0b01111100,
    0b01000100,
    0b00000000,
    0b00000000,
];

fn draw_sprite_btn(data: &[u8], x: i32, y: i32, pressed: bool) {
    if pressed {
        unsafe { *DRAW_COLORS = 0x30 }
    } else {
        unsafe { *DRAW_COLORS = 0x20 }
    }
    blit(data, x - 3, y - 3, 8, 8, BLIT_1BPP);
}

fn draw_menu_buttons(gp: PinputGamepad) {
    let x: i32 = 80;
    let y: i32 = 50;
    let dx: i32 = 9;
    let dy: i32 = 8;
    // back
    draw_dpad_btn(b"\x84", x - dx, y, { gp.buttons }.contains(PinputGamepadButtons::BACK));
    // start
    draw_dpad_btn(b"\x85", x + dx, y, { gp.buttons }.contains(PinputGamepadButtons::START));
    // home
    if { gp.flags }.contains(PinputGamepadFlags::HAS_GUIDE_BUTTON) {
        draw_sprite_btn(&HOUSE, x, y, { gp.buttons }.contains(PinputGamepadButtons::GUIDE));
    }
    // misc
    if { gp.flags }.contains(PinputGamepadFlags::HAS_MISC_BUTTON) {
        draw_sprite_btn(&STAR, x, y + dy, { gp.buttons }.contains(PinputGamepadButtons::MISC));
    }
}

#[rustfmt::skip]
const BATTERY: [u8; 8] = [
    0b00000000,
    0b01100110,
    0b11111111,
    0b11011111,
    0b10001001,
    0b11011111,
    0b11111111,
    0b00000000,
];

#[rustfmt::skip]
const BOLT: [u8; 8] = [
    0b00000000,
    0b00011000,
    0b00110000,
    0b00011000,
    0b00001100,
    0b00001000,
    0b00010000,
    0b00000000,
];

fn draw_battery(gp: PinputGamepad) {
    if !{gp.flags}.contains(PinputGamepadFlags::HAS_BATTERY) { return }

    let x: i32 = 80;
    let y: i32 = 130;
    unsafe { *DRAW_COLORS = 0x20 }
    blit(&BATTERY, x - 3, y - 3, 8, 8, BLIT_1BPP);

    if {gp.flags}.contains(PinputGamepadFlags::CHARGING) {
        unsafe { *DRAW_COLORS = 0x30 }
        blit(&BOLT, x - 10, y - 3, 8, 8, BLIT_1BPP);
    }

    unsafe { *DRAW_COLORS = 3 }
    text(format!("{}%", {gp.battery as i32} * 100 / (u8::MAX as i32)), x - 8, y + 6);
}

fn cls(color: u8) {
    if color == 0 { return }
    let c = color - 1;
    unsafe {
        (*FRAMEBUFFER).fill(c << 6 | c << 4 | c << 2 | c);
    }
}

#[no_mangle]
fn start() {
    pi_init();
}

#[no_mangle]
fn update() {
    cls(1);

    unsafe { *DRAW_COLORS = 2 }
    if !pi_is_inited() {
        text("waiting for Pinput", 10, 10);
        text("   connection...", 10, 20);
        return;
    }

    let gp = unsafe { (*PI_GAMEPADS)[0] };
    draw_triggers(gp);
    draw_analog_sticks(gp);
    draw_dpad(gp);
    draw_action_pad(gp);
    draw_menu_buttons(gp);
    draw_battery(gp);

    if {gp.flags}.contains(PinputGamepadFlags::HAS_RUMBLE) {
        unsafe {
            (*PI_GAMEPADS)[0].lo_freq_rumble = gp.left_trigger;
            (*PI_GAMEPADS)[0].hi_freq_rumble = gp.right_trigger;
        }
    }
}
