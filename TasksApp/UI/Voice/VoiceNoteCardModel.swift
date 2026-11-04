import Foundation
import Shared

/// Display-ready model of a voice-note card, mapped from the shared `VoiceNoteUiState` (one case each).
/// Pure value type: the mapping is unit-tested, the views only render it.
enum VoiceNoteCardModel: Equatable {
    case empty
    case permissionAsk
    case permissionDenied
    case recording(Recording)
    case player(Player)
    /// Start/stop failed: banner + "Record voice note".
    case recordFailed
    /// File missing / unplayable: "Voice note unavailable" + Delete.
    case unavailable

    struct Recording: Equatable {
        /// "0:07" (shared `VoiceNoteFormat`).
        let timerText: String
        /// "max 2:00", or "0:09 left" from the last 10 s.
        let hintText: String
        /// >= 1:50: timer and hint switch to `danger`.
        let isWarning: Bool
        /// Always 32 values 0..1, oldest first.
        let levels: [Float]
        let elapsedMs: Int64
    }

    struct Player: Equatable {
        let isPlaying: Bool
        /// "0:12"
        let positionText: String
        /// "0:42"
        let durationText: String
        /// 0..1
        let progress: Float
        /// "1×" / "1.5×" / "2×"
        let speedText: String
        /// 40 values 0..1.
        let waveform: [Float]
        let durationMs: Int64
        let fileName: String
    }

    /// Case without payload: the animation key (the card expands / collapses only when this changes).
    enum Kind: Equatable {
        case empty, permissionAsk, permissionDenied, recording, player, recordFailed, unavailable
    }

    var kind: Kind {
        switch self {
        case .empty: .empty
        case .permissionAsk: .permissionAsk
        case .permissionDenied: .permissionDenied
        case .recording: .recording
        case .player: .player
        case .recordFailed: .recordFailed
        case .unavailable: .unavailable
        }
    }
}

extension VoiceNoteCardModel {
    init(state: VoiceNoteUiState) {
        switch onEnum(of: state) {
        case .empty:
            self = .empty
        case .permissionExplainer:
            self = .permissionAsk
        case .permissionDenied:
            self = .permissionDenied
        case .recording(let recording):
            self = .recording(Recording(
                timerText: VoiceNoteFormat.shared.duration(ms: recording.elapsedMs),
                hintText: recording.isWarning
                    ? L10n.format("voice_seconds_left", VoiceNoteFormat.shared.remaining(ms: recording.remainingMs))
                    : L10n.string("voice_max_hint"),
                isWarning: recording.isWarning,
                levels: recording.levels.map(\.floatValue),
                elapsedMs: recording.elapsedMs
            ))
        case .ready(let ready):
            self = .player(Player(
                isPlaying: ready.isPlaying,
                positionText: VoiceNoteFormat.shared.duration(ms: ready.positionMs),
                durationText: ready.note.durationText,
                progress: ready.progress,
                speedText: Self.speedText(ready.speed),
                waveform: ready.note.waveform.map(\.floatValue),
                durationMs: ready.note.durationMs,
                fileName: ready.note.fileName
            ))
        case .error(let error):
            switch error.kind {
            case .recordFailed: self = .recordFailed
            case .unavailable: self = .unavailable
            }
        }
    }

    /// 1.0 -> "1×", 1.5 -> "1.5×", 2.0 -> "2×" (same on Android).
    static func speedText(_ speed: Float) -> String {
        speed == speed.rounded() ? "\(Int(speed))×" : "\(speed)×"
    }
}

extension VoiceNoteCardModel.Player {
    /// "Voice note, 42 seconds".
    var accessibilityLabel: String {
        L10n.format("voice_a11y_player", VoiceSpeech.duration(ms: durationMs))
    }

    /// "0:12 of 0:42"
    var accessibilityValue: String {
        L10n.format("voice_a11y_progress", positionText, durationText)
    }
}

/// Spoken durations for VoiceOver: "42 seconds", "1 minute 5 seconds" (plural-aware strings).
enum VoiceSpeech {
    static func duration(ms: Int64) -> String {
        let total = max(0, Int(ms / 1000))
        let minutes = total / 60
        let seconds = total % 60
        var parts: [String] = []
        if minutes > 0 { parts.append(L10n.plural("voice_a11y_minutes", minutes)) }
        if seconds > 0 || minutes == 0 { parts.append(L10n.plural("voice_a11y_seconds", seconds)) }
        return parts.joined(separator: " ")
    }
}
