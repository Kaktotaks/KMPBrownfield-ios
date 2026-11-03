import SwiftUI
import UIKit
import Shared

/// New / Edit task sheet (§3.3). UI only: controls bind to `TaskEditorViewModel`, which forwards every
/// change to the Kotlin `TaskEditorViewModel` (form state + live validation).
@MainActor
struct TaskEditorScreen: View {
    /// Owned by the presenting ViewModel (`newTaskEditor` / `editor`) → observed, not owned.
    @ObservedObject var model: TaskEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isPickingDate = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if model.errorFieldCount > 0 {
                        ErrorBanner(text: model.bannerText)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    TasksTextField(label: "title_label", text: model.title, placeholder: "title_placeholder", error: model.titleError)
                    TasksTextField(label: "notes", text: model.notes, error: model.notesError, isMultiline: true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("priority").tkStyled(.overline).foregroundStyle(Color.tk.textSecondary)
                        PillSegmentedControl(
                            options: model.priorityOptions,
                            selection: model.priority,
                            segmentHeight: 36,
                            dotColor: { model.dotColor($0) }
                        )
                    }
                    DateField(
                        label: "due_date",
                        labelText: L10n.string("due_date"),
                        valueText: model.dueDateText,
                        error: model.dueDateError
                    ) { isPickingDate = true }
                    .popover(isPresented: $isPickingDate) {
                        DueDatePickerPopover(selection: model.dueDate)
                    }
                }
                .tkAnimation(Motion.emphasized(Motion.medium), value: model.errorFieldCount)
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, 14)
                .padding(.bottom, Spacing.s24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.tk.bg)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.xl)
        .presentationBackground(Color.tk.bg)
    }

    /// Header: 3-column grid (Cancel / title / SavePill). Focus order: Cancel → fields → Save.
    private var header: some View {
        ZStack {
            Text(model.screenTitle)
                .tkStyle(.sheetTitle)
                .foregroundStyle(Color.tk.textPrimary)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button { dismiss() } label: {
                    Text("cancel")
                        .tkStyle(.bodyMedium)
                        .foregroundStyle(Color.tk.textPrimary)
                        .frame(minHeight: Spacing.minTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                SavePill(isEnabled: model.canSave) {
                    if model.save() {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.top, 20)
        .frame(minHeight: 48)
    }
}

/// System graphical `DatePicker` in a popover. Explicit size: left to itself a popover squeezes the picker.
struct DueDatePickerPopover: View {
    @Binding var selection: Date

    var body: some View {
        DatePicker("due_date", selection: $selection, displayedComponents: .date)
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(Color.tk.textPrimary)
            .frame(width: 320, height: 340)
            .padding(Spacing.s12)
            .presentationCompactAdaptation(.popover)
    }
}
