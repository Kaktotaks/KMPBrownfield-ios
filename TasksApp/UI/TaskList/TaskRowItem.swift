import Foundation
import Shared

/// Display-ready row of the task list, mapped from the Kotlin `TaskItem` by `TaskListViewModel`.
struct TaskRowItem: Identifiable, Equatable {
    let id: Int32
    let title: String
    /// "5 Nov 2026" (shared `DateFormatting`); the "Due %@" copy is applied by the UI (`DueLine`).
    let dueDate: String
    let isOverdue: Bool
    let isDone: Bool
    let priority: Priority
    /// Set when the task has a voice note: the row shows the indicator.
    var voice: VoiceRowInfo? = nil
}

/// Voice note of a list row: "0:42" (shared `VoiceNoteFormat`, same text on Android) and the length for VoiceOver.
struct VoiceRowInfo: Equatable {
    let durationText: String
    let durationMs: Int64
}

extension TaskRowItem {
    init(task: TaskItem, today: LocalDate) {
        self.init(
            id: task.id,
            title: task.title,
            dueDate: Self.formatted(task.dueDate),
            isOverdue: task.isOverdue(today: today),
            isDone: task.isDone,
            priority: task.priority,
            voice: task.voiceNote.map { VoiceRowInfo(durationText: $0.durationText, durationMs: $0.durationMs) }
        )
    }

    /// "29 Oct 2026" via the shared Kotlin `DateFormatting` (same format on Android).
    static func formatted(_ date: LocalDate) -> String {
        DateFormatting.shared.format(date: date)
    }
}
