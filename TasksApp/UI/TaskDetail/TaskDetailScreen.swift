import SwiftUI
import Shared

/// Task detail (§3.2). UI only: display state and intents live in `TaskDetailViewModel`.
/// Chrome is the system back button only ("‹ Tasks"); no Edit in the bar.
@MainActor
struct TaskDetailScreen: View {
    /// Owned by `TaskListViewModel.detail` (created on tap, released on pop) → observed, not owned.
    @ObservedObject var model: TaskDetailViewModel
    @State private var isConfirmingDelete = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if model.isDeleting {
                Color.clear
            } else if let details = model.details {
                TaskDetailContent(details: details, model: model, isConfirmingDelete: $isConfirmingDelete)
            } else {
                EmptyState(title: "not_found_title", message: "not_found_body")
            }
        }
        .background(Color.tk.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(item: $model.editor) { editor in
            TaskEditorScreen(model: editor)
        }
        .confirmationDialog("delete_confirm_title", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("delete", role: .destructive) {
                model.delete()
                dismiss()
            }
            Button("cancel", role: .cancel) {}
        }
    }
}

/// HeroCard, notes card, info rows and actions.
@MainActor
struct TaskDetailContent: View {
    let details: TaskDetailViewModel.Details
    @ObservedObject var model: TaskDetailViewModel
    @Binding var isConfirmingDelete: Bool

    private var overdue: Bool { details.isOverdue && !details.isDone }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.sectionGap) {
                HeroCard {
                    HStack(spacing: 8) {
                        PriorityBadge(priority: details.priority)
                        StatusBadge(isDone: details.isDone)
                    }
                    Text(details.title)
                        .tkStyle(.heroTitle)
                        .foregroundStyle(Color.tk.heroText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 14)
                    HStack(spacing: 8) {
                        TKIcon(name: .calendar, size: 16)
                        let due = L10n.format("due_format", details.dueDate)
                        Text(overdue ? "\(due) \(L10n.string("overdue_suffix"))" : due)
                            .tkStyle(overdue ? .subheadStrong : .subhead)
                    }
                    .foregroundStyle(overdue ? Color.tk.danger : Color.tk.heroTextSecondary)
                    .padding(.top, 14)
                }

                // Hidden when the notes are blank.
                if let notes = details.notes {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("notes").tkStyled(.overline).foregroundStyle(Color.tk.textSecondary)
                        Text(notes).tkStyle(.body).foregroundStyle(Color.tk.textPrimary)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.tk.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                }

                InfoRowsCard(rows: [
                    InfoRowItem(icon: .flag, label: "priority", value: details.priority.displayName),
                    InfoRowItem(icon: .calendar, label: "due_date", value: details.dueDate),
                    InfoRowItem(icon: .statusRing, label: "status", value: L10n.string(details.isDone ? "status_done" : "status_active")),
                ])

                if details.isDone {
                    SecondaryButton(title: "mark_active") { model.toggleDone() }
                } else {
                    PrimaryButton(title: "mark_done", icon: .check) { model.toggleDone() }
                }
                HStack(spacing: 12) {
                    SecondaryButton(title: "edit", icon: .pencil) { model.showEditor() }
                    DestructiveButton(title: "delete", icon: .trash) { isConfirmingDelete = true }
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, 8)
            .padding(.bottom, Spacing.gutter)
        }
    }
}
