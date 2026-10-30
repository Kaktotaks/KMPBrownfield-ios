import Foundation
import Shared

/// App-level composition root (replaces the step 2/3 `TaskStore` adapter).
///
/// Owns the single Kotlin `TaskRepository`, the `TaskValidator` and the `DateProvider`, loads the
/// tasks once on start, and creates the Kotlin ViewModels wrapped in `SharedViewModel`.
/// It is not observed by SwiftUI: screens observe their own ViewModel's `uiState`.
@MainActor
final class AppDependencies {
    let repository: TaskRepository
    let dateProvider: any DateProvider
    let validator: TaskValidator

    init(repository: TaskRepository, dateProvider: any DateProvider) {
        self.repository = repository
        self.dateProvider = dateProvider
        self.validator = TaskValidator(dateProvider: dateProvider)
    }

    /// Production graph: Ktor client (Darwin engine) + shared TaskRepository.
    convenience init() {
        let dateProvider: any DateProvider = SystemDateProvider.shared
        self.init(
            repository: TaskRepository(api: KtorTaskApi(), dateProvider: dateProvider),
            dateProvider: dateProvider
        )
    }

    // MARK: - Loading

    /// Loads tasks once on app start; a no-op after a successful load.
    /// Network/decoding failures become `LoadState.Error` (screens show Retry → `onRetry()`).
    func loadIfNeeded() async {
        if case .loaded = onEnum(of: repository.state.value) { return }
        try? await repository.load()
    }

    // MARK: - ViewModel factories

    func makeTaskList() -> TaskListModel {
        let vm = TaskListViewModel(repository: repository, dateProvider: dateProvider)
        return TaskListModel(vm, states: vm.uiState, value: { vm.uiState.value })
    }

    func makeTaskDetail(taskId: Int32) -> TaskDetailModel {
        let vm = TaskDetailViewModel(taskId: taskId, repository: repository, dateProvider: dateProvider)
        return TaskDetailModel(vm, states: vm.uiState, value: { vm.uiState.value })
    }

    /// `taskId == nil` → new task (Kotlin `NEW_TASK_ID`).
    func makeTaskEditor(taskId: Int32?) -> TaskEditorModel {
        let vm = TaskEditorViewModel(
            taskId: taskId ?? TaskEditorViewModel.companion.NEW_TASK_ID,
            repository: repository,
            validator: validator,
            dateProvider: dateProvider
        )
        return TaskEditorModel(vm, states: vm.uiState, value: { vm.uiState.value })
    }

    func makeStats() -> StatsModel {
        let vm = StatsViewModel(repository: repository, dateProvider: dateProvider)
        return StatsModel(vm, states: vm.uiState, value: { vm.uiState.value })
    }
}
