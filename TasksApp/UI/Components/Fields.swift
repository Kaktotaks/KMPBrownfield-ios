import SwiftUI

/// PillSearchField (§2): custom view, NOT `.searchable`. h 44, r `pill`, `surface2`; clear button when not empty.
struct PillSearchField: View {
    @Binding var text: String
    var isEnabled = true

    var body: some View {
        HStack(spacing: 10) {
            TKIcon(name: .search, size: 18)
                .foregroundStyle(Color.tk.textSecondary)
            TextField(
                "",
                text: $text,
                prompt: Text("search_placeholder").foregroundStyle(Color.tk.textSecondary)
            )
            .tkStyle(.body)
            .foregroundStyle(Color.tk.textPrimary)
            .tint(Color.tk.textPrimary)
            .submitLabel(.search)
            .disabled(!isEnabled)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    TKIcon(name: .close, size: 16)
                        .foregroundStyle(Color.tk.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle().inset(by: -8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("search_clear")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(Color.tk.surface2, in: Capsule())
    }
}

/// Border of a field (§2): 1.5 `border`, focused 2 `textPrimary`, invalid 2 `danger`.
struct FieldChrome: ViewModifier {
    let focused: Bool
    let invalid: Bool
    let minHeight: CGFloat
    var alignment: Alignment = .leading

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
        let (width, color): (CGFloat, Color) = invalid ? (2, Color.tk.danger)
            : focused ? (2, Color.tk.textPrimary)
            : (1.5, Color.tk.border)
        content
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: alignment)
            .background(Color.tk.surface, in: shape)
            .overlay(shape.strokeBorder(color, lineWidth: width))
    }
}

/// Label above a field: `overline`, `textSecondary`, gap 6.
struct FieldLabel: View {
    let key: LocalizedStringKey
    var body: some View {
        Text(key).tkStyled(.overline).foregroundStyle(Color.tk.textSecondary)
    }
}

/// Message under a field; M6 fade + height expand.
private struct FieldError: View {
    let message: String?
    var body: some View {
        if let message {
            Text(message)
                .tkStyle(.caption)
                .foregroundStyle(Color.tk.danger)
                .transition(.opacity)
        }
    }
}

/// TasksTextField (§2): custom, not the system rounded style. [isMultiline] makes it the notes field.
struct TasksTextField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var placeholder: LocalizedStringKey?
    var error: String?
    var isMultiline = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(key: label)
            field
                .tkStyle(.body)
                .foregroundStyle(Color.tk.textPrimary)
                .tint(Color.tk.textPrimary)
                .focused($focused)
                .padding(.horizontal, 14)
                .padding(.vertical, isMultiline ? 12 : 0)
                .modifier(FieldChrome(focused: focused, invalid: error != nil, minHeight: isMultiline ? 96 : 48,
                                      alignment: isMultiline ? .topLeading : .leading))
            FieldError(message: error)
        }
        .tkAnimation(Motion.emphasized(Motion.medium), value: error)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var field: some View {
        let prompt = placeholder.map { Text($0).foregroundStyle(Color.tk.textSecondary) }
        if isMultiline {
            TextField("", text: $text, prompt: prompt, axis: .vertical).lineLimit(3...8)
        } else {
            TextField("", text: $text, prompt: prompt)
        }
    }
}

/// DateField (§2): looks like [TasksTextField]; tapping opens the system picker (hosted by the screen).
struct DateField: View {
    let label: LocalizedStringKey
    let labelText: String
    let valueText: String
    var error: String?
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(key: label)
            Button(action: action) {
                HStack {
                    Text(valueText).tkStyle(.body).foregroundStyle(Color.tk.textPrimary)
                    Spacer(minLength: 8)
                    TKIcon(name: .calendar, size: 20).foregroundStyle(Color.tk.textPrimary)
                }
                .padding(.horizontal, 14)
                .modifier(FieldChrome(focused: false, invalid: error != nil, minHeight: 48))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.format("a11y_date_field", labelText, valueText))
            .accessibilityAddTraits(.isButton)
            FieldError(message: error)
        }
        .tkAnimation(Motion.emphasized(Motion.medium), value: error)
    }
}

/// ErrorBanner (§2): `dangerContainer`, r `m`, alert icon + text.
struct ErrorBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            TKIcon(name: .alert, size: 20)
            Text(text).tkStyle(.subhead)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.tk.onDangerContainer)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.tk.dangerContainer, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
