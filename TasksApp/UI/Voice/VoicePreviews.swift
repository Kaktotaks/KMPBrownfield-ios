#if DEBUG
import SwiftUI
import Shared

/// Every voice-note card state with fake adapters (no microphone, no files outside the fake "audio" text files),
/// in Detail and Editor placement, light and dark.
enum VoicePreviewState: CaseIterable {
    case empty, ask, denied, recording, player, recordFailed, unavailable
}

@MainActor
struct VoiceCardPreview: View {
    let state: VoicePreviewState
    var placement: VoiceNoteCard.Placement = .detail
    @StateObject private var model: VoiceNoteCardViewModel

    init(_ state: VoicePreviewState, placement: VoiceNoteCard.Placement = .detail) {
        self.state = state
        self.placement = placement
        let audio: VoiceAudio = switch state {
        case .ask: .fake(permission: .notDetermined)
        case .denied: .fake(permission: .denied)
        case .recordFailed: .fake(failRecording: true)
        case .unavailable: .fake(unavailable: true)
        default: .fake()
        }
        let app = AppDependencies.preview(voiceAudio: audio)
        var initial: VoiceNote?
        if state == .player || state == .unavailable {
            let name = "preview-\(state).m4a"
            if state == .player { try? "42000".write(toFile: app.repository.voiceFiles.pathOf(name: name), atomically: true, encoding: .utf8) }
            initial = VoiceNote(fileName: name, durationMs: 42_000, waveform: FakeVoiceRecorder.sampleWaveform.map { KotlinFloat(float: $0) })
        }
        let model = app.makeVoiceNoteViewModel(target: VoiceNoteTarget.Draft(initial: initial))
        if [.ask, .denied, .recording, .recordFailed].contains(state) { model.record() }
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        VoiceNoteCard(model: model, placement: placement)
    }
}

private struct VoiceStatesPreview: View {
    let placement: VoiceNoteCard.Placement

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(VoicePreviewState.allCases, id: \.self) { VoiceCardPreview($0, placement: placement) }
            }
            .padding(Spacing.gutter)
        }
        .background(Color.tk.bg)
    }
}

#Preview("Voice card states · Detail · light") { VoiceStatesPreview(placement: .detail) }
#Preview("Voice card states · Detail · dark") { VoiceStatesPreview(placement: .detail).preferredColorScheme(.dark) }
#Preview("Voice card states · Editor · light") { VoiceStatesPreview(placement: .editor) }
#Preview("Voice card states · Editor · dark") { VoiceStatesPreview(placement: .editor).preferredColorScheme(.dark) }

#Preview("Detail with voice note · light") {
    PreviewHost(app: .preview(voiceAudio: .fake())) { app in
        NavigationStack { TaskDetailScreen(model: app.makeTaskDetailViewModel(taskId: 5)) }
    }
}

#Preview("List voice indicator · light") {
    PreviewHost(app: .preview(tasks: AppDependencies.previewTasks.map {
        TaskItem(id: $0.id, title: $0.title, notes: $0.notes, priority: $0.priority, dueDate: $0.dueDate, isDone: $0.isDone,
                 voiceNote: $0.id % 2 == 1 ? VoiceNote(fileName: "x.m4a", durationMs: 42_000, waveform: []) : nil)
    })) { TaskListScreen(model: $0.makeTaskListViewModel()) }
}
#endif
