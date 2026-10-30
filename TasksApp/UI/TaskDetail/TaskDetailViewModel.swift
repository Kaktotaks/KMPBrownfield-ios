import Foundation
import Observation
import Shared

@MainActor
@Observable
final class TaskDetailViewModel {
    let taskId: Int32

    private let store: TaskStore
    private let dateProvider: any DateProvider

    init(taskId: Int32, store: TaskStore, dateProvider: any DateProvider) {
        self.taskId = taskId
        self.store = store
        self.dateProvider = dateProvider
    }

    /// nil after the task was deleted.
    var task: TaskItem? {
        store.task(id: taskId)
    }

    var isOverdue: Bool {
        task?.isOverdue(today: dateProvider.today()) ?? false
    }

    func toggleDone() {
        store.toggleDone(id: taskId)
    }

    func delete() {
        store.delete(id: taskId)
    }
}
