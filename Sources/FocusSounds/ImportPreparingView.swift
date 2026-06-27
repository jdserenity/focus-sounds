import SwiftUI

@available(macOS 14.2, *)
struct ImportPreparingView: View {
  let fileName: String
  let progress: Float

  private var percent: Int { Int((progress * 100).rounded()) }
  private var phase: String {
    if progress < 0.12 { return "Reading your file…" }
    if progress < 0.95 { return "Converting to audio…" }
    return "Almost done…"
  }

  var body: some View {
    VStack(spacing: 16) {
      ZStack {
        Circle()
          .fill(.tint.opacity(0.12))
          .frame(width: 56, height: 56)
        Image(systemName: "waveform.circle.fill")
          .font(.system(size: 28))
          .foregroundStyle(.tint)
          .symbolEffect(.pulse, options: .repeating)
      }

      VStack(spacing: 6) {
        Text("Preparing audio")
          .font(.headline)
        Text(fileName)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .multilineTextAlignment(.center)
      }

      VStack(alignment: .leading, spacing: 6) {
        ProgressView(value: Double(progress))
          .progressViewStyle(.linear)
        HStack {
          Text(phase)
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
          Text("\(percent)%")
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(.quaternary, lineWidth: 1)
    )
    .padding(4)
  }
}
