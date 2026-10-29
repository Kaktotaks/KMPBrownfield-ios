import XCTest
@testable import TasksApp

final class TodoMappingTests: XCTestCase {
    func testDeterministicMapping() {
        let dto = TodoDto(userId: 1, id: 1, title: "delectus aut autem", completed: false)
        let task = dto.toTask(today: TestDates.today)

        XCTAssertEqual(task.id, 1)
        XCTAssertEqual(task.title, "delectus aut autem")
        XCTAssertEqual(task.notes, "")
        XCTAssertEqual(task.priority, .medium)          // 1 % 3 = 1
        XCTAssertEqual(task.dueDate, TestDates.day(-2)) // (1 % 14) - 3 = -2
        XCTAssertFalse(task.isDone)
    }

    func testPriorityAndDueDateForOtherIds() {
        let t3 = TodoDto(userId: 1, id: 3, title: "x", completed: true).toTask(today: TestDates.today)
        XCTAssertEqual(t3.priority, .low)               // 3 % 3 = 0
        XCTAssertEqual(t3.dueDate, TestDates.day(0))
        XCTAssertTrue(t3.isDone)

        let t14 = TodoDto(userId: 1, id: 14, title: "x", completed: false).toTask(today: TestDates.today)
        XCTAssertEqual(t14.priority, .high)             // 14 % 3 = 2
        XCTAssertEqual(t14.dueDate, TestDates.day(-3))  // (14 % 14) - 3 = -3
    }

    func testDueDateFormat() {
        XCTAssertEqual(DueDateFormatter.string(from: TestDates.today), "29 Oct 2026")
    }
}
