import SwiftUI
import Shared

/// App entry point.
/// The struct is intentionally NOT named `TasksApp` (the module name), so that
/// module-qualified names like `TasksApp.LoadState` stay usable in tests.
@main
@MainActor
struct TasksMainApp: App {
    @State private var repository: TaskRepository
    /// "Today" provider from the shared Kotlin module.
    private let dateProvider: any DateProvider

    init() {
        let dateProvider: any DateProvider = SystemDateProvider.shared
        self.dateProvider = dateProvider
        _repository = State(initialValue: TaskRepository(api: URLSessionTaskApi(), dateProvider: dateProvider))
    }

    var body: some Scene {
        WindowGroup {
            RootView(dateProvider: dateProvider)
                .environment(repository)
        }
    }
}
