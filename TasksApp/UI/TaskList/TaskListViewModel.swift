import Foundation
import Observation
import Shared

@MainActor
@Observable
final class TaskListViewModel {
    /// Kotlin enums don't bridge as Swift `CaseIterable`, so the segment/menu order is listed here.
    static let statusFilters: [StatusFilter] = [.all, .active, .done]
    static let sortOrders: [SortOrder] = [.dueDate, .priority]

    var query: String = ""
    var status: StatusFilter = .all
    var sort: SortOrder = .dueDate

    private let repository: TaskRepository
    private let dateProvider: any DateProvider

    init(repository: TaskRepository, dateProvider: any DateProvider) {
        self.repository = repository
        self.dateProvider = dateProvider
    }

    var loadState: LoadState {
        repository.loadState
    }

    var visibleTasks: [TaskItem] {
        TaskFilter.shared.apply(tasks: repository.tasks, query: query, status: status, sort: sort)
    }

    func isOverdue(_ task: TaskItem) -> Bool {
        task.isOverdue(today: dateProvider.today())
    }

    func toggleDone(id: Int32) {
        repository.toggleDone(id: id)
    }

    func retry() {
        Task {
            await self.repository.load()
        }
    }
}
