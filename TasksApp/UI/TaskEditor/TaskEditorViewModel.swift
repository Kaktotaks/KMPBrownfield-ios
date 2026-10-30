import Foundation
import Observation
import SwiftUI
import Shared

/// Swift ViewModel of the New / Edit task sheet. Wraps the shared Kotlin `TaskEditorViewModel`
/// (form state + live validation + save). Created by the presenting ViewModel when the sheet
/// opens (`sheet(item:)`), so there is exactly one Kotlin ViewModel per presentation.
@MainActor
@Observable
final class TaskEditorViewModel {
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

    // MARK: - Bindings: read from Kotlin uiState, write as a Kotlin event (SharedViewModel.binding)

    var title: Binding<String> { shared.binding(\.title) { $0.onTitleChange(value: $1) } }
    var notes: Binding<String> { shared.binding(\.notes) { $0.onNotesChange(value: $1) } }
    var priority: Binding<Priority> { shared.binding(\.priority) { $0.onPriorityChange(value: $1) } }

    /// SwiftUI `DatePicker` works with `Date`, Kotlin with `LocalDate` (IosDates helpers).
    var dueDate: Binding<Date> {
        shared.binding(\.dueDate, get: \.asDate) { $0.onDueDateChange(value: $1.asLocalDate) }
    }

    // MARK: - Intents

    /// Returns true when saved (the view dismisses the sheet).
    func save() -> Bool {
        shared.send { $0.save() }
    }
}

/// `sheet(item:)` needs Identifiable; a class gets `id = ObjectIdentifier(self)` for free.
extension TaskEditorViewModel: Identifiable {}
