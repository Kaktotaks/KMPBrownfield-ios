import SwiftUI
import Shared

@MainActor
struct TaskDetailScreen: View {
    /// Kotlin `TaskDetailViewModel` (task by id, toggle, delete) behind the Swift wrapper.
    @State private var model: TaskDetailModel
    /// Created when the sheet opens, released (→ `clear()`) when it closes.
    @State private var editor: TaskEditorModel?
    @State private var isConfirmingDelete = false
    @Environment(\.dismiss) private var dismiss

    private let app: AppDependencies

    init(taskId: Int32, app: AppDependencies) {
        self.app = app
        _model = State(initialValue: app.makeTaskDetail(taskId: taskId))
    }

    var body: some View {
        Group {
            if let task = model.state.task {
                details(task)
            } else {
                // Briefly visible while popping back after delete.
                Color.clear
            }
        }
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    editor = app.makeTaskEditor(taskId: model.viewModel.taskId)
                }
                .disabled(model.state.task == nil)
            }
        }
        .sheet(item: $editor) { editor in
            TaskEditorScreen(model: editor)
        }
        .confirmationDialog("Delete task?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                model.send { $0.onDelete() }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func details(_ task: TaskItem) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(task.title)
                        .font(.largeTitle.bold())
                    HStack(spacing: 8) {
                        Text(task.isDone ? "Done" : "Active")
                            .foregroundStyle(Color.secondary)
                        PriorityBadge(priority: task.priority)
                    }
                    DueDateLine(dueDate: task.dueDate, isOverdue: task.isOverdue(today: model.state.today))
                }
                .padding(.vertical, 4)
            }

            Section {
                if task.notes.isEmpty {
                    Text("No notes")
                        .foregroundStyle(Color.secondary)
                } else {
                    Text(task.notes)
                }
            }

            Section {
                Button(task.isDone ? "Mark as active" : "Mark as done") {
                    model.send { $0.onToggle() }
                }
            }

            Section {
                Button("Delete task", role: .destructive) {
                    isConfirmingDelete = true
                }
            }
        }
    }
}
