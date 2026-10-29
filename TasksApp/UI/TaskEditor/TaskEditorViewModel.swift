import Foundation
import Observation

/// Editor mode: create a new task or edit an existing one.
enum TaskEditorMode {
    case new
    case edit(Task)
}

@MainActor
@Observable
final class TaskEditorViewModel {
    var title: String
    var notes: String
    var priority: Priority
    var dueDate: Date

    let mode: TaskEditorMode

    private let repository: TaskRepository
    private let validator: TaskValidator

    init(mode: TaskEditorMode, repository: TaskRepository, clock: any Clock) {
        self.mode = mode
        self.repository = repository
        self.validator = TaskValidator(clock: clock)
        switch mode {
        case .new:
            title = ""
            notes = ""
            priority = .medium
            dueDate = clock.today
        case .edit(let task):
            title = task.title
            notes = task.notes
            priority = task.priority
            dueDate = task.dueDate
        }
    }

    var screenTitle: String {
        switch mode {
        case .new: return "New Task"
        case .edit: return "Edit Task"
        }
    }

    private var originalDueDate: Date? {
        switch mode {
        case .new: return nil
        case .edit(let task): return task.dueDate
        }
    }

    /// Live validation, recomputed whenever a field changes.
    var errors: [ValidationError] {
        validator.validate(title: title, notes: notes, dueDate: dueDate, originalDueDate: originalDueDate)
    }

    var canSave: Bool {
        errors.isEmpty
    }

    /// Returns true if saved.
    @discardableResult
    func save() -> Bool {
        guard canSave else { return false }
        switch mode {
        case .new:
            repository.add(title: title, notes: notes, priority: priority, dueDate: dueDate)
        case .edit(let original):
            var updated = original
            updated.title = title
            updated.notes = notes
            updated.priority = priority
            updated.dueDate = dueDate
            repository.update(updated)
        }
        return true
    }
}
