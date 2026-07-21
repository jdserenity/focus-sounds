import AVFoundation
import FocusSoundsCore
import Foundation

@MainActor
final class FocusPlayer {
  private var slotA: AVPlayer?
  private var slotB: AVPlayer?
  private var activeSlotIsA = true
  private var loadedURL: URL?
  private var trackDurationSeconds = 0.0
  private var crossfadeSeconds = 0.0
  private var isCrossfading = false
  private var timeObserver: Any?
  private var endObserver: NSObjectProtocol?
  private var targetOutputVolume: Float = 1

  var isPlaying: Bool {
    (slotA?.rate ?? 0) > 0 || (slotB?.rate ?? 0) > 0
  }

  var hasLoadedItem: Bool { slotA != nil }

  var outputVolume: Float {
    get { targetOutputVolume }
    set {
      targetOutputVolume = newValue
      applyVolumes()
    }
  }

  func load(url: URL) throws {
    stop()
    loadedURL = url
    let item = AVPlayerItem(url: url)
    let player = AVPlayer(playerItem: item)
    player.actionAtItemEnd = .pause
    slotA = player
    slotB = nil
    activeSlotIsA = true
    isCrossfading = false
    observeDuration(of: item)
    observeEnd(of: item)
    installTimeObserver(on: player)
  }

  func play() throws {
    guard let active = activePlayer else { throw FocusPlayerError.nothingLoaded }
    active.play()
    if isCrossfading { crossfadePartner?.play() }
    if active.rate == 0, !isCrossfading {
      throw FocusPlayerError.playbackFailed
    }
  }

  func pause() {
    slotA?.pause()
    slotB?.pause()
  }

  func stop() {
    removeTimeObserver()
    removeEndObserver()
    slotA?.pause()
    slotB?.pause()
    slotA?.replaceCurrentItem(with: nil)
    slotB?.replaceCurrentItem(with: nil)
    slotA = nil
    slotB = nil
    loadedURL = nil
    trackDurationSeconds = 0
    crossfadeSeconds = 0
    isCrossfading = false
    activeSlotIsA = true
  }

  private var activePlayer: AVPlayer? { activeSlotIsA ? slotA : slotB }
  private var crossfadePartner: AVPlayer? { activeSlotIsA ? slotB : slotA }

  private func observeDuration(of item: AVPlayerItem) {
    let asset = item.asset
    Task { @MainActor in
      do {
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite, seconds > 0 else { return }
        trackDurationSeconds = seconds
        crossfadeSeconds = LoopCrossfade.effectiveCrossfadeSeconds(trackDurationSeconds: seconds)
      } catch {
        return
      }
    }
  }

  private func observeEnd(of item: AVPlayerItem) {
    removeEndObserver()
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.handlePlayToEnd() }
    }
  }

  private func removeEndObserver() {
    if let endObserver {
      NotificationCenter.default.removeObserver(endObserver)
      self.endObserver = nil
    }
  }

  private func handlePlayToEnd() {
    guard !isCrossfading, let active = activePlayer else { return }
    active.seek(to: .zero)
    active.play()
  }

  private func installTimeObserver(on player: AVPlayer) {
    removeTimeObserver()
    let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
    timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
      Task { @MainActor in self?.handlePeriodicTime(time) }
    }
  }

  private func removeTimeObserver() {
    if let timeObserver {
      (activePlayer ?? slotA)?.removeTimeObserver(timeObserver)
    }
    timeObserver = nil
  }

  private func handlePeriodicTime(_ time: CMTime) {
    let currentSeconds = CMTimeGetSeconds(time)
    guard currentSeconds.isFinite, trackDurationSeconds > 0 else { return }

    if LoopCrossfade.shouldBeginCrossfade(
      currentSeconds: currentSeconds,
      trackDurationSeconds: trackDurationSeconds,
      crossfadeSeconds: crossfadeSeconds,
      isCrossfading: isCrossfading
    ) {
      beginCrossfade()
    }

    if isCrossfading {
      let progress = LoopCrossfade.progress(
        currentSeconds: currentSeconds,
        trackDurationSeconds: trackDurationSeconds,
        crossfadeSeconds: crossfadeSeconds
      )
      applyVolumes(progress: progress)
      if progress >= 1 {
        finishCrossfade()
      }
    }
  }

  private func beginCrossfade() {
    guard let url = loadedURL, crossfadePartner == nil, activePlayer != nil else { return }
    let item = AVPlayerItem(url: url)
    let incoming = AVPlayer(playerItem: item)
    incoming.actionAtItemEnd = .pause
    if activeSlotIsA {
      slotB = incoming
    } else {
      slotA = incoming
    }
    incoming.volume = 0
    incoming.seek(to: .zero)
    incoming.play()
    isCrossfading = true
    applyVolumes(progress: 0)
  }

  private func finishCrossfade() {
    guard let outgoing = activePlayer, let incoming = crossfadePartner else { return }
    removeTimeObserver()
    outgoing.pause()
    outgoing.replaceCurrentItem(with: nil)
    if activeSlotIsA {
      slotA = nil
    } else {
      slotB = nil
    }
    activeSlotIsA.toggle()
    isCrossfading = false
    installTimeObserver(on: incoming)
    applyVolumes()
  }

  private func applyVolumes(progress: Double? = nil) {
    guard let active = activePlayer else { return }
    if isCrossfading, let progress {
      let channels = LoopCrossfade.channelVolumes(progress: progress)
      active.volume = targetOutputVolume * channels.outgoing
      crossfadePartner?.volume = targetOutputVolume * channels.incoming
    } else {
      active.volume = targetOutputVolume
      crossfadePartner?.volume = 0
    }
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
