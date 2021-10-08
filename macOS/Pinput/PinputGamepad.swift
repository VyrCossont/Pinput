import GameController

/// Gamepad informational flags.
struct PinputGamepadFlags: OptionSet {
    let rawValue: UInt8

    /// This gamepad is connected.
    static let connected: Self = .init(rawValue: 1 << 0)

    /// This gamepad has a battery.
    /// If this is true, the `battery` field and the `isCharging` flag may be non-zero.
    static let hasBattery: Self = .init(rawValue: 1 << 1)

    /// This gamepad is currently charging its battery.
    static let charging: Self = .init(rawValue: 1 << 2)

    /// Does this controller have a usable guide button?
    /// Not all Apple-supported gamepads have a guide button,
    /// and versions of Pinput on other platforms might not have access to them
    /// (XInput on Windows, for example).
    static let hasGuideButton: Self = .init(rawValue: 1 << 3)

    /// Update the battery charging status.
    mutating func update(from gcDeviceBattery: GCDeviceBattery) {
        if gcDeviceBattery.batteryState == .charging {
            insert(.charging)
        } else {
            remove(.charging)
        }
    }
}

extension PinputGamepadFlags {
    /// Create flags from the current state of a gamepad.
    init(_ gcExtendedGamepad: GCExtendedGamepad) {
        self = [.connected]

        if let battery = gcExtendedGamepad.controller?.battery {
            insert(.hasBattery)
            if battery.batteryState == .charging {
                insert(.charging)
            }
        }

        if gcExtendedGamepad.buttonHome != nil {
            insert(.hasGuideButton)
        }
    }
}

/// Flags field indicating which buttons are currently pressed.
/// Same as <https://docs.microsoft.com/en-us/windows/win32/api/xinput/ns-xinput-xinput_gamepad>
/// with the addition of a guide button after all of the other buttons.
struct PinputGamepadButtons: OptionSet {
    let rawValue: UInt16

    static let dpadUp: Self = .init(rawValue: 1 << 0)
    static let dpadDown: Self = .init(rawValue: 1 << 1)
    static let dpadLeft: Self = .init(rawValue: 1 << 2)
    static let dpadRight: Self = .init(rawValue: 1 << 3)

    static let start: Self = .init(rawValue: 1 << 4)
    static let back: Self = .init(rawValue: 1 << 5)

    static let leftStick: Self = .init(rawValue: 1 << 6)
    static let rightStick: Self = .init(rawValue: 1 << 7)

    static let leftBumper: Self = .init(rawValue: 1 << 8)
    static let rightBumper: Self = .init(rawValue: 1 << 9)

    static let guide: Self = .init(rawValue: 1 << 10)

    /// Does not correspond to any actual buttons.
    static let reserved: Self = .init(rawValue: 1 << 11)

    static let a: Self = .init(rawValue: 1 << 12)
    static let b: Self = .init(rawValue: 1 << 13)
    static let x: Self = .init(rawValue: 1 << 14)
    static let y: Self = .init(rawValue: 1 << 15)

    /// Update based on a specific button changing.
    mutating func update(from gcExtendedGamepad: GCExtendedGamepad, _ gcControllerButtonInput: GCControllerButtonInput) {
        let button: PinputGamepadButtons

        switch gcControllerButtonInput {
        case gcExtendedGamepad.dpad.up:
            button = .dpadUp
        case gcExtendedGamepad.dpad.down:
            button = .dpadDown
        case gcExtendedGamepad.dpad.left:
            button = .dpadLeft
        case gcExtendedGamepad.dpad.right:
            button = .dpadRight

        case gcExtendedGamepad.buttonMenu:
            button = .start
        case gcExtendedGamepad.buttonOptions:
            button = .back

        case gcExtendedGamepad.leftThumbstickButton:
            button = .leftStick
        case gcExtendedGamepad.rightThumbstickButton:
            button = .rightStick

        case gcExtendedGamepad.leftShoulder:
            button = .leftBumper
        case gcExtendedGamepad.rightShoulder:
            button = .rightBumper

        case gcExtendedGamepad.buttonA:
            button = .a
        case gcExtendedGamepad.buttonB:
            button = .b
        case gcExtendedGamepad.buttonX:
            button = .x
        case gcExtendedGamepad.buttonY:
            button = .y

        case gcExtendedGamepad.buttonHome:
            button = .guide

        default:
            logger.log("Gamepad \(gcExtendedGamepad, privacy: .public) updated unknown button: \(gcControllerButtonInput, privacy: .public)")
            return
        }

        if gcControllerButtonInput.isPressed {
            insert(button)
        } else {
            remove(button)
        }
    }
}

extension PinputGamepadButtons {
    /// Create buttons from the current state of a gamepad.
    init(_ gcExtendedGamepad: GCExtendedGamepad) {
        self = []

        if gcExtendedGamepad.dpad.up.isPressed {
            self.insert(.dpadUp)
        }
        if gcExtendedGamepad.dpad.down.isPressed {
            self.insert(.dpadDown)
        }
        if gcExtendedGamepad.dpad.left.isPressed {
            self.insert(.dpadLeft)
        }
        if gcExtendedGamepad.dpad.right.isPressed {
            self.insert(.dpadRight)
        }

        if gcExtendedGamepad.buttonMenu.isPressed {
            self.insert(.start)
        }
        if gcExtendedGamepad.buttonOptions?.isPressed ?? false {
            self.insert(.back)
        }

        if gcExtendedGamepad.leftThumbstickButton?.isPressed ?? false {
            self.insert(.leftStick)
        }
        if gcExtendedGamepad.rightThumbstickButton?.isPressed ?? false {
            self.insert(.rightStick)
        }

        if gcExtendedGamepad.leftShoulder.isPressed {
            self.insert(.leftBumper)
        }
        if gcExtendedGamepad.rightShoulder.isPressed {
            self.insert(.rightBumper)
        }

        if gcExtendedGamepad.buttonA.isPressed {
            self.insert(.a)
        }
        if gcExtendedGamepad.buttonB.isPressed {
            self.insert(.b)
        }
        if gcExtendedGamepad.buttonX.isPressed {
            self.insert(.x)
        }
        if gcExtendedGamepad.buttonY.isPressed {
            self.insert(.y)
        }

        if gcExtendedGamepad.buttonHome?.isPressed ?? false {
            self.insert(.guide)
        }
    }
}

/// Structure representing a gamepad to PICO-8.
/// Based on <https://docs.microsoft.com/en-us/windows/win32/api/xinput/ns-xinput-xinput_gamepad>
/// and <https://docs.microsoft.com/en-us/windows/win32/api/xinput/ns-xinput-xinput_vibration>
/// but prefixed with controller flags and a battery meter, and with smaller rumble types to fit into a convenient size (16 bytes).
/// All fields are written to PICO-8, except for the rumble fields, which are read from PICO-8.
struct PinputGamepad {
    var flags: PinputGamepadFlags
    /// 0 for empty or not present, max value for fully charged.
    var battery: UInt8
    var buttons: PinputGamepadButtons

    var leftTrigger: UInt8
    var rightTrigger: UInt8

    var leftStickX: Int16
    var leftStickY: Int16

    var rightStickX: Int16
    var rightStickY: Int16

    /// Output from PICO-8.
    var loFreqRumble: UInt8
    /// Output from PICO-8.
    var hiFreqRumble: UInt8

    /// Create a zeroed-out gamepad with no state, not even the connection flag.
    static func zero() -> Self {
        .init(
            flags: [],
            battery: 0,
            buttons: [],
            leftTrigger: 0,
            rightTrigger: 0,
            leftStickX: 0,
            leftStickY: 0,
            rightStickX: 0,
            rightStickY: 0,
            loFreqRumble: 0,
            hiFreqRumble: 0
        )
    }

    /// Update all inputs from the current state of an actual gamepad.
    mutating func update(from gcExtendedGamepad: GCExtendedGamepad) {
        flags = .init(gcExtendedGamepad)
        battery = UInt8((gcExtendedGamepad.controller?.battery?.batteryLevel ?? 0) * Float(UInt8.max))
        buttons = .init(gcExtendedGamepad)

        leftTrigger = UInt8(gcExtendedGamepad.leftTrigger.value * Float(UInt8.max))
        rightTrigger = UInt8(gcExtendedGamepad.rightTrigger.value * Float(UInt8.max))

        leftStickX = Int16(gcExtendedGamepad.leftThumbstick.xAxis.value * Float(Int16.max))
        leftStickY = Int16(gcExtendedGamepad.leftThumbstick.xAxis.value * Float(Int16.max))

        rightStickX = Int16(gcExtendedGamepad.rightThumbstick.xAxis.value * Float(Int16.max))
        rightStickY = Int16(gcExtendedGamepad.rightThumbstick.yAxis.value * Float(Int16.max))
    }

    mutating func update(from gcDeviceBattery: GCDeviceBattery) {
        flags.update(from: gcDeviceBattery)
        battery = UInt8((gcDeviceBattery.batteryLevel) * Float(UInt8.max))
    }

    /// Update based on a specific input changing.
    mutating func update(from gcExtendedGamepad: GCExtendedGamepad, _ gcControllerElement: GCControllerElement) {
        switch gcControllerElement {
        case gcExtendedGamepad.dpad:
            buttons.update(from: gcExtendedGamepad, gcExtendedGamepad.dpad.up)
            buttons.update(from: gcExtendedGamepad, gcExtendedGamepad.dpad.down)
            buttons.update(from: gcExtendedGamepad, gcExtendedGamepad.dpad.left)
            buttons.update(from: gcExtendedGamepad, gcExtendedGamepad.dpad.right)

        case gcExtendedGamepad.buttonMenu:
            buttons.update(from: gcExtendedGamepad, gcExtendedGamepad.buttonMenu)
        case gcExtendedGamepad.buttonOptions:
            buttons.update(from: gcExtendedGamepad, gcExtendedGamepad.buttonOptions!)

        case gcExtendedGamepad.leftThumbstickButton:
            buttons.update(from: gcExtendedGamepad, gcExtendedGamepad.leftThumbstickButton!)
        case gcExtendedGamepad.rightThumbstickButton:
            buttons.update(from: gcExtendedGamepad, gcExtendedGamepad.rightThumbstickButton!)

        case gcExtendedGamepad.leftShoulder:
            buttons.update(from: gcExtendedGamepad, gcExtendedGamepad.leftShoulder)
        case gcExtendedGamepad.rightShoulder:
            buttons.update(from: gcExtendedGamepad, gcExtendedGamepad.rightShoulder)

        case gcExtendedGamepad.buttonA:
            buttons.update(from: gcExtendedGamepad, gcExtendedGamepad.buttonA)
        case gcExtendedGamepad.buttonB:
            buttons.update(from: gcExtendedGamepad, gcExtendedGamepad.buttonB)
        case gcExtendedGamepad.buttonX:
            buttons.update(from: gcExtendedGamepad, gcExtendedGamepad.buttonX)
        case gcExtendedGamepad.buttonY:
            buttons.update(from: gcExtendedGamepad, gcExtendedGamepad.buttonY)

        case gcExtendedGamepad.buttonHome:
            buttons.update(from: gcExtendedGamepad, gcExtendedGamepad.buttonHome!)

        case gcExtendedGamepad.leftTrigger:
            leftTrigger = UInt8(gcExtendedGamepad.leftTrigger.value * Float(UInt8.max))
        case gcExtendedGamepad.rightTrigger:
            rightTrigger = UInt8(gcExtendedGamepad.rightTrigger.value * Float(UInt8.max))

        case gcExtendedGamepad.leftThumbstick:
            leftStickX = Int16(gcExtendedGamepad.leftThumbstick.xAxis.value * Float(Int16.max))
            leftStickY = Int16(gcExtendedGamepad.leftThumbstick.yAxis.value * Float(Int16.max))

        case gcExtendedGamepad.rightThumbstick:
            rightStickX = Int16(gcExtendedGamepad.rightThumbstick.xAxis.value * Float(Int16.max))
            rightStickY = Int16(gcExtendedGamepad.rightThumbstick.yAxis.value * Float(Int16.max))

        default:
            logger.log("Gamepad \(gcExtendedGamepad, privacy: .public) updated unknown element: \(gcControllerElement, privacy: .public)")
        }
    }
}
