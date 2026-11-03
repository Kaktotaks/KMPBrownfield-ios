import SwiftUI

/// PillSegmentedControl (§2): `surface2` track, padding 3, selected = `inverse` (light) / `accent` (dark).
/// The thumb slides (M3: 250 ms emphasized, `matchedGeometryEffect`). `segmentHeight` 34 (filter) / 36 (editor
/// priority); `dotColor` adds the 8 pt priority dot before each label.
struct PillSegmentedControl<Value: Hashable>: View {
    let options: [PickerOption<Value>]
    @Binding var selection: Value
    var segmentHeight: CGFloat = 34
    var isEnabled = true
    var dotColor: ((Value) -> Color)?

    @Namespace private var thumbSpace
    @Environment(\.colorScheme) private var colorScheme

    private var thumbColor: Color { colorScheme == .dark ? Color.tk.accent : Color.tk.inverse }
    private var onThumb: Color { colorScheme == .dark ? Color.tk.onAccent : Color.tk.onInverse }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                let selected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    HStack(spacing: 6) {
                        if let dotColor {
                            Circle().fill(dotColor(option.value)).frame(width: 8, height: 8)
                        }
                        Text(option.title)
                            .tkStyle(selected ? .bodyStrong : .bodyMedium)
                            .lineLimit(1)
                    }
                    .foregroundStyle(selected ? onThumb : Color.tk.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: segmentHeight)
                    .background {
                        if selected {
                            Capsule()
                                .fill(thumbColor)
                                .matchedGeometryEffect(id: "thumb", in: thumbSpace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.tk.surface2, in: Capsule())
        .tkAnimation(Motion.emphasized(Motion.medium), value: selection)
        .disabled(!isEnabled)
    }
}

/// SortPill (§2): h 40, 1.5 `textPrimary` border; label = current sort; opens a system menu with a check on
/// the current option (`Menu` + `Picker`).
struct SortPill<Value: Hashable>: View {
    let label: String
    let options: [PickerOption<Value>]
    @Binding var selection: Value
    var isEnabled = true

    var body: some View {
        Menu {
            Picker("sort_label", selection: $selection) {
                ForEach(options) { option in
                    Text(option.title).tag(option.value)
                }
            }
        } label: {
            HStack(spacing: 6) {
                TKIcon(name: .sort, size: 16)
                Text(label).tkStyle(.subheadStrong)
                TKIcon(name: .chevronDown, size: 14)
            }
            .foregroundStyle(Color.tk.textPrimary)
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .overlay(Capsule().strokeBorder(Color.tk.textPrimary, lineWidth: 1.5))
            .contentShape(Capsule())
        }
        .disabled(!isEnabled)
        .accessibilityLabel(Text("sort_label"))
        .accessibilityValue(label)
    }
}
