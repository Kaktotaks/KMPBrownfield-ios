import Foundation
import Observation
import Shared

/// Swift screen model of the Tasks tab ("local ViewModel", SwiftUI-style).
///
/// Wraps the shared Kotlin `TaskListViewModel` (through the generic `SharedViewModel` bridge) and turns
/// its `uiState` into display-ready values, bindable properties and intents, so `TaskListScreen`
/// stays UI only. Search/filter/sort/toggle/retry logic itself lives in Kotlin.
@MainActor
@Observable
final class TaskListViewModel {
    enum Content {
        case loading
        case error
        /// Loaded, but nothing matches the query/filter → "No tasks".
        case empty
        case loaded([TaskRowItem])
    }

    /// Kotlin enums with SKIE are Swift enums, but not `CaseIterable`: the segment/menu order is listed here.
    let statusOptions: [PickerOption<StatusFilter>] = [StatusFilter.all, .active, .done]
        .map { PickerOption(value: $0, title: $0.displayName) }
    let sortOptions: [PickerOption<SortOrder>] = [SortOrder.dueDate, .priority]
        .map { PickerOption(value: $0, title: $0.displayName) }

    /// Created when the "New Task" sheet opens, released (→ Kotlin `clear()`) when it closes.
    var newTaskEditor: TaskEditorViewModel?

    private let shared: TaskListModel
    private let app: AppDependencies
    /// Search text is stored here and forwarded to Kotlin: `uiState` (stateIn) updates
    /// asynchronously, and binding a TextField straight to it would make typing jump.
    private var queryText = ""

    init(shared: TaskListModel, app: AppDependencies) {
        self.shared = shared
        self.app = app
    }

    // MARK: - Display state

    var content: Content {
        let state = shared.state
        // SKIE: Kotlin sealed `TaskListContent` → exhaustive Swift enum.
        switch onEnum(of: state.content) {
        case .loading:
            return .loading
        case .error:
            return .error
        case .loaded(let loaded):
            let today = state.today
            let rows = loaded.tasks.map { TaskRowItem(task: $0, today: today) }
            return rows.isEmpty ? .empty : .loaded(rows)
        }
    }

    // MARK: - Bindable properties (get from uiState / local, set → Kotlin event)

    var query: String {
        get { queryText }
        set {
            queryText = newValue
            shared.send { $0.onQueryChange(value: newValue) }
        }
    }

    var status: StatusFilter {
        get { shared.state.status }
        set { shared.send { $0.onStatusChange(value: newValue) } }
    }

    var sort: SortOrder {
        get { shared.state.sort }
        set { shared.send { $0.onSortChange(value: newValue) } }
    }

    // MARK: - Intents

    func retry() {
        shared.send { $0.onRetry() }
    }

    func toggle(id: Int32) {
        shared.send { $0.onToggle(id: id) }
    }

    func showNewTaskEditor() {
        newTaskEditor = app.makeTaskEditorViewModel(taskId: nil)
    }

    /// Navigation factory for `navigationDestination(for: Int32.self)`.
    func makeDetail(taskId: Int32) -> TaskDetailViewModel {
        app.makeTaskDetailViewModel(taskId: taskId)
    }
}
