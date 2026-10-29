import Foundation

/// Provides "today" so business rules are testable with a fixed date.
/// KMP sharing candidate (expect/actual or an injected interface in `shared`).
///
/// Note: shadows Swift Concurrency's `Clock` protocol inside the app module.
protocol Clock {
    /// Start of the current day in `Calendar.current`.
    var today: Date { get }
}

struct SystemClock: Clock {
    var today: Date {
        Calendar.current.startOfDay(for: Date())
    }
}
