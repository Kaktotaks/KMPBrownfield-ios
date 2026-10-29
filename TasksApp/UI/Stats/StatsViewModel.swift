import Foundation
import Observation

@MainActor
@Observable
final class StatsViewModel {
    private let repository: TaskRepository
    private let clock: any Clock

    init(repository: TaskRepository, clock: any Clock) {
        self.repository = repository
        self.clock = clock
    }

    var loadState: LoadState {
        repository.loadState
    }

    var stats: TaskStats {
        StatsCalculator.calculate(tasks: repository.tasks, today: clock.today)
    }

    func retry() {
        _Concurrency.Task {
            await self.repository.load()
        }
    }
}
