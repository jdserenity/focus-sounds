import Foundation

public enum LoopCrossfade {
  public static let preferredCrossfadeSeconds = 2.5

  public static func effectiveCrossfadeSeconds(trackDurationSeconds: Double, preferred: Double = preferredCrossfadeSeconds) -> Double {
    guard trackDurationSeconds > 0 else { return 0 }
    return min(preferred, trackDurationSeconds / 2)
  }

  public static func shouldBeginCrossfade(
    currentSeconds: Double,
    trackDurationSeconds: Double,
    crossfadeSeconds: Double,
    isCrossfading: Bool
  ) -> Bool {
    guard !isCrossfading, crossfadeSeconds > 0, trackDurationSeconds > crossfadeSeconds else { return false }
    return currentSeconds >= trackDurationSeconds - crossfadeSeconds
  }

  public static func progress(
    currentSeconds: Double,
    trackDurationSeconds: Double,
    crossfadeSeconds: Double
  ) -> Double {
    let start = trackDurationSeconds - crossfadeSeconds
    guard crossfadeSeconds > 0 else { return 1 }
    return min(1, max(0, (currentSeconds - start) / crossfadeSeconds))
  }

  /// Equal-power crossfade keeps perceived loudness steadier than a linear blend.
  public static func channelVolumes(progress: Double) -> (outgoing: Float, incoming: Float) {
    let clamped = min(1, max(0, progress))
    let out = Float(sqrt(1 - clamped))
    let inc = Float(sqrt(clamped))
    return (out, inc)
  }
}
