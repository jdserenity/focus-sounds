import FocusSoundsCore
import UniformTypeIdentifiers

enum SoundImportTypes {
  static let all: [UTType] = {
    var types: [UTType] = [.audio, .movie, .mpeg4Movie, .mpeg4Audio, .mp3, .aiff, .wav]
    for ext in SoundImport.supportedExtensions {
      if let type = UTType(filenameExtension: ext), !types.contains(type) { types.append(type) }
    }
    return types
  }()
}
