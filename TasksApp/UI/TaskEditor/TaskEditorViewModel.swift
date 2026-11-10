import Combine
import Foundation
import SwiftUI
import Shared

/// Swift ViewModel of the New / Edit task sheet. Wraps the shared Kotlin `TaskEditorViewModel`
/// (form state + live validation + save). Created by the presenting ViewModel when the sheet
/// opens (`sheet(item:)`), so there is exactly one Kotlin ViewModel per presentation.
@MainActor
final class TaskEditorViewModel: ObservableObject {
    /// Kotlin enums with SKIE are Swift enums, but not `CaseIterable`: the segment order is listed here.
    let priorityOptions: [PickerOption<Priority>] = [Priority.low, .medium, .high]
        .map { PickerOption(value: $0, title: $0.displayName) }

    /// Segment dot colors (`outline` for Low, like the Stats bars).
    func dotColor(_ priority: Priority) -> Color { priority.barFill }

    /// The voice-note card of this sheet (`Draft` target): nothing is written until `save()`.
    let voice: VoiceNoteCardViewModel

    /// Address search of the Place row (a shared `PlaceSearchViewModel`), alive while its sheet is open.
    @Published var placeSearch: PlaceSearchModel?
    /// Set by `AppDependencies`: creates the search view model (shared `Geocoder` + app language).
    var makePlaceSearch: (() -> PlaceSearchModel?)?

    private var forwarding: AnyCancellable?
    private let shared: TaskEditorModel

    init(shared: TaskEditorModel, voice: VoiceNoteCardViewModel) {
        self.shared = shared
        self.voice = voice
        // Every change of the draft note is forwarded to the Kotlin editor state (committed by save()).
        voice.bind(to: shared.viewModel)
        // Nested ObservableObject: changes of `shared.state` don't reach SwiftUI by themselves
        // (classic Combine pitfall), so re-publish them as this object's changes.
        forwarding = shared.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    // MARK: - Display state

    /// "New task" / "Edit task"
    var screenTitle: String { shared.state.screenTitle }
    var canSave: Bool { shared.state.canSave }

    /// Validation messages (text from shared), mapped to the field they belong to.
    var titleError: String? {
        shared.state.errors.first { $0 == .titleTooShort || $0 == .titleTooLong }?.message
    }
    var notesError: String? { shared.state.errors.first { $0 == .notesTooLong }?.message }
    var dueDateError: String? { shared.state.errors.first { $0 == .dueDateInPast }?.message }

    /// Number of fields with an error: "Fix N fields to save this task."
    var errorFieldCount: Int { [titleError, notesError, dueDateError].compactMap { $0 }.count }
    var bannerText: String { L10n.plural("fix_fields", errorFieldCount) }
    var dueDateText: String { DateFormatting.shared.format(date: shared.state.dueDate) }

    // MARK: - Bindings: read from Kotlin uiState, write as a Kotlin event (SharedViewModel.binding)

    var title: Binding<String> { shared.binding(\.title) { $0.onTitleChange(value: $1) } }
    var notes: Binding<String> { shared.binding(\.notes) { $0.onNotesChange(value: $1) } }
    var priority: Binding<Priority> { shared.binding(\.priority) { $0.onPriorityChange(value: $1) } }

    /// SwiftUI `DatePicker` works with `Date`, Kotlin with `LocalDate` (IosDates helpers).
    var dueDate: Binding<Date> {
        shared.binding(\.dueDate, get: \.asDate) { $0.onDueDateChange(value: $1.asLocalDate) }
    }

    // MARK: - Time and place (Map feature)

    /// "16:30", or "No time".
    var timeText: String { shared.state.time.map(MapFormat.clock) ?? MapFormat.tr("map_no_time") }
    var hasTime: Bool { shared.state.time != nil }

    /// Wheel value; while there is no time it shows 09:00 (the first change sets it).
    var timeDate: Binding<Date> {
        Binding(
            get: { [shared] in
                let state = shared.state
                let time = state.time ?? IosDates.shared.localTime(hour: 9, minute: 0)
                return IosDates.shared.toDate(localDate: state.dueDate, localTime: time)
            },
            set: { [shared] date in
                shared.send { $0.onTimeChange(value: IosDates.shared.toLocalTime(date: date)) }
            }
        )
    }

    func setDefaultTimeIfNeeded() {
        guard !hasTime else { return }
        shared.send { $0.onTimeChange(value: IosDates.shared.localTime(hour: 9, minute: 0)) }
    }

    func clearTime() { shared.send { $0.onTimeChange(value: nil) } }

    /// The place's short address, nil when the task has none.
    var placeAddress: String? { shared.state.place?.address }

    func openPlaceSearch() { placeSearch = makePlaceSearch?() }
    func closePlaceSearch() { placeSearch = nil }

    func choosePlace(_ place: Place) {
        shared.send { $0.onPlaceChange(value: place) }
        placeSearch = nil
    }

    func clearPlace() {
        shared.send { $0.onPlaceChange(value: nil) }
        placeSearch = nil
    }

    // MARK: - Intents

    /// Returns true when saved (the view dismisses the sheet).
    /// A recording still running is stopped and kept first (the note must be in the editor state before saving).
    func save() -> Bool {
        voice.finishForSave(editor: shared.viewModel)
        return shared.send { $0.save() }
    }

    /// Cancel / sheet dismissed without saving: shared deletes the files recorded in this session and keeps the
    /// original note. A no-op after a successful save; safe to call twice.
    func cancel() {
        shared.send { $0.onCancel() }
    }
}

/// `sheet(item:)` needs Identifiable; a class gets `id = ObjectIdentifier(self)` for free.
extension TaskEditorViewModel: Identifiable {}
