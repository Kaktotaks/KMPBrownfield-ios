import SwiftUI

/// VoicePlayer (notes board). One accessibility element: "Voice note, 42 seconds", actions Play / Pause and
/// "Speed 1.5×", adjustable seek (swipe up / down = +/- 5 s). Re-record and Delete stay separate buttons.
///
/// - `full` (Detail): 48 play/pause circle (accent) + scrubbable 40-bar waveform (40 high), "0:12 / 0:42" and the
///   speed pill (outline 1.5, 32 high, cycles 1x -> 1.5x -> 2x).
/// - `compact` (Editor): 56 high row on `surface` with a border: 40 play button, mini waveform (24 high), duration.
struct VoicePlayerView: View {
    enum Style { case full, compact }

    let player: VoiceNoteCardModel.Player
    var style: Style = .full
    let onPlayPause: () -> Void
    let onSeek: (Float) -> Void
    let onCycleSpeed: () -> Void

    var body: some View {
        Group {
            switch style {
            case .full: full
            case .compact: compact
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(player.accessibilityLabel)
        .accessibilityValue(player.accessibilityValue)
        .accessibilityAdjustableAction { direction in
            let step = Float(5000) / Float(max(player.durationMs, 1))
            switch direction {
            case .increment: onSeek(min(player.progress + step, 1))
            case .decrement: onSeek(max(player.progress - step, 0))
            @unknown default: break
            }
        }
        .accessibilityAction(named: Text(player.isPlaying ? "voice_a11y_pause" : "voice_a11y_play"), onPlayPause)
        .modifier(SpeedAction(enabled: style == .full, speed: player.speedText, action: onCycleSpeed))
        .accessibilityAction(.default, onPlayPause)
    }

    private var full: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                PlayPauseButton(isPlaying: player.isPlaying, size: 48, iconSize: 22, action: onPlayPause)
                WaveformView(levels: player.waveform, mode: .progress(player.progress), height: 40, onSeek: onSeek)
            }
            HStack(alignment: .center) {
                HStack(spacing: 4) {
                    Text(player.positionText)
                        .tkStyle(.playerElapsed)
                        .foregroundStyle(Color.tk.textPrimary)
                    Text("/ \(player.durationText)")
                        .tkStyle(.playerTotal)
                        .foregroundStyle(Color.tk.textSecondary)
                }
                Spacer(minLength: 8)
                SpeedPill(text: player.speedText, action: onCycleSpeed)
            }
            .padding(.top, 8)
            .padding(.leading, 62) // under the waveform, after the 48 button + 14 gap
        }
    }

    private var compact: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
        return HStack(spacing: 12) {
            PlayPauseButton(isPlaying: player.isPlaying, size: 40, iconSize: 18, action: onPlayPause)
            WaveformView(levels: player.waveform, mode: .progress(player.progress), height: 24)
            Text(player.durationText)
                .tkStyle(.playerElapsed)
                .foregroundStyle(Color.tk.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.trailing, 4)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(Color.tk.surface, in: shape)
        .overlay(shape.strokeBorder(Color.tk.border, lineWidth: 1.5))
    }
}

/// Accent circle; play <-> pause morphs over 150 ms (crossfade + scale; the glyphs are custom drawn, not SF Symbols,
/// so Android can match it exactly).
struct PlayPauseButton: View {
    let isPlaying: Bool
    let size: CGFloat
    let iconSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color.tk.accent)
                VoiceIcon(name: .play, size: iconSize)
                    .opacity(isPlaying ? 0 : 1)
                    .scaleEffect(isPlaying ? 0.6 : 1)
                VoiceIcon(name: .pause, size: iconSize)
                    .opacity(isPlaying ? 1 : 0)
                    .scaleEffect(isPlaying ? 1 : 0.6)
            }
            .foregroundStyle(Color.tk.onAccent)
            .frame(width: size, height: size)
            .tkAnimation(Motion.emphasized(Motion.short), value: isPlaying)
            .contentShape(Circle().inset(by: min(0, size - Spacing.minTarget)))
        }
        .buttonStyle(TKPressStyle())
    }
}

/// Speed pill: outline 1.5 `textPrimary`, 32 high, pill; tabular text; 44 pt hit area.
struct SpeedPill: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .tkStyle(.subheadStrong)
                .monospacedDigit()
                .foregroundStyle(Color.tk.textPrimary)
                .padding(.horizontal, 16)
                .frame(minWidth: 52, minHeight: 32)
                .overlay(Capsule().strokeBorder(Color.tk.textPrimary, lineWidth: 1.5))
                .contentShape(Rectangle().inset(by: -6))
        }
        .buttonStyle(TKPressStyle())
    }
}

/// "Speed 1.5×" custom action (names the CURRENT speed); the compact editor player has none.
private struct SpeedAction: ViewModifier {
    let enabled: Bool
    let speed: String
    let action: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.accessibilityAction(named: Text(L10n.format("voice_a11y_speed", speed)), action)
        } else {
            content
        }
    }
}
