import SwiftUI

/// A `surface2` block that pulses (M7): opacity 0.45 <-> 1, 1000 ms per half cycle, ease-in-out, repeat + reverse.
/// Static under Reduce Motion.
struct SkeletonBlock<S: Shape>: View {
    var shape: S
    @State private var dimmed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        shape
            .fill(Color.tk.surface2)
            .opacity(reduceMotion ? 1 : (dimmed ? 0.45 : 1))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(Motion.easeInOut(Motion.pulseHalfCycle).repeatForever(autoreverses: true)) {
                    dimmed = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// Skeleton row (§2): TaskCard shape; circle 26, line 14 h (65-80%), line 10 h (40-50%).
struct SkeletonRow: View {
    let titleFraction: CGFloat
    let dueFraction: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SkeletonBlock(shape: Circle()).frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { proxy in
                    SkeletonBlock(shape: Capsule()).frame(width: proxy.size.width * titleFraction, height: 14)
                }
                .frame(height: 14)
                GeometryReader { proxy in
                    SkeletonBlock(shape: Capsule()).frame(width: proxy.size.width * dueFraction, height: 10)
                }
                .frame(height: 10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.tk.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }
}
