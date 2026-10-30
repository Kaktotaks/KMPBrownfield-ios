import Foundation
import Observation
import Shared

/// Editor mode: create a new task or edit an existing one.
enum TaskEditorMode {
    case new
    case edit(TaskItem)
}

@MainActor
@Observable
final class TaskEditorViewModel {
    /// Kotlin enums don't bridge as Swift `CaseIterable`, so the segment order is listed here.
    static let priorities: [Priority] = [.low, .medium, .high]

    var title: String
    var notes: String
    var priority: Priority
    /// Swift `Date` for the DatePicker; converted to Kotlin `LocalDate` for validation and saving.
    var dueDate: Date

    let mode: TaskEditorMode

    private let store: TaskStore
    private let validator: TaskValidator

    init(mode: TaskEditorMode, store: TaskStore, dateProvider: any DateProvider) {
        self.mode = mode
        self.store = store
        self.validator = TaskValidator(dateProvider: dateProvider)
        switch mode {
        case .new:
            title = ""
            notes = ""
            priority = .medium
            dueDate = dateProvider.today().asDate
        case .edit(let task):
            title = task.title
            notes = task.notes
            priority = task.priority
            dueDate = task.dueDate.asDate
        }
    }

    var screenTitle: String {
        switch mode {
        case .new: return "New Task"
        case .edit: return "Edit Task"
        }
    }

    private var originalDueDate: LocalDate? {
        switch mode {
        case .new: return nil
        case .edit(let task): return task.dueDate
        }
    }

    /// Live validation, recomputed whenever a field changes.
    var errors: [ValidationError] {
        // Kotlin default arguments are not exported: originalDueDate is always passed (nil for new).
        validator.validate(
            title: title,
            notes: notes,
            dueDate: dueDate.asLocalDate,
            originalDueDate: originalDueDate
        )
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
            store.add(title: title, notes: notes, priority: priority, dueDate: dueDate.asLocalDate)
        case .edit(let original):
            let updated = original.doCopy(
                id: original.id,
                title: title,
                notes: notes,
                priority: priority,
                dueDate: dueDate.asLocalDate,
                isDone: original.isDone
            )
            store.update(updated)
        }
        return true
    }
}
