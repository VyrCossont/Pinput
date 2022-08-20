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
    // left
    draw_dpad_btn(b"\x84", x - d, y, gp.buttons.contains(PinputGamepadButtons::DPAD_LEFT));
    // right
    draw_dpad_btn(b"\x85", x + d, y, gp.buttons.contains(PinputGamepadButtons::DPAD_RIGHT));
    // up
    draw_dpad_btn(b"\x86", x, y - d, gp.buttons.contains(PinputGamepadButtons::DPAD_UP));
    // down
    draw_dpad_btn(b"\x87", x, y + d, gp.buttons.contains(PinputGamepadButtons::DPAD_DOWN));
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
    draw_action_btn("X", x - d, y, gp.buttons.contains(PinputGamepadButtons::X));
    draw_action_btn("B", x + d, y, gp.buttons.contains(PinputGamepadButtons::B));
    draw_action_btn("Y", x, y - d, gp.buttons.contains(PinputGamepadButtons::Y));
    draw_action_btn("A", x, y + d, gp.buttons.contains(PinputGamepadButtons::A));
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

    draw_dpad(gp);
    draw_action_pad(gp);
}
