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
    /// "42%"
    let completionText: String
    /// 0...100 for `ProgressView(value:total: 100)`.
    let completionValue: Double
    /// Total / Done / Active / Overdue
    let totals: [StatRow]
    /// High / Medium / Low
    let byPriority: [StatRow]
}

struct StatRow: Identifiable, Equatable {
    let title: String
    let value: String

    var id: String { title }
}

extension StatsSummary {
    init(stats: TaskStats) {
        self.init(
            completionText: "\(stats.completionPercent)%",
            completionValue: Double(stats.completionPercent),
            totals: [
                StatRow(title: "Total", value: "\(stats.total)"),
                StatRow(title: "Done", value: "\(stats.done)"),
                StatRow(title: "Active", value: "\(stats.active)"),
                StatRow(title: "Overdue", value: "\(stats.overdue)"),
            ],
            byPriority: [
                StatRow(title: "High", value: "\(stats.high)"),
                StatRow(title: "Medium", value: "\(stats.medium)"),
                StatRow(title: "Low", value: "\(stats.low)"),
            ]
        )
    }
}
