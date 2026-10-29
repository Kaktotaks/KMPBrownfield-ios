import Foundation

/// Validates editor input.
/// KMP sharing candidate: pure business rules, no UI.
struct TaskValidator {
    static let minTitleLength = 3
    static let maxTitleLength = 60
    static let maxNotesLength = 500

    private let clock: any Clock
    private let calendar: Calendar

    init(clock: any Clock, calendar: Calendar = .current) {
        self.clock = clock
        self.calendar = calendar
    }

    /// Returns errors in a fixed order: title short, title long, notes long, due date in past.
    /// - Parameter originalDueDate: the task's due date before editing (nil when creating).
    ///   An unchanged overdue date is allowed when editing.
    func validate(
        title: String,
        notes: String,
        dueDate: Date,
        originalDueDate: Date? = nil
    ) -> [ValidationError] {
        var errors: [ValidationError] = []
        let trimmedLength = title.trimmingCharacters(in: .whitespacesAndNewlines).count

        if trimmedLength < Self.minTitleLength {
            errors.append(.titleTooShort)
        }
        if trimmedLength > Self.maxTitleLength {
            errors.append(.titleTooLong)
        }
        if notes.count > Self.maxNotesLength {
            errors.append(.notesTooLong)
        }

        let day = calendar.startOfDay(for: dueDate)
        if day < clock.today {
            var isUnchangedOriginal = false
            if let originalDueDate = originalDueDate {
                isUnchangedOriginal = calendar.startOfDay(for: originalDueDate) == day
            }
            if !isUnchangedOriginal {
                errors.append(.dueDateInPast)
            }
        }
        return errors
    }
}
