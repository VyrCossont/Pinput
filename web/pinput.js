const magic = [
    0x02,
    0x20,
    0xc7,
    0x46,
    0x77,
    0xab,
    0x44,
    0x6e,
    0xbe,
    0xdc,
    0x7f,
    0xd6,
    0xd2,
    0x77,
    0x98,
    0x4d,
];

const maxGamepads = 8;

const gamepadStride = 16;

const connected = 1 << 0;
const hasGuideButton = 1 << 3;

// Gamepad battery status not supported.

// See https://w3c.github.io/gamepad/#dfn-standard-gamepad for what we should be getting.
// What we're actually getting has the guide button at index 0 instead of 16.
// TODO: test in browsers other than Firefox

const buttonsLoOffset = 2;
const dpadUp = 1 << 0;
const dpadDown = 1 << 1;
const dpadLeft = 1 << 2;
const dpadRight = 1 << 3;
const start = 1 << 4;
const back = 1 << 5;
const leftStick = 1 << 6;
const rightStick = 1 << 7;

const buttonsHiOffset = 3;
const leftBumper = 1 << 0;
const rightBumper = 1 << 1;
const a = 1 << 2;
const b = 1 << 3;
const x = 1 << 4;
const y = 1 << 5;
const guide = 1 << 6;

const triggerMax = 0xff;
const leftTriggerOffset = 4;
const rightTriggerOffset = 5;

const axisMax = 0x7fff;
const leftStickXOffset = 6;
const leftStickYOffset = 8;
const rightStickXOffset = 10;
const rightStickYOffset = 12;

// TODO: rumble using Web Vibration API or GamepadHapticActuator (preferred)
const rumbleMax = 0xff;
const loFreqRumbleOffset = 14;
const hiFreqRumbleOffset = 15;

/** Called every animation frame to push gamepad inputs into PICO-8's GPIO area. */ 
function loop() {
    // Check for the magic that indicates that we should initialize Pinput.
    let shouldReinit = true;
    for (const [i, byte] of magic.entries()) {
        if (pico8_gpio[i] !== byte) {
            shouldReinit = false;
            break;
        }
    }
    if (shouldReinit) {
        // Zero the GPIO area.
        pico8_gpio.fill(0);
    }

    // Write each supported gamepad's current state into GPIO.
    // Note: `navigator.getGamepads()` does not return an array on Chrome.
    for (const [i, gamepad] of Array.from(navigator.getGamepads()).slice(0, maxGamepads).entries()) {
        const gamepadBase = i * gamepadStride;
        if (gamepad === null || gamepad.mapping !== 'standard' || !gamepad.connected) {
            // This is a disconnected or unsupported gamepad: zero it and go to the next one.
            pico8_gpio.fill(0, gamepadBase, gamepadBase + gamepadStride);
            continue;
        }

        // Assume any gamepad using the 'standard' mapping has a usable guide button.
        let flags = connected | hasGuideButton;
        pico8_gpio[gamepadBase] = flags;

        let buttonsLo = 0;
        if (gamepad.buttons[12].pressed) {
            buttonsLo |= dpadUp;
        }
        if (gamepad.buttons[13].pressed) {
            buttonsLo |= dpadDown;
        }
        if (gamepad.buttons[14].pressed) {
            buttonsLo |= dpadLeft;
        }
        if (gamepad.buttons[15].pressed) {
            buttonsLo |= dpadRight;
        }
        if (gamepad.buttons[9].pressed) {
            buttonsLo |= start;
        }
        if (gamepad.buttons[8].pressed) {
            buttonsLo |= back;
        }
        if (gamepad.buttons[10].pressed) {
            buttonsLo |= leftStick;
        }
        if (gamepad.buttons[11].pressed) {
            buttonsLo |= rightStick;
        }
        pico8_gpio[gamepadBase + buttonsLoOffset] = buttonsLo;

        let buttonsHi = 0;
        if (gamepad.buttons[4].pressed) {
            buttonsHi |= leftBumper;
        }
        if (gamepad.buttons[5].pressed) {
            buttonsHi |= rightBumper;
        }
        if (gamepad.buttons[0].pressed) {
            buttonsHi |= a;
        }
        if (gamepad.buttons[1].pressed) {
            buttonsHi |= b;
        }
        if (gamepad.buttons[2].pressed) {
            buttonsHi |= x;
        }
        if (gamepad.buttons[3].pressed) {
            buttonsHi |= y;
        }
        if (gamepad.buttons[16].pressed) {
            buttonsHi |= guide;
        }
        pico8_gpio[gamepadBase + buttonsHiOffset] = buttonsHi;
    }

    window.requestAnimationFrame(loop);
}

/** Call this to start running the update loop. */
export function init() {
    window.requestAnimationFrame(loop);
}
