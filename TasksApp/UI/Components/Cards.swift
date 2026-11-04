import SwiftUI
import Shared

/// HeroCard (§2): `heroBg`, r `xl`, padding 22 (detail) / 24 (stats).
struct HeroCard<Content: View>: View {
    var padding: CGFloat = 22
    /// Dark Task detail uses `surface2` so the hero reads against true black (voice-notes board).
    var darkUsesSurface2 = false
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0, content: content)
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(darkUsesSurface2 && colorScheme == .dark ? Color.tk.surface2 : Color.tk.heroBg, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
    }
}

struct InfoRowItem: Identifiable {
    let icon: TKIconName
    let label: LocalizedStringKey
    let value: String
    var id: String { value + "\(icon)" }
}

/// InfoRowsCard (§2): `surface`, r `l`, 18 h padding, rows 52 pt with 1 pt `border` dividers.
struct InfoRowsCard: View {
    let rows: [InfoRowItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 12) {
                    TKIcon(name: row.icon, size: 20).foregroundStyle(Color.tk.textSecondary)
                    Text(row.label).tkStyle(.body).foregroundStyle(Color.tk.textSecondary)
                    Spacer(minLength: 8)
                    Text(row.value).tkStyle(.bodyStrong).foregroundStyle(Color.tk.textPrimary)
                }
                .padding(.vertical, 8)
                .frame(minHeight: 52)
                .accessibilityElement(children: .combine)
                if index < rows.count - 1 {
                    Rectangle().fill(Color.tk.border).frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(Color.tk.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }
}

enum StatTileVariant { case standard, done, overdue }

/// StatTile (§2): r `l`, padding 16 v / 18 h, label `subhead` + number `statNumber` (tabular).
/// `value` is the animated number (S3), `target` the final one.
struct StatTile: View {
    let label: LocalizedStringKey
    let value: Double
    let target: Int
    let variant: StatTileVariant

    private var container: Color {
        switch variant {
        case .standard: return Color.tk.surface
        case .done: return Color.tk.accent
        case .overdue: return Color.tk.dangerContainer
        }
    }

    private var labelColor: Color {
        switch variant {
        case .standard: return Color.tk.textSecondary
        case .done: return Color.tk.onAccentMuted
        case .overdue: return Color.tk.onDangerContainer
        }
    }

    private var numberColor: Color {
        switch variant {
        case .standard: return Color.tk.textPrimary
        case .done: return Color.tk.onAccent
        case .overdue: return Color.tk.onDangerContainer
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).tkStyle(.subhead).foregroundStyle(labelColor)
            AnimatedCountText(value: value, target: Double(target), finalValue: target)
                .tkStyle(.statNumber)
                .foregroundStyle(numberColor)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(container, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }
}

/// CompletionRing (§2): 104 x 104, radius 42, stroke 14, round caps; starts at 12 o'clock, runs clockwise.
/// The arc is an `Animatable` shape that is ALWAYS in the tree (empty at 0), so the progress line sweeps
/// 0 -> p with the animation instead of the view being inserted (which would only fade in).
struct CompletionRing: View {
    /// 0...1, already animated.
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(Color.tk.ringTrack, lineWidth: 14)
            RingArc(progress: progress)
                .stroke(Color.tk.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
        }
        .frame(width: 84, height: 84)
        .frame(width: 104, height: 104)
    }
}

/// Arc from 12 o'clock, clockwise, `progress` of a full turn. Empty path at 0 (no round-cap dot).
private struct RingArc: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * min(progress, 1)),
            clockwise: false
        )
        return path
    }
}

/// An integer that animates by value: `Animatable` so ring and number share ONE animated value (§4.1).
/// The last frame shows `finalValue` exactly instead of a rounded float. NOT `.contentTransition(.numericText())`.
struct AnimatedCountText: View, Animatable {
    /// Animated value on the same scale as `target` (e.g. 0...1 for a fraction).
    var value: Double
    let target: Double
    let finalValue: Int
    var scale: Double = 1
    var suffix = ""

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    private var shown: Int {
        value == target ? finalValue : Int((value * scale).rounded())
    }

    var body: some View {
        Text("\(shown)\(suffix)")
    }
}

/// PriorityBar (§2): label + "N tasks"; bar h 10, `surface2` track; `fraction` = count / total, already animated.
struct PriorityBar: View {
    let label: String
    let countText: String
    let fraction: Double
    let fill: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label).tkStyle(.label15).foregroundStyle(Color.tk.textPrimary)
                Spacer(minLength: 8)
                Text(countText).tkStyle(.subhead15).foregroundStyle(Color.tk.textSecondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.tk.surface2)
                    Capsule().fill(fill).frame(width: proxy.size.width * min(max(fraction, 0), 1))
                }
            }
            .frame(height: 10)
        }
        .accessibilityElement(children: .combine)
    }
}
