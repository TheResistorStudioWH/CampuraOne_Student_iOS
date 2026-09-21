import SwiftUI

/// Material-inspired wave primitives. No dependency on authentication or networking.
private struct WaveTrack: Shape {
    var phase: CGFloat
    var amplitude: CGFloat = 3
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0 else { return path }
        for x in stride(from: CGFloat.zero, through: rect.width, by: 1) {
            let y = rect.midY + sin(x / 24 * .pi * 2 + phase) * amplitude
            if x == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }
}

/// Pass nil for indeterminate loading, or a fraction in 0...1.
struct WaveProgressView: View {
    var value: Double? = nil
    var tint: Color = .accentColor
    var label = "加载进度"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            GeometryReader { geometry in
                let phase = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate * 3
                let fraction = value.map { min(1, max(0, $0.isFinite ? $0 : 0)) } ?? 0.35
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.14)).frame(height: 4)
                    WaveTrack(phase: phase, amplitude: reduceMotion ? 0 : 3)
                        .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: geometry.size.width * fraction, height: 16)
                        .offset(x: value == nil ? (geometry.size.width * 0.65 * (sin(phase / 2) + 1) / 2) : 0)
                }.frame(height: 16)
            }
        }
        .frame(height: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value.map { "\(Int(min(1, max(0, $0.isFinite ? $0 : 0)) * 100))%" } ?? "正在加载")
    }
}

/// A native Slider provides hit testing, keyboard and VoiceOver semantics;
/// the wave is a visual overlay and cannot steal gestures.
struct WaveSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var step: Double = 0.01
    var label = "调整数值"
    var tint: Color = .accentColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fraction: Double {
        guard range.upperBound > range.lowerBound, value.isFinite else { return 0 }
        return min(1, max(0, (value - range.lowerBound) / (range.upperBound - range.lowerBound)))
    }
    var body: some View {
        Slider(value: $value, in: range, step: max(step, 0.0001)) {
            Text(label)
        }
        .tint(tint)
        .overlay {
            GeometryReader { geometry in
                WaveTrack(phase: fraction * .pi * 2, amplitude: reduceMotion ? 0 : 3)
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: max(0, (geometry.size.width - 28) * fraction - 8), height: 14)
                    .position(x: max(0, (geometry.size.width - 28) * fraction - 8) / 2 + 3, y: geometry.size.height / 2)
            }.allowsHitTesting(false).accessibilityHidden(true)
        }
        .frame(minHeight: 44)
    }
}

private struct WaveComponentGallery: View {
    @State private var value = 0.45
    var body: some View {
        Form {
            Section("确定进度") { WaveProgressView(value: value) }
            Section("等待加载") { WaveProgressView() }
            Section("波浪滑块") { WaveSlider(value: $value, label: "预览数值") }
        }
    }
}

#Preview("Wave Components") { WaveComponentGallery() }
