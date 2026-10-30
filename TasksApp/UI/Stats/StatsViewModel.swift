import Foundation
import Observation
import Shared

@MainActor
@Observable
final class StatsViewModel {
    private let repository: TaskRepository
    private let dateProvider: any DateProvider

    init(repository: TaskRepository, dateProvider: any DateProvider) {
        self.repository = repository
        self.dateProvider = dateProvider
    }

    var loadState: LoadState {
        repository.loadState
    }

    var stats: TaskStats {
        StatsCalculator.shared.calculate(tasks: repository.tasks, today: dateProvider.today())
    }

    func retry() {
        Task {
            await self.repository.load()
        }
    }
}
