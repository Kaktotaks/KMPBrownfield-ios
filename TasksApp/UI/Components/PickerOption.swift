import Foundation

/// One display-ready option of a picker: the value it selects + its title.
/// Built by the Swift ViewModels (Kotlin enums are not `CaseIterable` in Swift, so the order is listed there).
struct PickerOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String

    var id: Value { value }
}
