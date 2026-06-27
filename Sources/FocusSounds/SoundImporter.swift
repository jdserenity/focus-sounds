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
  typealias ProgressHandler = @Sendable (Float) -> Void

  func importSound(
    from sourceURL: URL,
    to directory: URL,
    existingFilenames: [String],
    progress: ProgressHandler? = nil
  ) async throws -> URL {
    let didAccess = sourceURL.startAccessingSecurityScopedResource()
    defer { if didAccess { sourceURL.stopAccessingSecurityScopedResource() } }

    progress?(0.02)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let baseName = sourceURL.deletingPathExtension().lastPathComponent
    let outputName = SoundImport.deduplicatedFilename(baseName: baseName, existingFilenames: existingFilenames)
    let outputURL = directory.appendingPathComponent(outputName)
    if FileManager.default.fileExists(atPath: outputURL.path) {
      try FileManager.default.removeItem(at: outputURL)
    }

    let asset = AVURLAsset(url: sourceURL)
    progress?(0.06)
    let sourceTracks = try await asset.loadTracks(withMediaType: .audio)
    guard let sourceTrack = sourceTracks.first else { throw SoundImporterError.noAudioTrack }

    let sourceDuration = try await asset.load(.duration)
    let exportSeconds = SoundImport.clampedDuration(sourceSeconds: CMTimeGetSeconds(sourceDuration))
    let timeRange = CMTimeRange(
      start: .zero,
      duration: CMTime(seconds: exportSeconds, preferredTimescale: 600)
    )
    progress?(0.10)

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

    try await export(session) { exportProgress in
      progress?(0.10 + exportProgress * 0.90)
    }
    progress?(1)
    return outputURL
  }

  private func export(_ session: AVAssetExportSession, progress: @escaping @Sendable (Float) -> Void) async throws {
    let pollTask = Task {
      while !Task.isCancelled {
        let status = session.status
        if status == .exporting || status == .waiting {
          progress(Float(session.progress))
        }
        if status == .completed || status == .failed || status == .cancelled { break }
        try await Task.sleep(nanoseconds: 50_000_000)
      }
    }
    defer { pollTask.cancel() }

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      session.exportAsynchronously {
        let status = session.status
        let error = session.error
        switch status {
        case .completed:
          progress(1)
          continuation.resume()
        case .cancelled:
          continuation.resume(throwing: SoundImporterError.cancelled)
        case .failed:
          let detail = error?.localizedDescription ?? "unknown error"
          continuation.resume(throwing: SoundImporterError.exportFailed(detail))
        default:
          continuation.resume(throwing: SoundImporterError.exportFailed("status \(status.rawValue)"))
        }
      }
    }
  }
}
