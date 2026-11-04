import SwiftUI

/// MicPermissionCard (notes board): 48 circle icon + headline + body + actions.
/// - `ask` (accent circle): "Not now" (surface2) + "Continue" (accent), shown BEFORE the system dialog.
/// - `denied` (dangerContainer circle): "Open Settings" with an external-link icon.
struct MicPermissionCard: View {
    enum Variant { case ask, denied }

    let variant: Variant
    var onNotNow: () -> Void = {}
    var onContinue: () -> Void = {}
    var onOpenSettings: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().fill(variant == .ask ? Color.tk.accent : Color.tk.dangerContainer)
                    VoiceIcon(name: variant == .ask ? .mic : .micOff, size: 22)
                        .foregroundStyle(variant == .ask ? Color.tk.onAccent : Color.tk.onDangerContainer)
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(variant == .ask ? "voice_perm_title" : "voice_perm_denied_title")
                        .tkStyle(.headline)
                        .foregroundStyle(Color.tk.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(variant == .ask ? "voice_perm_body" : "voice_perm_denied_body")
                        .tkStyle(.subhead)
                        .foregroundStyle(Color.tk.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
            switch variant {
            case .ask:
                HStack(spacing: 10) {
                    VoiceButton(title: "voice_perm_not_now", style: .neutral, action: onNotNow)
                    VoiceButton(title: "voice_perm_continue", style: .accent, action: onContinue)
                }
            case .denied:
                VoiceButton(title: "voice_open_settings", style: .inverse, icon: { VoiceIcon(name: .externalLink, size: 18) }, iconTrailing: true, action: onOpenSettings)
            }
        }
    }
}
