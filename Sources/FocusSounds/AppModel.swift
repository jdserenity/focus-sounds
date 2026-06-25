import AVFoundation
import FocusSoundsCore
import Foundation

@available(macOS 14.2, *)
@MainActor
@Observable
final class AppModel {
  enum PermissionState {
    case unknown
    case granted
    case denied
  }

  private static let focusVolumeKey = "focusVolume"

  private let player = FocusPlayer()
  private let monitor = SystemAudioMonitor()
  private var ducking = DuckingController()
  private var volumeFader = VolumeFader()
  private var clockMs = 0
  private var monitorTimer: DispatchSourceTimer?

  var sounds: [FocusSound] = SoundCatalog.bundledSounds()
  var selectedSoundID: String?
  var isPlaying = false
  var isDucked = false
  var permissionState: PermissionState = .unknown
  var externalLevel: Float = 0
  var statusMessage = "Add audio files to Sounds/, then rebuild."
  var focusVolume: Float

  var selectedSound: FocusSound? {
    guard let selectedSoundID else { return sounds.first }
    return sounds.first { $0.id == selectedSoundID } ?? sounds.first
  }

  init() {
    let stored = UserDefaults.standard.float(forKey: Self.focusVolumeKey)
    focusVolume = stored > 0 ? stored : 0.75
    selectedSoundID = sounds.first?.id
    if !sounds.isEmpty {
      statusMessage = "Ready. Press play to start focus audio."
    }
  }

  func togglePlayPause() {
    if isPlaying {
      pause()
    } else {
      play()
    }
  }

  func play() {
    guard let sound = selectedSound else {
      statusMessage = "No sounds bundled. Copy files into Sounds/ and run scripts/build-app.sh."
      return
    }

    do {
      if !player.hasLoadedItem {
        try player.load(url: sound.url)
        volumeFader = VolumeFader(current: focusVolume * (ducking.isDucked ? volumeFader.duckFloor : 1))
      }
      try player.play()
      isPlaying = true
      applyVolume()
      statusMessage = "Playing \(sound.title)."
      do {
        try startMonitoringIfNeeded()
      } catch {
        permissionState = .denied
        statusMessage = "Playing \(sound.title). Ducking unavailable: \(error.localizedDescription)"
      }
    } catch {
      statusMessage = "Could not start: \(error.localizedDescription)"
      isPlaying = false
    }
  }

  func pause() {
    player.pause()
    monitor.stop()
    monitorTimer?.cancel()
    monitorTimer = nil
    isPlaying = false
    externalLevel = 0
    statusMessage = "Paused."
  }

  func setFocusVolume(_ volume: Float) {
    focusVolume = min(1, max(0, volume))
    UserDefaults.standard.set(focusVolume, forKey: Self.focusVolumeKey)
    let target = focusVolume * (ducking.isDucked ? volumeFader.duckFloor : 1)
    if isPlaying {
      applyVolume()
    } else if player.hasLoadedItem {
      volumeFader = VolumeFader(
        current: target,
        duckFloor: volumeFader.duckFloor,
        duckFadeMs: volumeFader.duckFadeMs,
        restoreFadeMs: volumeFader.restoreFadeMs
      )
      player.outputVolume = target
    }
  }

  func selectSound(_ sound: FocusSound) {
    selectedSoundID = sound.id
    player.stop()
    monitor.stop()
    monitorTimer?.cancel()
    monitorTimer = nil
    isPlaying = false
    isDucked = false
    externalLevel = 0
    clockMs = 0
    ducking = DuckingController()
    volumeFader = VolumeFader(current: focusVolume)
    if let title = selectedSound?.title {
      statusMessage = "Selected \(title). Press play to start."
    }
  }

  private func startMonitoringIfNeeded() throws {
    guard !monitor.isRunning else { return }

    try monitor.start { [weak self] level in
      Task { @MainActor in self?.handleExternalLevel(level) }
    }

    permissionState = .granted
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now(), repeating: .milliseconds(50))
    timer.setEventHandler { [weak self] in
      Task { @MainActor in self?.tick() }
    }
    timer.resume()
    monitorTimer = timer
  }

  private func tick() {
    clockMs += 50
    applyVolume()
  }

  private func handleExternalLevel(_ level: Float) {
    externalLevel = level
    _ = ducking.update(level: level, nowMs: clockMs)
    isDucked = ducking.isDucked
  }

  private func applyVolume() {
    let level = volumeFader.step(baseVolume: focusVolume, isDucked: ducking.isDucked, dtMs: 50)
    player.outputVolume = level
  }
}
