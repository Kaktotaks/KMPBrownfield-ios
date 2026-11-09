import CoreLocation
import XCTest
import Shared
@testable import TasksApp

/// Map tab on iOS: the app only formats, maps and draws. Routing, geocoding, past / overdue / next stop and the style are
/// tested once in shared; here: text formats (en), the Swift mapping of `MapUiState`, geometry helpers, the SVG parser.
final class MapFormatTests: XCTestCase {
    func testClockIsTwentyFourHourWithLeadingZero() {
        XCTAssertEqual(MapFormat.clock(hour: 9, minute: 5), "09:05")
        XCTAssertEqual(MapFormat.clock(hour: 18, minute: 0), "18:00")
    }

    func testDurationUsesHoursOnlyFromOneHour() {
        XCTAssertEqual(MapFormat.duration(minutes: 42), "42 min")
        XCTAssertEqual(MapFormat.duration(minutes: 62), "1 h 02 min")
    }

    func testDistanceHasOneDecimalInKm() {
        XCTAssertEqual(MapFormat.distance(meters: 14_200), "14.2 km")
        XCTAssertEqual(MapFormat.distance(meters: 800), "0.8 km")
    }

    func testLegShowsDistanceOnlyWithoutDurations() {
        XCTAssertEqual(MapFormat.leg(durationSeconds: 12 * 60, meters: 3_100), "12 min · 3.1 km")
        XCTAssertEqual(MapFormat.leg(durationSeconds: nil, meters: 3_100), "3.1 km")
    }

    func testSummaryStatesAndPlurals() {
        XCTAssertEqual(MapFormat.summary(stops: 5, kind: .ready(minutes: 62, meters: 14_200)), "5 stops · 1 h 02 min · 14.2 km")
        XCTAssertEqual(MapFormat.summary(stops: 5, kind: .loading), "5 stops · Building route…")
        XCTAssertEqual(MapFormat.summary(stops: 1, kind: .fallback), "1 stop · Travel times unavailable")
        XCTAssertEqual(MapFormat.summary(stops: 0, kind: .empty), "Nothing planned with a place")
    }

    func testNextAndStopLines() {
        XCTAssertEqual(MapFormat.next(time: "13:15", minutesAway: 14), "Next · 13:15 · 14 min away")
        XCTAssertEqual(MapFormat.next(time: "13:15", minutesAway: nil), "Next · 13:15")
        XCTAssertEqual(MapFormat.stopTimeLine(time: "09:30", isDone: true, isOverdue: false), "09:30 · Done")
        XCTAssertEqual(MapFormat.stopTimeLine(time: "11:00", isDone: false, isOverdue: true), "11:00 · Overdue")
        XCTAssertEqual(MapFormat.stopTimeLine(time: "13:15", isDone: false, isOverdue: false), "13:15")
        XCTAssertEqual(MapFormat.stopTimeLine(time: nil, isDone: false, isOverdue: false), "No time")
    }

    func testStartLine() {
        XCTAssertEqual(MapFormat.startLine(leaveBy: "09:18", startIsPast: false), "Leave by 09:18")
        XCTAssertEqual(MapFormat.startLine(leaveBy: "09:18", startIsPast: true), "Left 09:18")
        XCTAssertNil(MapFormat.startLine(leaveBy: nil, startIsPast: true))
    }

    func testPinLabelFollowsTheHandoffWording() {
        XCTAssertEqual(
            MapFormat.pinLabel(time: "09:30", title: "Pick up dry cleaning", priority: "Low", isDone: true, isOverdue: false, isPast: true, order: 1),
            "09:30, Pick up dry cleaning, Low priority, done, stop 1"
        )
        XCTAssertEqual(
            MapFormat.pinLabel(time: "11:00", title: "Renew passport photos", priority: "High", isDone: false, isOverdue: true, isPast: true, order: 2),
            "11:00, Renew passport photos, High priority, overdue, stop 2"
        )
        XCTAssertEqual(
            MapFormat.pinLabel(time: nil, title: "Buy milk", priority: "Low", isDone: false, isOverdue: false, isPast: false, order: nil),
            "no time, Buy milk, Low priority"
        )
    }

    func testDayText() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 12))!
        XCTAssertEqual(MapFormat.dayText(date, timeZone: calendar.timeZone), "Wed 4 Nov")
    }
}

@MainActor
final class MapGeometryTests: XCTestCase {
    private func leg(_ coords: [(Double, Double)], past: Bool = false) -> MapLegModel {
        MapLegModel(coords: coords.map { MapCoord(lat: $0.0, lng: $0.1) }, isPast: past)
    }

    func testTrimmedRouteSplitsPastAndLiveAndCutsAtProgress() {
        let past = leg([(48.0, 35.0), (48.0, 35.01)], past: true)
        let live = leg([(48.0, 35.01), (48.0, 35.02)])
        let full = RouteRenderer.trimmed([past, live], progress: 1)
        XCTAssertEqual(full.past.count, 1)
        XCTAssertEqual(full.live.count, 1)

        let most = RouteRenderer.trimmed([past, live], progress: 0.75)
        XCTAssertEqual(most.past[0].count, 2, "the first leg is complete")
        XCTAssertEqual(most.live.count, 1, "the second leg is cut")
        XCTAssertEqual(most.live[0].last!.longitude, 35.015, accuracy: 0.0005)

        let quarter = RouteRenderer.trimmed([past, live], progress: 0.25)
        XCTAssertEqual(quarter.past[0].last!.longitude, 35.005, accuracy: 0.0005)
        XCTAssertTrue(RouteRenderer.trimmed([past, live], progress: 0).past.isEmpty)
    }

    func testPrefixInterpolatesInsideASegment() {
        let line = [CLLocationCoordinate2D(latitude: 0, longitude: 0), CLLocationCoordinate2D(latitude: 0, longitude: 0.01)]
        let length = RouteRenderer.length(line)
        let cut = RouteRenderer.prefix(of: line, length: length / 2)
        XCTAssertEqual(cut.count, 2)
        XCTAssertEqual(cut[1].longitude, 0.005, accuracy: 1e-6)
    }

    func testSVGPathParsesArcsAndRelativeCommands() {
        // The pin icon: a relative curve path plus a full circle made of two arcs.
        let bounds = SVGPath.path("M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z").boundingRect
        XCTAssertEqual(bounds.minX, 5.5, accuracy: 0.2)
        XCTAssertEqual(bounds.maxX, 18.5, accuracy: 0.2)
        XCTAssertEqual(bounds.maxY, 21, accuracy: 0.2)

        let circle = SVGPath.path("M9.6 10a2.4 2.4 0 1 0 4.8 0a2.4 2.4 0 1 0 -4.8 0").boundingRect
        XCTAssertEqual(circle.midX, 12, accuracy: 0.05)
        XCTAssertEqual(circle.width, 4.8, accuracy: 0.1)
        XCTAssertEqual(circle.height, 4.8, accuracy: 0.1)
    }

    func testEveryMapIconHasAPath() {
        for icon in [MapIcon.pin, .pinAdd, .flame, .star, .leaf, .check, .home, .car, .locate, .move,
                     .chevronLeft, .chevronRight, .clock, .pencil, .trash, .close, .alert, .wifiOff] {
            XCTAssertFalse(MapIconShape(icon: icon).path(in: CGRect(x: 0, y: 0, width: 24, height: 24)).isEmpty, "\(icon)")
        }
    }
}

/// A routing service that always fails, so the shared view model falls back to straight lines without any network.
private final class FailingRouting: NSObject, RoutingApi {
    struct Failure: Error {}
    // SKIE hides the ObjC completion-handler requirement behind a `__` name (the `async` overload is for callers).
    func __route(points: [GeoPoint], completionHandler: @escaping @Sendable (Route?, (any Error)?) -> Void) {
        completionHandler(nil, Failure())
    }
}

/// Swift mapping of the shared `MapViewModel` with the frozen clock Wed 4 Nov 2026 12:40.
@MainActor
final class MapViewModelTests: XCTestCase {
    private let clock = FixedTimeProvider(year: 2026, month: 11, day: 4, hour: 12, minute: 40)

    private func makeModel() async throws -> TasksApp.MapViewModel {
        let day = LocalDate(year: 2026, month: 11, day: 4)
        let tasks = (1...5).map {
            TaskItem(id: Int32($0), title: "Task \($0)", notes: "", priority: $0 % 2 == 0 ? .high : .low, dueDate: day, isDone: false)
        }
        let repository = makeTestRepository(api: FakeTaskApi(result: .success(tasks)), dateProvider: clock)
        let app = AppDependencies(repository: repository, dateProvider: clock, routing: FailingRouting())
        await app.loadIfNeeded()
        let model = app.makeMapViewModel()
        for _ in 0..<80 {
            if !model.state.isTasksLoading, model.state.stopsCount == 5, model.state.routeFailed { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        return model
    }

    func testDemoRouteStopsRowsAndPastStates() async throws {
        let model = try await makeModel()
        XCTAssertEqual(model.state.stopsCount, 5)
        XCTAssertEqual(model.dayText, "Wed 4 Nov")
        XCTAssertEqual(model.relativeDay, "Today")
        XCTAssertEqual(model.sheetHeading, "Today’s route")

        // Start row + 5 stops; the demo times 09:30 / 11:00 are before 12:40.
        let rows = model.rows
        XCTAssertEqual(rows.count, 6)
        XCTAssertEqual(rows.first?.kind, .start)
        XCTAssertEqual(rows[1].timeLine, "09:30 · Overdue", "past and not done")
        XCTAssertTrue(rows[1].isPast)
        XCTAssertTrue(rows[2].isOverdue)
        XCTAssertEqual(rows[2].timeLine, "11:00 · Overdue")
        XCTAssertFalse(rows[3].isPast)
        XCTAssertEqual(model.next?.order, 3)
    }

    /// `uiState` reaches Swift through the async bridge: wait for the change (a `send` re-reads the flow's value, which for
    /// derived `stateIn` flows can lag by one emission).
    private func until(_ condition: () -> Bool) async {
        await waitUntil(timeout: 3, condition)
    }

    func testRoutingFailureShowsFallbackWithStraightLinesAndChip() async throws {
        let model = try await makeModel()
        XCTAssertEqual(model.chip, .failed)
        XCTAssertEqual(model.chipText, "Route unavailable — showing straight lines")
        XCTAssertEqual(model.summaryText, "5 stops · Travel times unavailable")
        let render = model.renderState(dark: false, layout: MapLayout())
        XCTAssertEqual(render.route.kind, .fallback)
        XCTAssertEqual(render.route.legs.count, 5)
        XCTAssertEqual(render.pins.count, 5)
        XCTAssertEqual(render.pins.first?.order, 1)
    }

    func testSelectionOpensTheTaskSheetAndRequestsTheCamera() async throws {
        let model = try await makeModel()
        let third = try XCTUnwrap(model.state.stops.first { $0.order?.intValue == 3 }?.task.id)
        model.selectTask(third)
        await until { model.isTaskSheetPresented }
        XCTAssertTrue(model.isTaskSheetPresented)
        let sheet = try XCTUnwrap(model.taskSheet)
        XCTAssertEqual(sheet.whenText, "Today, 13:15 · Stop 3 of 5")
        XCTAssertNotNil(model.taskVoice)
        if case .focusPin = model.cameraRequest?.kind {} else { XCTFail("expected a focus camera request") }
        model.clearSelection()
        await until { !model.isTaskSheetPresented }
        XCTAssertFalse(model.isTaskSheetPresented)
        XCTAssertNil(model.taskVoice)
    }

    func testLongPressCreatesADraftAndMoveHidesTheTaskSheet() async throws {
        let model = try await makeModel()
        model.longPress(MapCoord(lat: 48.46, lng: 35.04))
        await until { model.draft != nil }
        XCTAssertNotNil(model.draft)
        XCTAssertNotNil(model.newTaskVoice)
        model.cancelNewTask()
        await until { model.draft == nil }
        XCTAssertNil(model.draft)

        let id = try XCTUnwrap(model.state.stops.first?.task.id)
        model.selectTask(id)
        model.startMove(id)
        await until { model.state.move != nil }
        XCTAssertNotNil(model.state.move)
        XCTAssertFalse(model.isTaskSheetPresented, "the task sheet is hidden while moving")
        let render = model.renderState(dark: false, layout: MapLayout())
        XCTAssertNotNil(render.move)
        XCTAssertFalse(render.pins.contains { $0.id == id }, "the moved pin is drawn by the fixed centre pin")
        model.cancelMove()
    }
}
