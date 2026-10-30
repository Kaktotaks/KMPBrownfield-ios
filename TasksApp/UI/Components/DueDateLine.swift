import SwiftUI

/// "Due 29 Oct 2026" (already formatted by the Swift ViewModel) and, if overdue, a red "Overdue".
struct DueDateLine: View {
    let dueText: String
    let isOverdue: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(dueText)
                .foregroundStyle(Color.secondary)
            if isOverdue {
                Text("Overdue")
                    .foregroundStyle(Color.red)
            }
        }
        .font(.subheadline)
    }
}
