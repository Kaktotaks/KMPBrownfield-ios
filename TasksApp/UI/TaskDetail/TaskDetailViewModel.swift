import Combine
import Foundation
import Shared

/// Swift ViewModel of the task detail screen. Wraps the shared Kotlin `TaskDetailViewModel`.
@MainActor
final class TaskDetailViewModel: ObservableObject {
    /// Display-ready task details.
    struct Details: Equatable {
        let title: String
        let isDone: Bool
        let priority: Priority
        /// "5 Nov 2026"; the "Due %@" copy is applied by the UI.
        let dueDate: String
        let isOverdue: Bool
        /// `nil` when blank (the notes card is hidden then).
        let notes: String?
    }

    /// Created when the edit sheet opens, released (→ Kotlin `clear()`) when it closes.
    @Published var editor: TaskEditorViewModel?
    /// Set on delete so "Task not found" doesn't flash while the screen pops.
    @Published private(set) var isDeleting = false

    /// The voice-note card of this task (`ExistingTask` target): records / plays / replaces / deletes right away.
    let voice: VoiceNoteCardViewModel

    private var forwarding: AnyCancellable?
    private let shared: TaskDetailModel
    private let app: AppDependencies

    init(shared: TaskDetailModel, app: AppDependencies) {
        self.shared = shared
        self.app = app
        self.voice = app.makeVoiceNoteViewModel(target: VoiceNoteTarget.ExistingTask(taskId: shared.viewModel.taskId))
        // Nested ObservableObject: changes of `shared.state` don't reach SwiftUI by themselves
        // (classic Combine pitfall), so re-publish them as this object's changes.
        forwarding = shared.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    // MARK: - Display state

    /// `nil` after the task was deleted: the screen shows "Task not found".
    var details: Details? {
        let state = shared.state
        guard let task = state.task else { return nil }
        return Details(
            title: task.title,
            isDone: task.isDone,
            priority: task.priority,
            dueDate: TaskRowItem.formatted(task.dueDate),
            isOverdue: task.isOverdue(today: state.today),
            notes: task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : task.notes
        )
    }

    var canEdit: Bool {
        shared.state.task != nil
    }

    // MARK: - Intents

    func toggleDone() {
        shared.send { $0.onToggle() }
    }

    func delete() {
        isDeleting = true
        shared.send { $0.onDelete() }
    }

    func showEditor() {
        voice.pausePlayback()
        editor = app.makeTaskEditorViewModel(taskId: shared.viewModel.taskId)
    }
}

/// `navigationDestination(item:)` needs Hashable: identity of this ViewModel instance.
extension TaskDetailViewModel: Hashable {
    nonisolated static func == (lhs: TaskDetailViewModel, rhs: TaskDetailViewModel) -> Bool {
        lhs === rhs
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
