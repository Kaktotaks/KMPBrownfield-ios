import SwiftUI
import Shared

/// Root navigation: bottom tab bar with "Tasks" and "Stats".
/// Each tab owns its own NavigationStack.
@MainActor
struct RootView: View {
    @Environment(TaskRepository.self) private var repository
    let dateProvider: any DateProvider

    var body: some View {
        TabView {
            TaskListScreen(repository: repository, dateProvider: dateProvider)
                .tabItem {
                    Label("Tasks", systemImage: "list.bullet")
                }

            StatsScreen(repository: repository, dateProvider: dateProvider)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
        }
        .task {
            // Loaded once on app start.
            await repository.loadIfNeeded()
        }
    }
}
