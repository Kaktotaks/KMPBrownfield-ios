import SwiftUI
import Shared

/// Capsule badge: Low = gray, Medium = orange, High = red.
struct PriorityBadge: View {
    let priority: Priority

    var body: some View {
        Text(priority.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
    }

    private var color: Color {
        // Kotlin enums are classes in Swift, so the switch needs `default`.
        switch priority {
        case .high: return .red
        case .medium: return .orange
        default: return .gray
        }
    }
}
