import AudioToolbox
import AVFoundation
import FocusSoundsCore
import Foundation

@available(macOS 14.2, *)
final class SystemAudioMonitor {
  typealias LevelHandler = (Float) -> Void

  private let queue = DispatchQueue(label: "FocusSounds.SystemAudioMonitor", qos: .userInitiated)
  private var processTapID: AudioObjectID = .unknown
  private var aggregateDeviceID: AudioObjectID = .unknown
  private var deviceProcID: AudioDeviceIOProcID?
  private var levelHandler: LevelHandler?
  private(set) var isRunning = false

  func start(levelHandler: @escaping LevelHandler) throws {
    guard !isRunning else { return }
    self.levelHandler = levelHandler

    let pid = ProcessInfo.processInfo.processIdentifier
    let selfProcessID = try AudioObjectID.translatePIDToProcessObjectID(pid: pid)
    let tapDescription = CATapDescription(stereoGlobalTapButExcludeProcesses: [selfProcessID])
    tapDescription.uuid = UUID()
    tapDescription.name = "Focus Sounds Monitor"

    var tapID = AudioObjectID.unknown
    let tapErr = AudioHardwareCreateProcessTap(tapDescription, &tapID)
    guard tapErr == noErr, tapID.isValid else {
      throw CoreAudioHelperError.tapCreationFailed(tapErr)
    }
    processTapID = tapID

    let outputID = try AudioObjectID.defaultSystemOutputDeviceID()
    let outputUID = try outputID.deviceUID()
    let aggregateUID = UUID().uuidString
    let aggregateDescription: [String: Any] = [
      kAudioAggregateDeviceNameKey: "FocusSounds Monitor",
      kAudioAggregateDeviceUIDKey: aggregateUID,
      kAudioAggregateDeviceMainSubDeviceKey: outputUID,
      kAudioAggregateDeviceIsPrivateKey: true,
      kAudioAggregateDeviceIsStackedKey: false,
      kAudioAggregateDeviceTapAutoStartKey: true,
      kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
      kAudioAggregateDeviceTapListKey: [[
        kAudioSubTapDriftCompensationKey: true,
        kAudioSubTapUIDKey: tapDescription.uuid.uuidString,
      ]],
    ]

    var aggregateID = AudioObjectID.unknown
    let aggregateErr = AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &aggregateID)
    guard aggregateErr == noErr, aggregateID.isValid else {
      AudioHardwareDestroyProcessTap(tapID)
      processTapID = .unknown
      throw CoreAudioHelperError.aggregateCreationFailed(aggregateErr)
    }
    aggregateDeviceID = aggregateID

    var procID: AudioDeviceIOProcID?
    let procErr = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateDeviceID, queue) { [weak self] _, inInputData, _, _, _ in
      self?.handleInput(inInputData)
    }
    guard procErr == noErr, let procID else {
      stop()
      throw CoreAudioHelperError.ioProcCreationFailed(procErr)
    }
    deviceProcID = procID

    let startErr = AudioDeviceStart(aggregateDeviceID, procID)
    guard startErr == noErr else {
      stop()
      throw CoreAudioHelperError.deviceStartFailed(startErr)
    }

    isRunning = true
  }

  func stop() {
    defer {
      isRunning = false
      levelHandler = nil
    }

    if aggregateDeviceID.isValid {
      if let deviceProcID {
        AudioDeviceStop(aggregateDeviceID, deviceProcID)
        AudioDeviceDestroyIOProcID(aggregateDeviceID, deviceProcID)
        self.deviceProcID = nil
      }
      AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
      aggregateDeviceID = .unknown
    }

    if processTapID.isValid {
      AudioHardwareDestroyProcessTap(processTapID)
      processTapID = .unknown
    }
  }

  deinit { stop() }

  private func handleInput(_ inputData: UnsafePointer<AudioBufferList>) {
    let bufferList = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
    var samples: [Float] = []
    samples.reserveCapacity(4096)
    for buffer in bufferList {
      guard let data = buffer.mData else { continue }
      let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
      guard count > 0 else { continue }
      let floats = data.assumingMemoryBound(to: Float.self)
      samples.append(contentsOf: UnsafeBufferPointer(start: floats, count: count))
    }
    levelHandler?(RMSMeter.level(from: samples))
  }
}
