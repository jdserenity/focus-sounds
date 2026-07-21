import Foundation

public enum AudioOutputKind: Equatable, Sendable {
  case headphones
  case other
}

public enum AudioOutputClassifier {
  /// FourCC 'bltn'
  public static let builtInTransport: UInt32 = 0x626C746E
  /// FourCC 'blue'
  public static let bluetoothTransport: UInt32 = 0x626C7565
  /// FourCC 'blea'
  public static let bluetoothLETransport: UInt32 = 0x626C6561
  /// FourCC 'hdpn'
  public static let headphonesDataSource: UInt32 = 0x6864706E
  /// FourCC 'ispk'
  public static let internalSpeakersDataSource: UInt32 = 0x6973706B

  public static func kind(transport: UInt32, dataSource: UInt32?) -> AudioOutputKind {
    if transport == bluetoothTransport || transport == bluetoothLETransport {
      return .headphones
    }
    if dataSource == headphonesDataSource {
      return .headphones
    }
    return .other
  }
}
