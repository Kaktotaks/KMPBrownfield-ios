import Combine
import Foundation
import SwiftUI
import Shared

/// Swift ViewModel of the New / Edit task sheet. Wraps the shared Kotlin `TaskEditorViewModel`
/// (form state + live validation + save). Created by the presenting ViewModel when the sheet
/// opens (`sheet(item:)`), so there is exactly one Kotlin ViewModel per presentation.
@MainActor
final class TaskEditorViewModel: ObservableObject {
    /// Kotlin enums with SKIE are Swift enums, but not `CaseIterable`: the segment order is listed here.
    let priorityOptions: [PickerOption<Priority>] = [Priority.low, .medium, .high]
        .map { PickerOption(value: $0, title: $0.displayName) }

    /// Segment dot colors (`outline` for Low, like the Stats bars).
    func dotColor(_ priority: Priority) -> Color { priority.barFill }

    private var forwarding: AnyCancellable?
    private let shared: TaskEditorModel

    init(shared: TaskEditorModel) {
        self.shared = shared
        // Nested ObservableObject: changes of `shared.state` don't reach SwiftUI by themselves
        // (classic Combine pitfall), so re-publish them as this object's changes.
        forwarding = shared.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    // MARK: - Display state

    /// "New Task" / "Edit Task"
    var screenTitle: String { shared.state.screenTitle }
    var canSave: Bool { shared.state.canSave }

    /// Validation messages (text from shared), mapped to the field they belong to.
    var titleError: String? {
        shared.state.errors.first { $0 == .titleTooShort || $0 == .titleTooLong }?.message
    }
    var notesError: String? { shared.state.errors.first { $0 == .notesTooLong }?.message }
    var dueDateError: String? { shared.state.errors.first { $0 == .dueDateInPast }?.message }

    /// Number of fields with an error: "Fix N fields to save this task."
    var errorFieldCount: Int { [titleError, notesError, dueDateError].compactMap { $0 }.count }
    var bannerText: String { L10n.plural("fix_fields", errorFieldCount) }
    var dueDateText: String { DateFormatting.shared.format(date: shared.state.dueDate) }

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
