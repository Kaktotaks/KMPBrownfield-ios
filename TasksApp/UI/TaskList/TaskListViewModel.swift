import Foundation
import Observation
import SwiftUI
import Shared

/// Swift ViewModel of the Tasks tab ("local ViewModel", SwiftUI-style).
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
    /// Pushed detail screen. Created once on tap and released (→ Kotlin `clear()`) on pop.
    /// (A `navigationDestination(for:)` closure would build a new Kotlin VM on every re-render.)
    var detail: TaskDetailViewModel?

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

    // MARK: - Bindings: read from Kotlin uiState, write as a Kotlin event (SharedViewModel.binding)

    /// The search text is kept locally (Kotlin's `uiState` updates asynchronously and typing would
    /// jump) and forwarded to Kotlin on every change — so this one Binding is written by hand.
    var query: Binding<String> {
        Binding(
            get: { self.queryText },
            set: { newValue in
                self.queryText = newValue
                self.shared.send { $0.onQueryChange(value: newValue) }
            }
        )
    }

    var status: Binding<StatusFilter> { shared.binding(\.status) { $0.onStatusChange(value: $1) } }
    var sort: Binding<SortOrder> { shared.binding(\.sort) { $0.onSortChange(value: $1) } }

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

    func openDetail(id: Int32) {
        detail = app.makeTaskDetailViewModel(taskId: id)
    }
}
