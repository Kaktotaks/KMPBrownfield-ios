import SwiftUI
import Shared

@MainActor
struct TaskListScreen: View {
    /// Kotlin `TaskListViewModel` (search, filter, sort, toggle, retry) behind the Swift wrapper.
    @State private var model: TaskListModel
    /// Search text stays local and is forwarded to Kotlin: `uiState` (stateIn) updates
    /// asynchronously, and binding a TextField straight to it would make typing jump.
    @State private var query = ""
    /// Created when the sheet opens, released (→ `clear()`) when it closes.
    @State private var newTaskEditor: TaskEditorModel?

    private let app: AppDependencies

    /// Kotlin enums with SKIE are Swift enums, but not `CaseIterable`: the segment/menu order is listed here.
    private static let statusFilters: [StatusFilter] = [.all, .active, .done]
    private static let sortOrders: [SortOrder] = [.dueDate, .priority]

    init(app: AppDependencies) {
        self.app = app
        _model = State(initialValue: app.makeTaskList())
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Tasks")
                .searchable(text: $query, prompt: "Search tasks")
                .onChange(of: query) { _, newValue in
                    model.send { $0.onQueryChange(value: newValue) }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Picker("Sort", selection: sortBinding) {
                                ForEach(Self.sortOrders, id: \.self) { order in
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
                            newTaskEditor = app.makeTaskEditor(taskId: nil)
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("New Task")
                    }
                }
                .navigationDestination(for: Int32.self) { taskId in
                    TaskDetailScreen(taskId: taskId, app: app)
                }
                .sheet(item: $newTaskEditor) { editor in
                    TaskEditorScreen(model: editor)
                }
        }
    }

    // MARK: - Bindings to Kotlin state (get from uiState, set → Kotlin event)

    private var statusBinding: Binding<StatusFilter> {
        Binding(
            get: { model.state.status },
            set: { value in model.send { $0.onStatusChange(value: value) } }
        )
    }

    private var sortBinding: Binding<SortOrder> {
        Binding(
            get: { model.state.sort },
            set: { value in model.send { $0.onSortChange(value: value) } }
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        // SKIE: Kotlin sealed `TaskListContent` → exhaustive Swift enum.
        switch onEnum(of: model.state.content) {
        case .loading:
            LoadingView()
        case .error:
            LoadErrorView {
                model.send { $0.onRetry() }
            }
        case .loaded(let loaded):
            loadedContent(loaded.tasks)
        }
    }

    private func loadedContent(_ tasks: [TaskItem]) -> some View {
        VStack(spacing: 0) {
            Picker("Status", selection: statusBinding) {
                ForEach(Self.statusFilters, id: \.self) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if tasks.isEmpty {
                ContentUnavailableView("No tasks", systemImage: "checklist")
            } else {
                let today = model.state.today
                // TaskItem is a Kotlin class; identify rows by its Int32 id.
                List(tasks, id: \.id) { task in
                    NavigationLink(value: task.id) {
                        TaskRow(
                            task: task,
                            isOverdue: task.isOverdue(today: today),
                            onToggle: { model.send { $0.onToggle(id: task.id) } }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}
