import SwiftUI

/// App entry point.
/// The struct is intentionally NOT named `TasksApp` (the module name), so that
/// `TasksApp.Task` / `TasksApp.SortOrder` stay usable as module-qualified names in tests.
@main
@MainActor
struct TasksMainApp: App {
    @State private var repository: TaskRepository
    private let clock: any Clock

    init() {
        let clock = SystemClock()
        self.clock = clock
        _repository = State(initialValue: TaskRepository(api: URLSessionTaskApi(), clock: clock))
    }

    var body: some Scene {
        WindowGroup {
            RootView(clock: clock)
                .environment(repository)
        }
    }
}
