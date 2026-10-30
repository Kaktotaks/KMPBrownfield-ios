import SwiftUI
import Shared

/// Task detail. UI only: display state and intents live in `TaskDetailScreenModel`.
@MainActor
struct TaskDetailScreen: View {
    @State var model: TaskDetailScreenModel
    @State private var isConfirmingDelete = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let details = model.details {
                TaskDetailContent(details: details, model: model, isConfirmingDelete: $isConfirmingDelete)
            } else {
                // Briefly visible while popping back after delete.
                Color.clear
            }
        }
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { model.showEditor() }
                    .disabled(!model.canEdit)
            }
        }
        .sheet(item: $model.editor) { editor in
            TaskEditorScreen(model: editor)
        }
        .confirmationDialog("Delete task?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                model.delete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

/// Title, status, priority, due date, notes, toggle and delete buttons.
@MainActor
struct TaskDetailContent: View {
    let details: TaskDetailScreenModel.Details
    let model: TaskDetailScreenModel
    @Binding var isConfirmingDelete: Bool

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(details.title)
                        .font(.largeTitle.bold())
                    HStack(spacing: 8) {
                        Text(details.statusText)
                            .foregroundStyle(Color.secondary)
                        PriorityBadge(priority: details.priority)
                    }
                    DueDateLine(dueText: details.dueText, isOverdue: details.isOverdue)
                }
                .padding(.vertical, 4)
            }

            Section {
                if let notes = details.notes {
                    Text(notes)
                } else {
                    Text("No notes")
                        .foregroundStyle(Color.secondary)
                }
            }

            Section {
                Button(details.toggleTitle) { model.toggleDone() }
            }

            Section {
                Button("Delete task", role: .destructive) {
                    isConfirmingDelete = true
                }
            }
        }
    }
}
