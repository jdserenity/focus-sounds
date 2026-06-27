import SwiftUI
import UniformTypeIdentifiers

@available(macOS 14.2, *)
struct ImportWindowView: View {
  @Bindable var model: AppModel
  @Environment(\.dismissWindow) private var dismissWindow
  @State private var showFileImporter = false
  @State private var isDropTargeted = false

  var body: some View {
    ZStack {
      if model.isImporting {
        ImportPreparingView(fileName: model.importFileName, progress: model.importProgress)
          .padding(20)
      } else {
        idleContent
      }
    }
    .frame(width: 340, height: model.isImporting ? 220 : 260)
    .animation(.easeInOut(duration: 0.2), value: model.isImporting)
    .fileImporter(
      isPresented: $showFileImporter,
      allowedContentTypes: SoundImportTypes.all,
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

  private var idleContent: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Import focus sound")
        .font(.headline)

      Text("Choose a file or drag one from Finder. Video is stripped; output is audio-only M4A, max 10 minutes.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      dropZone

      HStack {
        Button("Choose file…") { showFileImporter = true }
        Spacer()
        Button("Close") { dismissWindow(id: "import-sound") }
      }
    }
    .padding(20)
  }

  private var dropZone: some View {
    RoundedRectangle(cornerRadius: 10, style: .continuous)
      .strokeBorder(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
      .background(isDropTargeted ? Color.accentColor.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      .frame(maxWidth: .infinity, minHeight: 72)
      .overlay {
        VStack(spacing: 4) {
          Image(systemName: "arrow.down.doc")
            .font(.title3)
            .foregroundStyle(.secondary)
          Text("Drop audio or video here")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
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
