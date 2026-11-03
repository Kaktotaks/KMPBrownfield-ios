import SwiftUI

/// Shared look of the three 52 pt buttons (§2): h 52, r `m`, `button` type, optional 20 pt leading icon.
private struct TKButton: View {
    let title: LocalizedStringKey
    let icon: TKIconName?
    let container: Color
    let content: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { TKIcon(name: icon, size: 20) }
                Text(title).tkStyle(.button)
            }
            .foregroundStyle(isEnabled ? content : Color.tk.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 16)
            .background(isEnabled ? container : Color.tk.surface2, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        }
        .buttonStyle(TKPressStyle())
        .disabled(!isEnabled)
    }
}

struct PrimaryButton: View {
    let title: LocalizedStringKey
    var icon: TKIconName?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        TKButton(title: title, icon: icon, container: Color.tk.accent, content: Color.tk.onAccent, isEnabled: isEnabled, action: action)
    }
}

struct SecondaryButton: View {
    let title: LocalizedStringKey
    var icon: TKIconName?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        TKButton(title: title, icon: icon, container: Color.tk.inverse, content: Color.tk.onInverse, isEnabled: isEnabled, action: action)
    }
}

struct DestructiveButton: View {
    let title: LocalizedStringKey
    var icon: TKIconName?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        TKButton(title: title, icon: icon, container: Color.tk.dangerContainer, content: Color.tk.onDangerContainer, isEnabled: isEnabled, action: action)
    }
}

/// SavePill (§2): h 36, pill, 0 x 18 padding; disabled = `surface2` / `textTertiary`.
struct SavePill: View {
    var isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("save")
                .tkStyle(.savePill)
                .foregroundStyle(isEnabled ? Color.tk.onAccent : Color.tk.textTertiary)
                .padding(.horizontal, 18)
                .frame(minHeight: 36)
                .background(isEnabled ? Color.tk.accent : Color.tk.surface2, in: Capsule())
                // 44 pt hit area around the 36 pt pill.
                .contentShape(Rectangle().inset(by: -4))
        }
        .buttonStyle(TKPressStyle())
        .disabled(!isEnabled)
    }
}

/// FloatingAddButton (§2): 56 x 56, r `m`, `accent`; the only add affordance.
struct FloatingAddButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            TKIcon(name: .plusBold, size: 26)
                .foregroundStyle(Color.tk.onAccent)
                .frame(width: 56, height: 56)
                .background(Color.tk.accent, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                // 0 6 16 @ 22% (light) / 50% (dark) black; CSS blur 16 ~ radius 8.
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.22), radius: 8, x: 0, y: 6)
        }
        .buttonStyle(TKPressStyle())
        .accessibilityLabel("add_task")
    }
}
