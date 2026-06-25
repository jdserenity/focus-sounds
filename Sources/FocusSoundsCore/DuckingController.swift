import Foundation

public struct DuckingController: Equatable {
  public var isDucked: Bool
  public let duckThreshold: Float
  public let unduckThreshold: Float
  public let duckHoldMs: Int
  public let unduckHoldMs: Int

  private var aboveSinceMs: Int?
  private var belowSinceMs: Int?

  public init(
    isDucked: Bool = false,
    duckThreshold: Float = 0.012,
    unduckThreshold: Float = 0.007,
    duckHoldMs: Int = 120,
    unduckHoldMs: Int = 450
  ) {
    self.isDucked = isDucked
    self.duckThreshold = duckThreshold
    self.unduckThreshold = unduckThreshold
    self.duckHoldMs = duckHoldMs
    self.unduckHoldMs = unduckHoldMs
    self.aboveSinceMs = nil
    self.belowSinceMs = nil
  }

  public mutating func update(level: Float, nowMs: Int) -> Bool {
    if level >= duckThreshold {
      belowSinceMs = nil
      if aboveSinceMs == nil { aboveSinceMs = nowMs }
      if !isDucked, let started = aboveSinceMs, nowMs - started >= duckHoldMs {
        isDucked = true
        return true
      }
      return false
    }

    aboveSinceMs = nil
    if level <= unduckThreshold {
      if belowSinceMs == nil { belowSinceMs = nowMs }
      if isDucked, let started = belowSinceMs, nowMs - started >= unduckHoldMs {
        isDucked = false
        return true
      }
      return false
    }

    belowSinceMs = nil
    return false
  }
}
