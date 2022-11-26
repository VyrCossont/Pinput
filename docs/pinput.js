/**
 * Pinput server for cartridges exported to web format.
 * Include this module in your exported HTML and call `Pinput.init()`,
 * and it should work the same way as the desktop versions.
 *
 * v0.1.3 by @vyr@demon.social
 */

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
const hasMiscButton = 1 << 4;
const hasRumble = 1 << 5;
const hapticDevice = 1 << 6;

// Gamepad battery status not supported.

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
const guide = 1 << 2;
const misc = 1 << 3;
const a = 1 << 4;
const b = 1 << 5;
const x = 1 << 6;
const y = 1 << 7;

const triggerMax = 0xff;
const leftTriggerOffset = 4;
const rightTriggerOffset = 5;
const triggerMappings = new Map();
triggerMappings.set(6, leftTriggerOffset);
triggerMappings.set(7, rightTriggerOffset);

const axisMax = 0x7fff;
const leftStickXOffset = 6;
const leftStickYOffset = 8;
const rightStickXOffset = 10;
const rightStickYOffset = 12;
const axisMappings = new Map();
axisMappings.set(0, [leftStickXOffset, 1]);
axisMappings.set(1, [leftStickYOffset, -1]);
axisMappings.set(2, [rightStickXOffset, 1]);
axisMappings.set(3, [rightStickYOffset, -1]);

const rumbleMax = 0xff;
const loFreqRumbleOffset = 14;
const hiFreqRumbleOffset = 15;
const rumbleDurationMs = 33; // 2 PICO-8 frames.
const rumbleMappings = new Map();
rumbleMappings.set(0, [loFreqRumbleOffset, 'weakMagnitude']);
rumbleMappings.set(1, [hiFreqRumbleOffset, 'strongMagnitude']);

let buttplugInitAttempted = false;
/** @type Buttplug.ButtplugClient */
let buttplugClient = null;

/** Called by `loop` to push gamepad inputs into PICO-8's GPIO area. */
async function sync() {
    let gpio;
    if (window.wrappedJSObject !== undefined) {
        // We're in a Firefox extension content script:
        // https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Sharing_objects_with_page_scripts
        gpio = window.wrappedJSObject.pico8_gpio;
    } else {
        gpio = window.pico8_gpio;
    }
    if (gpio === undefined) {
        throw "pico8_gpio is not defined yet!";
    }

    // Check for the magic that indicates that we should initialize Pinput.
    let shouldReinit = true;
    for (const [i, byte] of magic.entries()) {
        if (gpio[i] !== byte) {
            shouldReinit = false;
            break;
        }
    }
    if (shouldReinit) {
        // Zero the GPIO area.
        gpio.fill(0);
    }

    // Write each supported gamepad's current state into GPIO.
    // Note: `navigator.getGamepads()` does not return an array on Chrome.
    let gamepads = Array.from(navigator.getGamepads()).slice(0, maxGamepads);
    for (const [gamepadIndex, gamepad] of gamepads.entries()) {
        const gamepadBase = gamepadIndex * gamepadStride;
        if (gamepad === null || gamepad.mapping !== 'standard' || !gamepad.connected) {
            // This is a disconnected or unsupported gamepad: zero it and go to the next one.
            gpio.fill(0, gamepadBase, gamepadBase + gamepadStride);
            continue;
        }

        // Detect Firefox vibration support.
        // https://developer.mozilla.org/en-US/docs/Web/API/Gamepad/hapticActuators
        const hasSupportedGamepadHapticActuators =
            gamepad.hapticActuators !== undefined
            && gamepad.hapticActuators.length >= 2
            && gamepad.hapticActuators
                .every(actuator => actuator.type === 'vibration');

        // Detect Chrome vibration support.
        // https://web.dev/gamepad/#making-use-of-the-vibration-actuator
        // https://docs.google.com/document/d/1jPKzVRNzzU4dUsvLpSXm1VXPQZ8FP-0lKMT-R_p-s6g/edit
        const hasSupportedVibrationActuator =
            gamepad.vibrationActuator !== undefined
            && gamepad.vibrationActuator !== null
            && gamepad.vibrationActuator.type === 'dual-rumble';

        // Some gamepads use the standard mapping but have a `buttons` array too short to have the guide button.
        // The Logitech F310 in DirectInput mode is an example.
        let flags = connected;
        if (gamepad.buttons.length > 16) {
            flags |= hasGuideButton;
        }
        if (gamepad.buttons.length > 17) {
            flags |= hasMiscButton;
        }
        if (hasSupportedGamepadHapticActuators || hasSupportedVibrationActuator) {
            flags |= hasRumble;
        }
        gpio[gamepadBase] = flags;

        // Handle low byte of buttons.
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
        gpio[gamepadBase + buttonsLoOffset] = buttonsLo;

        // Handle high byte of buttons.
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
        if (gamepad.buttons.length > 16 && gamepad.buttons[16].pressed) {
            buttonsHi |= guide;
        }
        if (gamepad.buttons.length > 17 && gamepad.buttons[17].pressed) {
            buttonsHi |= misc;
        }
        gpio[gamepadBase + buttonsHiOffset] = buttonsHi;

        // Map triggers.
        // Triggers are considered analog buttons, not axes.
        for (const [buttonIndex, triggerOffset] of triggerMappings) {
            const triggerValue = gamepad.buttons[buttonIndex].value * triggerMax;
            gpio[gamepadBase + triggerOffset] = triggerValue;
        }

        // Map axes. Y axes have to be flipped to match XInput/Apple Game Controller conventions for up.
        for (const [axisIndex, [axisOffset, axisMultiplier]] of axisMappings) {
            const axisValue = gamepad.axes[axisIndex] * axisMultiplier * axisMax;
            const axisLo = (axisValue >>> 0) & 0xff;
            gpio[gamepadBase + axisOffset] = axisLo;
            const axisHi = (axisValue >>> 8) & 0xff;
            gpio[gamepadBase + axisOffset + 1] = axisHi;
        }

        // Rumble, if this browser and gamepad support it.
        // Note that the gpio array may be the right length but have undefined entries,
        // so we need to handle that by providing a default.
        if (hasSupportedGamepadHapticActuators) {
            for (const [rumbleIndex, [rumbleOffset, _]] of rumbleMappings) {
                const rumble = (gpio[gamepadBase + rumbleOffset] || 0) / rumbleMax;
                const _ = gamepad.hapticActuators[rumbleIndex].pulse(rumble, rumbleDurationMs);
            }
        } else if (hasSupportedVibrationActuator) {
            const effect = {
                startDelay: 0,
                duration: rumbleDurationMs,
            }
            for (const [_, [rumbleOffset, rumbleKey]] of rumbleMappings) {
                effect[rumbleKey] = (gpio[gamepadBase + rumbleOffset] || 0) / rumbleMax;
            }
            gamepad.vibrationActuator.playEffect('dual-rumble', effect);
        }
    }

    if (buttplugClient === null) {
        return;
    }

    for (const [index, device] of buttplugClient.Devices.entries()) {
        const gamepadIndex = gamepads.length + index;
        if (index >= maxGamepads) {
            break;
        }
        const gamepadBase = gamepadIndex * gamepadStride;
        const loFreqRumble = (gpio[gamepadBase + loFreqRumbleOffset] || 0) / rumbleMax;
        const hiFreqRumble = (gpio[gamepadBase + hiFreqRumbleOffset] || 0) / rumbleMax;
        const numVibes = device.messageAttributes(Buttplug.ButtplugDeviceMessageType.VibrateCmd).featureCount;

        let flags = connected | hapticDevice;
        if (numVibes > 0) {
            flags |= hasRumble;
        }
        gpio[gamepadBase] = flags;

        // Vibrators only past this point.
        if (numVibes === 0) {
            continue;
        }

        try {
            if (numVibes === 2) {
                await device.vibrate([loFreqRumble, hiFreqRumble]);
            } else {
                await device.vibrate(Math.max(loFreqRumble, hiFreqRumble));
            }
        } catch (error) {
            console.error(`Buttplug: ${error}`);
        }
    }
}

/** Runs `sync` in a try-catch block and then schedules itself again. */
async function loop() {
    try {
        await sync();
    } catch (error) {
        console.error(`Pinput: ${error}`);
    }
    window.requestAnimationFrame(loop);
}

/** Has to be called from an interaction event handler to be allowed to use Bluetooth. */
export async function initHaptics() {
    if (buttplugInitAttempted) {
        // Already initialized.
        return;
    }
    buttplugInitAttempted = true;

    await Buttplug.buttplugInit();
    const client = new Buttplug.ButtplugClient("Pinput");
    const hasBluetooth = window.Bluetooth !== undefined;
    let btPromptAddendum = hasBluetooth ? ' (cancel to try Bluetooth in browser)' : '';
    const server = window.prompt(`Haptics: enter buttplug.io websocket server address${btPromptAddendum}:`, "ws://127.0.0.1:12345");
    let connector;
    if (server === null) {
        if (hasBluetooth) {
            connector = new Buttplug.ButtplugEmbeddedConnectorOptions();
        } else {
            return;
        }
    } else {
        connector = new Buttplug.ButtplugWebsocketConnectorOptions(server);
    }
    client.addListener('deviceadded', (device) => {
        const numVibes = device.messageAttributes(Buttplug.ButtplugDeviceMessageType.VibrateCmd).featureCount;
        console.log(`Buttplug device connected: ${device.Name}, ${numVibes} motors`);
    });
    client.addListener('deviceremoved', (device) => {
        console.log(`Buttplug device disconnected: ${device.Name}`);
    });
    await client.connect(connector);
    await client.startScanning();
    buttplugClient = client;
}

async function reinitHaptics() {
    buttplugInitAttempted = false;
    buttplugClient = null;
    await initHaptics();
}

function onLoad(f) {
    if (document.readyState !== 'complete') {
        window.addEventListener('load', f);
    } else {
        f();
    }
}

export function initHapticsOnPlayerClick() {
    onLoad((_) => {
        document.getElementById('p8_container').addEventListener('click', initHaptics);
    })
}

const vibeIcon = 'data:image/png;base64,' +
    'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAJBJREFUSIntlL0OgCAM' +
    'hAtxd/X9n46VJ6gTpsFruYiTchMh9L7+BZGlf0lrUa1F34zPM0AmoWwfi4ik/Uhcvne1WAt1K2CAyLBXZ' +
    's3au1FLeiisAAGtsT2PqgiHjAyju8eAGVEANBt22yAA9dUaotl4wOwZemBm06yn2yIGyq' +
    'z3BWCriISAWxQwasfMt7L0IZ0FY3cnh/Y4aAAAAABJRU5ErkJggg==';

export function addHapticsButton() {
    onLoad((_) => {
        // Have to add an entry to p8_gfx_dat because the PICO-8 player code
        // changes all button images to values from it.

        p8_gfx_dat['p8b_haptics_touch'] = vibeIcon;
        document.getElementById('p8_menu_buttons_touch').innerHTML += '' +
            '<div class="p8_menu_button" style="float:left;margin-left:10px" id="p8b_haptics_touch">' +
            '   <img width="24" height="24" style="pointer-events:none">' +
            '</div>';
        document.getElementById('p8b_haptics_touch').addEventListener('click', reinitHaptics);

        p8_gfx_dat['p8b_haptics'] = vibeIcon;
        document.getElementById('p8_menu_buttons').innerHTML += '' +
            '<div class="p8_menu_button" style="position:absolute; bottom:-15px" ' +
            'id="p8b_haptics">' +
            '   <img width="24" height="24" style="pointer-events:none">' +
            '</div>';
        document.getElementById('p8b_haptics').addEventListener('click', reinitHaptics);
    });
}

/** Call this to start running the update loop. */
export async function init() {
    console.log('Pinput: initialized');
    window.requestAnimationFrame(loop);
}
