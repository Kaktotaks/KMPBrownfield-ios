import SwiftUI
import Shared

/// Tasks tab (§3.1). UI only: state mapping, bindings and navigation state live in `TaskListViewModel`.
/// The large title is content; the navigation bar stays inline and empty (its title is only the back label of the
/// pushed detail). FloatingAddButton is the only add affordance.
@MainActor
struct TaskListScreen: View {
    /// The screen owns its ViewModel. `StateObject(wrappedValue:)` takes an autoclosure, so the
    /// ViewModel (and its Kotlin VM) is created once, not on every re-creation of this struct.
    @StateObject private var model: TaskListViewModel

    init(model: @autoclosure @escaping () -> TaskListViewModel) {
        _model = StateObject(wrappedValue: model())
    }

    private var isLoading: Bool {
        if case .loading = model.content { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    Text("tasks_title")
                        .tkStyle(.largeTitle)
                        .foregroundStyle(Color.tk.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.gutter)
                        .padding(.top, 2)
                        .padding(.bottom, 12)
                        .accessibilityAddTraits(.isHeader)
                    PillSearchField(text: model.query, isEnabled: !isLoading)
                        .padding(.horizontal, Spacing.gutter)
                    HStack(spacing: 8) {
                        PillSegmentedControl(options: model.statusOptions, selection: model.status, isEnabled: !isLoading)
                        SortPill(label: model.sortLabel, options: model.sortOptions, selection: model.sort, isEnabled: !isLoading)
                    }
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.top, 12)
                    content
                }
                FloatingAddButton { model.showNewTaskEditor() }
                    .padding(Spacing.gutter)
            }
            .background(Color.tk.bg.ignoresSafeArea())
            .navigationTitle("tasks_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                // Empty principal item: the inline title is hidden, the back label of the detail stays "Tasks".
                ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }
            }
            .navigationDestination(item: $model.detail) { detail in
                TaskDetailScreen(model: detail)
            }
            .sheet(item: $model.newTaskEditor) { editor in
                TaskEditorScreen(model: editor)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.content {
        case .loading:
            LoadingRows()
        case .error:
            EmptyState(title: "error_title", message: "error_body", kind: .error) {
                SecondaryButton(title: "retry", icon: .refresh) { model.retry() }
            }
        case .empty(let hasActiveFilter):
            if hasActiveFilter {
                EmptyState(title: "no_match_title", message: "no_match_body")
            } else {
                EmptyState(title: "empty_title", message: "empty_body") {
                    PrimaryButton(title: "add_task", icon: .plus) { model.showNewTaskEditor() }
                }
            }
        case .loaded(let rows):
            TaskRowsList(model: model, rows: rows)
        }
    }
}

/// Loading (§3.1): 4 skeleton rows, then a 16 pt spinner + "Loading tasks…".
private struct LoadingRows: View {
    var body: some View {
        VStack(spacing: 8) {
            SkeletonRow(titleFraction: 0.8, dueFraction: 0.45)
            SkeletonRow(titleFraction: 0.65, dueFraction: 0.4)
            SkeletonRow(titleFraction: 0.75, dueFraction: 0.5)
            SkeletonRow(titleFraction: 0.7, dueFraction: 0.45)
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(Color.tk.textSecondary)
                Text("loading").tkStyle(.subhead).foregroundStyle(Color.tk.textSecondary)
            }
            .padding(.top, 8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
    }
}

/// The loaded, non-empty list; tapping a card pushes the detail screen (`model.openDetail`).
/// M4: insert = fade + 8 pt rise, remove = fade, reorder = move (250 ms emphasized).
@MainActor
struct TaskRowsList: View {
    @ObservedObject var model: TaskListViewModel
    let rows: [TaskRowItem]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.cardGap) {
                ForEach(rows) { row in
                    TaskCard(
                        title: row.title,
                        dueDate: row.dueDate,
                        priority: row.priority,
                        isDone: row.isDone,
                        isOverdue: row.isOverdue,
                        onTap: { model.openDetail(id: row.id) },
                        onToggle: { model.toggle(id: row.id) }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 8)),
                        removal: .opacity
                    ))
                }
            }
            .tkAnimation(Motion.emphasized(Motion.medium), value: rows.map(\.id))
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, 16)
            // Last card clears the FloatingAddButton: 16 + 56 + 16.
            .padding(.bottom, 88)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
