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
    if pressed {
        unsafe { *DRAW_COLORS = 3 }
    } else {
        unsafe { *DRAW_COLORS = 2 }
    }
    btext(label, x, y);
}

fn draw_dpad(gp: PinputGamepad) {
    let x: i32 = 40;
    let y: i32 = 120;
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
    if pressed {
        unsafe { *DRAW_COLORS = 0x30 }
    } else {
        unsafe { *DRAW_COLORS = 0x20 }
    }
    oval(x - 2, y - 2, 10, 10);
    if pressed {
        unsafe { *DRAW_COLORS = 3 }
    } else {
        unsafe { *DRAW_COLORS = 2 }
    }
    text(label, x, y);
}

fn draw_action_pad(gp: PinputGamepad) {
    let x: i32 = 120;
    let y: i32 = 120;
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

fn draw_analog_sticks(gp: PinputGamepad) {
    let x: i32 = 80;
    let y: i32 = 50;
    let d: i32 = 30;
    draw_analog_stick(x - d, y, gp.left_stick_x, gp.left_stick_y);
    draw_analog_stick(x + d, y, gp.right_stick_x, gp.right_stick_y);
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
    draw_analog_sticks(gp);
    draw_dpad(gp);
    draw_action_pad(gp);
}
