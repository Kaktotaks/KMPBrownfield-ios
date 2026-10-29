import Foundation

/// Aggregated statistics for the Stats screen.
/// KMP sharing candidate.
struct TaskStats: Equatable {
    let total: Int
    let done: Int
    let active: Int
    /// 0...100, rounded half up.
    let completionPercent: Int
    let low: Int
    let medium: Int
    let high: Int
    let overdue: Int

    static let empty = TaskStats(
        total: 0, done: 0, active: 0, completionPercent: 0,
        low: 0, medium: 0, high: 0, overdue: 0
    )
}

/// KMP sharing candidate: pure function over domain models.
enum StatsCalculator {
    static func calculate(tasks: [Task], today: Date) -> TaskStats {
        let total = tasks.count
        let done = tasks.filter { $0.isDone }.count
        // Integer "round half up" of done * 100 / total (identical on Kotlin side).
        let percent = total == 0 ? 0 : (done * 200 + total) / (2 * total)

        return TaskStats(
            total: total,
            done: done,
            active: total - done,
            completionPercent: percent,
            low: tasks.filter { $0.priority == .low }.count,
            medium: tasks.filter { $0.priority == .medium }.count,
            high: tasks.filter { $0.priority == .high }.count,
            overdue: tasks.filter { $0.isOverdue(today: today) }.count
        )
    }
}
