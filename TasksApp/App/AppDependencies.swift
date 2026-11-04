import Foundation
import Shared

/// App-level composition root.
///
/// Owns the single Kotlin `TaskRepository` (offline-first, SQLite via `TasksIos`), the `TaskValidator` and the
/// `DateProvider`, the native voice adapters, loads the tasks once on start, and creates the Kotlin ViewModels wrapped in `SharedViewModel` and the
/// Swift ViewModels around them. It is not observed by SwiftUI: screens observe their own ViewModel.
@MainActor
final class AppDependencies {
    let repository: TaskRepository
    let dateProvider: any DateProvider
    let validator: TaskValidator
    let voiceAudio: VoiceAudio

    init(repository: TaskRepository, dateProvider: any DateProvider, voiceAudio: VoiceAudio = .live) {
        self.repository = repository
        self.dateProvider = dateProvider
        self.validator = TaskValidator(dateProvider: dateProvider)
        self.voiceAudio = voiceAudio
    }

    /// Production graph: `TasksIos.createRepository()` = Ktor client (Darwin engine) + SQLite database
    /// (`tasks.db`) + voice files in `Application Support/VoiceNotes` (`repository.voiceFiles`).
    convenience init() {
        #if DEBUG
        if let debug = DebugLaunch.current {
            self.init(repository: debug.makeRepository(), dateProvider: debug.dateProvider, voiceAudio: debug.audio)
            return
        }
        #endif
        self.init(
            repository: TasksIos.shared.createRepository(),
            dateProvider: SystemDateProvider.shared
        )
    }

    // MARK: - Loading

    /// Loads tasks on app start: the first launch seeds the database from the network, later launches read
    /// SQLite only (no network). `load()` is safe to repeat. Network failures with an empty database become
    /// `LoadState.Error` (screens show Retry → `onRetry()`).
    func loadIfNeeded() async {
        if case .loaded = onEnum(of: repository.state.value) { return }
        try? await repository.load()
        #if DEBUG
        DebugLaunch.current?.seedIfNeeded(repository)
        #endif
    }

    // MARK: - ViewModel factories

    func makeTaskList() -> TaskListModel {
        let vm = Shared.TaskListViewModel(repository: repository, dateProvider: dateProvider)
        return TaskListModel(vm, states: vm.uiState, value: { vm.uiState.value })
    }

    func makeTaskDetail(taskId: Int32) -> TaskDetailModel {
        let vm = Shared.TaskDetailViewModel(taskId: taskId, repository: repository, dateProvider: dateProvider)
        return TaskDetailModel(vm, states: vm.uiState, value: { vm.uiState.value })
    }

    /// `taskId == nil` → new task (Kotlin `NEW_TASK_ID`).
    func makeTaskEditor(taskId: Int32?) -> TaskEditorModel {
        let vm = Shared.TaskEditorViewModel(
            taskId: taskId ?? Shared.TaskEditorViewModel.companion.NEW_TASK_ID,
            repository: repository,
            validator: validator,
            dateProvider: dateProvider
        )
        return TaskEditorModel(vm, states: vm.uiState, value: { vm.uiState.value })
    }

    /// One Kotlin `VoiceNoteViewModel` per card: `ExistingTask(taskId)` in Detail, `Draft(initial:)` in the Editor.
    /// `files` must be `repository.voiceFiles`.
    func makeVoiceNote(target: VoiceNoteTarget) -> VoiceNoteModel {
        let vm = Shared.VoiceNoteViewModel(
            target: target,
            repository: repository,
            files: repository.voiceFiles,
            recorder: voiceAudio.makeRecorder(),
            player: voiceAudio.makePlayer(),
            permission: voiceAudio.permission
        )
        return VoiceNoteModel(vm, states: vm.uiState, value: { vm.uiState.value })
    }

    func makeStats() -> StatsModel {
        let vm = Shared.StatsViewModel(repository: repository, dateProvider: dateProvider)
        return StatsModel(vm, states: vm.uiState, value: { vm.uiState.value })
    }

    // MARK: - Swift ViewModel factories (what the SwiftUI screens hold)

    func makeTaskListViewModel() -> TaskListViewModel {
        TaskListViewModel(shared: makeTaskList(), app: self)
    }

    func makeTaskDetailViewModel(taskId: Int32) -> TaskDetailViewModel {
        TaskDetailViewModel(shared: makeTaskDetail(taskId: taskId), app: self)
    }

    /// `taskId == nil` → new task.
    func makeTaskEditorViewModel(taskId: Int32?) -> TaskEditorViewModel {
        let shared = makeTaskEditor(taskId: taskId)
        let voice = makeVoiceNoteViewModel(target: VoiceNoteTarget.Draft(initial: shared.state.voiceNote))
        return TaskEditorViewModel(shared: shared, voice: voice)
    }

    func makeVoiceNoteViewModel(target: VoiceNoteTarget) -> VoiceNoteCardViewModel {
        VoiceNoteCardViewModel(shared: makeVoiceNote(target: target))
    }

    func makeStatsViewModel() -> StatsViewModel {
        StatsViewModel(shared: makeStats())
    }
}
