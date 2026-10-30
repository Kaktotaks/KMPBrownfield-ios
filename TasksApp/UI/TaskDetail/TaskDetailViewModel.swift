import Foundation
import Observation
import Shared

@MainActor
@Observable
final class TaskDetailViewModel {
    let taskId: Int32

    private let repository: TaskRepository
    private let dateProvider: any DateProvider

    init(taskId: Int32, repository: TaskRepository, dateProvider: any DateProvider) {
        self.taskId = taskId
        self.repository = repository
        self.dateProvider = dateProvider
    }

    /// nil after the task was deleted.
    var task: TaskItem? {
        repository.task(id: taskId)
    }

    var isOverdue: Bool {
        task?.isOverdue(today: dateProvider.today()) ?? false
    }

    func toggleDone() {
        repository.toggleDone(id: taskId)
    }

    func delete() {
        repository.delete(id: taskId)
    }
}
