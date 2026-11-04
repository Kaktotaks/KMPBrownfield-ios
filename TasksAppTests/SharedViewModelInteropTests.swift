import XCTest
import Shared
@testable import TasksApp

/// Smoke tests: the shared Kotlin ViewModels are usable from Swift via SKIE,
/// and the Swift `SharedViewModel` wrapper mirrors `uiState` and clears the VM on deinit.
/// ViewModel behaviour itself is tested once, in shared/src/commonTest.
@MainActor
final class SharedViewModelInteropTests: XCTestCase {
    private var today: LocalDate { IosDates.shared.toLocalDate(date: Date()) }

    func testEditorViewModelCreatesTaskFromSwift() async throws {
        let repository = makeTestRepository(
            api: FakeTaskApi(result: .success([])),
            dateProvider: SystemDateProvider.shared
        )
        try await repository.load()

        let vm = Shared.TaskEditorViewModel(
            taskId: Shared.TaskEditorViewModel.companion.NEW_TASK_ID,
            repository: repository,
            validator: TaskValidator(dateProvider: SystemDateProvider.shared),
            dateProvider: SystemDateProvider.shared
        )
        // MutableStateFlow-backed: uiState.value is updated synchronously.
        XCTAssertTrue(vm.uiState.value.isNew)
        XCTAssertEqual(vm.uiState.value.screenTitle, "New Task")
        XCTAssertFalse(vm.uiState.value.canSave) // empty title

        vm.onTitleChange(value: "Write tests")
        XCTAssertTrue(vm.uiState.value.canSave)
        XCTAssertTrue(vm.save())
        XCTAssertEqual(repository.task(id: 1)?.title, "Write tests") // reads the database directly
        await waitUntil { repository.tasks.count == 1 }
        XCTAssertEqual(repository.tasks.map(\.title), ["Write tests"])

        // iosMain extension: cancels viewModelScope (what the Swift wrapper calls in deinit).
        vm.clear()
    }

    func testWrapperMirrorsListStateAndIsReleased() async throws {
        let tasks = [
            TaskItem(id: 1, title: "Buy milk", notes: "", priority: .low, dueDate: today, isDone: false),
            TaskItem(id: 2, title: "Call mom", notes: "", priority: .high, dueDate: today, isDone: true),
        ]
        let repository = makeTestRepository(
            api: FakeTaskApi(result: .success(tasks)),
            dateProvider: SystemDateProvider.shared
        )
        let app = AppDependencies(repository: repository, dateProvider: SystemDateProvider.shared)
        var model: TaskListModel? = app.makeTaskList()
        guard case .loading = onEnum(of: model!.state.content) else {
            return XCTFail("expected Loading before load")
        }

        await app.loadIfNeeded()
        model!.send { $0.onStatusChange(value: .active) }

        // uiState uses stateIn(WhileSubscribed): it reaches Swift through the wrapper's `for await` loop.
        var visible: [TaskItem] = []
        for _ in 0..<40 {
            if case .loaded(let loaded) = onEnum(of: model!.state.content), model!.state.status == .active {
                visible = loaded.tasks
                break
            }
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTAssertEqual(visible.map(\.id), [1])

        // Releasing the wrapper runs deinit → cancels the loop and calls viewModel.clear().
        weak var weakModel = model
        model = nil
        XCTAssertNil(weakModel)
    }
}
