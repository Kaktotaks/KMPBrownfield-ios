import XCTest
import Shared

/// Smoke tests: the Kotlin framework links into the app/test bundle and Swift interop works.
/// The domain rules themselves are unit-tested once, in shared/src/commonTest.
final class SharedInteropTests: XCTestCase {
    func testTodoMapperMapsIdOne() {
        let todayDate = Date()
        let today = IosDates.shared.toLocalDate(date: todayDate)

        let task = TodoMapper.shared.map(id: 1, title: "Buy milk", completed: false, today: today)

        XCTAssertEqual(task.id, 1)
        XCTAssertEqual(task.title, "Buy milk")
        XCTAssertEqual(task.notes, "")
        XCTAssertEqual(task.priority, Priority.medium) // [low, medium, high][1 % 3]
        XCTAssertFalse(task.isDone)
        // dueDate = today + ((1 % 14) - 3) = today - 2 days
        let expectedDate = Calendar.current.date(byAdding: .day, value: -2, to: todayDate)!
        XCTAssertEqual(task.dueDate, IosDates.shared.toLocalDate(date: expectedDate))
        XCTAssertTrue(task.isOverdue(today: today))
    }

    func testIosDatesRoundTripIsStartOfDay() {
        let now = Date()
        let localDate = IosDates.shared.toLocalDate(date: now)
        let back = IosDates.shared.toDate(localDate: localDate)
        XCTAssertEqual(back, Calendar.current.startOfDay(for: now))
    }

    func testDateFormattingOfKnownDate() {
        let components = DateComponents(year: 2026, month: 10, day: 29)
        let date = Calendar.current.date(from: components)!
        let localDate = IosDates.shared.toLocalDate(date: date)
        XCTAssertEqual(DateFormatting.shared.format(date: localDate), "29 Oct 2026")
    }
}
