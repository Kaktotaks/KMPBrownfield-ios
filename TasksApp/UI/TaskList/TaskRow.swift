import SwiftUI
import Shared

struct TaskRow: View {
    let item: TaskRowItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isDone ? Color.accentColor : Color.secondary)
            }
            // Borderless so tapping the circle doesn't trigger the row's NavigationLink.
            .buttonStyle(.borderless)
            .accessibilityLabel(item.toggleTitle)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? Color.secondary : Color.primary)
                DueDateLine(dueText: item.dueText, isOverdue: item.isOverdue)
            }

            Spacer(minLength: 8)

            PriorityBadge(priority: item.priority)
        }
        .padding(.vertical, 2)
    }
}
