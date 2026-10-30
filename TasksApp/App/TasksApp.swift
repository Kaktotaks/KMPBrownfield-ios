import SwiftUI
import Shared

/// App entry point.
/// The struct is intentionally NOT named `TasksApp` (the module name), so that
/// module-qualified names like `TasksApp.AppDependencies` stay usable in tests.
@main
@MainActor
struct TasksMainApp: App {
    /// One Kotlin TaskRepository + TaskValidator for the whole app.
    @State private var app: AppDependencies

    init() {
        _app = State(initialValue: AppDependencies())
    }

    var body: some Scene {
        WindowGroup {
            RootView(app: app)
        }
    }
}
