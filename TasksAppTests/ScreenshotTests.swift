import SwiftUI
import UIKit
import XCTest
@testable import TasksApp

/// Opt-in screenshot generator (skipped unless `SCREENSHOT_DIR` is set), used for the design-handoff comparison:
///
///     TEST_RUNNER_SCREENSHOT_DIR=/path xcodebuild test -project TasksApp.xcodeproj -scheme TasksApp \
///         -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TasksAppTests/ScreenshotTests
///
/// It renders the real SwiftUI screens against the fake-data `AppDependencies.preview` (same sample tasks as the
/// handoff reference) at 393 x 852, in light and dark, and writes PNGs.
@MainActor
final class ScreenshotTests: XCTestCase {
    private var outputDirectory: URL? {
        ProcessInfo.processInfo.environment["SCREENSHOT_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    private func snapshot<V: View>(_ name: String, dark: Bool = false, settle: Double = 1.6, @ViewBuilder _ view: () -> V) async throws {
        let directory = try XCTUnwrap(outputDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let host = UIHostingController(rootView: view())
        host.overrideUserInterfaceStyle = dark ? .dark : .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        try await Task.sleep(nanoseconds: UInt64(settle * 1_000_000_000))
        let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try XCTUnwrap(image.pngData()).write(to: directory.appendingPathComponent("\(name).png"))
    }

    func testCaptureScreens() async throws {
        try XCTSkipUnless(outputDirectory != nil, "Set SCREENSHOT_DIR (TEST_RUNNER_SCREENSHOT_DIR) to generate screenshots.")

        for dark in [false, true] {
            let suffix = dark ? "-Dark" : ""
            let app = AppDependencies.preview()
            try await snapshot("List\(suffix)", dark: dark) {
                PreviewHost(app: app) { TaskListScreen(model: $0.makeTaskListViewModel()) }
            }
            try await snapshot("Detail\(suffix)", dark: dark) {
                PreviewHost(app: app) { app in NavigationStack { TaskDetailScreen(model: app.makeTaskDetailViewModel(taskId: 5)) } }
            }
            try await snapshot("Stats\(suffix)", dark: dark) {
                PreviewHost(app: app) { StatsScreen(model: $0.makeStatsViewModel()) }
            }
            try await snapshot("Editor\(suffix)", dark: dark) {
                PreviewHost(app: app) { app in
                    let editor = app.makeTaskEditorViewModel(taskId: nil)
                    editor.notes.wrappedValue = "Ask about the express option and bring the old passport."
                    editor.priority.wrappedValue = .high
                    // Past due date + empty title = the two validation errors of the reference screen.
                    editor.dueDate.wrappedValue = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
                    return TaskEditorScreen(model: editor)
                }
            }
            try await snapshot("Empty\(suffix)", dark: dark) {
                PreviewHost(app: .preview(tasks: [])) { TaskListScreen(model: $0.makeTaskListViewModel()) }
            }
            try await snapshot("Error\(suffix)", dark: dark) {
                PreviewHost(app: .preview(fails: true)) { TaskListScreen(model: $0.makeTaskListViewModel()) }
            }
            try await snapshot("Loading\(suffix)", dark: dark) {
                PreviewHost(app: .preview(), load: false) { TaskListScreen(model: $0.makeTaskListViewModel()) }
            }
        }
    }
}
