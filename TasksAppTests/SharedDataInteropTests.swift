import XCTest
import Shared
@testable import TasksApp

/// Swift implementation of the Kotlin `TaskApi` interface (exported as an ObjC protocol).
/// Kotlin `suspend fun fetchTasks(today)` → ObjC `fetchTasks(today:completionHandler:)`.
/// The completion-handler form is implemented (not the Swift `async` one) so the fake answers
/// synchronously, on the thread Kotlin called it from — no Swift concurrency involved.
final class FakeTaskApi: NSObject, TaskApi {
    private let result: Result<[TaskItem], Error>

    init(result: Result<[TaskItem], Error>) {
        self.result = result
    }

    func fetchTasks(today: LocalDate, completionHandler: @escaping ([TaskItem]?, Error?) -> Void) {
        switch result {
        case .success(let tasks): completionHandler(tasks, nil)
        case .failure(let error): completionHandler(nil, error)
        }
    }
}

/// Smoke tests: the shared Kotlin data layer (TaskRepository) is usable from Swift.
/// Repository behaviour itself is tested once, in shared/src/commonTest.
@MainActor
final class SharedDataInteropTests: XCTestCase {
    private var today: LocalDate { IosDates.shared.toLocalDate(date: Date()) }

    private func makeTasks() -> [TaskItem] {
        [
            TaskItem(id: 1, title: "Buy milk", notes: "", priority: .low, dueDate: today, isDone: false),
            TaskItem(id: 2, title: "Call mom", notes: "", priority: .high, dueDate: today, isDone: true),
        ]
    }

    func testLoadFromFakeApiThenMutate() async throws {
        let repository = TaskRepository(
            api: FakeTaskApi(result: .success(makeTasks())),
            dateProvider: SystemDateProvider.shared
        )
        XCTAssertTrue(repository.state.value is LoadStateLoading)

        // SKIE: Kotlin suspend fun → Swift async.
        try await repository.load()

        // SKIE: StateFlow.value is typed; sealed → exhaustive Swift enum via onEnum(of:).
        guard case .loaded(let loaded) = onEnum(of: repository.state.value) else {
            return XCTFail("expected Loaded")
        }
        XCTAssertEqual(loaded.tasks.count, 2)
        XCTAssertEqual(repository.tasks.count, 2)

        let added = repository.add(title: "  New  ", notes: "", priority: .medium, dueDate: today)
        XCTAssertEqual(added.id, 3)
        XCTAssertEqual(added.title, "New")
        repository.toggle(id: 1)
        XCTAssertEqual(repository.task(id: 1)?.isDone, true)
        repository.delete(id: 2)
        XCTAssertEqual(repository.tasks.map(\.id), [1, 3])
    }

    func testFailingApiGivesErrorStateOnAppLoad() async {
        let repository = TaskRepository(
            api: FakeTaskApi(result: .failure(NSError(domain: "test", code: 1))),
            dateProvider: SystemDateProvider.shared
        )
        let app = AppDependencies(repository: repository, dateProvider: SystemDateProvider.shared)
        XCTAssertTrue(repository.state.value is LoadStateLoading)

        await app.loadIfNeeded()

        // Kotlin maps the thrown NSError to LoadState.Error (no Swift error escapes).
        guard case .error = onEnum(of: repository.state.value) else {
            return XCTFail("expected Error")
        }
        XCTAssertTrue(repository.tasks.isEmpty)
    }
}
