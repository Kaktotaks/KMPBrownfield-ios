import SwiftUI

/// Voice-note button: r16, `voiceButton` type (Inter 600 15), optional leading icon (18, gap 8).
/// Same four fills as the shared buttons (Secondary = inverse, Destructive = dangerContainer), plus the
/// accent and surface2 ones of the recorder / permission rows. Height 48 in the player action row, 52 elsewhere.
struct VoiceButton<Icon: View>: View {
    enum Style { case accent, inverse, neutral, destructive }

    let title: LocalizedStringKey
    var style: Style = .inverse
    var height: CGFloat = 52
    @ViewBuilder var icon: () -> Icon
    var iconTrailing = false
    var accessibilityLabel: LocalizedStringKey?
    let action: () -> Void

    private var container: Color {
        switch style {
        case .accent: Color.tk.accent
        case .inverse: Color.tk.inverse
        case .neutral: Color.tk.surface2
        case .destructive: Color.tk.dangerContainer
        }
    }

    private var content: Color {
        switch style {
        case .accent: Color.tk.onAccent
        case .inverse: Color.tk.onInverse
        case .neutral: Color.tk.textPrimary
        case .destructive: Color.tk.onDangerContainer
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if !iconTrailing { icon() }
                Text(title).tkStyle(.voiceButton)
                if iconTrailing { icon() }
            }
            .foregroundStyle(content)
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.horizontal, 12)
            .background(container, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        }
        .buttonStyle(TKPressStyle())
        .accessibilityLabel(accessibilityLabel ?? title)
    }
}

extension VoiceButton where Icon == EmptyView {
    init(title: LocalizedStringKey, style: Style = .inverse, height: CGFloat = 52, action: @escaping () -> Void) {
        self.init(title: title, style: style, height: height, icon: { EmptyView() }, action: action)
    }
}

/// Horizontal row whose children share the width by weight (Cancel : Stop = 1 : 2, like CSS `1fr 2fr`).
struct WeightedRow<Content: View>: View {
    let weights: [CGFloat]
    var spacing: CGFloat = 10
    @ViewBuilder let content: () -> Content

    var body: some View {
        WeightedLayout(weights: weights, spacing: spacing) { content() }
    }
}

private struct WeightedLayout: Layout {
    let weights: [CGFloat]
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = subviews.map { $0.sizeThatFits(.init(width: nil, height: proposal.height)).height }.max() ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let total = weights.prefix(subviews.count).reduce(0, +)
        let available = bounds.width - spacing * CGFloat(max(subviews.count - 1, 0))
        var x = bounds.minX
        for (index, subview) in subviews.enumerated() {
            let width = available * weights[index] / max(total, 1)
            subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading, proposal: .init(width: width, height: bounds.height))
            x += width + spacing
        }
    }
}
