import Foundation

public enum RMSMeter {
  public static func level(from samples: [Float]) -> Float {
    guard !samples.isEmpty else { return 0 }
    var sum: Float = 0
    for sample in samples { sum += sample * sample }
    return sqrt(sum / Float(samples.count))
  }

  public static func level(fromInterleaved buffer: UnsafePointer<Float>, frameCount: Int, channelCount: Int) -> Float {
    guard frameCount > 0, channelCount > 0 else { return 0 }
    let sampleCount = frameCount * channelCount
    var sum: Float = 0
    for index in 0..<sampleCount {
      let sample = buffer[index]
      sum += sample * sample
    }
    return sqrt(sum / Float(sampleCount))
  }
}
