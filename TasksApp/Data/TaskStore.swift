import Foundation
import Observation
import Shared

// TaskStore: the thin Swift adapter between SwiftUI and the shared Kotlin data layer.
//
// The data layer itself is Kotlin (`../shared`, package `...shared.data`):
//   - `KtorTaskApi`    — HTTP via Ktor (Darwin engine on iOS), JSON via kotlinx.serialization
//   - `TaskRepository` — single in-memory source of truth, exposes `StateFlow<LoadState>`
//
// Why an adapter is still needed: SwiftUI observes only Swift `@Observable` objects, not a
// Kotlin StateFlow. But with SKIE (step 3) the adapter is just a typed `for await` loop:
//   - `repository.state` is an `AsyncSequence` of `LoadState` (SKIE keeps the generic);
//   - `onEnum(of: state)` turns the sealed `LoadState` into a Swift enum → exhaustive switch;
//   - `try await repository.load()` works from any thread and cancels the Kotlin coroutine
//     when the Swift Task is cancelled.
// Before SKIE (step 2) this file needed a hand-written `watchState` callback bridge in iosMain,
// `as?`/`is` checks without exhaustiveness, and a continuation to start `load()` on the main thread.
@MainActor
@Observable
final class TaskStore {
    /// Swift-friendly mirror of Kotlin `LoadState` (the tasks themselves live in `tasks`).
    enum Phase: Equatable {
        case loading
        case error
        case loaded
    }

    private(set) var phase: Phase = .loading
    /// Tasks of the current state (empty while loading or on error, like Kotlin `repository.tasks`).
    private(set) var tasks: [TaskItem] = []

    @ObservationIgnored private let repository: TaskRepository
    @ObservationIgnored private var hasLoaded = false
    /// The `for await` observation loop. `nonisolated(unsafe)` so the nonisolated `deinit` may
    /// cancel it (Swift 5 mode has no `isolated deinit`). The store lives for the app lifetime.
    @ObservationIgnored nonisolated(unsafe) private var observation: Task<Void, Never>?

    init(repository: TaskRepository) {
        self.repository = repository
        apply(repository.state.value)
        let states = repository.state
        // The Task inherits the main actor from this init, so `apply` runs on the main actor.
        observation = Task { [weak self] in
            for await state in states {
                self?.apply(state)
            }
        }
    }

    deinit {
        observation?.cancel()
    }

    /// Kotlin sealed `LoadState` → Swift `Phase` + tasks. Exhaustive thanks to SKIE's `onEnum`.
    private func apply(_ state: LoadState) {
        switch onEnum(of: state) {
        case .loading:
            tasks = []
            phase = .loading
        case .error:
            tasks = []
            phase = .error
        case .loaded(let loaded):
            tasks = loaded.tasks
            phase = .loaded
            hasLoaded = true
        }
    }

    // MARK: - Loading

    /// Loads tasks once. Subsequent calls are no-ops after a successful load.
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    /// Loads (or re-loads after an error). Kotlin turns network/decoding failures into
    /// `LoadState.Error`, which arrives through `repository.state`; only cancellation can throw.
    func load() async {
        try? await repository.load()
    }

    // MARK: - Queries & mutations (forwarded to Kotlin; UI updates via repository.state)

    func task(id: Int32) -> TaskItem? {
        repository.task(id: id)
    }

    @discardableResult
    func add(title: String, notes: String, priority: Priority, dueDate: LocalDate) -> TaskItem {
        repository.add(title: title, notes: notes, priority: priority, dueDate: dueDate)
    }

    /// Kotlin trims the title before saving.
    func update(_ task: TaskItem) {
        repository.update(task: task)
    }

    func toggleDone(id: Int32) {
        repository.toggle(id: id)
    }

    func delete(id: Int32) {
        repository.delete(id: id)
    }
}
