import AVFoundation
import Foundation

@MainActor
final class FocusPlayer {
  private var player: AVPlayer?
  private var endObserver: NSObjectProtocol?

  var isPlaying: Bool { (player?.rate ?? 0) > 0 }
  var hasLoadedItem: Bool { player != nil }

  var outputVolume: Float {
    get { player?.volume ?? 0 }
    set { player?.volume = newValue }
  }

  func load(url: URL) throws {
    stop()
    let item = AVPlayerItem(url: url)
    let player = AVPlayer(playerItem: item)
    player.actionAtItemEnd = .pause
    self.player = player
    observeEnd(of: item)
  }

  func play() throws {
    guard let player else { throw FocusPlayerError.nothingLoaded }
    player.play()
    if player.rate == 0 {
      throw FocusPlayerError.playbackFailed
    }
  }

  func pause() {
    player?.pause()
  }

  func stop() {
    if let endObserver {
      NotificationCenter.default.removeObserver(endObserver)
      self.endObserver = nil
    }
    player?.pause()
    player?.replaceCurrentItem(with: nil)
    player = nil
  }

  private func observeEnd(of item: AVPlayerItem) {
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.restartFromBeginning() }
    }
  }

  private func restartFromBeginning() {
    guard let player else { return }
    player.seek(to: .zero)
    player.play()
  }
}

enum FocusPlayerError: LocalizedError {
  case nothingLoaded
  case playbackFailed

  var errorDescription: String? {
    switch self {
    case .nothingLoaded:
      return "No sound loaded."
    case .playbackFailed:
      return "Playback failed to start."
    }
  }
}
