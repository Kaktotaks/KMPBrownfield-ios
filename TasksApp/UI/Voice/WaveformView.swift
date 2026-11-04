import SwiftUI

/// WaveformView (voice notes board): bars 3 wide, r2, evenly spread over the width.
/// - Static (player): 40 bars; played = `textPrimary`, rest = `waveformTrack`; optional scrubbing.
/// - Live (recorder): the last 32 input levels, newest on the right, older bars fade to 25 % opacity; each bar
///   animates its height over 80 ms (the shared state ticks every 50 ms, ~20 fps). Reduce Motion: static mid-height bars.
struct WaveformView: View {
    enum Mode: Equatable {
        case progress(Float)
        case live
    }

    let levels: [Float]
    var mode: Mode = .progress(0)
    var height: CGFloat = 40
    /// Static mode only: called with 0...1 while the user drags across the bars.
    var onSeek: ((Float) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let barWidth: CGFloat = 3
    private let minBar: CGFloat = 3

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                bar(index: index, level: level)
                if index < levels.count - 1 { Spacer(minLength: 0) }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .modifier(ScrubGesture(onSeek: onSeek))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func bar(index: Int, level: Float) -> some View {
        let count = max(levels.count, 1)
        switch mode {
        case .progress(let progress):
            let played = Float(index) < progress * Float(count)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(played ? Color.tk.textPrimary : Color.tk.waveformTrack)
                .frame(width: barWidth, height: barHeight(level))
        case .live:
            let age = count > 1 ? Double(index) / Double(count - 1) : 1
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.tk.textPrimary)
                .opacity(0.25 + 0.75 * age)
                .frame(width: barWidth, height: reduceMotion ? height / 2 : barHeight(level))
                .animation(reduceMotion ? nil : .linear(duration: Double(Motion.liveBarSmoothing) / 1000), value: level)
        }
    }

    private func barHeight(_ level: Float) -> CGFloat {
        max(minBar, CGFloat(min(max(level, 0), 1)) * height)
    }
}

private struct ScrubGesture: ViewModifier {
    let onSeek: ((Float) -> Void)?

    func body(content: Content) -> some View {
        if let onSeek {
            content.overlay {
                GeometryReader { proxy in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let width = max(proxy.size.width, 1)
                                    onSeek(Float(min(max(value.location.x / width, 0), 1)))
                                }
                        )
                }
            }
        } else {
            content
        }
    }
}
