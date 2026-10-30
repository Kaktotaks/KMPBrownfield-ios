import Foundation
import Observation
import Shared

/// Swift screen model of the task detail screen. Wraps the shared Kotlin `TaskDetailViewModel`.
@MainActor
@Observable
final class TaskDetailScreenModel {
    /// Display-ready task details.
    struct Details: Equatable {
        let title: String
        /// "Done" / "Active"
        let statusText: String
        let priority: Priority
        /// "Due 29 Oct 2026"
        let dueText: String
        let isOverdue: Bool
        /// `nil` → "No notes".
        let notes: String?
        /// "Mark as done" / "Mark as active"
        let toggleTitle: String
    }

    /// Created when the edit sheet opens, released (→ Kotlin `clear()`) when it closes.
    var editor: TaskEditorScreenModel?

    private let shared: TaskDetailModel
    private let app: AppDependencies

    init(shared: TaskDetailModel, app: AppDependencies) {
        self.shared = shared
        self.app = app
    }

    // MARK: - Display state

    /// `nil` after the task was deleted (briefly visible while popping back).
    var details: Details? {
        let state = shared.state
        guard let task = state.task else { return nil }
        return Details(
            title: task.title,
            statusText: task.isDone ? "Done" : "Active",
            priority: task.priority,
            dueText: TaskRowItem.dueText(task.dueDate),
            isOverdue: task.isOverdue(today: state.today),
            notes: task.notes.isEmpty ? nil : task.notes,
            toggleTitle: TaskRowItem.toggleTitle(isDone: task.isDone)
        )
    }

    var canEdit: Bool {
        shared.state.task != nil
    }

    // MARK: - Intents

    func toggleDone() {
        shared.send { $0.onToggle() }
    }

    func delete() {
        shared.send { $0.onDelete() }
    }

    func showEditor() {
        editor = app.makeTaskEditorScreenModel(taskId: shared.viewModel.taskId)
    }
}
