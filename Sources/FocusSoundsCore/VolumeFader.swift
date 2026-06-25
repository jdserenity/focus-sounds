import Foundation

public struct VolumeFader: Equatable {
  public private(set) var current: Float
  public let duckFloor: Float
  public let duckFadeMs: Int
  public let restoreFadeMs: Int

  public init(
    current: Float = 1,
    duckFloor: Float = 0.08,
    duckFadeMs: Int = 80,
    restoreFadeMs: Int = 120
  ) {
    self.current = current
    self.duckFloor = duckFloor
    self.duckFadeMs = duckFadeMs
    self.restoreFadeMs = restoreFadeMs
  }

  public mutating func step(baseVolume: Float, isDucked: Bool, dtMs: Int) -> Float {
    let target = baseVolume * (isDucked ? duckFloor : 1)
    let fadeMs = target < current ? duckFadeMs : restoreFadeMs
    guard fadeMs > 0, current != target else {
      current = target
      return current
    }

    let step = abs(target - current) * Float(dtMs) / Float(fadeMs)
    if current < target {
      current = min(target, current + step)
    } else {
      current = max(target, current - step)
    }
    return current
  }
}
