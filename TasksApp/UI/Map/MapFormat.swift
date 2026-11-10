import Foundation
import Shared

/// Text of the Map screens. Shared exposes numbers, enums and times only; the words, plurals and number formats
/// are native (`Map.xcstrings`, en + uk). Pure functions, so they are unit-tested without Kotlin state.
enum MapFormat {
    /// Number / date formatting follows the language the app UI is in, not the device region
    /// (an English-region device running the Ukrainian UI still gets "14,2 км").
    static var locale: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
    }

    static func tr(_ key: String) -> String {
        NSLocalizedString(key, tableName: "Map", comment: "")
    }

    static func tr(_ key: String, _ args: CVarArg...) -> String {
        String(format: NSLocalizedString(key, tableName: "Map", comment: ""), locale: locale, arguments: args)
    }

    static func plural(_ key: String, _ count: Int) -> String {
        String.localizedStringWithFormat(NSLocalizedString(key, tableName: "Map", comment: ""), count)
    }

    // MARK: - Times and numbers

    /// "09:30": 24-hour on both platforms.
    static func clock(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    static func clock(_ time: Kotlinx_datetimeLocalTime) -> String {
        clock(hour: Int(time.hour), minute: Int(time.minute))
    }

    /// 62 → "1 h 02 min", 42 → "42 min".
    static func duration(minutes: Int) -> String {
        if minutes >= 60 {
            return tr("map_duration_h_min", minutes / 60, minutes % 60)
        }
        return tr("map_duration_min", max(minutes, 0))
    }

    /// 14 200 m → "14.2 km" (locale decimal separator).
    static func distance(meters: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return tr("map_distance_km", formatter.string(from: NSNumber(value: meters / 1000)) ?? "")
    }

    /// "12 min · 3.1 km"; routes without durations (straight-line fallback) show the distance only.
    static func leg(durationSeconds: Double?, meters: Double) -> String {
        guard let durationSeconds else { return distance(meters: meters) }
        let minutes = max(1, Int((durationSeconds / 60).rounded()))
        return tr("map_leg", duration(minutes: minutes), distance(meters: meters))
    }

    // MARK: - Day

    /// "Wed 4 Nov" / "ср, 4 лист." (pattern from the catalog).
    static func dayText(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = tr("map_day_format")
        return formatter.string(from: date)
    }

    static func relativeDay(_ label: DayLabel) -> String? {
        switch label {
        case .today: return tr("map_today")
        case .tomorrow: return tr("map_tomorrow")
        case .yesterday: return tr("map_yesterday")
        case .none: return nil
        }
    }

    /// "Today’s route" / "Tomorrow" / "Mon 9 Nov".
    static func sheetHeading(_ label: DayLabel, dayText: String) -> String {
        switch label {
        case .today: return tr("map_sheet_today")
        case .tomorrow: return tr("map_sheet_tomorrow")
        case .yesterday: return tr("map_sheet_yesterday")
        case .none: return dayText
        }
    }

    // MARK: - Summary

    enum SummaryKind: Equatable {
        case empty
        case loading
        case fallback
        case ready(minutes: Int, meters: Double)
        /// Only pins without a time: nothing is routed, so no totals.
        case unrouted
    }

    static func summary(stops: Int, kind: SummaryKind) -> String {
        let count = plural("map_stops_count", stops)
        switch kind {
        case .empty: return tr("map_summary_empty")
        case .loading: return tr("map_summary_loading", count)
        case .fallback: return tr("map_summary_fallback", count)
        case .unrouted: return count
        case .ready(let minutes, let meters):
            return tr("map_summary_ready", count, duration(minutes: minutes), distance(meters: meters))
        }
    }

    /// "Next · 13:15 · 14 min away".
    static func next(time: String, minutesAway: Int?) -> String {
        guard let minutesAway else { return tr("map_next_no_eta", time) }
        return tr("map_next", time, duration(minutes: minutesAway))
    }

    // MARK: - Stop lines

    /// "09:30 · Done" / "11:00 · Overdue" / "13:15".
    static func stopTimeLine(time: String?, isDone: Bool, isOverdue: Bool) -> String {
        guard let time else { return tr("map_no_time") }
        if isOverdue { return tr("map_stop_overdue", time) }
        if isDone { return tr("map_stop_done", time) }
        return time
    }

    /// Start row address line: "Leave by 09:18" (still ahead) or "Left 09:18".
    static func startLine(leaveBy: String?, startIsPast: Bool) -> String? {
        guard let leaveBy else { return nil }
        return tr(startIsPast ? "map_left" : "map_leave_by", leaveBy)
    }

    // MARK: - Accessibility

    /// "09:30, Pick up dry cleaning, Low priority, done, stop 1" (same wording as the handoff `a11y`).
    static func pinLabel(time: String?, title: String, priority: String, isDone: Bool, isOverdue: Bool, isPast: Bool, order: Int?) -> String {
        var parts: [String] = []
        parts.append(time ?? tr("map_a11y_unscheduled"))
        parts.append(title)
        parts.append(tr("map_a11y_priority", priority))
        if isDone { parts.append(tr("map_a11y_done")) }
        if isOverdue { parts.append(tr("map_a11y_overdue")) }
        if isPast && !isDone && !isOverdue { parts.append(tr("map_a11y_past")) }
        if let order { parts.append(tr("map_a11y_stop", order)) }
        return parts.joined(separator: ", ")
    }
}
