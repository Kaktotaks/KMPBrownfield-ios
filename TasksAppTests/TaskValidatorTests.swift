import XCTest
@testable import TasksApp

final class TaskValidatorTests: XCTestCase {
    private let validator = TaskValidator(clock: FixedClock(today: TestDates.today))

    func testValidInputHasNoErrors() {
        let errors = validator.validate(title: "Buy milk", notes: "", dueDate: TestDates.today)
        XCTAssertEqual(errors, [])
    }

    func testTitleTooShortAfterTrimming() {
        let errors = validator.validate(title: "  ab  ", notes: "", dueDate: TestDates.today)
        XCTAssertEqual(errors, [.titleTooShort])
    }

    func testTitleOfThreeCharactersIsValid() {
        XCTAssertEqual(validator.validate(title: "abc", notes: "", dueDate: TestDates.today), [])
    }

    func testTitleTooLong() {
        let title = String(repeating: "a", count: 61)
        XCTAssertEqual(validator.validate(title: title, notes: "", dueDate: TestDates.today), [.titleTooLong])
    }

    func testTitleOfSixtyCharactersIsValid() {
        let title = String(repeating: "a", count: 60)
        XCTAssertEqual(validator.validate(title: title, notes: "", dueDate: TestDates.today), [])
    }

    func testNotesTooLong() {
        let notes = String(repeating: "n", count: 501)
        XCTAssertEqual(validator.validate(title: "Valid", notes: notes, dueDate: TestDates.today), [.notesTooLong])
    }

    func testPastDueDateWhenCreating() {
        let errors = validator.validate(title: "Valid", notes: "", dueDate: TestDates.day(-1))
        XCTAssertEqual(errors, [.dueDateInPast])
    }

    func testUnchangedOverdueDateAllowedWhenEditing() {
        let original = TestDates.day(-5)
        let errors = validator.validate(title: "Valid", notes: "", dueDate: original, originalDueDate: original)
        XCTAssertEqual(errors, [])
    }

    func testChangedPastDateRejectedWhenEditing() {
        let errors = validator.validate(
            title: "Valid", notes: "", dueDate: TestDates.day(-2), originalDueDate: TestDates.day(-5)
        )
        XCTAssertEqual(errors, [.dueDateInPast])
    }

    func testErrorsAreReportedInOrder() {
        let notes = String(repeating: "n", count: 501)
        let errors = validator.validate(title: "a", notes: notes, dueDate: TestDates.day(-1))
        XCTAssertEqual(errors, [.titleTooShort, .notesTooLong, .dueDateInPast])
    }

    func testErrorMessages() {
        XCTAssertEqual(ValidationError.titleTooShort.message, "Title must be at least 3 characters.")
        XCTAssertEqual(ValidationError.titleTooLong.message, "Title must be at most 60 characters.")
        XCTAssertEqual(ValidationError.notesTooLong.message, "Notes must be at most 500 characters.")
        XCTAssertEqual(ValidationError.dueDateInPast.message, "Due date can't be in the past.")
    }
}
