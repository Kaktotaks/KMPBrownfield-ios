import SwiftUI
import Shared

/// Root navigation: bottom tab bar with "Tasks" and "Stats".
/// Each tab owns its own NavigationStack.
@MainActor
struct RootView: View {
    let app: AppDependencies

    var body: some View {
        TabView {
            TaskListScreen(model: app.makeTaskListViewModel())
                .tabItem {
                    Label("Tasks", systemImage: "list.bullet")
                }

            StatsScreen(model: app.makeStatsViewModel())
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
