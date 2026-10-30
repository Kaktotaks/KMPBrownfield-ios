import SwiftUI
import Shared

/// Capsule badge: Low = gray, Medium = orange, High = red (`Priority.badgeColor`).
struct PriorityBadge: View {
    let priority: Priority

    var body: some View {
        Text(priority.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(priority.badgeColor)
            .background(priority.badgeColor.opacity(0.15), in: Capsule())
    }
}
