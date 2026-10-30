import SwiftUI
import Shared

/// Tasks tab. UI only: state mapping, bindings and navigation factories live in `TaskListScreenModel`.
@MainActor
struct TaskListScreen: View {
    @State var model: TaskListScreenModel

    var body: some View {
        NavigationStack {
            Group {
                switch model.content {
                case .loading:
                    LoadingView()
                case .error:
                    LoadErrorView { model.retry() }
                case .empty:
                    VStack(spacing: 0) {
                        StatusFilterBar(model: model)
                        ContentUnavailableView("No tasks", systemImage: "checklist")
                    }
                case .loaded(let rows):
                    VStack(spacing: 0) {
                        StatusFilterBar(model: model)
                        TaskRowsList(model: model, rows: rows)
                    }
                }
            }
            .navigationTitle("Tasks")
            .searchable(text: $model.query, prompt: "Search tasks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SortMenu(model: model)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.showNewTaskEditor()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Task")
                }
            }
            .navigationDestination(for: Int32.self) { taskId in
                TaskDetailScreen(model: model.makeDetail(taskId: taskId))
            }
            .sheet(item: $model.newTaskEditor) { editor in
                TaskEditorScreen(model: editor)
            }
        }
    }
}

/// Segmented "All / Active / Done" filter above the list.
@MainActor
struct StatusFilterBar: View {
    @Bindable var model: TaskListScreenModel

    var body: some View {
        SegmentedPicker(title: "Status", selection: $model.status, options: model.statusOptions)
            .padding(.horizontal)
            .padding(.vertical, 8)
    }
}

/// Toolbar menu: "Sort by due date" / "Sort by priority".
@MainActor
struct SortMenu: View {
    @Bindable var model: TaskListScreenModel

    var body: some View {
        Menu {
            Picker("Sort", selection: $model.sort) {
                ForEach(model.sortOptions) { option in
                    Text(option.title).tag(option.value)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("Sort")
    }
}

/// The loaded, non-empty list; rows push the detail screen by task id.
@MainActor
struct TaskRowsList: View {
    let model: TaskListScreenModel
    let rows: [TaskRowItem]

    var body: some View {
        List(rows) { row in
            NavigationLink(value: row.id) {
                TaskRow(item: row) { model.toggle(id: row.id) }
            }
        }
        .listStyle(.plain)
    }
}
