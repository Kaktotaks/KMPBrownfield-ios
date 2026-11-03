import Foundation
import Shared

/// Display-ready row of the task list, mapped from the Kotlin `TaskItem` by `TaskListViewModel`.
struct TaskRowItem: Identifiable, Equatable {
    let id: Int32
    let title: String
    /// "5 Nov 2026" (shared `DateFormatting`); the "Due %@" copy is applied by the UI (`DueLine`).
    let dueDate: String
    let isOverdue: Bool
    let isDone: Bool
    let priority: Priority
}

extension TaskRowItem {
    init(task: TaskItem, today: LocalDate) {
        self.init(
            id: task.id,
            title: task.title,
            dueDate: Self.formatted(task.dueDate),
            isOverdue: task.isOverdue(today: today),
            isDone: task.isDone,
            priority: task.priority
        )
    }

    /// "29 Oct 2026" via the shared Kotlin `DateFormatting` (same format on Android).
    static func formatted(_ date: LocalDate) -> String {
        DateFormatting.shared.format(date: date)
    }
}
