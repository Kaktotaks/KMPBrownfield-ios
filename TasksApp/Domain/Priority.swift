import Foundation

/// Task priority.
/// KMP sharing candidate: moves to the `shared` module as-is.
enum Priority: String, CaseIterable, Identifiable, Hashable {
    // Declaration order matters: the DTO mapping indexes `allCases` as [low, medium, high].
    case low
    case medium
    case high

    var id: Self { self }

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    /// Higher weight sorts first when sorting by priority.
    var sortWeight: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }
}
