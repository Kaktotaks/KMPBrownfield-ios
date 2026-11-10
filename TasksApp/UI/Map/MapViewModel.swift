import Combine
import Foundation
import SwiftUI
import UIKit
import Shared

/// `MapUiState` is a Kotlin class (day, stops, route, selection, move, draft, flags); everything on the Map tab is
/// driven by it. Routing, geocoding, past / overdue / next stop and the map style come from shared.
typealias MapModel = SharedViewModel<Shared.MapViewModel, MapUiState>
typealias PlaceSearchModel = SharedViewModel<Shared.PlaceSearchViewModel, PlaceSearchUiState>

/// A row of the route sheet's full list (start row, then the stops).
struct MapStopRow: Identifiable, Equatable {
    enum Kind: Equatable { case start, stop }

    let id: String
    let kind: Kind
    let taskId: Int32?
    let order: Int?
    /// "09:30 · Done", "11:00 · Overdue", "Start", "No time".
    let timeLine: String
    let title: String
    /// Address, or "Left 09:18" on the start row.
    let address: String
    let priority: Priority?
    let isDone: Bool
    let isOverdue: Bool
    let isPast: Bool
    /// "12 min · 3.1 km" to the next stop; nil on the last row.
    let legText: String?
    let accessibilityLabel: String
}

struct MapNextStop: Equatable {
    let taskId: Int32
    let order: Int?
    let line: String
    let title: String
    let priority: Priority
    let accessibilityLabel: String
}

/// Content of the task sheet (pin selected).
struct MapTaskSheetModel: Equatable {
    let taskId: Int32
    let priority: Priority
    let whenText: String
    let title: String
    let address: String
    let notes: String?
    let isDone: Bool
    let isOverdue: Bool
    let isPast: Bool
}

enum MapChip: Equatable { case loading, failed, offline }

/// Swift ViewModel of the Map tab. Wraps the shared Kotlin `MapViewModel` (nested `SharedViewModel`, re-published),
/// maps its state to display values, and owns what is platform-only: the camera commands, the voice view models of
/// the two sheets, the editor sheet and the delete confirmation.
@MainActor
final class MapViewModel: ObservableObject {
    /// Latest one-shot camera command for the MapLibre view.
    @Published private(set) var cameraRequest: MapCameraRequest?
    /// Voice card of the selected task (`ExistingTask`), nil while nothing is selected.
    @Published private(set) var taskVoice: VoiceNoteCardViewModel?
    /// Voice card of the "new task here" sheet (`Draft`, bound to the map view model).
    @Published private(set) var newTaskVoice: VoiceNoteCardViewModel?
    @Published var editor: TaskEditorViewModel?
    @Published var isConfirmingDelete = false
    @Published var isPickingDay = false
    /// Set by the map view when it cannot reach the style / tiles (`MapLibre` failure or no network path).
    @Published private(set) var announcement: String?

    let shared: MapModel
    let app: AppDependencies
    private var forwarding: AnyCancellable?
    private var transitions: AnyCancellable?
    private var cameraToken = 0
    private var lastFitDay: Int?
    private var lastFitHadStops = false
    private var previousChip: MapChip?
    private var paletteCache: [Bool: MapRoutePalette] = [:]

    init(shared: MapModel, app: AppDependencies) {
        self.shared = shared
        self.app = app
        forwarding = shared.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        transitions = shared.$state.sink { [weak self] state in self?.stateChanged(state) }
    }

    // MARK: - State

    var state: MapUiState { shared.state }

    var dayKey: Int { Int(state.day.year) * 1000 + Int(state.day.dayOfYear) }
    var dayDate: Date { IosDates.shared.toDate(localDate: state.day) }
    var dayText: String { MapFormat.dayText(dayDate) }
    /// "Today" / "Tomorrow" / "Yesterday"; nil for other days (the date alone is the label).
    var relativeDay: String? { MapFormat.relativeDay(state.dayLabel) }
    var dayAccessibilityLabel: String {
        L10nMap.choose(day: [relativeDay, dayText].compactMap { $0 }.joined(separator: ", "))
    }
    var sheetHeading: String { MapFormat.sheetHeading(state.dayLabel, dayText: dayText) }

    var isEmptyDay: Bool {
        if case .empty = onEnum(of: state.route) { return true }
        return false
    }

    var isLoadingRoute: Bool {
        if case .loading = onEnum(of: state.route) { return true }
        return false
    }

    var summaryText: String {
        let count = Int(state.stopsCount)
        switch onEnum(of: state.route) {
        case .empty: return MapFormat.summary(stops: 0, kind: .empty)
        case .loading: return MapFormat.summary(stops: count, kind: .loading)
        case .fallback: return MapFormat.summary(stops: count, kind: .fallback)
        case .ready:
            if let minutes = state.totalDurationMinutes?.intValue, let meters = state.totalDistanceMeters?.doubleValue {
                return MapFormat.summary(stops: count, kind: .ready(minutes: minutes, meters: meters))
            }
            return MapFormat.summary(stops: count, kind: .unrouted)
        case .idle: return MapFormat.summary(stops: count, kind: count == 0 ? .empty : .unrouted)
        }
    }

    var chip: MapChip? { Self.chip(of: state) }

    private static func chip(of state: MapUiState) -> MapChip? {
        if state.tilesOffline { return .offline }
        if state.routeFailed { return .failed }
        if case .loading = onEnum(of: state.route) { return .loading }
        return nil
    }

    var chipText: String { Self.chipText(chip) }

    private static func chipText(_ chip: MapChip?) -> String {
        switch chip {
        case .offline: return MapFormat.tr("map_chip_offline")
        case .failed: return MapFormat.tr("map_chip_failed")
        case .loading: return MapFormat.tr("map_chip_loading")
        case nil: return ""
        }
    }

    var next: MapNextStop? {
        guard let stop = state.nextStop, let time = stop.task.time.map(MapFormat.clock) else { return nil }
        let line = MapFormat.next(time: time, minutesAway: state.nextStopMinutesAway?.intValue)
        let order = stop.order?.intValue
        let label = pinLabel(stop)
        return MapNextStop(
            taskId: stop.task.id,
            order: order,
            line: line,
            title: stop.task.title,
            priority: stop.task.priority,
            accessibilityLabel: MapFormat.tr("map_a11y_next_stop", label) + ". " + MapFormat.tr("map_a11y_show_pin")
        )
    }

    /// The full list: Start, then routed stops in time order, then pins without a time (no leg).
    var rows: [MapStopRow] {
        let stops = state.stops
        guard !stops.isEmpty else { return [] }
        var rows: [MapStopRow] = []
        let firstLeg = stops.first?.legFromPrevious
        rows.append(MapStopRow(
            id: "start",
            kind: .start,
            taskId: nil,
            order: nil,
            timeLine: MapFormat.tr("map_start"),
            title: MapFormat.tr("map_start_address"),
            address: MapFormat.startLine(leaveBy: state.leaveBy.map(MapFormat.clock), startIsPast: state.startIsPast) ?? "",
            priority: nil,
            isDone: false,
            isOverdue: false,
            isPast: false,
            legText: firstLeg.map { MapFormat.leg(durationSeconds: $0.durationSeconds?.doubleValue, meters: $0.distanceMeters) },
            accessibilityLabel: MapFormat.tr("map_start_a11y")
        ))
        for (index, stop) in stops.enumerated() {
            let nextLeg = index + 1 < stops.count ? stops[index + 1].legFromPrevious : nil
            let time = stop.task.time.map(MapFormat.clock)
            rows.append(MapStopRow(
                id: "task-\(stop.task.id)",
                kind: .stop,
                taskId: stop.task.id,
                order: stop.order?.intValue,
                timeLine: MapFormat.stopTimeLine(time: time, isDone: stop.isDone, isOverdue: stop.isOverdue && !stop.isDone),
                title: stop.task.title,
                address: stop.place.address,
                priority: stop.task.priority,
                isDone: stop.isDone,
                isOverdue: stop.isOverdue && !stop.isDone,
                isPast: stop.isPast,
                legText: nextLeg.map { MapFormat.leg(durationSeconds: $0.durationSeconds?.doubleValue, meters: $0.distanceMeters) },
                accessibilityLabel: pinLabel(stop) + ". " + MapFormat.tr("map_a11y_show_pin")
            ))
        }
        return rows
    }

    private func pinLabel(_ stop: MapStop) -> String {
        MapFormat.pinLabel(
            time: stop.task.time.map(MapFormat.clock),
            title: stop.task.title,
            priority: stop.task.priority.displayName,
            isDone: stop.isDone,
            isOverdue: stop.isOverdue && !stop.isDone,
            isPast: stop.isPast,
            order: stop.order?.intValue
        )
    }

    // MARK: - Map render state

    func renderState(dark: Bool, layout: MapLayout) -> MapRenderState {
        let state = self.state
        let moving = state.move
        var pins: [MapPinModel] = []
        for stop in state.stops where stop.task.id != moving?.taskId {
            pins.append(pin(stop, selected: stop.task.id == state.selectedTaskId?.int32Value, lifted: false))
        }
        var moveModel: MapMoveModel?
        if let moving, let stop = state.stops.first(where: { $0.task.id == moving.taskId }) {
            moveModel = MapMoveModel(original: MapCoord(moving.originalPlace.point), pin: pin(stop, selected: false, lifted: true))
        }
        return MapRenderState(
            dayKey: dayKey,
            start: MapCoord(state.start.point),
            startAccessibilityLabel: MapFormat.tr("map_start_a11y"),
            pins: pins,
            route: routeModel(),
            palette: palette(dark: dark),
            move: moveModel,
            draft: state.newTaskDraft.map {
                MapDraftModel(coord: MapCoord($0.point), accessibilityLabel: MapFormat.tr("map_a11y_dropped_pin", $0.address ?? MapFormat.tr("map_locating")))
            },
            tilesOffline: state.tilesOffline,
            layout: layout
        )
    }

    private func pin(_ stop: MapStop, selected: Bool, lifted: Bool) -> MapPinModel {
        MapPinModel(
            id: stop.task.id,
            coord: MapCoord(stop.place.point),
            order: stop.order?.intValue,
            time: stop.task.time.map(MapFormat.clock),
            title: stop.task.title,
            priority: stop.task.priority,
            isDone: stop.isDone,
            isOverdue: stop.isOverdue && !stop.isDone,
            isPast: stop.isPast,
            isSelected: selected,
            isLifted: lifted,
            accessibilityLabel: pinLabel(stop)
        )
    }

    private func palette(dark: Bool) -> MapRoutePalette {
        if let cached = paletteCache[dark] { return cached }
        let made = MapRoutePalette(MapStyle.shared.routePalette(dark: dark))
        paletteCache[dark] = made
        return made
    }

    private func routeModel() -> MapRouteModel {
        let state = self.state
        let routed = state.stops.filter { $0.order != nil }
        switch onEnum(of: state.route) {
        case .idle, .empty:
            return .none
        case .loading:
            let points = [MapCoord(state.start.point)] + routed.map { MapCoord($0.place.point) }
            return MapRouteModel(kind: .pending, legs: [], pendingPoints: points)
        case .ready(let ready):
            return MapRouteModel(kind: .ready, legs: legs(of: ready.route, routed: routed), pendingPoints: [])
        case .fallback(let fallback):
            return MapRouteModel(kind: .fallback, legs: legs(of: fallback.route, routed: routed), pendingPoints: [])
        }
    }

    private func legs(of route: Route, routed: [MapStop]) -> [MapLegModel] {
        // Taken from the route, not from the stops: while an edit is being re-routed the stops' legs are hidden but the
        // previous route stays on screen.
        let past = routed.map(\.legIsPast)
        return route.legs.enumerated().map { index, leg in
            MapLegModel(coords: leg.geometry.map { MapCoord($0) }, isPast: past.count == route.legs.count ? past[index] : false)
        }
    }

    /// Content of the task sheet, nil while nothing is selected.
    var taskSheet: MapTaskSheetModel? {
        guard let stop = state.selectedStop else { return nil }
        let task = stop.task
        let time = task.time.map(MapFormat.clock)
        let overdue = stop.isOverdue && !stop.isDone
        var when: String
        if let time {
            if overdue {
                when = MapFormat.stopTimeLine(time: time, isDone: false, isOverdue: true)
            } else if stop.isDone {
                when = MapFormat.stopTimeLine(time: time, isDone: true, isOverdue: false)
            } else if state.dayLabel == .today {
                when = MapFormat.tr("map_when_today", time)
            } else {
                let day = MapFormat.relativeDay(state.dayLabel) ?? dayText
                when = MapFormat.tr("map_when_other", day, time)
            }
        } else {
            when = MapFormat.tr("map_no_time")
        }
        if let order = stop.order?.intValue {
            when = MapFormat.tr("map_when_stop", when, MapFormat.tr("map_stop_of", order, Int(state.routedStopsCount)))
        }
        let notes = task.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return MapTaskSheetModel(
            taskId: task.id,
            priority: task.priority,
            whenText: when,
            title: task.title,
            address: stop.place.address,
            notes: notes.isEmpty ? nil : notes,
            isDone: stop.isDone,
            isOverdue: overdue,
            isPast: stop.isPast
        )
    }

    var moveAddress: String {
        guard let move = state.move else { return "" }
        if let address = move.candidateAddress { return address }
        return MapFormat.tr("map_locating")
    }

    var draft: NewTaskDraft? { state.newTaskDraft }

    var isTaskSheetPresented: Bool {
        state.selectedStop != nil && state.move == nil && state.newTaskDraft == nil
    }

    // MARK: - Transitions (camera, sheets' view models)

    private var observedSelection: Int32?
    private var observedDraft = false
    private var observedMove = false

    private func stateChanged(_ state: MapUiState) {
        let selected = state.selectedTaskId?.int32Value
        if selected != observedSelection {
            observedSelection = selected
            if let selected {
                taskVoice = app.makeVoiceNoteViewModel(target: VoiceNoteTarget.ExistingTask(taskId: selected))
                if let stop = state.selectedStop, state.move == nil {
                    request(.focusPin(MapCoord(stop.place.point)))
                }
            } else {
                taskVoice = nil
            }
        }

        let hasDraft = state.newTaskDraft != nil
        if hasDraft != observedDraft {
            observedDraft = hasDraft
            if let draft = state.newTaskDraft {
                let voice = app.makeVoiceNoteViewModel(target: VoiceNoteTarget.Draft(initial: nil))
                voice.bind(to: shared.viewModel)
                newTaskVoice = voice
                request(.focusDraft(MapCoord(draft.point)))
            } else {
                newTaskVoice = nil
            }
        }

        let isMoving = state.move != nil
        if isMoving != observedMove {
            observedMove = isMoving
            if let move = state.move {
                request(.focusMove(MapCoord(move.originalPlace.point)))
            } else if let stop = state.selectedStop {
                request(.focusPin(MapCoord(stop.place.point)))
            }
        }

        // Fit the camera once per day when its pins arrive (and again when the first pin of an empty day appears).
        if !state.isTasksLoading {
            let key = Int(state.day.year) * 1000 + Int(state.day.dayOfYear)
            let hasStops = state.stopsCount > 0
            if lastFitDay != key || (hasStops && !lastFitHadStops && state.newTaskDraft == nil) {
                lastFitDay = key
                lastFitHadStops = hasStops
                request(hasStops ? .fit : .centerStart(MapCoord(state.start.point)))
            }
        }

        let chip = Self.chip(of: state)
        if chip != previousChip {
            previousChip = chip
            if chip != nil {
                let text = Self.chipText(chip)
                announcement = text
                UIAccessibility.post(notification: .announcement, argument: NSAttributedString(
                    string: text,
                    attributes: [.accessibilitySpeechQueueAnnouncement: true]
                ))
            }
        }
    }

    func request(_ kind: MapCameraRequest.Kind) {
        cameraToken += 1
        cameraRequest = MapCameraRequest(id: cameraToken, kind: kind)
    }

    // MARK: - Intents

    func previousDay() { shared.send { $0.previousDay() } }
    func nextDay() { shared.send { $0.nextDay() } }

    func selectDay(_ date: Date) {
        shared.send { $0.selectDay(date: IosDates.shared.toLocalDate(date: date)) }
    }

    func setSheetExpanded(_ expanded: Bool) {
        guard state.sheetExpanded != expanded else { return }
        shared.send { $0.setSheetExpanded(expanded: expanded) }
    }

    func recenter() {
        request(state.stopsCount > 0 ? .fit : .centerStart(MapCoord(state.start.point)))
    }

    func selectTask(_ id: Int32) {
        shared.send { $0.selectTask(id: id) }
        // Selecting an already selected task changes no state: still bring the pin into view.
        if observedSelection == id, let stop = state.selectedStop {
            request(.focusPin(MapCoord(stop.place.point)))
        }
    }

    func clearSelection() { shared.send { $0.clearSelection() } }

    func longPress(_ coord: MapCoord) {
        shared.send { $0.longPress(point: coord.geoPoint) }
    }

    func cancelNewTask() { shared.send { $0.cancelNewTask() } }

    /// Returns true when the task was saved (the draft is closed by shared).
    func saveNewTask(title: String, notes: String, priority: Priority, time: Date?) -> Bool {
        let voice = newTaskVoice
        if let voice, case .recording = voice.card { voice.stop() }
        let note = voice?.currentNote
        shared.viewModel.onDraftVoiceNoteChange(note: note)
        let localTime = time.map { IosDates.shared.toLocalTime(date: $0) }
        return shared.send { $0.saveNewTask(title: title, notes: notes, priority: priority, time: localTime, voiceNote: note) }
    }

    func validateNewTask(title: String, notes: String) -> [ValidationError] {
        shared.viewModel.validateNewTask(title: title, notes: notes)
    }

    func startMove(_ id: Int32) {
        taskVoice?.pausePlayback()
        shared.send { $0.startMove(id: id) }
    }

    func updateMoveCandidate(_ coord: MapCoord) {
        guard state.move != nil else { return }
        shared.send { $0.updateMoveCandidate(point: coord.geoPoint) }
    }

    func confirmMove() { shared.send { $0.confirmMove() } }
    func cancelMove() { shared.send { $0.cancelMove() } }

    func markDone(_ id: Int32) { shared.send { $0.markDone(id: id) } }

    func requestDelete() { isConfirmingDelete = true }

    func confirmDelete() {
        guard let id = state.selectedTaskId?.int32Value else { return }
        shared.send { $0.delete(id: id) }
    }

    func showEditor(for id: Int32) {
        taskVoice?.pausePlayback()
        editor = app.makeTaskEditorViewModel(taskId: id)
    }

    func retry() { shared.send { $0.retry() } }

    /// Called by the map view when the style / tiles fail to load or load again.
    func reportTilesOffline(_ offline: Bool) {
        guard state.tilesOffline != offline else { return }
        shared.send { $0.reportTilesOffline(offline: offline) }
    }

    /// Accessibility alternative to long-press: a task at the centre of the visible map.
    func addTaskHere(at coord: MapCoord) { longPress(coord) }
}

/// Small localized builders that take an argument.
enum L10nMap {
    static func choose(day: String) -> String { MapFormat.tr("map_a11y_choose_day", day) }
}
