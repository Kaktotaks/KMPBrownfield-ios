import Foundation
import Shared

// Thin Swift adapters over the Kotlin `Shared` framework (SPM binary XCFramework, see README).
// The Swift Domain layer was removed: TaskItem, Priority, TaskValidator, TaskFilter,
// StatsCalculator, DateFormatting, TodoMapper, DateProvider all come from Kotlin now.

/// kotlinx-datetime is not exported from the framework, so Kotlin's `LocalDate`
/// is visible to Swift under its generated (module-prefixed) name.
/// If the generated name ever differs (e.g. after changing `export(...)` in
/// shared/build.gradle.kts), this typealias is the ONE place to fix.
typealias LocalDate = Kotlinx_datetimeLocalDate

/// Foundation also declares `SortOrder` (iOS 15+), so the bare name would be ambiguous
/// between Foundation and Shared. A module-level alias makes the Kotlin one win in this app.
typealias SortOrder = Shared.SortOrder

extension Date {
    /// Calendar day of this date in the current calendar/time zone.
    var asLocalDate: LocalDate {
        IosDates.shared.toLocalDate(date: self)
    }
}

extension Kotlinx_datetimeLocalDate {
    /// Start of this day in the current calendar/time zone (for DatePicker etc.).
    var asDate: Date {
        IosDates.shared.toDate(localDate: self)
    }
}
