import SwiftUI

@MainActor
struct TaskListScreen: View {
    @State private var viewModel: TaskListViewModel
    @State private var isPresentingNewTask = false

    private let repository: TaskRepository
    private let clock: any Clock

    init(repository: TaskRepository, clock: any Clock) {
        self.repository = repository
        self.clock = clock
        _viewModel = State(initialValue: TaskListViewModel(repository: repository, clock: clock))
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
                                ForEach(SortOrder.allCases) { order in
                                    Text(order.title).tag(order)
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
                .navigationDestination(for: Int.self) { taskId in
                    TaskDetailScreen(taskId: taskId, repository: repository, clock: clock)
                }
                .sheet(isPresented: $isPresentingNewTask) {
                    TaskEditorScreen(mode: .new, repository: repository, clock: clock)
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
                ForEach(StatusFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            let tasks = viewModel.visibleTasks
            if tasks.isEmpty {
                ContentUnavailableView("No tasks", systemImage: "checklist")
            } else {
                List(tasks) { task in
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
