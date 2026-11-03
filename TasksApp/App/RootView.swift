import SwiftUI
import Shared

/// Root navigation: the SYSTEM tab bar with "Tasks" and "Stats" (selected item tinted `textPrimary`; no custom
/// lime pill, see handoff §0). Each tab owns its own NavigationStack.
@MainActor
struct RootView: View {
    let app: AppDependencies

    var body: some View {
        TabView {
            // @StateObject autoclosure: the factory runs once per screen lifetime.
            TaskListScreen(model: app.makeTaskListViewModel())
                .tabItem {
                    Label("tasks_title", systemImage: "checklist")
                }

            StatsScreen(model: app.makeStatsViewModel())
                .tabItem {
                    Label("stats_title", systemImage: "chart.bar")
                }
        }
        .tint(Color.tk.textPrimary)
        .task {
            // Loaded once on app start.
            await app.loadIfNeeded()
        }
    }
}
