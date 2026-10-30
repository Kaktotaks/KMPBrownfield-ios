import Foundation
import Shared

/// Network DTO for https://jsonplaceholder.typicode.com/todos
/// JSON parsing stays native (Codable); the mapping rule lives in Kotlin (`TodoMapper`).
struct TodoDto: Codable, Equatable {
    let userId: Int
    let id: Int
    let title: String
    let completed: Bool
}

extension TodoDto {
    /// Deterministic mapping from SPEC.md, implemented once in the shared module:
    /// priority = [low, medium, high][id % 3], dueDate = today + ((id % 14) - 3) days.
    func toTask(today: LocalDate) -> TaskItem {
        TodoMapper.shared.map(id: Int32(id), title: title, completed: completed, today: today)
    }
}
