import SwiftUI

/// EmptyState (§2): 96 pt illustration (outlined card + lime disc + check, drawn with tokens), `title`, `body`,
/// optional action. `.error` swaps the lime check for a danger disc.
enum EmptyStateKind { case normal, error }

struct EmptyState<Action: View>: View {
    typealias Kind = EmptyStateKind

    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var kind: EmptyStateKind = .normal
    @ViewBuilder let action: () -> Action

    var body: some View {
        VStack(spacing: 12) {
            EmptyIllustration(kind: kind)
            Text(title)
                .tkStyle(.title)
                .foregroundStyle(Color.tk.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .tkStyle(.body)
                .foregroundStyle(Color.tk.textSecondary)
                .multilineTextAlignment(.center)
            action()
                .padding(.top, 12)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension EmptyState where Action == EmptyView {
    init(title: LocalizedStringKey, message: LocalizedStringKey, kind: EmptyStateKind = .normal) {
        self.init(title: title, message: message, kind: kind) { EmptyView() }
    }
}

/// Same motif as the app icon: outlined card, a disc at its top-right, a check (or "!") in the disc.
private struct EmptyIllustration: View {
    let kind: EmptyStateKind

    var body: some View {
        Canvas { context, size in
            let u = size.width / 96
            context.stroke(
                Path(roundedRect: CGRect(x: 10 * u, y: 26 * u, width: 58 * u, height: 58 * u), cornerRadius: 16 * u),
                with: .color(Color.tk.textPrimary),
                lineWidth: 4 * u
            )
            let center = CGPoint(x: 64 * u, y: 34 * u)
            let disc = Path(ellipseIn: CGRect(x: center.x - 26 * u, y: center.y - 26 * u, width: 52 * u, height: 52 * u))
            context.fill(disc, with: .color(kind == .error ? Color.tk.dangerContainer : Color.tk.accent))
            var glyph = Path()
            if kind == .error {
                glyph.move(to: CGPoint(x: center.x, y: center.y - 11 * u))
                glyph.addLine(to: CGPoint(x: center.x, y: center.y + 2 * u))
                glyph.move(to: CGPoint(x: center.x, y: center.y + 10 * u))
                glyph.addLine(to: CGPoint(x: center.x + 0.01, y: center.y + 10 * u))
            } else {
                glyph.move(to: CGPoint(x: center.x - 11 * u, y: center.y + 1 * u))
                glyph.addLine(to: CGPoint(x: center.x - 3 * u, y: center.y + 9 * u))
                glyph.addLine(to: CGPoint(x: center.x + 11 * u, y: center.y - 7 * u))
            }
            context.stroke(
                glyph,
                with: .color(kind == .error ? Color.tk.danger : Color.tk.onAccent),
                style: StrokeStyle(lineWidth: 5 * u, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: 96, height: 96)
        .accessibilityHidden(true)
    }
}
