import FocusSoundsCore
import SwiftUI
import UniformTypeIdentifiers

@available(macOS 14.2, *)
struct MenuBarView: View {
  @Bindable var model: AppModel
  @State private var showFileImporter = false
  @State private var isDropTargeted = false

  private static let importTypes: [UTType] = {
    var types: [UTType] = [.audio, .movie, .mpeg4Movie, .mpeg4Audio, .mp3, .aiff, .wav]
    for ext in SoundImport.supportedExtensions {
      if let type = UTType(filenameExtension: ext), !types.contains(type) { types.append(type) }
    }
    return types
  }()

  var body: some View {
    ZStack {
      mainContent
        .disabled(model.isImporting)
        .opacity(model.isImporting ? 0.4 : 1)

      if model.isImporting {
        ImportPreparingView(fileName: model.importFileName, progress: model.importProgress)
          .transition(.opacity.combined(with: .scale(scale: 0.98)))
      }
    }
    .animation(.easeInOut(duration: 0.2), value: model.isImporting)
    .padding()
    .frame(width: 300)
    .fileImporter(
      isPresented: $showFileImporter,
      allowedContentTypes: Self.importTypes,
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        guard let url = urls.first else { return }
        Task { await model.importSound(from: url) }
      case .failure(let error):
        AppAlert.show(title: "Import failed", message: error.localizedDescription)
      }
    }
  }

  private var mainContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Focus Sounds")
        .font(.headline)

      if model.sounds.isEmpty {
        Text("No sounds yet.")
          .font(.caption)
          .foregroundStyle(.secondary)
        importHint
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

      dropZone

      HStack {
        Button(model.isPlaying ? "Pause" : "Play") {
          model.togglePlayPause()
        }
        .keyboardShortcut(.return, modifiers: [])
        .disabled(model.sounds.isEmpty || model.isImporting)

        Button("Import…") { showFileImporter = true }
          .disabled(model.isImporting)

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

      if model.permissionState == .denied {
        Text("Grant System Audio Recording in System Settings → Privacy & Security if prompted.")
          .font(.caption2)
          .foregroundStyle(.orange)
      }

      Divider()

      Button("Quit") { NSApplication.shared.terminate(nil) }
    }
  }

  private var importHint: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Import or drop a file. Converts to audio-only M4A, max 10 minutes.")
      Text("This window closes while the file picker is open — reopen it to see progress.")
    }
    .font(.caption)
    .foregroundStyle(.secondary)
  }

  private var dropZone: some View {
    RoundedRectangle(cornerRadius: 8, style: .continuous)
      .strokeBorder(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5]))
      .background(isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      .frame(height: 44)
      .overlay {
        Text("Drop audio or video here")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
          guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
          Task { @MainActor in await model.importSound(from: url) }
        }
        return true
      }
  }
}
