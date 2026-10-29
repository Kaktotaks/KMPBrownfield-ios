import Foundation
import Observation

@MainActor
@Observable
final class TaskListViewModel {
    var query: String = ""
    var status: StatusFilter = .all
    var sort: SortOrder = .dueDate

    private let repository: TaskRepository
    private let clock: any Clock

    init(repository: TaskRepository, clock: any Clock) {
        self.repository = repository
        self.clock = clock
    }

    var loadState: LoadState {
        repository.loadState
    }

    var visibleTasks: [Task] {
        TaskFilter.apply(repository.tasks, query: query, status: status, sort: sort)
    }

    func isOverdue(_ task: Task) -> Bool {
        task.isOverdue(today: clock.today)
    }

    func toggleDone(id: Int) {
        repository.toggleDone(id: id)
    }

    func retry() {
        // `Task` is our domain model in this module, hence the qualified name.
        _Concurrency.Task {
            await self.repository.load()
        }
    }
}
