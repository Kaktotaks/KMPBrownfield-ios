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
            // Borderless so tapping the circle doesn't also trigger the row's button (open detail).
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

            // Rows are Buttons (the list VM owns navigation), so draw the disclosure chevron ourselves.
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}
