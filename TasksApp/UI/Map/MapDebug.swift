#if DEBUG
import Foundation
import Shared

// DEBUG-only launch arguments for the Map tab, compiled out of Release. Same pattern as the splash freeze hook
// (`-splashFrozenAtMs`) and the voice hooks (`-fakeVoiceAudio`); pass them as `-name value` (flags have no value):
//
//   -mapFrozenNow            freeze "now" at Wed 4 Nov 2026 12:40 (shared FixedTimeProvider: clock + repository date) and use
//                            the in-memory fixture of the design references (5 tasks on 4 Nov; the demo route gives them the
//                            reference times and addresses; task 1 is marked done; tasks 2 and 3 get a voice note).
//                            Implies the fake voice audio / in-memory database of `-fakeVoiceAudio`.
//   -mapTab <tasks|map|stats>  initial tab (default tasks)
//   -mapDay <N>              select the day N days from "today" (0 = Today, 1 = Tomorrow = the Empty reference, -1 = Yesterday)
//   -mapScenario <name>      drive the screen into a reference state once the day has loaded:
//                              expanded   route sheet expanded
//                              pin        select stop 3 (task sheet)      pastpin  select stop 2 (overdue)
//                              move       select stop 3, then "Move pin"  longpress  long-press at a point east of stop 4
//                              offline    tiles unreachable (see -mapForceOffline)
//   -mapOsrmHost <url>       OSRM base URL. `https://invalid.invalid` = routing failure (dashed straight lines + chip);
//                            `http://10.255.255.1` never answers = the "Building route…" state for 8 s
//   -mapForceOffline         point the tile source at an invalid host: the style / tiles really fail to load
//
// Example: xcrun simctl launch booted com.example.tasks.ios -disableSplash -mapFrozenNow -mapTab map -mapScenario pin
enum MapDebug {
    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    private static func value(of name: String) -> String? {
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    static var isFrozen: Bool { arguments.contains("-mapFrozenNow") }
    static var forceOffline: Bool { arguments.contains("-mapForceOffline") || scenario == "offline" }
    static var initialTab: String? { value(of: "-mapTab") }
    static var day: Int? { value(of: "-mapDay").flatMap(Int.init) }
    static var scenario: String? { value(of: "-mapScenario") }

    /// Wed 4 Nov 2026 12:40.
    static func frozenClock() -> FixedTimeProvider {
        FixedTimeProvider(year: 2026, month: 11, day: 4, hour: 12, minute: 40)
    }

    static var routing: (any RoutingApi)? {
        value(of: "-mapOsrmHost").map { OsrmRoutingApi(baseUrl: $0) }
    }

    /// The tasks of the reference screens (all due 4 Nov 2026, none done: the demo route needs not-done tasks).
    static var fixtureTasks: [TaskItem] {
        let day = LocalDate(year: 2026, month: 11, day: 4)
        return [
            TaskItem(id: 1, title: "Pick up dry cleaning", notes: "", priority: .low, dueDate: day, isDone: false),
            TaskItem(id: 2, title: "Renew passport photos", notes: "Studio closes for lunch 13:00–14:00. 4 photos, 3.5 × 4.5 cm.",
                     priority: .high, dueDate: day, isDone: false),
            TaskItem(id: 3, title: "Dentist check-up", notes: "Bring the insurance card. Ask about the night guard.",
                     priority: .medium, dueDate: day, isDone: false),
            TaskItem(id: 4, title: "Pick up parcel", notes: "", priority: .low, dueDate: day, isDone: false),
            TaskItem(id: 5, title: "Sprint demo rehearsal", notes: "", priority: .high, dueDate: day, isDone: false),
        ]
    }

    /// After the data loaded: the done stop of the references and the two voice notes (dentist 0:18, passport 1:05).
    static func seed(_ repository: TaskRepository) {
        guard isFrozen else { return }
        if let task = repository.task(id: 1), !task.isDone { repository.toggle(id: 1) }
    }

    /// Replaces the tile host so the tile source genuinely fails (the same code path as no network).
    static func transform(styleJSON json: String) -> String {
        forceOffline ? json.replacingOccurrences(of: "tiles.openfreemap.org", with: "tiles.invalid") : json
    }

    /// Runs `-mapDay` / `-mapScenario` once the day's stops are loaded.
    @MainActor
    static func run(on model: MapViewModel) async {
        // Wait for the data: the repository loads in the background after launch.
        for _ in 0..<100 {
            if !model.state.isTasksLoading { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        try? await Task.sleep(nanoseconds: 400_000_000)
        if let offset = day, offset != 0 {
            for _ in 0..<abs(offset) { offset > 0 ? model.nextDay() : model.previousDay() }
            try? await Task.sleep(nanoseconds: 600_000_000)
        }
        func stop(order: Int) -> Int32? { model.state.stops.first { $0.order?.intValue == order }?.task.id }
        switch scenario {
        case "offline":
            model.reportTilesOffline(true)
        case "expanded":
            model.setSheetExpanded(true)
        case "pin":
            if let id = stop(order: 3) { model.selectTask(id) }
        case "pastpin":
            if let id = stop(order: 2) { model.selectTask(id) }
        case "move":
            if let id = stop(order: 3) {
                model.selectTask(id)
                try? await Task.sleep(nanoseconds: 700_000_000)
                model.startMove(id)
            }
        case "longpress":
            if let fourth = model.state.stops.first(where: { $0.order?.intValue == 4 }) {
                let point = fourth.place.point
                model.longPress(MapCoord(lat: point.lat + 0.0006, lng: point.lng + 0.0016))
            }
        default:
            break
        }
    }
}
#endif
