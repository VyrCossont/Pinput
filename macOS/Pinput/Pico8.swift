import Combine
import Foundation

/// UI-friendly wrapper around a possible PICO-8 connection.
/// Checks every second to see if it needs to connect or disconnect.
class Pico8: ObservableObject {
    internal static let noPico8ProcessMessage = "PICO-8 not running."

    /// Display name of PICO-8 process that we're connected to, or an error message.
    @Published var name: String = noPico8ProcessMessage

    /// Call `updateConnection` periodically.
    internal var scanProcesses: AnyCancellable?

    /// Publish the PICO-8 connection for `Gamepads` to consume.
    @Published var pico8Connection: Pico8Connection?

    /// Constructor for SwiftUI previews.
    init(preview: String) {
        name = preview
    }

    init() {
        updateConnection()

        scanProcesses = Timer.TimerPublisher(
            interval: 1,
            runLoop: .current,
            mode: .default
        )
        .autoconnect()
        .sink { [weak self] _ in
            guard let self = self else { return }
            self.updateConnection()
        }
    }

    /// If there is a connection, check to see if it's still alive.
    /// If there isn't, try to connect to PICO-8.
    internal func updateConnection() {
        if let currentConnection = pico8Connection {
            if (try? pidPath(currentConnection.pid)) == nil {
                // Assume the process has died, and disconnect.
                // TODO: won't work if the PID got immediately reused.
                pico8Connection = nil
                name = Self.noPico8ProcessMessage
            }
        } else {
            do {
                let newConnection = try Pico8Connection.connect()
                pico8Connection = newConnection
                name = "PICO-8 pid: \(newConnection.pid)"
            } catch Pico8Connection.Failure.noPico8Process {
                self.name = Self.noPico8ProcessMessage
            } catch Pico8Connection.Failure.pinputMagicNotFound {
                self.name = "PICO-8 process hasn't initialized Pinput."
            } catch {
                self.name = "Error: \(error)"
            }
        }
    }
}

