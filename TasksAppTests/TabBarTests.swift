import SwiftUI
import XCTest
@testable import TasksApp

/// The iOS tab bar copies the Android M3 NavigationBar (`TasksRoot.kt`): same tabs in the same order, same glyphs,
/// same metrics. Pixel comparison lives in design-handoff/map/implementation (side-by-side images).
@MainActor
final class TabBarTests: XCTestCase {
    func testMetricsMatchAndroidNavigationBar() {
        XCTAssertEqual(TKTabBarMetrics.barHeight, 80)
        XCTAssertEqual(TKTabBarMetrics.pillWidth, 56)
        XCTAssertEqual(TKTabBarMetrics.pillHeight, 32)
        XCTAssertEqual(TKTabBarMetrics.iconSize, 24)
        XCTAssertEqual(TKTabBarMetrics.labelGap, 4)
        XCTAssertEqual(TKTabBarMetrics.dividerHeight, 1)
        // 13 + 32 + 4 + 18 + 13 = 80: the icon column is centred in the bar.
        XCTAssertEqual(TKTabBarMetrics.pillHeight + TKTabBarMetrics.labelGap + TKTabBarMetrics.labelHeight, 54)
    }

    func testRootTabsAreTasksMapStatsWithAndroidGlyphs() {
        let items = RootView.tabItems
        XCTAssertEqual(items.map(\.tab), [.tasks, .map, .stats])
        XCTAssertEqual(items.map(\.identifier), ["tab_tasks", "tab_map", "tab_stats"])
        guard case .tk(.listChecks) = items[0].icon,
              case .map(.pin) = items[1].icon,
              case .tk(.barChart) = items[2].icon else {
            return XCTFail("icons must be ListChecks / Pin / BarChart, as on Android")
        }
        XCTAssertTrue(items.allSatisfy { !$0.title.isEmpty })
    }
}
