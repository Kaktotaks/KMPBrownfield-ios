#if DEBUG
import SwiftUI
import Shared

/// Fake data for `#Preview`s (ideas from the test fakes `FakeTaskApi` / `FixedDateProvider`, app-side copies).
///
/// Interop gotcha: to *implement* a Kotlin `suspend` interface in Swift, implement SKIE's `__`-prefixed requirement.
final class PreviewTaskApi: NSObject, TaskApi {
    private let result: Result<[TaskItem], Error>

    init(result: Result<[TaskItem], Error>) {
        self.result = result
    }

    func __fetchTasks(today: LocalDate) async throws -> [TaskItem] {
        try result.get()
    }
}

/// Fixed "today" = 2 Nov 2026 (the day of the design handoff), so the overdue state is stable in previews.
final class PreviewDateProvider: NSObject, DateProvider {
    func today() -> LocalDate { LocalDate(year: 2026, month: 11, day: 2) }
}

private struct PreviewError: Error {}

extension AppDependencies {
    /// Sample tasks matching the design handoff reference screens.
    static var previewTasks: [TaskItem] {
        func day(_ d: Int32, _ m: Int32 = 11) -> LocalDate { LocalDate(year: 2026, month: m, day: d) }
        return [
            TaskItem(id: 1, title: "Renew passport photos", notes: "Ask about the express option and bring the old passport.",
                     priority: .high, dueDate: day(31, 10), isDone: false),
            TaskItem(id: 2, title: "Pay electricity bill", notes: "", priority: .low, dueDate: day(1), isDone: true),
            TaskItem(id: 3, title: "Review pull request for offline sync", notes: "", priority: .medium, dueDate: day(2), isDone: true),
            TaskItem(id: 4, title: "Call the dentist to reschedule", notes: "", priority: .medium, dueDate: day(4), isDone: false),
            TaskItem(id: 5, title: "Prepare sprint demo slides",
                     notes: "Cover the offline sync work and the new Stats tab. Pull the latest crash-free numbers from the dashboard before Thursday.",
                     priority: .high, dueDate: day(5), isDone: false),
            TaskItem(id: 6, title: "Buy groceries for the week", notes: "", priority: .low, dueDate: day(8), isDone: false),
        ]
    }

    /// Fake-data graph for previews: a stub `TaskApi` + a fixed date. `result: .failure` previews the error state.
    static func preview(tasks: [TaskItem]? = nil, fails: Bool = false, voiceAudio: VoiceAudio = .live) -> AppDependencies {
        let tasks = tasks ?? previewTasks
        let provider = PreviewDateProvider()
        let api = PreviewTaskApi(result: fails ? .failure(PreviewError()) : .success(tasks))
        // In-memory SQLite (shared createInMemoryRepository): every preview starts seeded from `api`, tasks.db is untouched.
        let repository = FakeStorage.makeRepository(api: api, dateProvider: provider)
        return AppDependencies(repository: repository, dateProvider: provider, voiceAudio: voiceAudio)
    }
}

/// Loads the fake repository (unless `load` is false → stays in the Loading state), then shows the screen.
struct PreviewHost<Content: View>: View {
    let app: AppDependencies
    var load = true
    @ViewBuilder let content: (AppDependencies) -> Content

    var body: some View {
        content(app)
            .task { if load { await app.loadIfNeeded() } }
    }
}

// MARK: - Previews (every screen, light + dark)

#Preview("List · light") {
    PreviewHost(app: .preview()) { TaskListScreen(model: $0.makeTaskListViewModel()) }
}

#Preview("List · dark") {
    PreviewHost(app: .preview()) { TaskListScreen(model: $0.makeTaskListViewModel()) }
        .preferredColorScheme(.dark)
}

#Preview("List loading · light") {
    PreviewHost(app: .preview(), load: false) { TaskListScreen(model: $0.makeTaskListViewModel()) }
}

#Preview("List loading · dark") {
    PreviewHost(app: .preview(), load: false) { TaskListScreen(model: $0.makeTaskListViewModel()) }
        .preferredColorScheme(.dark)
}

#Preview("List empty · light") {
    PreviewHost(app: .preview(tasks: [])) { TaskListScreen(model: $0.makeTaskListViewModel()) }
}

#Preview("List empty · dark") {
    PreviewHost(app: .preview(tasks: [])) { TaskListScreen(model: $0.makeTaskListViewModel()) }
        .preferredColorScheme(.dark)
}

#Preview("List error · light") {
    PreviewHost(app: .preview(fails: true)) { TaskListScreen(model: $0.makeTaskListViewModel()) }
}

#Preview("List error · dark") {
    PreviewHost(app: .preview(fails: true)) { TaskListScreen(model: $0.makeTaskListViewModel()) }
        .preferredColorScheme(.dark)
}

#Preview("Detail · light") {
    PreviewHost(app: .preview()) { app in
        NavigationStack { TaskDetailScreen(model: app.makeTaskDetailViewModel(taskId: 5)) }
    }
}

#Preview("Detail overdue · dark") {
    PreviewHost(app: .preview()) { app in
        NavigationStack { TaskDetailScreen(model: app.makeTaskDetailViewModel(taskId: 1)) }
    }
    .preferredColorScheme(.dark)
}

#Preview("Detail not found · light") {
    PreviewHost(app: .preview()) { app in
        NavigationStack { TaskDetailScreen(model: app.makeTaskDetailViewModel(taskId: 99)) }
    }
}

#Preview("Detail not found · dark") {
    PreviewHost(app: .preview()) { app in
        NavigationStack { TaskDetailScreen(model: app.makeTaskDetailViewModel(taskId: 99)) }
    }
    .preferredColorScheme(.dark)
}

#Preview("Editor with errors · light") {
    PreviewHost(app: .preview()) { app in
        let editor = app.makeTaskEditorViewModel(taskId: nil)
        editor.dueDate.wrappedValue = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        return TaskEditorScreen(model: editor)
    }
}

#Preview("Editor edit · dark") {
    PreviewHost(app: .preview()) { app in
        TaskEditorScreen(model: app.makeTaskEditorViewModel(taskId: 5))
    }
    .preferredColorScheme(.dark)
}

#Preview("Stats · light") {
    PreviewHost(app: .preview()) { StatsScreen(model: $0.makeStatsViewModel()) }
}

#Preview("Stats · dark") {
    PreviewHost(app: .preview()) { StatsScreen(model: $0.makeStatsViewModel()) }
        .preferredColorScheme(.dark)
}

#Preview("Stats zero · light") {
    PreviewHost(app: .preview(tasks: [])) { StatsScreen(model: $0.makeStatsViewModel()) }
}

#Preview("Stats loading · dark") {
    PreviewHost(app: .preview(), load: false) { StatsScreen(model: $0.makeStatsViewModel()) }
        .preferredColorScheme(.dark)
}

#Preview("Stats error · light") {
    PreviewHost(app: .preview(fails: true)) { StatsScreen(model: $0.makeStatsViewModel()) }
}
#endif
