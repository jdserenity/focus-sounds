import SwiftUI
import UniformTypeIdentifiers

@available(macOS 14.2, *)
struct ImportWindowView: View {
  @Bindable var model: AppModel
  @Environment(\.dismissWindow) private var dismissWindow
  @State private var showFileImporter = false
  @State private var isDropTargeted = false
  @State private var pendingURL: URL?
  @State private var pendingHasSecurityAccess = false

  var body: some View {
    ZStack {
      if model.isImporting {
        ImportPreparingView(fileName: model.importFileName, progress: model.importProgress)
          .padding(20)
      } else {
        idleContent
      }
    }
    .frame(width: 340, height: model.isImporting ? 220 : (pendingURL == nil ? 260 : 280))
    .animation(.easeInOut(duration: 0.2), value: model.isImporting)
    .animation(.easeInOut(duration: 0.2), value: pendingURL != nil)
    .onAppear { if !model.isImporting { clearPending() } }
    .onDisappear { clearPending() }
    .fileImporter(
      isPresented: $showFileImporter,
      allowedContentTypes: SoundImportTypes.all,
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        guard let url = urls.first else { return }
        setPending(url)
      case .failure(let error):
        AppAlert.show(title: "Could not open file", message: error.localizedDescription)
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

      if let pendingURL {
        selectedFileRow(pendingURL)
      } else {
        dropZone
      }

      HStack {
        Button(pendingURL == nil ? "Choose file…" : "Choose different file…") { showFileImporter = true }
        Spacer()
        Button("Convert") { convert() }
          .keyboardShortcut(.defaultAction)
          .disabled(pendingURL == nil)
      }
    }
    .padding(20)
  }

  private func selectedFileRow(_ url: URL) -> some View {
    HStack(spacing: 10) {
      Image(systemName: "doc.fill")
        .foregroundStyle(.tint)
      VStack(alignment: .leading, spacing: 2) {
        Text("Ready to convert")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(url.lastPathComponent)
          .font(.callout)
          .lineLimit(2)
      }
      Spacer()
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
          Task { @MainActor in setPending(url) }
        }
        return true
      }
  }

  private func setPending(_ url: URL) {
    clearPending()
    pendingURL = url
    pendingHasSecurityAccess = url.startAccessingSecurityScopedResource()
  }

  private func clearPending() {
    if pendingHasSecurityAccess, let pendingURL {
      pendingURL.stopAccessingSecurityScopedResource()
    }
    pendingURL = nil
    pendingHasSecurityAccess = false
  }

  private func convert() {
    guard let url = pendingURL else { return }
    Task {
      let ok = await model.importSound(from: url)
      if ok {
        clearPending()
        dismissWindow(id: "import-sound")
      }
    }
  }
}
