import FocusSoundsCore
import Foundation
import MediaPlayer

/// Publishes Focus Sounds to macOS Now Playing and handles AirPods / media-key play-pause.
@MainActor
final class NowPlayingController {
  typealias CommandHandler = () -> Void

  private var playHandler: CommandHandler?
  private var pauseHandler: CommandHandler?
  private var toggleHandler: CommandHandler?
  private var didRegisterCommands = false

  func start(
    onPlay: @escaping CommandHandler,
    onPause: @escaping CommandHandler,
    onToggle: @escaping CommandHandler
  ) {
    playHandler = onPlay
    pauseHandler = onPause
    toggleHandler = onToggle
    guard !didRegisterCommands else { return }

    let center = MPRemoteCommandCenter.shared()
    center.playCommand.isEnabled = true
    center.pauseCommand.isEnabled = true
    center.togglePlayPauseCommand.isEnabled = true
    center.stopCommand.isEnabled = false
    center.nextTrackCommand.isEnabled = false
    center.previousTrackCommand.isEnabled = false
    center.changePlaybackPositionCommand.isEnabled = false
    center.skipForwardCommand.isEnabled = false
    center.skipBackwardCommand.isEnabled = false

    center.playCommand.addTarget { [weak self] _ in
      guard let self else { return .commandFailed }
      Task { @MainActor in self.playHandler?() }
      return .success
    }
    center.pauseCommand.addTarget { [weak self] _ in
      guard let self else { return .commandFailed }
      Task { @MainActor in self.pauseHandler?() }
      return .success
    }
    center.togglePlayPauseCommand.addTarget { [weak self] _ in
      guard let self else { return .commandFailed }
      Task { @MainActor in self.toggleHandler?() }
      return .success
    }

    didRegisterCommands = true
  }

  func publish(_ presentation: NowPlayingPresentation) {
    let center = MPNowPlayingInfoCenter.default()
    switch presentation {
    case .inactive:
      center.playbackState = .stopped
      center.nowPlayingInfo = nil
    case .active(let title, let isPlaying):
      center.nowPlayingInfo = [
        MPMediaItemPropertyTitle: title,
        MPMediaItemPropertyArtist: "Focus Sounds",
        MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
      ]
      center.playbackState = isPlaying ? .playing : .paused
    }
  }
}
