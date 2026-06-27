import AppKit
import FocusSoundsCore
import SwiftUI
import UniformTypeIdentifiers

@available(macOS 14.2, *)
struct MenuBarView: View {
  @Bindable var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Focus Sounds")
        .font(.headline)

      if model.sounds.isEmpty {
        Text("No sounds yet.")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("Import converts to audio-only M4A and trims to 10 minutes.")
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
        .disabled(model.sounds.isEmpty || model.isImporting)

        Button("Import…") { presentImportPanel() }
          .disabled(model.isImporting)

        if model.isImporting {
          ProgressView()
            .controlSize(.small)
        }

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
          ProgressView(value: Double(min(model.externalLevel * 8, 1)))
            .progressViewStyle(.linear)
          Text(String(format: "%.4f", model.externalLevel))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
      }

      Text(model.statusMessage)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if model.permissionState == .denied {
        Text("Grant System Audio Recording in System Settings → Privacy & Security if prompted.")
          .font(.caption2)
          .foregroundStyle(.orange)
      }

      Divider()

      Button("Quit") { NSApplication.shared.terminate(nil) }
    }
    .padding()
    .frame(width: 300)
  }

  private func presentImportPanel() {
    let panel = NSOpenPanel()
    panel.title = "Import focus sound"
    panel.message = "Video or audio files are converted to a 10-minute M4A loop."
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowedContentTypes = [.audio, .movie, .mpeg4Movie, .mpeg4Audio, .mp3, .aiff, .wav]
      + SoundImport.supportedExtensions
        .filter { !["m4a", "mp4", "mov", "mp3", "aiff", "wav", "aac"].contains($0) }
        .compactMap { UTType(filenameExtension: $0) }
    guard panel.runModal() == .OK, let url = panel.url else { return }
    Task { await model.importSound(from: url) }
  }
}
