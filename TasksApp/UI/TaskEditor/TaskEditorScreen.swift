import SwiftUI
import Shared

/// New / Edit task sheet. The form state and live validation live in Kotlin
/// (`TaskEditorViewModel`); this view only binds controls to it.
/// The model is created by the presenting screen when the sheet opens (`sheet(item:)`),
/// so there is exactly one Kotlin ViewModel per presentation, cleared when the sheet closes.
@MainActor
struct TaskEditorScreen: View {
    let model: TaskEditorModel
    @Environment(\.dismiss) private var dismiss

    /// Kotlin enums with SKIE are Swift enums, but not `CaseIterable`: the segment order is listed here.
    private static let priorities: [Priority] = [.low, .medium, .high]

    var body: some View {
        let state = model.state
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: binding(\.title) { vm, value in vm.onTitleChange(value: value) })
                    TextField("Notes", text: binding(\.notes) { vm, value in vm.onNotesChange(value: value) }, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section {
                    Picker("Priority", selection: binding(\.priority) { vm, value in vm.onPriorityChange(value: value) }) {
                        ForEach(Self.priorities, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)

                    // SwiftUI DatePicker works with Date; Kotlin with LocalDate (IosDates helpers).
                    DatePicker("Due date", selection: dueDateBinding, displayedComponents: .date)
                }

                let errors = state.errors
                if !errors.isEmpty {
                    Section {
                        ForEach(errors, id: \.self) { error in
                            Text(error.message)
                                .foregroundStyle(Color.red)
                                .font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle(state.screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if model.send({ $0.save() }) {
                            dismiss()
                        }
                    }
                    .disabled(!state.canSave)
                }
            }
        }
    }

    // MARK: - Bindings: read from Kotlin uiState, write as a Kotlin event

    /// `send` re-reads the Kotlin `MutableStateFlow` synchronously, so text fields don't lag.
    private func binding<Value>(
        _ keyPath: KeyPath<TaskEditorUiState, Value>,
        _ onChange: @escaping (TaskEditorViewModel, Value) -> Void
    ) -> Binding<Value> {
        Binding(
            get: { model.state[keyPath: keyPath] },
            set: { value in model.send { onChange($0, value) } }
        )
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { model.state.dueDate.asDate },
            set: { date in model.send { $0.onDueDateChange(value: date.asLocalDate) } }
        )
    }
}
