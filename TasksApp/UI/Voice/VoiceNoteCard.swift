import SwiftUI
import Shared

/// VoiceNoteCard (notes board): the one card that renders every voice-note state, in Detail and in the Editor.
/// UI only: display state and intents live in `VoiceNoteCardViewModel` (which wraps the shared Kotlin ViewModel).
///
/// - `.detail`: `surface` card r20, padding 18, overline "Voice note" inside.
/// - `.editor`: the section label is the form's (outside); the empty state is a dashed field-style row so it doesn't
///   compete with the lime Save; recorder / permission / error states sit on a bordered `surface` r16 card;
///   a recorded note is the compact player row with Re-record + Delete under it.
struct VoiceNoteCard: View {
    enum Placement { case detail, editor }

    @ObservedObject var model: VoiceNoteCardViewModel
    var placement: Placement = .detail

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Last non-nil confirmation: keeps the dialog text stable while it animates away.
    @State private var shownConfirmation: VoiceNoteConfirmation = .replace

    var body: some View {
        let card = model.card
        content(card)
            .padding(chromePadding(card))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { chromeBackground(card) }
            // Expand 250 ms / collapse 250 ms (height + fade); Reduce Motion: a 150 ms cross-fade.
            .animation(Motion.emphasized(reduceMotion ? Motion.short : Motion.medium), value: card.kind)
            .onChange(of: scenePhase) { _, phase in model.scenePhaseChanged(phase) }
            .onChange(of: model.confirmation) { _, new in if let new { shownConfirmation = new } }
            // The references (VN-iOS-Confirm-*.png) show a centered system alert (Cancel | Delete / Replace), not an action sheet.
            .alert(
                confirmationTitle,
                isPresented: confirmationPresented
            ) {
                if shownConfirmation == .delete {
                    Button("voice_delete", role: .destructive) { model.confirm() }
                } else {
                    Button("voice_replace_confirm", role: .destructive) { model.confirm() }
                }
                Button("cancel", role: .cancel) {}
            } message: {
                Text(confirmationMessage)
            }
    }

    // MARK: - States

    @ViewBuilder
    private func content(_ card: VoiceNoteCardModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if placement == .detail {
                Text("voice_section")
                    .tkStyled(.overline)
                    .foregroundStyle(Color.tk.textSecondary)
                    .accessibilityAddTraits(.isHeader)
            }
            Group {
                switch card {
                case .empty:
                    emptyState
                case .permissionAsk:
                    MicPermissionCard(variant: .ask, onNotNow: model.dismissPermission, onContinue: model.continueAfterExplainer)
                case .permissionDenied:
                    MicPermissionCard(variant: .denied, onOpenSettings: model.openSettings)
                case .recording(let recording):
                    VoiceRecorderView(recording: recording, onCancel: model.cancelRecording, onStop: model.stop)
                case .player(let player):
                    playerState(player)
                case .recordFailed:
                    VStack(spacing: 12) {
                        recordFailedBanner
                        recordButton
                    }
                case .unavailable:
                    unavailableState
                }
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch placement {
        case .detail:
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    VoiceIcon(name: .mic, size: 20)
                        .foregroundStyle(Color.tk.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(Color.tk.surface2, in: Circle())
                    Text("voice_empty_body")
                        .tkStyle(.subhead)
                        .foregroundStyle(Color.tk.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                recordButton
            }
        case .editor:
            let shape = RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
            Button(action: model.record) {
                HStack(spacing: 10) {
                    Circle().fill(Color.tk.danger).frame(width: 10, height: 10)
                    Text("voice_record").tkStyle(.bodyMedium).foregroundStyle(Color.tk.textPrimary)
                    Spacer(minLength: 8)
                    Text("voice_editor_hint").tkStyle(.subhead).foregroundStyle(Color.tk.textSecondary)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 52)
                .contentShape(shape)
                .overlay(shape.strokeBorder(Color.tk.textTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
            }
            .buttonStyle(TKPressStyle())
        }
    }

    private func playerState(_ player: VoiceNoteCardModel.Player) -> some View {
        VStack(spacing: placement == .detail ? 14 : 10) {
            VoicePlayerView(
                player: player,
                style: placement == .detail ? .full : .compact,
                onPlayPause: model.playPause,
                onSeek: model.seek(progress:),
                onCycleSpeed: model.cycleSpeed
            )
            // Side by side, with icons: Secondary + mic, Destructive + trash. Both 48 high.
            HStack(spacing: 10) {
                VoiceButton(
                    title: "voice_rerecord", style: .inverse, height: 48,
                    icon: { VoiceIcon(name: .mic, size: 18) },
                    accessibilityLabel: "voice_a11y_rerecord",
                    action: model.reRecord
                )
                VoiceButton(
                    title: "voice_delete", style: .destructive, height: 48,
                    icon: { TKIcon(name: .trash, size: 18) },
                    accessibilityLabel: "voice_delete_note",
                    action: model.delete
                )
            }
        }
    }

    private var recordButton: some View {
        VoiceButton(
            title: "voice_record", style: .inverse,
            icon: { Circle().fill(Color.tk.danger).frame(width: 10, height: 10) },
            action: model.record
        )
    }

    private var recordFailedBanner: some View {
        HStack(spacing: 10) {
            TKIcon(name: .alert, size: 20)
            Text("voice_err_record").tkStyle(.subheadStrong)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.tk.onDangerContainer)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.tk.dangerContainer, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var unavailableState: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                TKIcon(name: .alert, size: 22)
                    .foregroundStyle(Color.tk.onDangerContainer)
                    .frame(width: 48, height: 48)
                    .background(Color.tk.dangerContainer, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("voice_err_unavailable").tkStyle(.headline).foregroundStyle(Color.tk.textPrimary)
                    Text("voice_err_unavailable_body").tkStyle(.subhead).foregroundStyle(Color.tk.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
            VoiceButton(
                title: "voice_delete_note", style: .destructive,
                icon: { TKIcon(name: .trash, size: 18) },
                action: model.delete
            )
        }
    }

    // MARK: - Chrome

    private func chromePadding(_ card: VoiceNoteCardModel) -> EdgeInsets {
        switch placement {
        case .detail:
            return EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
        case .editor:
            switch card {
            case .recording, .permissionAsk, .permissionDenied, .recordFailed, .unavailable:
                return EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
            case .empty, .player:
                return EdgeInsets()
            }
        }
    }

    @ViewBuilder
    private func chromeBackground(_ card: VoiceNoteCardModel) -> some View {
        switch placement {
        case .detail:
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous).fill(Color.tk.surface)
        case .editor:
            switch card {
            case .recording, .permissionAsk, .permissionDenied, .recordFailed, .unavailable:
                let shape = RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                shape.fill(Color.tk.surface).overlay(shape.strokeBorder(Color.tk.border, lineWidth: 1.5))
            case .empty, .player:
                Color.clear
            }
        }
    }

    // MARK: - Confirmation (system dialog)

    private var confirmationPresented: Binding<Bool> {
        Binding(
            get: { model.confirmation != nil },
            set: { presented in
                // Tapping a button runs its action and then clears the binding: defer the dismiss one turn so a
                // confirm always wins (both intents are idempotent in shared).
                if !presented { Task { @MainActor in model.dismissConfirmation() } }
            }
        )
    }

    private var confirmationTitle: LocalizedStringKey {
        shownConfirmation == .delete ? "voice_delete_title" : "voice_replace_title"
    }

    private var confirmationMessage: LocalizedStringKey {
        shownConfirmation == .delete ? "voice_delete_body" : "voice_replace_body"
    }
}
