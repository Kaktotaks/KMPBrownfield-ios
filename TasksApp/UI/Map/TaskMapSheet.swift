import SwiftUI
import Shared

/// TaskMapSheet (pin selected): priority + time, title, address, notes, the unchanged `VoiceNoteCard`, and the four
/// actions. Presented as a non-modal `.sheet` (detents, background interaction on, no dimming) so it covers the tab bar
/// but the map stays live behind it.
struct TaskMapSheet: View {
    @ObservedObject var model: MapViewModel
    let sheet: MapTaskSheetModel
    @Environment(\.dismiss) private var dismiss

    private var titleColor: Color { sheet.isPast ? Color.tk.textTertiary : Color.tk.textPrimary }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header
                Text(sheet.title)
                    .tkStyle(.mapSheetTitle)
                    .foregroundStyle(titleColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 6) {
                    MapIconView(icon: .pin, size: 16)
                    Text(sheet.address).font(.custom("Inter-Medium", size: 15, relativeTo: .subheadline))
                }
                .foregroundStyle(Color.tk.textSecondary)
                .accessibilityElement(children: .combine)
                if let notes = sheet.notes {
                    Text(notes).font(.custom("Inter-Regular", size: 15, relativeTo: .body)).foregroundStyle(Color.tk.textPrimary)
                }
                if let voice = model.taskVoice {
                    VoiceNoteCard(model: voice, placement: .detail)
                }
                actions.padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .background(Color.tk.bg)
        .confirmationDialog("delete_confirm_title", isPresented: $model.isConfirmingDelete, titleVisibility: .visible) {
            Button("delete", role: .destructive) { model.confirmDelete() }
            Button(MapFormat.tr("map_cancel"), role: .cancel) {}
        }
        .sheet(item: $model.editor) { editor in
            TaskEditorScreen(model: editor)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            MapPriorityBadge(priority: sheet.priority, faded: sheet.isPast, large: true)
            HStack(spacing: 5) {
                MapIconView(icon: .clock, size: 15, stroke: 2.3)
                Text(sheet.whenText)
                    .font(.custom("Inter-SemiBold", size: 14, relativeTo: .subheadline))
                    .monospacedDigit()
                    .lineLimit(2)
            }
            .foregroundStyle(sheet.isOverdue ? Color.tk.danger : Color.tk.textSecondary)
            Spacer(minLength: 0)
            Button {
                model.clearSelection()
            } label: {
                MapIconView(icon: .close, size: 16, stroke: 2.6)
                    .foregroundStyle(Color.tk.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.tk.surface2, in: Circle())
                    .frame(width: Spacing.minTarget, height: Spacing.minTarget)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(MapFormat.tr("map_a11y_close"))
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            if sheet.isDone {
                MapActionButton(title: MapFormat.tr("map_done_state"), icon: .check, iconStroke: 2.8,
                                fill: Color.tk.surface2, content: Color.tk.textTertiary, isEnabled: false) {}
            } else {
                MapActionButton(title: MapFormat.tr("map_mark_done"), icon: .check, iconStroke: 2.8,
                                fill: Color.tk.accent, content: Color.tk.onAccent) { model.markDone(sheet.taskId) }
            }
            MapActionButton(title: MapFormat.tr("map_edit"), icon: .pencil,
                            fill: Color.tk.inverse, content: Color.tk.onInverse) { model.showEditor(for: sheet.taskId) }
            MapActionButton(title: MapFormat.tr("map_move_pin"), icon: .move,
                            fill: Color.tk.surface2, content: Color.tk.textPrimary) { model.startMove(sheet.taskId) }
            MapActionButton(title: MapFormat.tr("map_delete"), icon: .trash,
                            fill: Color.tk.dangerContainer, content: Color.tk.onDangerContainer) { model.requestDelete() }
        }
    }
}

/// 60 pt tile with an icon over a 13 pt label (the task sheet's action row).
struct MapActionButton: View {
    let title: String
    let icon: MapIcon
    var iconStroke: CGFloat = 2.2
    let fill: Color
    let content: Color
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                MapIconView(icon: icon, size: 19, stroke: iconStroke)
                Text(title)
                    .font(.custom("Inter-SemiBold", size: 13, relativeTo: .footnote))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(content)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(fill, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        }
        .buttonStyle(TKPressStyle())
        .disabled(!isEnabled)
    }
}
