import SwiftUI
import Shared

/// Presentation helper: Low = gray, Medium = orange, High = red.
extension Priority {
    var badgeColor: Color {
        // With SKIE the Kotlin enum is a real Swift enum → exhaustive switch, no `default`.
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .gray
        }
    }
}
