import XCTest
import Shared
@testable import TasksApp

/// Swift implementation of the Kotlin `TaskApi` interface (exported as an ObjC protocol).
///
/// Interop gotcha: SKIE hides the original ObjC suspend requirement behind a `__` prefix
/// (`__fetchTasks(today:completionHandler:)` / `__fetchTasks(today:) async throws`) and gives
/// *callers* its own Swift `async` wrapper `fetchTasks(today:)`. So to *implement* a Kotlin
/// suspend interface in Swift you implement the `__`-prefixed requirement. Either form satisfies
/// it (SE-0297); the `async throws` one is used here. The completion handler is `@Sendable`.
final class FakeTaskApi: NSObject, TaskApi {
    private let result: Result<[TaskItem], Error>

    init(result: Result<[TaskItem], Error>) {
        self.result = result
    }

    func __fetchTasks(today: LocalDate) async throws -> [TaskItem] {
        try result.get()
    }
}

/// Swift implementation of the Kotlin `fun interface DateProvider` (a plain, non-suspend
/// requirement → no SKIE renaming). NSObject subclass: Kotlin interfaces are ObjC protocols.
final class FixedDateProvider: NSObject, DateProvider {
    private let date: LocalDate

    init(year: Int32, month: Int32, day: Int32) {
        date = LocalDate(year: year, month: month, day: day)
    }

    func today() -> LocalDate { date }
}

/// A repository over a FRESH database. Since 0.7.0 `TaskRepository` is SQLite-backed and Swift can only build it through
/// `TasksIos.createRepository` (persistent `tasks.db`; no in-memory variant is exposed), so the database files are
/// wiped first and every test starts "never seeded".
@MainActor
func makeTestRepository(api: any TaskApi, dateProvider: any DateProvider) -> TaskRepository {
    FakeStorage.wipe()
    return TasksIos.shared.createRepository(api: api, dateProvider: dateProvider, logger: SharedLoggerCompanion.shared.NONE)
}

/// Polls until `condition` holds (flows re-emit asynchronously on the repository scope). Fails the wait silently after
/// `timeout`; the caller's assertion then reports the actual value.
@MainActor
func waitUntil(timeout: TimeInterval = 3, _ condition: () -> Bool) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline {
        try? await Task.sleep(nanoseconds: 20_000_000)
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
        let repository = makeTestRepository(
            api: FakeTaskApi(result: .success(makeTasks())),
            dateProvider: SystemDateProvider.shared
        )
        // Until the database emits (and the first seed lands) the state is Loading.
        XCTAssertTrue(repository.state.value is LoadStateLoading)

        // SKIE: Kotlin suspend fun → Swift async. The seed is written before load() returns; `state` follows asynchronously.
        try await repository.load()
        await waitUntil { repository.state.value is LoadStateLoaded && repository.tasks.count == 2 }

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
        await waitUntil { repository.tasks.map(\.id) == [1, 3] }
        XCTAssertEqual(repository.tasks.map(\.id), [1, 3])
    }

    func testFailingApiGivesErrorStateOnAppLoad() async {
        let repository = makeTestRepository(
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
