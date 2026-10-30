import SwiftUI
import Shared

/// Root navigation: bottom tab bar with "Tasks" and "Stats".
/// Each tab owns its own NavigationStack.
@MainActor
struct RootView: View {
    @Environment(TaskStore.self) private var store
    let dateProvider: any DateProvider

    var body: some View {
        TabView {
            TaskListScreen(store: store, dateProvider: dateProvider)
                .tabItem {
                    Label("Tasks", systemImage: "list.bullet")
                }

            StatsScreen(store: store, dateProvider: dateProvider)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
        }
        .task {
            // Loaded once on app start.
            await store.loadIfNeeded()
        }
    }
}
