import SwiftUI
import UIKit
import Shared

/// Root navigation: the custom `TKTabBar` (Android NavigationBar look and behaviour, accent pill) with "Tasks", "Map"
/// and "Stats" (the user asked for iOS to match Android; this replaces the system bar of handoff §0). Each tab owns its own NavigationStack (the Map tab is a full-screen map).
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
    @State private var tab: RootTab

    init(app: AppDependencies) {
        self.app = app
        _taskList = State(initialValue: app.makeTaskListViewModel())
        _splash = State(initialValue: Self.initialSplashPhase)
        _tab = State(initialValue: Self.initialTab)
    }

    enum RootTab: Hashable { case tasks, map, stats }

    /// Same order, labels and glyphs as the Android tabs (Tasks: ListChecks, Map: Pin, Stats: BarChart).
    static var tabItems: [TKTabBar<RootTab>.Item] {
        [
            .init(tab: .tasks, title: String(localized: "tasks_title"), icon: .tk(.listChecks), identifier: "tab_tasks"),
            .init(tab: .map, title: MapFormat.tr("map_tab"), icon: .map(.pin), identifier: "tab_map"),
            .init(tab: .stats, title: String(localized: "stats_title"), icon: .tk(.barChart), identifier: "tab_stats"),
        ]
    }

    private static var initialTab: RootTab {
        #if DEBUG
        switch MapDebug.initialTab {
        case "map": return .map
        case "stats": return .stats
        default: break
        }
        #endif
        return .tasks
    }

    private static var initialSplashPhase: SplashPhase {
        if SplashLaunch.isDisabled { return .done }
        if let frozen = SplashLaunch.frozenAtMs { return SplashLaunch.frozenExitStart(frozen) == nil ? .holding : .exiting }
        return .holding
    }

    var body: some View {
        ZStack {
            // Tab bar below the tabs (as the Android Scaffold bottomBar). The tabs stay alive in a TabView whose system
            // bar is hidden, so each keeps its own NavigationStack and state; the bar is `TKTabBar` (copy of the
            // Android M3 NavigationBar). It is a sibling under the splash overlay, like the system bar was.
            VStack(spacing: 0) {
                TabView(selection: $tab) {
                    TaskListScreen(model: taskList)
                        .toolbar(.hidden, for: .tabBar)
                        .tag(RootTab.tasks)

                    // Created on first display; the map view itself waits for the splash to finish (`isMapEnabled`),
                    // so tile requests never compete with the launch hand-over.
                    MapTab(app: app, isMapEnabled: splash == .done)
                        .toolbar(.hidden, for: .tabBar)
                        .tag(RootTab.map)

                    StatsScreen(model: app.makeStatsViewModel())
                        .toolbar(.hidden, for: .tabBar)
                        .tag(RootTab.stats)
                }

                TKTabBar(items: Self.tabItems, selection: $tab)
            }
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
            #if DEBUG
            if let id = MapDebug.openDetailId { taskList.openDetail(id: id) }
            #endif
        }
    }

    private func finishSplash() {
        splash = .done
        // Focus lands on the list once the overlay is gone.
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }
}
