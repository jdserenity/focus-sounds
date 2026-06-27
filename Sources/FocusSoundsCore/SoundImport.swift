import Foundation

public enum SoundImport {
  public static let maxDurationSeconds: TimeInterval = 600
  public static let outputExtension = "m4a"
  public static let supportedExtensions = ["mp3", "wav", "m4a", "mp4", "aiff", "aac", "caf", "flac", "mov", "mkv", "webm"]

  public static func clampedDuration(sourceSeconds: TimeInterval, maxSeconds: TimeInterval = maxDurationSeconds) -> TimeInterval {
    min(max(0, sourceSeconds), maxSeconds)
  }

  public static func sanitizedBaseName(from filename: String) -> String {
    let base = (filename as NSString).deletingPathExtension
    let folded = base
      .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = folded.split { !$0.isLetter && !$0.isNumber }.map(String.init)
    let joined = parts.joined(separator: "-").lowercased()
    return joined.isEmpty ? "imported-sound" : joined
  }

  public static func displayTitle(fromFilename filename: String) -> String {
    (filename as NSString).deletingPathExtension
      .replacingOccurrences(of: "_", with: " ")
      .replacingOccurrences(of: "-", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  public static func outputFilename(baseName: String) -> String {
    "\(sanitizedBaseName(from: baseName)).\(outputExtension)"
  }

  public static func deduplicatedFilename(baseName: String, existingFilenames: [String]) -> String {
    let first = outputFilename(baseName: baseName)
    guard existingFilenames.contains(first) else { return first }
    let stem = sanitizedBaseName(from: baseName)
    var n = 2
    while true {
      let candidate = "\(stem)-\(n).\(outputExtension)"
      if !existingFilenames.contains(candidate) { return candidate }
      n += 1
    }
  }

  public static func isContainedIn(directory: URL, file: URL) -> Bool {
    let dir = directory.standardizedFileURL.path
    let path = file.standardizedFileURL.path
    return path == dir || path.hasPrefix(dir + "/")
  }
}
