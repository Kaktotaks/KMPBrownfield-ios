import SwiftUI

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
        switch priority {
        case .low: return .gray
        case .medium: return .orange
        case .high: return .red
        }
    }
}
