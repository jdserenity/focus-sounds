import SwiftUI

@available(macOS 14.2, *)
struct MenuBarView: View {
  @Bindable var model: AppModel
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Focus Sounds")
        .font(.headline)

      if model.sounds.isEmpty {
        Text("No sounds yet.")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("Click Import to add one.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        Picker("Sound", selection: Binding(
          get: { model.selectedSound?.id ?? "" },
          set: { id in
            if let sound = model.sounds.first(where: { $0.id == id }) {
              model.selectSound(sound)
            }
          }
        )) {
          ForEach(model.sounds) { sound in
            Text(sound.title).tag(sound.id)
          }
        }
      }

      HStack {
        Button(model.isPlaying ? "Pause" : "Play") {
          model.togglePlayPause()
        }
        .keyboardShortcut(.return, modifiers: [])
        .disabled(model.sounds.isEmpty)

        Button("Import…") { openWindow(id: "import-sound") }

        if model.isPlaying, model.isDucked {
          Label("Ducked", systemImage: "speaker.wave.1.fill")
            .font(.caption)
            .foregroundStyle(.orange)
        }
      }

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Focus volume")
            .font(.caption)
          Spacer()
          Text("\(Int(model.focusVolume * 100))%")
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        Slider(value: Binding(
          get: { Double(model.focusVolume) },
          set: { model.setFocusVolume(Float($0)) }
        ), in: 0...1)
        Text("Only affects this app — not Spotify or system volume.")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      if model.isPlaying {
        VStack(alignment: .leading, spacing: 4) {
          Text("External audio")
            .font(.caption)
            .foregroundStyle(model.isDucked ? .orange : .primary)
          ProgressView(value: Double(min(model.externalLevel * 8, 1)))
            .progressViewStyle(.linear)
            .tint(model.isDucked ? .orange : .accentColor)
          Text(String(format: "%.4f", model.externalLevel))
            .font(.caption2)
            .foregroundStyle(model.isDucked ? .orange : .secondary)
            .monospacedDigit()
        }
      }

      if model.permissionState == .denied {
        Text("Grant System Audio Recording in System Settings → Privacy & Security if prompted.")
          .font(.caption2)
          .foregroundStyle(.orange)
      }

      Divider()

      HStack {
        Button("Quit") { NSApplication.shared.terminate(nil) }
        Spacer()
        if model.canDeleteSelectedSound {
          Button("Delete sound", role: .destructive) {
            model.deleteSelectedSound()
          }
        }
      }
    }
    .padding()
    .frame(width: 300)
  }
}
