import SwiftUI
import Shared

/// App entry point.
/// The struct is intentionally NOT named `TasksApp` (the module name), so that
/// module-qualified names like `TasksApp.TaskStore` stay usable in tests.
@main
@MainActor
struct TasksMainApp: App {
    @State private var store: TaskStore
    /// "Today" provider from the shared Kotlin module.
    private let dateProvider: any DateProvider

    init() {
        let dateProvider: any DateProvider = SystemDateProvider.shared
        self.dateProvider = dateProvider
        // Data layer from Kotlin: Ktor client (Darwin engine) + shared TaskRepository,
        // wrapped in the Swift TaskStore so SwiftUI can observe it.
        let repository = TaskRepository(api: KtorTaskApi(), dateProvider: dateProvider)
        _store = State(initialValue: TaskStore(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            RootView(dateProvider: dateProvider)
                .environment(store)
        }
    }
}
