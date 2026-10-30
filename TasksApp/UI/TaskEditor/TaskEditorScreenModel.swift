import Foundation
import Observation
import Shared

/// Swift screen model of the New / Edit task sheet. Wraps the shared Kotlin `TaskEditorViewModel`
/// (form state + live validation + save). Created by the presenting screen model when the sheet
/// opens (`sheet(item:)`), so there is exactly one Kotlin ViewModel per presentation.
@MainActor
@Observable
final class TaskEditorScreenModel {
    /// Kotlin enums with SKIE are Swift enums, but not `CaseIterable`: the segment order is listed here.
    let priorityOptions: [PickerOption<Priority>] = [Priority.low, .medium, .high]
        .map { PickerOption(value: $0, title: $0.displayName) }

    private let shared: TaskEditorModel

    init(shared: TaskEditorModel) {
        self.shared = shared
    }

    // MARK: - Display state

    /// "New Task" / "Edit Task"
    var screenTitle: String { shared.state.screenTitle }
    var canSave: Bool { shared.state.canSave }
    var errorMessages: [String] { shared.state.errors.map(\.message) }
    var hasErrors: Bool { !shared.state.errors.isEmpty }

    // MARK: - Bindable properties: read from Kotlin uiState, write as a Kotlin event
    // `send` re-reads the Kotlin `MutableStateFlow` synchronously, so text fields don't lag.

    var title: String {
        get { shared.state.title }
        set { shared.send { $0.onTitleChange(value: newValue) } }
    }

    var notes: String {
        get { shared.state.notes }
        set { shared.send { $0.onNotesChange(value: newValue) } }
    }

    var priority: Priority {
        get { shared.state.priority }
        set { shared.send { $0.onPriorityChange(value: newValue) } }
    }

    /// SwiftUI `DatePicker` works with `Date`, Kotlin with `LocalDate` (IosDates helpers).
    var dueDate: Date {
        get { shared.state.dueDate.asDate }
        set { shared.send { $0.onDueDateChange(value: newValue.asLocalDate) } }
    }

    // MARK: - Intents

    /// Returns true when saved (the view dismisses the sheet).
    func save() -> Bool {
        shared.send { $0.save() }
    }
}

/// `sheet(item:)` needs Identifiable; a class gets `id = ObjectIdentifier(self)` for free.
extension TaskEditorScreenModel: Identifiable {}
