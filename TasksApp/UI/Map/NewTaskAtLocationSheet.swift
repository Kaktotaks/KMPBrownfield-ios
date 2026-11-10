import SwiftUI
import UIKit
import Shared

/// "New task here" (long-press on the map): the Editor's fields plus a place card, a Time row and a voice note
/// (`VoiceNoteCard` in its editor placement: recorder → compact player). Save stays disabled until the shared validator
/// accepts the title. Non-modal sheet like the task sheet.
struct NewTaskAtLocationSheet: View {
    @ObservedObject var model: MapViewModel
    let draft: NewTaskDraft
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var notes = ""
    @State private var priority = Priority.medium
    @State private var time: Date
    @State private var isPickingTime = false

    private let priorityOptions: [PickerOption<Priority>] = [Priority.low, .medium, .high]
        .map { PickerOption(value: $0, title: $0.displayName) }

    init(model: MapViewModel, draft: NewTaskDraft) {
        self.model = model
        self.draft = draft
        _time = State(initialValue: IosDates.shared.toDate(localDate: model.state.day, localTime: draft.defaultTime))
    }

    private var errors: [ValidationError] { model.validateNewTask(title: title, notes: notes) }
    private var titleError: String? {
        guard !title.isEmpty else { return nil }
        return errors.first { $0 == .titleTooShort || $0 == .titleTooLong }?.message
    }
    private var notesError: String? { errors.first { $0 == .notesTooLong }?.message }
    private var canSave: Bool { errors.isEmpty }

    private var timeText: String {
        let clock = MapFormat.clock(IosDates.shared.toLocalTime(date: time))
        if let relative = model.relativeDay { return "\(relative), \(model.dayText) · \(clock)" }
        return "\(model.dayText) · \(clock)"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    placeCard
                    TasksTextField(label: "title_label", text: $title, placeholder: "title_placeholder", error: titleError)
                    timeField
                    VStack(alignment: .leading, spacing: 6) {
                        Text("priority").tkStyled(.overline).foregroundStyle(Color.tk.textSecondary)
                        PillSegmentedControl(
                            options: priorityOptions,
                            selection: $priority,
                            segmentHeight: 36,
                            dotColor: { $0.barFill }
                        )
                    }
                    TasksTextField(label: "notes", text: $notes, error: notesError, isMultiline: true)
                    if let voice = model.newTaskVoice {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("voice_section").tkStyled(.overline).foregroundStyle(Color.tk.textSecondary)
                            VoiceNoteCard(model: voice, placement: .editor)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, Spacing.s24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.tk.bg)
    }

    private var header: some View {
        ZStack {
            Text(MapFormat.tr("map_new_task"))
                .tkStyle(.sheetTitle)
                .foregroundStyle(Color.tk.textPrimary)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button {
                    model.cancelNewTask()
                } label: {
                    Text(MapFormat.tr("map_cancel"))
                        .tkStyle(.bodyMedium)
                        .foregroundStyle(Color.tk.textPrimary)
                        .frame(minHeight: Spacing.minTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    if model.saveNewTask(title: title, notes: notes, priority: priority, time: time) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                } label: {
                    Text(MapFormat.tr("map_save"))
                        .tkStyle(.savePill)
                        .foregroundStyle(canSave ? Color.tk.onAccent : Color.tk.textTertiary)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 36)
                        .background(canSave ? Color.tk.accent : Color.tk.surface2, in: Capsule())
                        .contentShape(Rectangle().inset(by: -4))
                }
                .buttonStyle(TKPressStyle())
                .disabled(!canSave)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .frame(minHeight: 48)
    }

    private var placeCard: some View {
        HStack(spacing: 12) {
            MapIconView(icon: .pin, size: 18, stroke: 2.4)
                .foregroundStyle(Color.tk.onAccent)
                .frame(width: 36, height: 36)
                .background(Color.tk.accent, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(draft.address ?? MapFormat.tr("map_locating"))
                    .font(.custom("Inter-SemiBold", size: 16, relativeTo: .body))
                    .foregroundStyle(Color.tk.textPrimary)
                    .lineLimit(2)
                Text(MapFormat.tr("map_dropped_pin")).tkStyle(.caption).foregroundStyle(Color.tk.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.tk.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// Time row: "Today, Wed 4 Nov · 16:30" + clock; opens the system hour / minute picker.
    private var timeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(MapFormat.tr("map_time")).tkStyled(.overline).foregroundStyle(Color.tk.textSecondary)
            Button { isPickingTime = true } label: {
                HStack {
                    Text(timeText).tkStyle(.body).foregroundStyle(Color.tk.textPrimary)
                    Spacer(minLength: 8)
                    MapIconView(icon: .clock, size: 20, stroke: 2.2).foregroundStyle(Color.tk.textPrimary)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .background(Color.tk.surface, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.s, style: .continuous).strokeBorder(Color.tk.border, lineWidth: 1.5))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("\(MapFormat.tr("map_time")), \(timeText)"))
            .popover(isPresented: $isPickingTime) {
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(width: 240, height: 180)
                    .padding(Spacing.s12)
                    .presentationCompactAdaptation(.popover)
            }
        }
    }
}
