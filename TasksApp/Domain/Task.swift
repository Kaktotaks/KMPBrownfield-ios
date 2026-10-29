import Foundation

/// Domain model of a task.
/// KMP sharing candidate: moves to the `shared` module.
///
/// Note: this type shadows Swift Concurrency's `Task` inside the app module.
/// To spawn an async task in the app, write `_Concurrency.Task { ... }`
/// (or prefer the SwiftUI `.task { }` modifier).
struct Task: Identifiable, Equatable, Hashable {
    let id: Int
    var title: String
    var notes: String
    var priority: Priority
    /// Date only: always the start of the day (Calendar.current).
    var dueDate: Date
    var isDone: Bool

    /// Overdue rule: not done and due before today.
    func isOverdue(today: Date) -> Bool {
        !isDone && dueDate < today
    }
}
