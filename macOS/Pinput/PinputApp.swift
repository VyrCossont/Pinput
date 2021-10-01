import SwiftUI

/// Creates a PICO-8 connection manager and a gamepad collection at app startup, and hooks them to each other.
@main
struct PinputGuiApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                pico8: pico8,
                gamepads: gamepads
            )
            .onAppear {
                gamepads.pico8ConnectionPublisher = pico8.$pico8Connection.eraseToAnyPublisher()
            }
            .onDisappear {
                gamepads.pico8ConnectionPublisher = nil
            }
        }
    }

    @StateObject var pico8 = Pico8()
    @StateObject var gamepads = Gamepads()
}
