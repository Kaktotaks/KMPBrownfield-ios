import Foundation

// UI strings for domain enums (kept out of Domain on purpose).

extension StatusFilter {
    var title: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .done: return "Done"
        }
    }
}

extension SortOrder {
    var title: String {
        switch self {
        case .dueDate: return "Sort by due date"
        case .priority: return "Sort by priority"
        }
    }
}
