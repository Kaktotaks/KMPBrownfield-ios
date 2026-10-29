import SwiftUI

struct TaskRow: View {
    let task: Task
    let isOverdue: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isDone ? Color.accentColor : Color.secondary)
            }
            // Borderless so tapping the circle doesn't trigger the row's NavigationLink.
            .buttonStyle(.borderless)
            .accessibilityLabel(task.isDone ? "Mark as active" : "Mark as done")

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? Color.secondary : Color.primary)
                DueDateLine(dueDate: task.dueDate, isOverdue: isOverdue)
            }

            Spacer(minLength: 8)

            PriorityBadge(priority: task.priority)
        }
        .padding(.vertical, 2)
    }
}
