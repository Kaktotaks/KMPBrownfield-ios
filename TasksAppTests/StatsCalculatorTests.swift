import XCTest
@testable import TasksApp

final class StatsCalculatorTests: XCTestCase {
    func testEmptyList() {
        let stats = StatsCalculator.calculate(tasks: [], today: TestDates.today)
        XCTAssertEqual(stats, TaskStats.empty)
    }

    func testCountsAndOverdue() {
        let tasks: [DomainTask] = [
            makeTask(id: 1, priority: .low, dueOffset: -1),                 // overdue
            makeTask(id: 2, priority: .high, dueOffset: -3, isDone: true),  // done, not overdue
            makeTask(id: 3, priority: .high, dueOffset: 0),                 // due today, not overdue
            makeTask(id: 4, priority: .medium, dueOffset: 4),
        ]
        let stats = StatsCalculator.calculate(tasks: tasks, today: TestDates.today)

        XCTAssertEqual(stats.total, 4)
        XCTAssertEqual(stats.done, 1)
        XCTAssertEqual(stats.active, 3)
        XCTAssertEqual(stats.completionPercent, 25)
        XCTAssertEqual(stats.low, 1)
        XCTAssertEqual(stats.medium, 1)
        XCTAssertEqual(stats.high, 2)
        XCTAssertEqual(stats.overdue, 1)
    }

    func testCompletionPercentRoundsHalfUp() {
        // 1 of 8 = 12.5% -> 13
        var tasks = (1...8).map { makeTask(id: $0) }
        tasks[0].isDone = true
        XCTAssertEqual(StatsCalculator.calculate(tasks: tasks, today: TestDates.today).completionPercent, 13)
    }

    func testCompletionPercentRoundsDown() {
        // 1 of 3 = 33.33% -> 33, 2 of 3 = 66.67% -> 67
        var tasks = (1...3).map { makeTask(id: $0) }
        tasks[0].isDone = true
        XCTAssertEqual(StatsCalculator.calculate(tasks: tasks, today: TestDates.today).completionPercent, 33)
        tasks[1].isDone = true
        XCTAssertEqual(StatsCalculator.calculate(tasks: tasks, today: TestDates.today).completionPercent, 67)
    }
}
