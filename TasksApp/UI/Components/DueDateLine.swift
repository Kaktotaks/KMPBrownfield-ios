import SwiftUI
import Shared

/// "Due 29 Oct 2026" and, if overdue, a red "Overdue".
struct DueDateLine: View {
    let dueDate: LocalDate
    let isOverdue: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("Due \(DateFormatting.shared.format(date: dueDate))")
                .foregroundStyle(Color.secondary)
            if isOverdue {
                Text("Overdue")
                    .foregroundStyle(Color.red)
            }
        }
        .font(.subheadline)
    }
}
