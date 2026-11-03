import Combine
import Foundation
import Shared

/// Swift ViewModel of the Stats tab. Wraps the shared Kotlin `StatsViewModel`.
@MainActor
final class StatsViewModel: ObservableObject {
    enum Content {
        case loading
        case error
        case loaded(StatsSummary)
    }

    private var forwarding: AnyCancellable?
    private let shared: StatsModel

    init(shared: StatsModel) {
        self.shared = shared
        // Nested ObservableObject: changes of `shared.state` don't reach SwiftUI by themselves
        // (classic Combine pitfall), so re-publish them as this object's changes.
        forwarding = shared.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    var content: Content {
        // SKIE: Kotlin sealed `StatsUiState` → exhaustive Swift enum.
        switch onEnum(of: shared.state) {
        case .loading:
            return .loading
        case .error:
            return .error
        case .loaded(let loaded):
            return .loaded(StatsSummary(stats: loaded.stats))
        }
    }

    func retry() {
        shared.send { $0.onRetry() }
    }
}

/// Display-ready stats.
struct StatsSummary: Equatable {
    /// `completionPercent` from shared, untouched: the animation must land exactly on it.
    let completionPercent: Int
    let total: Int
    let done: Int
    let active: Int
    let overdue: Int
    /// High, Medium, Low.
    let priorityRows: [PriorityRowItem]
}

/// One PriorityBar: `fraction` = count / total (0 when there are no tasks).
struct PriorityRowItem: Identifiable, Equatable {
    let priority: Priority
    let count: Int
    let fraction: Double

    var id: Int { Int(priority.sortWeightValue) }
}

extension Priority {
    /// Stable id for rows (`Priority` has no `Hashable` raw value in Swift).
    fileprivate var sortWeightValue: Int32 {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }
}

extension StatsSummary {
    init(stats: TaskStats) {
        let total = Int(stats.total)
        func row(_ priority: Priority, _ count: Int32) -> PriorityRowItem {
            PriorityRowItem(priority: priority, count: Int(count), fraction: total == 0 ? 0 : Double(count) / Double(total))
        }
        self.init(
            completionPercent: Int(stats.completionPercent),
            total: total,
            done: Int(stats.done),
            active: Int(stats.active),
            overdue: Int(stats.overdue),
            priorityRows: [row(.high, stats.high), row(.medium, stats.medium), row(.low, stats.low)]
        )
    }
}
