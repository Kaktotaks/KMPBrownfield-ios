import SwiftUI
import Shared

/// TaskCard (§2): `surface`, r `l`, padding 14 v / 16 h. The whole card opens the detail; [CheckCircle] is a
/// separate target on top of it. Accessibility: the card is ONE element ("title, High priority, Due …, overdue")
/// with a custom action that toggles; the checkbox stays individually focusable (§7).
struct TaskCard: View {
    let title: String
    let dueDate: String
    let priority: Priority
    let isDone: Bool
    let isOverdue: Bool
    let onTap: () -> Void
    let onToggle: () -> Void

    private var cardLabel: String {
        [
            title,
            L10n.format("a11y_priority", priority.displayName),
            L10n.format("due_format", dueDate),
            isDone ? L10n.string("a11y_done") : nil,
            isOverdue ? L10n.string("a11y_overdue") : nil,
        ].compactMap { $0 }.joined(separator: ", ")
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 14) {
                    // Room for the CheckCircle overlay below.
                    Color.clear.frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(title)
                                .tkStyle(.headline)
                                .strikethrough(isDone)
                                .foregroundStyle(isDone ? Color.tk.textTertiary : Color.tk.textPrimary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            PriorityBadge(priority: priority)
                        }
                        DueLine(dueDate: dueDate, isOverdue: isOverdue, isDone: isDone)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.tk.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                // M2: title / due line colors animate to and from `textTertiary`.
                .tkAnimation(Motion.emphasized(Motion.short), value: isDone)
            }
            .buttonStyle(TKPressStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(cardLabel)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: Text(isDone ? "mark_active" : "mark_done"), onToggle)

            CheckCircle(
                checked: isDone,
                isOverdue: isOverdue,
                label: L10n.format(isDone ? "a11y_mark_not_done" : "a11y_mark_done", title),
                action: onToggle
            )
            .padding(.leading, 16)
            .padding(.top, 14)
        }
        .accessibilityElement(children: .contain)
    }
}

/// CheckCircle (§2): 28 pt visible, 44 pt hit area. M1: fill crossfade 150 ms, check scale 0.6 -> 1 (spring).
struct CheckCircle: View {
    let checked: Bool
    let isOverdue: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(isOverdue && !checked ? Color.tk.danger : Color.tk.textPrimary, lineWidth: 2)
                    .opacity(checked ? 0 : 1)
                Circle()
                    .fill(Color.tk.accent)
                    .opacity(checked ? 1 : 0)
                TKIcon(name: .checkBold, size: 16)
                    .foregroundStyle(Color.tk.onAccent)
                    .scaleEffect(checked ? 1 : 0.6)
                    .opacity(checked ? 1 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: checked)
            }
            .frame(width: 28, height: 28)
            .animation(Motion.emphasized(Motion.short), value: checked)
            .contentShape(Rectangle().inset(by: -8))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: checked)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isToggle)
    }
}

/// PriorityBadge (§2): r `xs`, padding 3 v / 8 h, always shows the word.
struct PriorityBadge: View {
    let priority: Priority

    var body: some View {
        Text(priority.displayName)
            .tkStyled(.badge)
            .foregroundStyle(priority.onFill)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(priority.fill, in: RoundedRectangle(cornerRadius: Radius.xs, style: .continuous))
            .fixedSize()
    }
}

/// StatusBadge (§2, detail hero, on `heroBg`): Active = accent outline, Done = accent fill. 12 pt.
struct StatusBadge: View {
    let isDone: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
        Text(isDone ? "status_done" : "status_active")
            .tkStyled(.statusBadge)
            .foregroundStyle(isDone ? Color.tk.onAccent : Color.tk.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background { if isDone { shape.fill(Color.tk.accent) } }
            .overlay { if !isDone { shape.strokeBorder(Color.tk.accent, lineWidth: 1.5) } }
            .fixedSize()
    }
}

/// Due line (§2): "Due 5 Nov 2026"; overdue and not done: clock icon + "… · Overdue" in `danger`, 600.
struct DueLine: View {
    let dueDate: String
    let isOverdue: Bool
    let isDone: Bool

    var body: some View {
        let due = L10n.format("due_format", dueDate)
        if isOverdue && !isDone {
            HStack(spacing: 6) {
                TKIcon(name: .clock, size: 14)
                Text("\(due) \(L10n.string("overdue_suffix"))")
                    .tkStyle(.subheadStrong)
            }
            .foregroundStyle(Color.tk.danger)
        } else {
            Text(due)
                .tkStyle(.subhead)
                .foregroundStyle(isDone ? Color.tk.textTertiary : Color.tk.textSecondary)
        }
    }
}
