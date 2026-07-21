import Foundation

public struct HeadphoneAutoPauseController: Equatable {
  public enum Action: Equatable, Sendable {
    case none
    case pause
    case resume
  }

  public private(set) var pausedDueToDisconnect: Bool
  private var lastKind: AudioOutputKind?

  public init(pausedDueToDisconnect: Bool = false, lastKind: AudioOutputKind? = nil) {
    self.pausedDueToDisconnect = pausedDueToDisconnect
    self.lastKind = lastKind
  }

  public mutating func update(kind: AudioOutputKind, isPlaying: Bool) -> Action {
    defer { lastKind = kind }
    guard let previous = lastKind, previous != kind else { return .none }

    if previous == .headphones, kind == .other, isPlaying {
      pausedDueToDisconnect = true
      return .pause
    }

    if kind == .headphones, pausedDueToDisconnect {
      pausedDueToDisconnect = false
      return .resume
    }

    return .none
  }

  public mutating func noteManualPause() {
    pausedDueToDisconnect = false
  }

  public mutating func noteManualPlay() {
    pausedDueToDisconnect = false
  }
}
