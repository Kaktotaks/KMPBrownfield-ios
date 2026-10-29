import Foundation
import Observation

/// Load state of the repository.
enum LoadState: Equatable {
    case loading
    case error
    case loaded
}

/// Single in-memory source of truth for tasks.
/// Loads once from the network; afterwards all changes live in memory only.
/// KMP sharing candidate (StateFlow-based repository on the shared side).
@MainActor
@Observable
final class TaskRepository {
    private(set) var tasks: [Task] = []
    private(set) var loadState: LoadState = .loading

    private let api: any TaskApi
    private let clock: any Clock
    private var hasLoaded = false

    init(api: any TaskApi, clock: any Clock) {
        self.api = api
        self.clock = clock
    }

    /// Loads tasks once. Subsequent calls are no-ops after a successful load.
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    /// Loads (or re-loads after an error) from the network.
    func load() async {
        loadState = .loading
        do {
            let dtos = try await api.fetchTodos()
            let today = clock.today
            tasks = dtos.map { $0.toTask(today: today) }
            hasLoaded = true
            loadState = .loaded
        } catch {
            loadState = .error
        }
    }

    func task(id: Int) -> Task? {
        tasks.first { $0.id == id }
    }

    /// Next id = max existing id + 1, or 1 if empty.
    var nextId: Int {
        (tasks.map(\.id).max() ?? 0) + 1
    }

    @discardableResult
    func add(title: String, notes: String, priority: Priority, dueDate: Date) -> Task {
        let task = Task(
            id: nextId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes,
            priority: priority,
            dueDate: Calendar.current.startOfDay(for: dueDate),
            isDone: false
        )
        tasks.append(task)
        return task
    }

    func update(_ task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var updated = task
        updated.title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.dueDate = Calendar.current.startOfDay(for: task.dueDate)
        tasks[index] = updated
    }

    func toggleDone(id: Int) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isDone.toggle()
    }

    func delete(id: Int) {
        tasks.removeAll { $0.id == id }
    }
}
