import XCTest
import Shared
@testable import TasksApp

/// Swift ViewModels: Kotlin `uiState` → display-ready values, bindings → Kotlin events.
@MainActor
final class ViewModelTests: XCTestCase {
    /// Fixed "today" = 30 Oct 2026, so 29 Oct is always overdue regardless of the real date.
    private let clock = FixedDateProvider(year: 2026, month: 10, day: 30)
    private var today: LocalDate { clock.today() }
    private var oct29: LocalDate { LocalDate(year: 2026, month: 10, day: 29) }

    private func makeApp(tasks: [TaskItem]) -> AppDependencies {
        let repository = TaskRepository(
            api: FakeTaskApi(result: .success(tasks)),
            dateProvider: clock
        )
        return AppDependencies(repository: repository, dateProvider: clock)
    }

    /// `uiState` uses stateIn(WhileSubscribed): it reaches Swift asynchronously via the bridge's loop.
    private func rows(of model: TasksApp.TaskListViewModel, where condition: ([TaskRowItem]) -> Bool) async throws -> [TaskRowItem]? {
        for _ in 0..<40 {
            if case .loaded(let rows) = model.content, condition(rows) {
                return rows
            }
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        return nil
    }

    func testTaskListViewModelMapsRowsAndForwardsQuery() async throws {
        let app = makeApp(tasks: [
            TaskItem(id: 1, title: "Buy milk", notes: "", priority: .high, dueDate: oct29, isDone: false),
            TaskItem(id: 2, title: "Call mom", notes: "", priority: .low, dueDate: today, isDone: true),
        ])
        let model = app.makeTaskListViewModel()
        guard case .loading = model.content else {
            return XCTFail("expected Loading before load")
        }

        await app.loadIfNeeded()

        let loaded = try await rows(of: model) { $0.count == 2 }
        XCTAssertEqual(loaded, [
            TaskRowItem(id: 1, title: "Buy milk", dueText: "Due 29 Oct 2026", isOverdue: true,
                        isDone: false, priority: .high, toggleTitle: "Mark as done"),
            TaskRowItem(id: 2, title: "Call mom", dueText: TaskRowItem.dueText(today), isOverdue: false,
                        isDone: true, priority: .low, toggleTitle: "Mark as active"),
        ])

        // Bindable property: stored locally (no lag) and forwarded to Kotlin `onQueryChange`.
        model.query.wrappedValue = "milk"
        XCTAssertEqual(model.query.wrappedValue, "milk")
        let filtered = try await rows(of: model) { $0.count == 1 }
        XCTAssertEqual(filtered?.map(\.id), [1])
    }

    func testTaskEditorViewModelBindingsAndSave() async throws {
        let app = makeApp(tasks: [])
        await app.loadIfNeeded()
        let editor = app.makeTaskEditorViewModel(taskId: nil)

        XCTAssertEqual(editor.screenTitle, "New Task")
        XCTAssertFalse(editor.canSave)
        XCTAssertEqual(editor.errorMessages, ["Title must be at least 3 characters."])

        // Setter → Kotlin event; `send` re-reads the MutableStateFlow synchronously.
        editor.title.wrappedValue = "Write tests"
        editor.priority.wrappedValue = .high
        XCTAssertEqual(editor.title.wrappedValue, "Write tests")
        XCTAssertEqual(editor.priority.wrappedValue, .high)
        XCTAssertTrue(editor.canSave)
        XCTAssertFalse(editor.hasErrors)

        XCTAssertTrue(editor.save())
        XCTAssertEqual(app.repository.tasks.map(\.title), ["Write tests"])
        XCTAssertEqual(app.repository.tasks.first?.priority, .high)
    }

    func testTaskDetailViewModelDetails() async throws {
        let app = makeApp(tasks: [
            TaskItem(id: 7, title: "Pay rent", notes: "", priority: .medium, dueDate: oct29, isDone: false),
        ])
        await app.loadIfNeeded()
        // Kotlin initialValue reads repository.task(id) synchronously.
        let model = app.makeTaskDetailViewModel(taskId: 7)

        XCTAssertEqual(model.details, TasksApp.TaskDetailViewModel.Details(
            title: "Pay rent",
            statusText: "Active",
            priority: .medium,
            dueText: "Due 29 Oct 2026",
            isOverdue: true,
            notes: nil,
            toggleTitle: "Mark as done"
        ))
        XCTAssertTrue(model.canEdit)
    }
}
