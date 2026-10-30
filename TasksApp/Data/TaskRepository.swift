import Foundation
import Observation
import Shared

/// Load state of the repository.
enum LoadState: Equatable {
    case loading
    case error
    case loaded
}

/// Single in-memory source of truth for tasks.
/// Loads once from the network; afterwards all changes live in memory only.
/// Still Swift in this migration step; the models come from the shared KMP module.
@MainActor
@Observable
final class TaskRepository {
    private(set) var tasks: [TaskItem] = []
    private(set) var loadState: LoadState = .loading

    private let api: any TaskApi
    private let dateProvider: any DateProvider
    private var hasLoaded = false

    init(api: any TaskApi, dateProvider: any DateProvider) {
        self.api = api
        self.dateProvider = dateProvider
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
            let today = dateProvider.today()
            tasks = dtos.map { $0.toTask(today: today) }
            hasLoaded = true
            loadState = .loaded
        } catch {
            loadState = .error
        }
    }

    func task(id: Int32) -> TaskItem? {
        tasks.first { $0.id == id }
    }

    /// Next id = max existing id + 1, or 1 if empty.
    var nextId: Int32 {
        (tasks.map(\.id).max() ?? 0) + 1
    }

    @discardableResult
    func add(title: String, notes: String, priority: Priority, dueDate: LocalDate) -> TaskItem {
        let task = TaskItem(
            id: nextId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes,
            priority: priority,
            dueDate: dueDate,
            isDone: false
        )
        tasks.append(task)
        return task
    }

    func update(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        // Kotlin data class is immutable: copy with the trimmed title.
        tasks[index] = task.doCopy(
            id: task.id,
            title: task.title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: task.notes,
            priority: task.priority,
            dueDate: task.dueDate,
            isDone: task.isDone
        )
    }

    func toggleDone(id: Int32) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let task = tasks[index]
        tasks[index] = task.doCopy(
            id: task.id,
            title: task.title,
            notes: task.notes,
            priority: task.priority,
            dueDate: task.dueDate,
            isDone: !task.isDone
        )
    }

    func delete(id: Int32) {
        tasks.removeAll { $0.id == id }
    }
}
