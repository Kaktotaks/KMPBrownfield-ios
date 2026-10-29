import Foundation
@testable import TasksApp

// Module-qualified aliases: `Task`, `Clock` and `SortOrder` also exist in
// Swift Concurrency / Foundation, so tests refer to the app's types explicitly.
typealias DomainTask = TasksApp.Task
typealias DomainClock = TasksApp.Clock
typealias DomainSortOrder = TasksApp.SortOrder

/// Clock with a fixed "today" for deterministic tests.
struct FixedClock: DomainClock {
    let today: Date
}

enum TestDates {
    static let calendar = Calendar.current

    /// Fixed today: 29 Oct 2026, start of day.
    static let today: Date = {
        let components = DateComponents(year: 2026, month: 10, day: 29)
        return calendar.startOfDay(for: calendar.date(from: components)!)
    }()

    static func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: today)!
    }
}

func makeTask(
    id: Int,
    title: String = "Task",
    priority: Priority = .medium,
    dueOffset: Int = 0,
    isDone: Bool = false
) -> DomainTask {
    DomainTask(
        id: id,
        title: title,
        notes: "",
        priority: priority,
        dueDate: TestDates.day(dueOffset),
        isDone: isDone
    )
}
