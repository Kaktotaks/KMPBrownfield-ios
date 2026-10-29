import Foundation

/// Editor validation errors, in the order they are reported.
/// KMP sharing candidate.
enum ValidationError: Error, Equatable, Hashable {
    case titleTooShort
    case titleTooLong
    case notesTooLong
    case dueDateInPast

    var message: String {
        switch self {
        case .titleTooShort: return "Title must be at least 3 characters."
        case .titleTooLong: return "Title must be at most 60 characters."
        case .notesTooLong: return "Notes must be at most 500 characters."
        case .dueDateInPast: return "Due date can't be in the past."
        }
    }
}
