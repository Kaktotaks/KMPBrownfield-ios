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
            TaskRowItem(id: 1, title: "Buy milk", dueDate: "29 Oct 2026", isOverdue: true,
                        isDone: false, priority: .high),
            TaskRowItem(id: 2, title: "Call mom", dueDate: TaskRowItem.formatted(today), isOverdue: false,
                        isDone: true, priority: .low),
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
        // Errors map to the field they belong to; the banner counts fields.
        XCTAssertEqual(editor.titleError, "Title must be at least 3 characters.")
        XCTAssertNil(editor.notesError)
        XCTAssertNil(editor.dueDateError)
        XCTAssertEqual(editor.errorFieldCount, 1)
        XCTAssertEqual(editor.bannerText, "Fix 1 field to save this task.")

        // Setter → Kotlin event; `send` re-reads the MutableStateFlow synchronously.
        editor.title.wrappedValue = "Write tests"
        editor.priority.wrappedValue = .high
        XCTAssertEqual(editor.title.wrappedValue, "Write tests")
        XCTAssertEqual(editor.priority.wrappedValue, .high)
        XCTAssertTrue(editor.canSave)
        XCTAssertEqual(editor.errorFieldCount, 0)

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
            isDone: false,
            priority: .medium,
            dueDate: "29 Oct 2026",
            isOverdue: true,
            notes: nil
        ))
        XCTAssertTrue(model.canEdit)
    }

    func testBlankNotesAreHiddenOnDetail() async throws {
        let app = makeApp(tasks: [
            TaskItem(id: 7, title: "Pay rent", notes: "  \n ", priority: .low, dueDate: oct29, isDone: true),
        ])
        await app.loadIfNeeded()
        let details = app.makeTaskDetailViewModel(taskId: 7).details

        XCTAssertNil(details?.notes)
        XCTAssertEqual(details?.isDone, true)
        XCTAssertEqual(details?.isOverdue, false, "done tasks are never overdue")
    }

    func testListEmptyStatesAndSortOptions() async throws {
        let app = makeApp(tasks: [])
        let model = app.makeTaskListViewModel()
        await app.loadIfNeeded()

        // Loaded, no tasks, no query/filter → "No tasks yet".
        try await waitForContent(of: model) { if case .empty(false) = $0 { return true } else { return false } }

        // A query that matches nothing → "No matching tasks".
        model.query.wrappedValue = "zzz"
        try await waitForContent(of: model) { if case .empty(true) = $0 { return true } else { return false } }

        XCTAssertEqual(model.sortOptions.map(\.title), ["Due date", "Priority", "Title"])
        XCTAssertEqual(model.statusOptions.map(\.title), ["All", "Active", "Done"])
        XCTAssertEqual(model.sortLabel, "Due date")
        // `uiState` is stateIn(WhileSubscribed): the new sort reaches Swift asynchronously.
        model.sort.wrappedValue = .title
        for _ in 0..<40 where model.sortLabel != "Title" {
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTAssertEqual(model.sortLabel, "Title")
    }

    private func waitForContent(
        of model: TasksApp.TaskListViewModel,
        where condition: (TasksApp.TaskListViewModel.Content) -> Bool
    ) async throws {
        for _ in 0..<40 {
            if condition(model.content) { return }
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail("content never reached the expected state: \(model.content)")
    }

    func testStatsSummaryKeepsSharedNumbersAndFractions() {
        let stats = TaskStats(total: 4, done: 3, active: 1, completionPercent: 75, low: 1, medium: 2, high: 1, overdue: 1)
        let summary = StatsSummary(stats: stats)

        // The animation must land exactly on shared's completionPercent.
        XCTAssertEqual(summary.completionPercent, 75)
        XCTAssertEqual([summary.total, summary.done, summary.active, summary.overdue], [4, 3, 1, 1])
        XCTAssertEqual(summary.priorityRows.map(\.priority), [.high, .medium, .low])
        XCTAssertEqual(summary.priorityRows.map(\.count), [1, 2, 1])
        XCTAssertEqual(summary.priorityRows.map(\.fraction), [0.25, 0.5, 0.25])
    }

    func testStatsSummaryWithZeroTasksHasEmptyBars() {
        let summary = StatsSummary(stats: TaskStats.companion.EMPTY)

        XCTAssertEqual(summary.completionPercent, 0)
        XCTAssertEqual(summary.priorityRows.map(\.fraction), [0, 0, 0])
    }

    func testLocalizedCopy() {
        XCTAssertEqual(L10n.format("due_format", "5 Nov 2026"), "Due 5 Nov 2026")
        XCTAssertEqual(L10n.format("n_of_m_done", 2, 6), "2 of 6 tasks done")
        XCTAssertEqual(L10n.plural("n_tasks", 1), "1 task")
        XCTAssertEqual(L10n.plural("n_tasks", 2), "2 tasks")
        XCTAssertEqual(L10n.plural("fix_fields", 1), "Fix 1 field to save this task.")
        XCTAssertEqual(L10n.plural("fix_fields", 2), "Fix 2 fields to save this task.")
        XCTAssertEqual(L10n.string("overdue_suffix"), "· Overdue")
    }
}
