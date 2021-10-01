import SwiftUI

/// Display the state of the PICO-8 connection and the gamepad collection.
struct ContentView: View {
    @ObservedObject var pico8: Pico8
    @ObservedObject var gamepads: Gamepads
    
    var body: some View {
        Text(pico8.name)
            .padding()
        Text(gamepads.name)
            .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            pico8: Pico8(preview: "PICO-8: pid 666"),
            gamepads: Gamepads(preview: "Arcade Pad • Hobundo")
        )
    }
}
