import SwiftUI

/// "Due 29 Oct 2026" and, if overdue, a red "Overdue".
struct DueDateLine: View {
    let dueDate: Date
    let isOverdue: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("Due \(DueDateFormatter.string(from: dueDate))")
                .foregroundStyle(Color.secondary)
            if isOverdue {
                Text("Overdue")
                    .foregroundStyle(Color.red)
            }
        }
        .font(.subheadline)
    }
}
