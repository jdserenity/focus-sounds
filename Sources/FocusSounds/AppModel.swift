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
  private let outputRouteMonitor = OutputRouteMonitor()
  private let nowPlaying = NowPlayingController()
  private let globalHotkeyController = GlobalHotkeyController()
  private let hotkeyCapture = HotkeyCaptureSession()
  private var ducking = DuckingController()
  private var volumeFader = VolumeFader()
  private var headphoneAutoPause = HeadphoneAutoPauseController()
  private var clockMs = 0
  private var monitorTimer: DispatchSourceTimer?

  var sounds: [FocusSound] = SoundCatalog.allSounds()
  var selectedSoundID: String?
  var isPlaying = false
  var isImporting = false
  var importProgress: Float = 0
  var importFileName = ""
  var isDucked = false
  var permissionState: PermissionState = .unknown
  var externalLevel: Float = 0
  var focusVolume: Float
  var globalHotkey: GlobalHotkey
  var isCapturingHotkey = false

  var globalHotkeyMenuTitle: String {
    if isCapturingHotkey { return "Press" }
    return "\(globalHotkey.displayLabel)"
  }

  var selectedSound: FocusSound? {
    guard let selectedSoundID else { return sounds.first }
    return sounds.first { $0.id == selectedSoundID } ?? sounds.first
  }

  var canDeleteSelectedSound: Bool {
    selectedSound?.isImported == true
  }

  init() {
    let stored = UserDefaults.standard.float(forKey: Self.focusVolumeKey)
    focusVolume = stored > 0 ? stored : 0.75
    globalHotkey = Self.loadGlobalHotkey()
    selectedSoundID = sounds.first?.id
    startOutputRouteMonitoring()
    startNowPlaying()
    startGlobalHotkey()
  }

  func togglePlayPause() {
    if isPlaying {
      pause(manual: true)
    } else {
      play(manual: true)
    }
  }

  @discardableResult
  func importSound(from url: URL) async -> Bool {
    guard !isImporting else { return false }
    isImporting = true
    importProgress = 0
    importFileName = url.deletingPathExtension().lastPathComponent

    let directory = SoundCatalog.importedSoundsDirectory()
    let existing = SoundCatalog.existingImportedFilenames()
    do {
      let outputURL = try await Task.detached {
        try await SoundImporter().importSound(from: url, to: directory, existingFilenames: existing) { progress in
          Task { @MainActor in
            self.importProgress = progress
          }
        }
      }.value
      importProgress = 1
      reloadSounds()
      selectSound(SoundCatalog.focusSound(for: outputURL, isImported: true))
      try await Task.sleep(nanoseconds: 500_000_000)
      isImporting = false
      importProgress = 0
      importFileName = ""
      return true
    } catch {
      isImporting = false
      importProgress = 0
      importFileName = ""
      AppAlert.show(title: "Import failed", message: error.localizedDescription)
      return false
    }
  }

  func deleteSelectedSound() {
    guard let sound = selectedSound, sound.isImported else { return }
    pause(manual: true)
    player.stop()
    do {
      try SoundCatalog.deleteImportedSound(sound)
      reloadSounds()
      publishNowPlaying()
    } catch {
      AppAlert.show(title: "Could not delete", message: error.localizedDescription)
      publishNowPlaying()
    }
  }

  func reloadSounds() {
    sounds = SoundCatalog.allSounds()
    if let selectedSoundID, !sounds.contains(where: { $0.id == selectedSoundID }) {
      self.selectedSoundID = sounds.first?.id
    }
  }

  func play(manual: Bool = true) {
    guard let sound = selectedSound else { return }
    if manual { headphoneAutoPause.noteManualPlay() }

    do {
      if !player.hasLoadedItem {
        try player.load(url: sound.url)
        volumeFader = VolumeFader(current: focusVolume * (ducking.isDucked ? volumeFader.duckFloor : 1))
      }
      try player.play()
      isPlaying = true
      applyVolume()
      publishNowPlaying()
      do {
        try startMonitoringIfNeeded()
      } catch {
        permissionState = .denied
      }
    } catch {
      AppAlert.show(title: "Could not play", message: error.localizedDescription)
      isPlaying = false
      publishNowPlaying()
    }
  }

  func pause(manual: Bool = true) {
    if manual { headphoneAutoPause.noteManualPause() }
    player.pause()
    monitor.stop()
    monitorTimer?.cancel()
    monitorTimer = nil
    isPlaying = false
    externalLevel = 0
    publishNowPlaying()
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
    headphoneAutoPause.noteManualPause()
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
    publishNowPlaying()
  }

  func beginGlobalHotkeyCapture() {
    isCapturingHotkey = true
    hotkeyCapture.start(
      onCapture: { [weak self] hotkey in
        self?.setGlobalHotkey(hotkey)
      },
      onCancel: { [weak self] in
        self?.hotkeyCapture.stop()
        self?.isCapturingHotkey = false
      }
    )
  }

  func cancelGlobalHotkeyCapture() {
    hotkeyCapture.stop()
    isCapturingHotkey = false
  }

  func setGlobalHotkey(_ hotkey: GlobalHotkey) {
    hotkeyCapture.stop()
    isCapturingHotkey = false
    globalHotkey = hotkey
    saveGlobalHotkey(hotkey)
    globalHotkeyController.apply(hotkey)
  }

  private static func loadGlobalHotkey() -> GlobalHotkey {
    guard let data = UserDefaults.standard.data(forKey: GlobalHotkey.userDefaultsKey),
          let hotkey = try? JSONDecoder().decode(GlobalHotkey.self, from: data),
          hotkey.isValid else {
      return .default
    }
    return hotkey
  }

  private func saveGlobalHotkey(_ hotkey: GlobalHotkey) {
    guard let data = try? JSONEncoder().encode(hotkey) else { return }
    UserDefaults.standard.set(data, forKey: GlobalHotkey.userDefaultsKey)
  }

  private func startGlobalHotkey() {
    globalHotkeyController.onTrigger = { [weak self] in
      self?.togglePlayPause()
    }
    globalHotkeyController.apply(globalHotkey)
  }

  private func startNowPlaying() {
    nowPlaying.start(
      onPlay: { [weak self] in self?.play(manual: true) },
      onPause: { [weak self] in self?.pause(manual: true) },
      onToggle: { [weak self] in self?.togglePlayPause() }
    )
  }

  private func publishNowPlaying() {
    let presentation = NowPlayingPresentationBuilder.make(
      title: selectedSound?.title,
      isPlaying: isPlaying,
      hasSession: player.hasLoadedItem
    )
    nowPlaying.publish(presentation)
  }

  private func startOutputRouteMonitoring() {
    do {
      try outputRouteMonitor.start { [weak self] kind in
        Task { @MainActor in self?.handleOutputKind(kind) }
      }
    } catch {
      // Route monitoring is best-effort; playback still works without auto-pause.
    }
  }

  private func handleOutputKind(_ kind: AudioOutputKind) {
    switch headphoneAutoPause.update(kind: kind, isPlaying: isPlaying) {
    case .none:
      break
    case .pause:
      pause(manual: false)
    case .resume:
      play(manual: false)
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
