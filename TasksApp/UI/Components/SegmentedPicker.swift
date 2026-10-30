import SwiftUI

/// Segmented picker over display-ready options (status filter, priority).
struct SegmentedPicker<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [PickerOption<Value>]

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options) { option in
                Text(option.title).tag(option.value)
            }
        }
        .pickerStyle(.segmented)
    }
}
