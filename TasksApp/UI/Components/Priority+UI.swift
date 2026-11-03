import SwiftUI
import Shared

/// Priority -> token colors (§1.1). Same mapping as Android `priorityFill` / `onPriority` / `priorityBar`.
extension Priority {
    /// Badge background.
    var fill: Color {
        // With SKIE the Kotlin enum is a real Swift enum → exhaustive switch, no `default`.
        switch self {
        case .high: return Color.tk.priorityHigh
        case .medium: return Color.tk.priorityMedium
        case .low: return Color.tk.priorityLow
        }
    }

    /// Text on `fill`.
    var onFill: Color {
        switch self {
        case .high: return Color.tk.onPriorityHigh
        case .medium: return Color.tk.onPriorityMedium
        case .low: return Color.tk.onPriorityLow
        }
    }

    /// Bar fill and segment dot: Low uses `outline`, not its pale badge color.
    var barFill: Color {
        switch self {
        case .high: return Color.tk.priorityHigh
        case .medium: return Color.tk.priorityMedium
        case .low: return Color.tk.outline
        }
    }
}
