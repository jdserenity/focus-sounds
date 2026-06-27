import FocusSoundsCore
import Foundation

struct FocusSound: Identifiable, Hashable {
  let id: String
  let title: String
  let url: URL
}

enum SoundCatalog {
  private static let supportedExtensions = SoundImport.supportedExtensions

  static func importedSoundsDirectory() -> URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("FocusSounds/Sounds", isDirectory: true)
  }

  static func allSounds() -> [FocusSound] {
    let bundled = bundledSounds()
    let imported = sounds(in: importedSoundsDirectory(), createIfMissing: false)
    return (bundled + imported)
      .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
  }

  static func existingImportedFilenames() -> [String] {
    sounds(in: importedSoundsDirectory(), createIfMissing: false).map(\.id)
  }

  static func focusSound(for url: URL) -> FocusSound {
    let id = url.lastPathComponent
    let title = SoundImport.displayTitle(fromFilename: id)
    return FocusSound(id: id, title: title, url: url)
  }

  static func bundledSounds() -> [FocusSound] {
    guard let soundsRoot = locateBundledSoundsDirectory() else { return [] }
    return sounds(in: soundsRoot, createIfMissing: false)
  }

  private static func sounds(in directory: URL, createIfMissing: Bool) -> [FocusSound] {
    if createIfMissing {
      try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    guard let entries = try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    return entries
      .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
      .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
      .map { focusSound(for: $0) }
  }

  private static func locateBundledSoundsDirectory() -> URL? {
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
