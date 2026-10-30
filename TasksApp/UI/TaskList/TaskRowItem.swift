import Foundation
import Shared

/// Display-ready row of the task list, mapped from the Kotlin `TaskItem` by `TaskListViewModel`.
struct TaskRowItem: Identifiable, Equatable {
    let id: Int32
    let title: String
    /// "Due 29 Oct 2026"
    let dueText: String
    let isOverdue: Bool
    let isDone: Bool
    let priority: Priority
    /// "Mark as done" / "Mark as active" (accessibility label of the toggle button).
    let toggleTitle: String
}

extension TaskRowItem {
    init(task: TaskItem, today: LocalDate) {
        self.init(
            id: task.id,
            title: task.title,
            dueText: Self.dueText(task.dueDate),
            isOverdue: task.isOverdue(today: today),
            isDone: task.isDone,
            priority: task.priority,
            toggleTitle: Self.toggleTitle(isDone: task.isDone)
        )
    }

    /// "Due 29 Oct 2026" via the shared Kotlin `DateFormatting` (same format on Android).
    static func dueText(_ date: LocalDate) -> String {
        "Due \(DateFormatting.shared.format(date: date))"
    }

    static func toggleTitle(isDone: Bool) -> String {
        isDone ? "Mark as active" : "Mark as done"
    }
}
