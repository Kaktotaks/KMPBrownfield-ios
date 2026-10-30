import SwiftUI
import Shared

/// New / Edit task sheet. UI only: controls bind to `TaskEditorViewModel`, which forwards every
/// change to the Kotlin `TaskEditorViewModel` (form state + live validation).
@MainActor
struct TaskEditorScreen: View {
    /// Owned by the presenting ViewModel (`newTaskEditor` / `editor`) → observed, not owned.
    @ObservedObject var model: TaskEditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: model.title)
                    TextField("Notes", text: model.notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section {
                    SegmentedPicker(title: "Priority", selection: model.priority, options: model.priorityOptions)
                    DatePicker("Due date", selection: model.dueDate, displayedComponents: .date)
                }

                if model.hasErrors {
                    Section {
                        ForEach(model.errorMessages, id: \.self) { message in
                            Text(message)
                                .foregroundStyle(Color.red)
                                .font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle(model.screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if model.save() { dismiss() }
                    }
                    .disabled(!model.canSave)
                }
            }
        }
    }
}
