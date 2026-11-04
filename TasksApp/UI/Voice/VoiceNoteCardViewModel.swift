import Combine
import AVFoundation
import SwiftUI
import UIKit
import Shared

/// Swift ViewModel of a voice-note card (Detail: `ExistingTask`, Editor: `Draft`). Wraps the shared Kotlin
/// `VoiceNoteViewModel` (state machine, timer, waveform, files) the same way the other screens do:
/// the nested `SharedViewModel` is mirrored and re-published, views stay body-only.
///
/// Platform duties that shared cannot do live here: the system confirmation dialog binding, opening Settings,
/// scenePhase / audio-interruption forwarding, VoiceOver announcements and the light haptic on Start / Stop.
@MainActor
final class VoiceNoteCardViewModel: ObservableObject {
    /// Mirror of the Kotlin `confirmation` flow (`.replace` / `.delete`); the card shows `.confirmationDialog` while non-nil.
    @Published private(set) var confirmation: VoiceNoteConfirmation?

    private let shared: VoiceNoteModel
    private var forwarding: AnyCancellable?
    private var transitions: AnyCancellable?
    private var interruptions: AnyCancellable?
    nonisolated(unsafe) private var confirmationTask: Task<Void, Never>?

    // Transition tracking for announcements / haptics.
    private var previous: VoiceNoteCardModel
    private var fileBeforeRecording: String?
    private var announcedTenSecondsLeft = false

    init(shared: VoiceNoteModel) {
        self.shared = shared
        self.previous = VoiceNoteCardModel(state: shared.state)
        // Nested ObservableObject: re-publish (classic Combine pitfall).
        forwarding = shared.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        // `$state` emits the new value (willSet), so `previous` is the old card here.
        transitions = shared.$state.dropFirst().sink { [weak self] state in
            self?.observe(VoiceNoteCardModel(state: state))
        }
        let flow = shared.viewModel.confirmation
        confirmationTask = Task { [weak self] in
            for await value in flow {
                self?.confirmation = value
            }
        }
        // A call / Siri / alarm interrupts: stop recording (keeps the clip) or pause playback.
        interruptions = NotificationCenter.default
            .publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                if raw == AVAudioSession.InterruptionType.began.rawValue {
                    MainActor.assumeIsolated { self?.appBackgrounded() }
                }
            }
    }

    deinit {
        confirmationTask?.cancel()
    }

    // MARK: - Display state

    var card: VoiceNoteCardModel { VoiceNoteCardModel(state: shared.state) }

    /// The note the card currently holds (Draft target: what the editor saves).
    var currentNote: VoiceNote? { shared.viewModel.currentNote() }

    // MARK: - Intents (main thread)

    func record() { shared.send { $0.onRecordTapped() } }
    func stop() { shared.send { $0.onStop() } }
    func cancelRecording() { shared.send { $0.onCancelRecording() } }
    func playPause() { shared.send { $0.onPlayPause() } }
    func seek(progress: Float) { shared.send { $0.onSeek(progress: progress) } }
    func cycleSpeed() { shared.send { $0.onCycleSpeed() } }
    func reRecord() { shared.send { $0.onReRecordTapped() } }
    func delete() { shared.send { $0.onDeleteTapped() } }
    func continueAfterExplainer() { shared.send { $0.onExplainerContinue() } }
    func dismissPermission() { shared.send { $0.onPermissionDismissed() } }
    func confirm() { shared.send { $0.onConfirm() } }
    func dismissConfirmation() { shared.send { $0.onDismissConfirmation() } }

    /// Opens the app's page in Settings, then tells shared (no-op there).
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        shared.send { $0.onOpenSettingsHandled() }
    }

    func appBackgrounded() { shared.send { $0.onAppBackgrounded() } }
    func appForegrounded() { shared.send { $0.onAppForegrounded() } }

    /// `scenePhase` forwarding (the card view reports it): background / inactive stop-and-keep or pause,
    /// active picks up a permission granted in Settings.
    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active: appForegrounded()
        case .inactive, .background: appBackgrounded()
        @unknown default: break
        }
    }

    // MARK: - Editor

    /// Forwards every note change of this Draft card to the Kotlin editor ViewModel.
    func bind(to editor: Shared.TaskEditorViewModel) {
        shared.viewModel.bindTo(editor: editor)
    }

    /// Save pressed mid-recording: finish and keep the clip first. `bindTo` forwards on a later main-loop turn,
    /// so the current note is also pushed to the editor synchronously (save() follows immediately).
    func finishForSave(editor: Shared.TaskEditorViewModel) {
        if case .recording = card { stop() }
        editor.onVoiceNoteChange(note: currentNote)
    }

    /// Detail opens the editor sheet on top: don't keep playing underneath.
    func pausePlayback() {
        if case .player(let player) = card, player.isPlaying { playPause() }
    }

    // MARK: - Announcements and haptics

    private func observe(_ next: VoiceNoteCardModel) {
        defer { previous = next }
        switch (previous, next) {
        case (_, .recording(let recording)):
            if previous.kind != .recording {
                fileBeforeRecording = if case .player(let player) = previous { player.fileName } else { nil }
                announcedTenSecondsLeft = false
                haptic()
                announce(L10n.string("voice_a11y_started"))
            } else if recording.isWarning, !announcedTenSecondsLeft {
                announcedTenSecondsLeft = true
                announce(L10n.string("voice_a11y_ten_left"))
            }
        case (.recording, .player(let player)) where player.fileName != fileBeforeRecording:
            // A new clip was saved (Stop, 2:00 limit or backgrounding), not a cancel back to the old note.
            haptic()
            announce(player.durationMs >= 120_000
                ? L10n.string("voice_a11y_stopped_max")
                : L10n.format("voice_a11y_stopped", VoiceSpeech.duration(ms: player.durationMs)))
        default:
            break
        }
    }

    private func haptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func announce(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }
}
