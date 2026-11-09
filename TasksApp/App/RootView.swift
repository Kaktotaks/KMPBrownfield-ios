import SwiftUI
import UIKit
import Shared

/// Root navigation: the SYSTEM tab bar with "Tasks" and "Stats" (selected item tinted `textPrimary`; no custom
/// lime pill, see handoff §0). Each tab owns its own NavigationStack.
///
/// The animated splash (`SplashOverlay`, SPLASH_HANDOFF §3) sits above the tabs in a root `ZStack`. Its phase is
/// `@State` of this root view, which lives for the whole scene, so the splash plays on cold start only.
@MainActor
struct RootView: View {
    let app: AppDependencies

    /// The task list's ViewModel is created here (not inside the tab) so the splash can wait for its state.
    /// `@State` (not `@StateObject`): the root does not re-render on list changes.
    @State private var taskList: TaskListViewModel
    @State private var splash: SplashPhase

    init(app: AppDependencies) {
        self.app = app
        _taskList = State(initialValue: app.makeTaskListViewModel())
        _splash = State(initialValue: Self.initialSplashPhase)
    }

    private static var initialSplashPhase: SplashPhase {
        if SplashLaunch.isDisabled { return .done }
        if let frozen = SplashLaunch.frozenAtMs { return SplashLaunch.frozenExitStart(frozen) == nil ? .holding : .exiting }
        return .holding
    }

    var body: some View {
        ZStack {
            TabView {
                TaskListScreen(model: taskList)
                    .tabItem {
                        Label("tasks_title", systemImage: "checklist")
                    }

                StatsScreen(model: app.makeStatsViewModel())
                    .tabItem {
                        Label("stats_title", systemImage: "chart.bar")
                    }
            }
            .tint(Color.tk.textPrimary)
            // VoiceOver stays on the list only after the overlay is gone.
            .accessibilityHidden(splash != .done)

            if splash != .done {
                SplashHost(
                    list: taskList,
                    frozenAtMs: SplashLaunch.frozenAtMs,
                    onExit: { splash = .exiting },
                    onFinished: finishSplash
                )
                .transition(.identity)
            }
        }
        // Light status bar while the overlay holds (the launch frame and overlay are #0A0A0A in both appearances).
        // Released at the start of the exit, so the list under the reveal circle follows the system appearance.
        .preferredColorScheme(splash == .holding ? .dark : nil)
        .task {
            // Loaded once on app start.
            await app.loadIfNeeded()
        }
    }

    private func finishSplash() {
        splash = .done
        // Focus lands on the list once the overlay is gone.
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }
}
