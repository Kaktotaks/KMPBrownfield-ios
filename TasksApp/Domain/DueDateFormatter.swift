import Foundation

/// Single shared formatter for dates: "d MMM yyyy" in en_US_POSIX (e.g. "29 Oct 2026").
/// KMP sharing candidate (would become a platform formatter behind a common API).
enum DueDateFormatter {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}
