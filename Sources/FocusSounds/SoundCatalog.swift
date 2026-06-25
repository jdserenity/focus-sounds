import Foundation

struct FocusSound: Identifiable, Hashable {
  let id: String
  let title: String
  let url: URL
}

enum SoundCatalog {
  private static let supportedExtensions = ["mp3", "wav", "m4a", "mp4", "aiff", "aac", "caf", "flac"]

  static func bundledSounds() -> [FocusSound] {
    guard let soundsRoot = locateSoundsDirectory(),
          let entries = try? FileManager.default.contentsOfDirectory(
            at: soundsRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
          ) else {
      return []
    }

    return entries
      .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
      .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
      .map { url in
        let title = url.deletingPathExtension().lastPathComponent
          .replacingOccurrences(of: "_", with: " ")
          .replacingOccurrences(of: "-", with: " ")
        return FocusSound(id: url.lastPathComponent, title: title, url: url)
      }
  }

  private static func locateSoundsDirectory() -> URL? {
    let candidates: [URL] = [
      Bundle.main.resourceURL?.appendingPathComponent("Sounds", isDirectory: true),
      Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Sounds", isDirectory: true),
      URL(fileURLWithPath: CommandLine.arguments[0])
        .deletingLastPathComponent()
        .appendingPathComponent("FocusSounds_FocusSounds.bundle/Sounds", isDirectory: true),
      URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Resources/Sounds", isDirectory: true),
    ].compactMap { $0 }

    for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
      return candidate
    }
    return nil
  }
}
