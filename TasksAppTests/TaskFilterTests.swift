import XCTest
@testable import TasksApp

final class TaskFilterTests: XCTestCase {
    private let tasks: [DomainTask] = [
        makeTask(id: 1, title: "Buy milk", priority: .low, dueOffset: 2),
        makeTask(id: 2, title: "Write report", priority: .high, dueOffset: 5, isDone: true),
        makeTask(id: 3, title: "Call mom", priority: .medium, dueOffset: -1),
        makeTask(id: 4, title: "Buy bread", priority: .high, dueOffset: 2),
        makeTask(id: 5, title: "Gym", priority: .high, dueOffset: 2),
    ]

    private func ids(_ result: [DomainTask]) -> [Int] {
        result.map(\.id)
    }

    func testDefaultsSortByDueDateThenId() {
        let result = TaskFilter.apply(tasks, query: "", status: .all, sort: DomainSortOrder.dueDate)
        XCTAssertEqual(ids(result), [3, 1, 4, 5, 2])
    }

    func testQueryIsTrimmedAndCaseInsensitive() {
        let result = TaskFilter.apply(tasks, query: "  BUY ", status: .all, sort: DomainSortOrder.dueDate)
        XCTAssertEqual(ids(result), [1, 4])
    }

    func testBlankQueryDoesNotFilter() {
        let result = TaskFilter.apply(tasks, query: "   ", status: .all, sort: DomainSortOrder.dueDate)
        XCTAssertEqual(result.count, tasks.count)
    }

    func testActiveStatus() {
        let result = TaskFilter.apply(tasks, query: "", status: .active, sort: DomainSortOrder.dueDate)
        XCTAssertEqual(ids(result), [3, 1, 4, 5])
    }

    func testDoneStatus() {
        let result = TaskFilter.apply(tasks, query: "", status: .done, sort: DomainSortOrder.dueDate)
        XCTAssertEqual(ids(result), [2])
    }

    func testSortByPriorityThenDueDateThenId() {
        let result = TaskFilter.apply(tasks, query: "", status: .all, sort: DomainSortOrder.priority)
        XCTAssertEqual(ids(result), [4, 5, 2, 3, 1])
    }

    func testQueryAndStatusCombined() {
        let result = TaskFilter.apply(tasks, query: "r", status: .done, sort: DomainSortOrder.dueDate)
        XCTAssertEqual(ids(result), [2])
    }

    func testNoMatchesReturnsEmpty() {
        let result = TaskFilter.apply(tasks, query: "zzz", status: .all, sort: DomainSortOrder.dueDate)
        XCTAssertTrue(result.isEmpty)
    }
}
