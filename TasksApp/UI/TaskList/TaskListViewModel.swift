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

    private let store: TaskStore
    private let dateProvider: any DateProvider

    init(store: TaskStore, dateProvider: any DateProvider) {
        self.store = store
        self.dateProvider = dateProvider
    }

    var phase: TaskStore.Phase {
        store.phase
    }

    var visibleTasks: [TaskItem] {
        TaskFilter.shared.apply(tasks: store.tasks, query: query, status: status, sort: sort)
    }

    func isOverdue(_ task: TaskItem) -> Bool {
        task.isOverdue(today: dateProvider.today())
    }

    func toggleDone(id: Int32) {
        store.toggleDone(id: id)
    }

    func retry() {
        Task {
            await self.store.load()
        }
    }
}
