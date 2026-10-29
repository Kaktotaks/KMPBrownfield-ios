import Foundation

/// Network DTO for https://jsonplaceholder.typicode.com/todos
/// KMP sharing candidate (kotlinx.serialization on the shared side).
struct TodoDto: Codable, Equatable {
    let userId: Int
    let id: Int
    let title: String
    let completed: Bool
}

extension TodoDto {
    /// Deterministic mapping, identical on iOS and Android:
    /// - priority = [low, medium, high][id % 3]
    /// - dueDate = today + ((id % 14) - 3) days
    func toTask(today: Date, calendar: Calendar = .current) -> Task {
        let priorities: [Priority] = [.low, .medium, .high]
        let offsetDays = (id % 14) - 3
        let dueDate = calendar.date(byAdding: .day, value: offsetDays, to: today) ?? today
        return Task(
            id: id,
            title: title,
            notes: "",
            priority: priorities[id % 3],
            dueDate: calendar.startOfDay(for: dueDate),
            isDone: completed
        )
    }
}
