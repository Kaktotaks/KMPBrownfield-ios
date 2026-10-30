import SwiftUI
import Shared

@MainActor
struct TaskListScreen: View {
    @State private var viewModel: TaskListViewModel
    @State private var isPresentingNewTask = false

    private let repository: TaskRepository
    private let dateProvider: any DateProvider

    init(repository: TaskRepository, dateProvider: any DateProvider) {
        self.repository = repository
        self.dateProvider = dateProvider
        _viewModel = State(initialValue: TaskListViewModel(repository: repository, dateProvider: dateProvider))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Tasks")
                .searchable(text: $viewModel.query, prompt: "Search tasks")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Picker("Sort", selection: $viewModel.sort) {
                                ForEach(TaskListViewModel.sortOrders, id: \.self) { order in
                                    Text(order.displayName).tag(order)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .accessibilityLabel("Sort")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isPresentingNewTask = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("New Task")
                    }
                }
                .navigationDestination(for: Int32.self) { taskId in
                    TaskDetailScreen(taskId: taskId, repository: repository, dateProvider: dateProvider)
                }
                .sheet(isPresented: $isPresentingNewTask) {
                    TaskEditorScreen(mode: .new, repository: repository, dateProvider: dateProvider)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loading:
            LoadingView()
        case .error:
            LoadErrorView {
                viewModel.retry()
            }
        case .loaded:
            loadedContent
        }
    }

    private var loadedContent: some View {
        VStack(spacing: 0) {
            Picker("Status", selection: $viewModel.status) {
                ForEach(TaskListViewModel.statusFilters, id: \.self) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            let tasks = viewModel.visibleTasks
            if tasks.isEmpty {
                ContentUnavailableView("No tasks", systemImage: "checklist")
            } else {
                // TaskItem is a Kotlin class; identify rows by its Int32 id.
                List(tasks, id: \.id) { task in
                    NavigationLink(value: task.id) {
                        TaskRow(
                            task: task,
                            isOverdue: viewModel.isOverdue(task),
                            onToggle: { viewModel.toggleDone(id: task.id) }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}
