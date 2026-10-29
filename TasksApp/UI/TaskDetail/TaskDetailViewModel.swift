import Foundation
import Observation

@MainActor
@Observable
final class TaskDetailViewModel {
    let taskId: Int

    private let repository: TaskRepository
    private let clock: any Clock

    init(taskId: Int, repository: TaskRepository, clock: any Clock) {
        self.taskId = taskId
        self.repository = repository
        self.clock = clock
    }

    /// nil after the task was deleted.
    var task: Task? {
        repository.task(id: taskId)
    }

    var isOverdue: Bool {
        task?.isOverdue(today: clock.today) ?? false
    }

    func toggleDone() {
        repository.toggleDone(id: taskId)
    }

    func delete() {
        repository.delete(id: taskId)
    }
}
