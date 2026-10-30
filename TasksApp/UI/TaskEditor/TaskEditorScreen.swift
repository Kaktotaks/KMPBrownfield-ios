import SwiftUI
import Shared

@MainActor
struct TaskEditorScreen: View {
    @State private var viewModel: TaskEditorViewModel
    @Environment(\.dismiss) private var dismiss

    init(mode: TaskEditorMode, store: TaskStore, dateProvider: any DateProvider) {
        _viewModel = State(initialValue: TaskEditorViewModel(mode: mode, store: store, dateProvider: dateProvider))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $viewModel.title)
                    TextField("Notes", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section {
                    Picker("Priority", selection: $viewModel.priority) {
                        ForEach(TaskEditorViewModel.priorities, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)

                    DatePicker("Due date", selection: $viewModel.dueDate, displayedComponents: .date)
                }

                let errors = viewModel.errors
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
            .navigationTitle(viewModel.screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if viewModel.save() {
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
        }
    }
}
