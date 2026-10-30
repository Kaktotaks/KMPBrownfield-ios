import SwiftUI
import Shared

@MainActor
struct TaskDetailScreen: View {
    @State private var viewModel: TaskDetailViewModel
    @State private var isPresentingEditor = false
    @State private var isConfirmingDelete = false
    @Environment(\.dismiss) private var dismiss

    private let store: TaskStore
    private let dateProvider: any DateProvider

    init(taskId: Int32, store: TaskStore, dateProvider: any DateProvider) {
        self.store = store
        self.dateProvider = dateProvider
        _viewModel = State(initialValue: TaskDetailViewModel(taskId: taskId, store: store, dateProvider: dateProvider))
    }

    var body: some View {
        Group {
            if let task = viewModel.task {
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
                    isPresentingEditor = true
                }
                .disabled(viewModel.task == nil)
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            if let task = viewModel.task {
                TaskEditorScreen(mode: .edit(task), store: store, dateProvider: dateProvider)
            }
        }
        .confirmationDialog("Delete task?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                viewModel.delete()
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
                    DueDateLine(dueDate: task.dueDate, isOverdue: viewModel.isOverdue)
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
                    viewModel.toggleDone()
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
