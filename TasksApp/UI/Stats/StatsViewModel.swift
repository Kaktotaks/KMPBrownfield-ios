import Foundation
import Observation
import Shared

@MainActor
@Observable
final class StatsViewModel {
    private let store: TaskStore
    private let dateProvider: any DateProvider

    init(store: TaskStore, dateProvider: any DateProvider) {
        self.store = store
        self.dateProvider = dateProvider
    }

    var phase: TaskStore.Phase {
        store.phase
    }

    var stats: TaskStats {
        StatsCalculator.shared.calculate(tasks: store.tasks, today: dateProvider.today())
    }

    func retry() {
        Task {
            await self.store.load()
        }
    }
}
