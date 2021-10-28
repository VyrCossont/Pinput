import Combine
import CoreHaptics
import GameController

/// UI-friendly plumbing between a collection of extended gamepads and a PICO-8 connection.
/// Responsible for pushing gamepad control values into PICO-8 and eventually controlling rumble based on outputs.
class Gamepads: ObservableObject {
    /// Given the size of the `PinputGamepad` structure and the PICO-8 GPIO area, we can support this many gamepads.
    internal static let pinputMaxGamepads = 8

    internal static let noCurrentGamepad = "No current gamepad."

    // TODO: list all registered gamepads by index.
    /// Display name of current player 1 gamepad, or an error message if there isn't one connected.
    @Published var name: String = noCurrentGamepad

    /// Keep the displayed player 1 controller name up to date.
    internal var currentControllerChanged: AnyCancellable?

    /// Register controllers when they connect.
    internal var controllerConnected: AnyCancellable?

    /// Unregister controllers when they disconnect.
    internal var controllerDisconnected: AnyCancellable?

    /// Create a Pinput-specific view of GPIO for a connected PICO-8 process.
    internal var pico8ConnectionChanged: AnyCancellable?

    /// Every second, update battery and charging states, and reset if the PICO-8 Pinput client asks for it.
    internal var periodicTasks: AnyCancellable?

    /// Pinput-specific view of PICO-8 GPIO.
    internal var pinputGamepads: UnsafeMutableBufferPointer<PinputGamepad>?

    /// External source of PICO-8 connections/disconnections.
    var pico8ConnectionPublisher: AnyPublisher<Pico8Connection?, Never>? {
        didSet {
            guard let pico8ConnectionPublisher = pico8ConnectionPublisher else {
                // Publisher set to nil from outside. Stop listening for PICO-8 connection status changes.
                pico8ConnectionChanged = nil
                return
            }

            pico8ConnectionChanged = pico8ConnectionPublisher.sink { [weak self] pico8Connection in
                guard let self = self else { return }
                guard let pico8Connection = pico8Connection else {
                    // PICO-8 disconnected. Drop our GPIO binding.
                    self.pinputGamepads = nil
                    return
                }

                // Connected to PICO-8. Bind the PICO-8 GPIO region as an array of gamepads.
                self.pinputGamepads = pico8Connection.gpio.bindMemory(to: PinputGamepad.self)
                self.initGamepadStates()
            }
        }
    }

    /// Persistent indexes so that the gamepads don't renumber if someone disconnects theirs during play.
    internal var registeredGamepads: [GCExtendedGamepad?] = Array(repeating: nil, count: pinputMaxGamepads)
    internal var hapticEngines: [(CHHapticEngine, CHHapticPattern, CHHapticPatternPlayer, CHHapticEngine, CHHapticPattern, CHHapticPatternPlayer)?] = Array(repeating: nil, count: pinputMaxGamepads)

    /// Constructor for SwiftUI previews.
    init(preview: String) {
        name = preview
    }

    init() {
        let didBecomeCurrent = NotificationCenter.default
            .publisher(for: .GCControllerDidBecomeCurrent)
        let didStopBeingCurrent = NotificationCenter.default
            .publisher(for: .GCControllerDidStopBeingCurrent)
        currentControllerChanged = didBecomeCurrent
            .merge(with: didStopBeingCurrent)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateCurrentControllerName()
            }

        controllerConnected = NotificationCenter.default
            .publisher(for: .GCControllerDidConnect)
            .compactMap { ($0.object as? GCController)?.extendedGamepad }
            .sink { [weak self] gcExtendedGamepad in
                guard let self = self else { return }
                self.registerGamepad(gcExtendedGamepad)
            }

        controllerDisconnected = NotificationCenter.default
            .publisher(for: .GCControllerDidDisconnect)
            .compactMap { ($0.object as? GCController)?.extendedGamepad }
            .sink { [weak self] gcExtendedGamepad in
                guard let self = self else { return }
                self.unregisterGamepad(gcExtendedGamepad)
            }

        periodicTasks = Timer.TimerPublisher(
            interval: 0.016,
            runLoop: .current,
            mode: .default
        )
        .autoconnect()
        .sink { [weak self] _ in
            guard let self = self else { return }
            guard let pinputGamepads = self.pinputGamepads else { return }

            /// If the GPIO area starts with the Pinput magic bytes, the cartridge was restarted, and we should re-initialize.
            let gpio = UnsafeMutableRawBufferPointer(pinputGamepads)
            var shouldReinit = true
            for i in pinputMagic.indices {
                if pinputMagic[i] != gpio[i] {
                    shouldReinit = false
                    break
                }
            }
            if shouldReinit {
                self.initGamepadStates()
                return
            }

            // Update battery level and charging state for all registered gamepads.
            for (i, maybeGcExtendedGamepad) in self.registeredGamepads.enumerated() {
                guard let battery = maybeGcExtendedGamepad?.controller?.battery else { continue }
                self.pinputGamepads?[i].update(from: battery)
            }

            // Update rumble.
            for (i, maybeHapticEngines) in self.hapticEngines.enumerated() {
                // This mapping assumes that the left handle rumble motor is the low-frequency one,
                // and the right handle rumble motor is the high-frequency one.
                // This is XInput's assumption and probably holds for all Xbox controllers.
                // It also holds for the DualShock 4 (at least).
                // It's even mentioned in Apple examples, so maybe most controllers use this convention.
                guard let (_, _, leftPlayer, _, _, rightPlayer) = maybeHapticEngines,
                      let leftIntensityRaw = self.pinputGamepads?[i].loFreqRumble,
                      let rightIntensityRaw = self.pinputGamepads?[i].hiFreqRumble
                else { continue }

                if leftIntensityRaw == 0 {
                    try? leftPlayer.stop(atTime: .zero)
                } else {
                    let leftIntensity = Float(leftIntensityRaw) / Float(UInt8.max)
                    try? leftPlayer.start(atTime: .zero)
                    try? leftPlayer.sendParameters(
                        [
                            CHHapticDynamicParameter(
                                parameterID: .hapticIntensityControl,
                                value: leftIntensity,
                                relativeTime: .zero)
                        ],
                        atTime: .zero
                    )
                }

                if rightIntensityRaw == 0 {
                    try? rightPlayer.stop(atTime: .zero)
                } else {
                    let rightIntensity = Float(rightIntensityRaw) / Float(UInt8.max)
                    try? rightPlayer.start(atTime: .zero)
                    try? rightPlayer.sendParameters(
                        [
                            CHHapticDynamicParameter(
                                parameterID: .hapticIntensityControl,
                                value: rightIntensity,
                                relativeTime: .zero)
                        ],
                        atTime: .zero
                    )
                }
            }
        }
    }

    /// Update the current player 1 controller name displayed in the UI.
    internal func updateCurrentControllerName() {
        if let current = GCController.current {
            if let vendorName = current.vendorName {
                self.name = "\(current.className) • \(vendorName)"
            } else {
                self.name = "\(current.className)"
            }
        } else {
            self.name = Self.noCurrentGamepad
        }
    }

    /// Set initial gamepad states in PICO-8.
    /// Called when we get a new PICO-8 connection or the PICO-8 Pinput client asks to initialize again.
    internal func initGamepadStates() {
        for (i, maybeGcExtendedGamepad) in self.registeredGamepads.enumerated() {
            // Always clear first in case there's leftover magic or other junk in that memory.
            self.clearGamepadState(at: i)
            if let gcExtendedGamepad = maybeGcExtendedGamepad {
                self.updateGamepadState(at: i, gcExtendedGamepad)
            }
        }
    }

    /// Add a new gamepad to the registry and update its state.
    internal func registerGamepad(_ gcExtendedGamepad: GCExtendedGamepad) {
        for (i, registeredGamepad) in registeredGamepads.enumerated() {
            if registeredGamepad == nil {
                gcExtendedGamepad.valueChangedHandler = gamepadValueChanged(_:gcControllerElement:)
                registeredGamepads[i] = gcExtendedGamepad
                updateGamepadState(at: i, gcExtendedGamepad)
                // TODO: factor this out and make it neat
                if let haptics = gcExtendedGamepad.controller?.haptics,
                    haptics.supportedLocalities.contains(.leftHandle),
                    haptics.supportedLocalities.contains(.rightHandle),
                    let leftPattern = try? CHHapticPattern(
                        events: [
                            CHHapticEvent(
                                eventType: .hapticContinuous,
                                parameters: [
                                    CHHapticEventParameter(
                                        parameterID: .hapticIntensity,
                                        value: 1.0
                                    )
                                ],
                                relativeTime: .zero,
                                duration: .init(GCHapticDurationInfinite)
                            )
                        ],
                        parameters: []
                    ),
                    let rightPattern = try? CHHapticPattern(
                        events: [
                            CHHapticEvent(
                                eventType: .hapticContinuous,
                                parameters: [
                                    CHHapticEventParameter(
                                        parameterID: .hapticIntensity,
                                        value: 1.0
                                    )
                                ],
                                relativeTime: .zero,
                                duration: .init(GCHapticDurationInfinite)
                            )
                        ],
                        parameters: []
                    ),
                    let leftEngine = haptics.createEngine(withLocality: .leftHandle),
                    let rightEngine = haptics.createEngine(withLocality: .rightHandle),
                    let leftPlayer = try? leftEngine.makePlayer(with: leftPattern),
                    let rightPlayer = try? rightEngine.makePlayer(with: rightPattern) {
                    try? leftEngine.start()
                    try? rightEngine.start()
                    hapticEngines[i] = (leftEngine, leftPattern, leftPlayer, rightEngine, rightPattern, rightPlayer)
                } else {
                    hapticEngines[i] = nil
                    logger.log("Gamepad does not support the haptics we expect: \(gcExtendedGamepad, privacy: .public)")
                }
                return
            }
        }

        logger.log("More than \(self.registeredGamepads.count) controllers connected. Ignoring: \(gcExtendedGamepad, privacy: .public)")
    }

    /// Update gamepad state in PICO-8, including gamepad flags and battery level.
    internal func updateGamepadState(at i: Int, _ gcExtendedGamepad: GCExtendedGamepad) {
        pinputGamepads?[i].update(from: gcExtendedGamepad)
    }

    /// Remove a gamepad from the registry and clear its state.
    internal func unregisterGamepad(_ gcExtendedGamepad: GCExtendedGamepad) {
        for (i, registeredGamepad) in registeredGamepads.enumerated() {
            if registeredGamepad == gcExtendedGamepad {
                gcExtendedGamepad.valueChangedHandler = nil
                registeredGamepads[i] = nil
                clearGamepadState(at: i)
                if let (leftEngine, _, _, rightEngine, _, _) = hapticEngines[i] {
                    leftEngine.stop(completionHandler: nil)
                    rightEngine.stop(completionHandler: nil)
                }
                hapticEngines[i] = nil
                return
            }
        }

        logger.log("Unregistering a gamepad that was not registered: \(gcExtendedGamepad, privacy: .public)")
    }

    /// Zero out gamepad state in PICO-8 for this index.
    internal func clearGamepadState(at i: Int) {
        pinputGamepads?[i] = PinputGamepad(
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

    /// Won't return an index for unregistered controllers.
    internal func getGamepadIndex(_ gcExtendedGamepad: GCExtendedGamepad) -> Int? {
        for (i, registeredGamepad) in registeredGamepads.enumerated() {
            if registeredGamepad == gcExtendedGamepad {
                return i
            }
        }

        logger.log("getGamepadIndex called for unregistered gamepad \(gcExtendedGamepad, privacy: .public)")
        return nil
    }

    /// Callback for gamepad value changes from Game Controller API:
    /// update the PICO-8 state of that gamepad based on what element changed.
    internal func gamepadValueChanged(_ gcExtendedGamepad: GCExtendedGamepad, gcControllerElement: GCControllerElement) {
        guard let i = getGamepadIndex(gcExtendedGamepad),
              let pinputGamepads = pinputGamepads
        else { return }
        pinputGamepads[i].update(from: gcExtendedGamepad, gcControllerElement)
    }
}
