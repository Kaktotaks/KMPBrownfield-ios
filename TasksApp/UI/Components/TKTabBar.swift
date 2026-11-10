import SwiftUI

/// Metrics of `TKTabBar` (Android M3 NavigationBar values, dp = pt; measured on the Android screenshots: indicator 56 x 32).
enum TKTabBarMetrics {
    static let barHeight: CGFloat = 80
    static let pillWidth: CGFloat = 56
    static let pillHeight: CGFloat = 32
    static let iconSize: CGFloat = 24
    static let labelGap: CGFloat = 4
    /// M3 label line height (caption 18).
    static let labelHeight: CGFloat = 18
    static let dividerHeight: CGFloat = 1
}

/// Bottom tab bar, a 1:1 copy of the Android Material 3 `NavigationBar` used in `TasksRoot.kt`:
/// 1 pt `border` divider on top, `surface` container (no elevation), 80 pt tall (plus the home-indicator inset, which
/// the surface fills), 56 x 32 `accent` pill behind the selected 24 pt icon, selected icon `onAccent` / label
/// `textPrimary`, unselected icon and label `textTertiary`, label = `caption`, same glyphs as Android.
///
/// Behaviour (as Android): always visible on the root tabs and on pushed screens, tapping selects, re-tapping the
/// selected tab does nothing. The tabs themselves stay alive in a `TabView` whose system bar is hidden, so each tab
/// keeps its own navigation stack and state.
struct TKTabBar<Tab: Hashable>: View {
    struct Item: Identifiable {
        enum Icon { case tk(TKIconName), map(MapIcon) }
        let tab: Tab
        let title: String
        let icon: Icon
        let identifier: String
        var id: Tab { tab }
    }

    let items: [Item]
    @Binding var selection: Tab

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.tk.border)
                .frame(height: TKTabBarMetrics.dividerHeight)
            HStack(spacing: 0) {
                ForEach(items) { item in
                    TKTabBarItem(item: item, selected: item.tab == selection) {
                        // Re-selecting the current tab is a no-op (Android `launchSingleTop`).
                        if selection != item.tab { selection = item.tab }
                    }
                }
            }
        }
        .background(Color.tk.surface, ignoresSafeAreaEdges: .bottom)
    }
}

private struct TKTabBarItem<Tab: Hashable>: View {
    let item: TKTabBar<Tab>.Item
    let selected: Bool
    let action: () -> Void

    private typealias M = TKTabBarMetrics

    var body: some View {
        Button(action: action) {
            VStack(spacing: M.labelGap) {
                ZStack {
                    // M3 active indicator: grows from the centre while it fades in.
                    Capsule()
                        .fill(Color.tk.accent)
                        .frame(width: M.pillWidth, height: M.pillHeight)
                        .scaleEffect(x: selected ? 1 : 0.2, y: 1)
                        .opacity(selected ? 1 : 0)
                    icon
                        .foregroundStyle(selected ? Color.tk.onAccent : Color.tk.textTertiary)
                }
                .frame(width: M.pillWidth, height: M.pillHeight)

                Text(item.title)
                    .tkStyled(.caption)
                    .foregroundStyle(selected ? Color.tk.textPrimary : Color.tk.textTertiary)
                    .lineLimit(1)
                    .frame(minHeight: M.labelHeight)
            }
            .frame(maxWidth: .infinity, minHeight: M.barHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tkAnimation(Motion.emphasized(Motion.short), value: selected)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(item.identifier)
    }

    @ViewBuilder
    private var icon: some View {
        switch item.icon {
        case .tk(let name): TKIcon(name: name, size: M.iconSize)
        case .map(let icon): MapIconView(icon: icon, size: M.iconSize)
        }
    }
}
