import Foundation
import AudioToolbox

public extension AudioObjectID {
  static let system = AudioObjectID(kAudioObjectSystemObject)
  static let unknown = kAudioObjectUnknown

  var isValid: Bool { self != .unknown }

  static func translatePIDToProcessObjectID(pid: pid_t) throws -> AudioObjectID {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var processObject = AudioObjectID.unknown
    var dataSize = UInt32(MemoryLayout<AudioObjectID>.size)
    var pidCopy = pid
    let err = withUnsafeMutablePointer(to: &pidCopy) { qualifier in
      withUnsafeMutablePointer(to: &processObject) { value in
        AudioObjectGetPropertyData(system, &address, UInt32(MemoryLayout<pid_t>.size), qualifier, &dataSize, value)
      }
    }
    guard err == noErr, processObject.isValid else {
      throw CoreAudioHelperError.propertyReadFailed("translate PID \(pid): \(err)")
    }
    return processObject
  }

  static func defaultSystemOutputDeviceID() throws -> AudioDeviceID {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var deviceID = AudioDeviceID.unknown
    var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    let err = AudioObjectGetPropertyData(system, &address, 0, nil, &dataSize, &deviceID)
    guard err == noErr, deviceID.isValid else {
      throw CoreAudioHelperError.propertyReadFailed("default output device: \(err)")
    }
    return deviceID
  }

  func deviceUID() throws -> String {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceUID,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var uid = "" as CFString
    var dataSize = UInt32(MemoryLayout<CFString>.size)
    let err = withUnsafeMutablePointer(to: &uid) { pointer in
      AudioObjectGetPropertyData(self, &address, 0, nil, &dataSize, pointer)
    }
    guard err == noErr else {
      throw CoreAudioHelperError.propertyReadFailed("device UID: \(err)")
    }
    return uid as String
  }

  func tapStreamDescription() throws -> AudioStreamBasicDescription {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioTapPropertyFormat,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var description = AudioStreamBasicDescription()
    var dataSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    let err = AudioObjectGetPropertyData(self, &address, 0, nil, &dataSize, &description)
    guard err == noErr else {
      throw CoreAudioHelperError.propertyReadFailed("tap format: \(err)")
    }
    return description
  }
}

public enum CoreAudioHelperError: Error, CustomStringConvertible {
  case propertyReadFailed(String)
  case tapCreationFailed(OSStatus)
  case aggregateCreationFailed(OSStatus)
  case ioProcCreationFailed(OSStatus)
  case deviceStartFailed(OSStatus)

  public var description: String {
    switch self {
    case .propertyReadFailed(let message): return message
    case .tapCreationFailed(let status): return "Process tap creation failed: \(status)"
    case .aggregateCreationFailed(let status): return "Aggregate device creation failed: \(status)"
    case .ioProcCreationFailed(let status): return "I/O proc creation failed: \(status)"
    case .deviceStartFailed(let status): return "Audio device start failed: \(status)"
    }
  }
}
