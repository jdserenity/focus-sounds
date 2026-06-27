import AVFoundation
import FocusSoundsCore
import Foundation

enum SoundImporterError: LocalizedError {
  case noAudioTrack
  case exportSessionFailed
  case exportFailed(String)
  case cancelled

  var errorDescription: String? {
    switch self {
    case .noAudioTrack:
      return "That file has no audio track."
    case .exportSessionFailed:
      return "Could not start audio conversion."
    case .exportFailed(let detail):
      return "Audio conversion failed: \(detail)"
    case .cancelled:
      return "Import cancelled."
    }
  }
}

struct SoundImporter {
  func importSound(from sourceURL: URL, to directory: URL, existingFilenames: [String]) async throws -> URL {
    let didAccess = sourceURL.startAccessingSecurityScopedResource()
    defer { if didAccess { sourceURL.stopAccessingSecurityScopedResource() } }

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let baseName = sourceURL.deletingPathExtension().lastPathComponent
    let outputName = SoundImport.deduplicatedFilename(baseName: baseName, existingFilenames: existingFilenames)
    let outputURL = directory.appendingPathComponent(outputName)
    if FileManager.default.fileExists(atPath: outputURL.path) {
      try FileManager.default.removeItem(at: outputURL)
    }

    let asset = AVURLAsset(url: sourceURL)
    let sourceTracks = try await asset.loadTracks(withMediaType: .audio)
    guard let sourceTrack = sourceTracks.first else { throw SoundImporterError.noAudioTrack }

    let sourceDuration = try await asset.load(.duration)
    let exportSeconds = SoundImport.clampedDuration(sourceSeconds: CMTimeGetSeconds(sourceDuration))
    let timeRange = CMTimeRange(
      start: .zero,
      duration: CMTime(seconds: exportSeconds, preferredTimescale: 600)
    )

    let composition = AVMutableComposition()
    guard let track = composition.addMutableTrack(
      withMediaType: .audio,
      preferredTrackID: kCMPersistentTrackID_Invalid
    ) else {
      throw SoundImporterError.exportSessionFailed
    }
    try track.insertTimeRange(timeRange, of: sourceTrack, at: .zero)

    guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
      throw SoundImporterError.exportSessionFailed
    }
    session.outputURL = outputURL
    session.outputFileType = .m4a
    session.timeRange = CMTimeRange(start: .zero, duration: timeRange.duration)

    try await export(session)
    return outputURL
  }

  private func export(_ session: AVAssetExportSession) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      session.exportAsynchronously {
        switch session.status {
        case .completed:
          continuation.resume()
        case .cancelled:
          continuation.resume(throwing: SoundImporterError.cancelled)
        case .failed:
          let detail = session.error?.localizedDescription ?? "unknown error"
          continuation.resume(throwing: SoundImporterError.exportFailed(detail))
        default:
          continuation.resume(throwing: SoundImporterError.exportFailed("status \(session.status.rawValue)"))
        }
      }
    }
  }
}
