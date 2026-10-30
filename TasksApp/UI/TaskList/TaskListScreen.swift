import SwiftUI
import Shared

/// Tasks tab. UI only: state mapping, bindings and navigation state live in `TaskListViewModel`.
@MainActor
struct TaskListScreen: View {
    /// The screen owns its ViewModel. `StateObject(wrappedValue:)` takes an autoclosure, so the
    /// ViewModel (and its Kotlin VM) is created once, not on every re-creation of this struct.
    @StateObject private var model: TaskListViewModel

    init(model: @autoclosure @escaping () -> TaskListViewModel) {
        _model = StateObject(wrappedValue: model())
    }

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
            .searchable(text: model.query, prompt: "Search tasks")
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
            .navigationDestination(item: $model.detail) { detail in
                TaskDetailScreen(model: detail)
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
    @ObservedObject var model: TaskListViewModel

    var body: some View {
        SegmentedPicker(title: "Status", selection: model.status, options: model.statusOptions)
            .padding(.horizontal)
            .padding(.vertical, 8)
    }
}

/// Toolbar menu: "Sort by due date" / "Sort by priority".
@MainActor
struct SortMenu: View {
    @ObservedObject var model: TaskListViewModel

    var body: some View {
        Menu {
            Picker("Sort", selection: model.sort) {
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

/// The loaded, non-empty list; tapping a row pushes the detail screen (`model.openDetail`).
@MainActor
struct TaskRowsList: View {
    @ObservedObject var model: TaskListViewModel
    let rows: [TaskRowItem]

    var body: some View {
        List(rows) { row in
            Button {
                model.openDetail(id: row.id)
            } label: {
                TaskRow(item: row) { model.toggle(id: row.id) }
            }
            .foregroundStyle(Color.primary)
        }
        .listStyle(.plain)
    }
}
