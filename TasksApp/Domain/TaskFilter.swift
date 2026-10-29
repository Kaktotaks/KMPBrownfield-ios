import Foundation

/// Status segment of the task list.
/// KMP sharing candidate.
enum StatusFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case active
    case done

    var id: Self { self }
}

/// Sort order of the task list.
/// KMP sharing candidate.
///
/// Note: shadows Foundation's `SortOrder` inside the app module.
enum SortOrder: String, CaseIterable, Identifiable, Hashable {
    case dueDate
    case priority

    var id: Self { self }
}

/// Search + status filter + sort for the task list.
/// KMP sharing candidate: pure function over domain models.
enum TaskFilter {
    static func apply(
        _ tasks: [Task],
        query: String,
        status: StatusFilter,
        sort: SortOrder
    ) -> [Task] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered = tasks.filter { task in
            let matchesQuery = trimmedQuery.isEmpty
                || task.title.range(of: trimmedQuery, options: .caseInsensitive) != nil
            let matchesStatus: Bool
            switch status {
            case .all: matchesStatus = true
            case .active: matchesStatus = !task.isDone
            case .done: matchesStatus = task.isDone
            }
            return matchesQuery && matchesStatus
        }

        switch sort {
        case .dueDate:
            return filtered.sorted { lhs, rhs in
                (lhs.dueDate, lhs.id) < (rhs.dueDate, rhs.id)
            }
        case .priority:
            return filtered.sorted { lhs, rhs in
                if lhs.priority.sortWeight != rhs.priority.sortWeight {
                    return lhs.priority.sortWeight > rhs.priority.sortWeight
                }
                return (lhs.dueDate, lhs.id) < (rhs.dueDate, rhs.id)
            }
        }
    }
}
