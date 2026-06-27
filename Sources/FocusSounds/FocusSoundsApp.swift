import SwiftUI

@available(macOS 14.2, *)
@main
struct FocusSoundsApp: App {
  @State private var model = AppModel()

  var body: some Scene {
    MenuBarExtra("Focus Sounds", systemImage: "waveform.circle.fill") {
      MenuBarView(model: model)
    }
    .menuBarExtraStyle(.window)

    Window("Import Sound", id: "import-sound") {
      ImportWindowView(model: model)
    }
    .windowResizability(.contentSize)
  }
}
