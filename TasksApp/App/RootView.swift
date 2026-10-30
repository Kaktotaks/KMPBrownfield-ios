import SwiftUI
import Shared

/// Root navigation: bottom tab bar with "Tasks" and "Stats".
/// Each tab owns its own NavigationStack.
@MainActor
struct RootView: View {
    let app: AppDependencies

    var body: some View {
        TabView {
            TaskListScreen(app: app)
                .tabItem {
                    Label("Tasks", systemImage: "list.bullet")
                }

            StatsScreen(app: app)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
        }
        .task {
            // Loaded once on app start.
            await app.loadIfNeeded()
        }
    }
}
