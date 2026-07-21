import AudioToolbox
import FocusSoundsCore
import Foundation

/// Watches the Mac's default sound output and reports whether it looks like headphones/earbuds.
final class OutputRouteMonitor {
  typealias KindHandler = (AudioOutputKind) -> Void

  private let queue = DispatchQueue(label: "FocusSounds.OutputRouteMonitor", qos: .userInitiated)
  private var kindHandler: KindHandler?
  private var observedDeviceID: AudioDeviceID = .unknown
  private var defaultDeviceListener: AudioObjectPropertyListenerBlock?
  private var dataSourceListener: AudioObjectPropertyListenerBlock?
  private(set) var isRunning = false

  func start(kindHandler: @escaping KindHandler) throws {
    guard !isRunning else { return }
    self.kindHandler = kindHandler
    try addDefaultDeviceListener()
    try attachDataSourceListener()
    isRunning = true
    emitCurrentKind()
  }

  func stop() {
    removeDataSourceListener()
    removeDefaultDeviceListener()
    kindHandler = nil
    isRunning = false
  }

  deinit { stop() }

  private func emitCurrentKind() {
    guard let kind = Self.currentKind() else { return }
    kindHandler?(kind)
  }

  private static func currentKind() -> AudioOutputKind? {
    guard let deviceID = try? AudioObjectID.defaultOutputDeviceID(),
          let transport = try? deviceID.transportType()
    else { return nil }
    return AudioOutputClassifier.kind(transport: transport, dataSource: deviceID.outputDataSource())
  }

  private func addDefaultDeviceListener() throws {
    let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      guard let self else { return }
      try? self.attachDataSourceListener()
      self.emitCurrentKind()
    }
    var address = Self.defaultOutputAddress
    let err = AudioObjectAddPropertyListenerBlock(AudioObjectID.system, &address, queue, listener)
    guard err == noErr else {
      throw CoreAudioHelperError.propertyReadFailed("add default output listener: \(err)")
    }
    defaultDeviceListener = listener
  }

  private func removeDefaultDeviceListener() {
    guard let listener = defaultDeviceListener else { return }
    var address = Self.defaultOutputAddress
    AudioObjectRemovePropertyListenerBlock(AudioObjectID.system, &address, queue, listener)
    defaultDeviceListener = nil
  }

  private func attachDataSourceListener() throws {
    removeDataSourceListener()
    let deviceID = try AudioObjectID.defaultOutputDeviceID()
    let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      self?.emitCurrentKind()
    }
    var address = Self.dataSourceAddress
    let err = AudioObjectAddPropertyListenerBlock(deviceID, &address, queue, listener)
    observedDeviceID = deviceID
    // Some devices have no output data source; default-device changes are enough for those.
    guard err == noErr else { return }
    dataSourceListener = listener
  }

  private func removeDataSourceListener() {
    guard let listener = dataSourceListener, observedDeviceID.isValid else {
      observedDeviceID = .unknown
      dataSourceListener = nil
      return
    }
    var address = Self.dataSourceAddress
    AudioObjectRemovePropertyListenerBlock(observedDeviceID, &address, queue, listener)
    observedDeviceID = .unknown
    dataSourceListener = nil
  }

  private static var defaultOutputAddress: AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
  }

  private static var dataSourceAddress: AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDataSource,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
  }
}
