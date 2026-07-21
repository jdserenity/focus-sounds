import Foundation

public struct GlobalHotkey: Codable, Equatable, Sendable {
  public var keyCode: UInt16
  public var carbonModifiers: UInt32

  public static let userDefaultsKey = "globalPlayPauseHotkey"

  /// Control + Option + Space
  public static let `default` = GlobalHotkey(keyCode: 49, carbonModifiers: UInt32(controlKey | optionKey))
  
  public init(keyCode: UInt16, carbonModifiers: UInt32) {
    self.keyCode = keyCode
    self.carbonModifiers = carbonModifiers
  }

  public var isValid: Bool {
    keyCode != 0 && carbonModifiers != 0
  }

  public var displayLabel: String {
    var parts: [String] = []
    if carbonModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
    if carbonModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
    if carbonModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
    if carbonModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
    parts.append(Self.keyLabel(for: keyCode))
    return parts.joined()
  }

  public static func from(eventKeyCode: UInt16, carbonModifiers: UInt32) -> GlobalHotkey? {
    let trimmed = carbonModifiers & UInt32(controlKey | optionKey | shiftKey | cmdKey)
    guard trimmed != 0, eventKeyCode != 0 else { return nil }
    return GlobalHotkey(keyCode: eventKeyCode, carbonModifiers: trimmed)
  }

  private static func keyLabel(for keyCode: UInt16) -> String {
    switch keyCode {
    case 49: return "Space"
    case 36: return "Return"
    case 48: return "Tab"
    case 53: return "Esc"
    case 123: return "←"
    case 124: return "→"
    case 125: return "↓"
    case 126: return "↑"
    case 0: return "A"
    case 1: return "S"
    case 2: return "D"
    case 3: return "F"
    case 4: return "H"
    case 5: return "G"
    case 6: return "Z"
    case 7: return "X"
    case 8: return "C"
    case 9: return "V"
    case 11: return "B"
    case 12: return "Q"
    case 13: return "W"
    case 14: return "E"
    case 15: return "R"
    case 16: return "Y"
    case 17: return "T"
    case 18: return "1"
    case 19: return "2"
    case 20: return "3"
    case 21: return "4"
    case 22: return "6"
    case 23: return "5"
    case 24: return "="
    case 25: return "9"
    case 26: return "7"
    case 27: return "-"
    case 28: return "8"
    case 29: return "0"
    case 30: return "]"
    case 31: return "O"
    case 32: return "U"
    case 33: return "["
    case 34: return "I"
    case 35: return "P"
    case 37: return "L"
    case 38: return "J"
    case 39: return "'"
    case 40: return "K"
    case 41: return ";"
    case 42: return "\\"
    case 43: return ","
    case 44: return "/"
    case 45: return "N"
    case 46: return "M"
    case 47: return "."
    case 50: return "`"
    default: return "Key \(keyCode)"
    }
  }
}

// Carbon modifier constants (HIToolbox); duplicated here so FocusSoundsCore stays AppKit-free.
private let cmdKey: UInt32 = 256
private let shiftKey: UInt32 = 512
private let optionKey: UInt32 = 2048
private let controlKey: UInt32 = 4096
