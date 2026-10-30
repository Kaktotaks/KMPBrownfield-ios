import Foundation
import Observation
import Shared

// TaskStore: the thin Swift adapter between SwiftUI and the shared Kotlin data layer.
//
// The data layer itself is Kotlin now (`../shared`, package `...shared.data`):
//   - `KtorTaskApi`    — HTTP via Ktor (Darwin engine on iOS), JSON via kotlinx.serialization
//   - `TaskRepository` — single in-memory source of truth, exposes `StateFlow<LoadState>`
//
// Why an adapter at all?
//   - SwiftUI can only observe Swift `@Observable` / `ObservableObject` objects. A Kotlin
//     `StateFlow` is invisible to it, and without SKIE its generic is erased in Swift
//     (`value: Any?`), so `repository.state` is not usable from Swift without casts.
//   - "Raw" interop instead: the iosMain extension `watchState { state in ... }` turns the
//     StateFlow into a plain callback (fired on the main thread, immediately with the current
//     value and on every change). This class mirrors each state into `@Observable` properties.
//   - The Kotlin `sealed interface LoadState` arrives as a protocol plus three separate classes
//     (`LoadStateLoading`, `LoadStateError`, `LoadStateLoaded`), so a Swift `switch` over it can't
//     be exhaustive. We map it once, here, to the Swift `Phase` enum the screens switch over.
//
// Next step (SKIE): `for await state in repository.state` + `onEnum(of: state)` give an
// exhaustive Swift enum and a typed AsyncSequence, so most of this file goes away.
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
    /// Subscription to the Kotlin StateFlow. `nonisolated(unsafe)` so the nonisolated `deinit`
    /// may cancel it (in Swift 5 mode there is no `isolated deinit`). The store lives for the
    /// whole app lifetime anyway; the cancel is for tests/previews and correctness.
    @ObservationIgnored nonisolated(unsafe) private var watchHandle: WatchHandle?

    init(repository: TaskRepository) {
        self.repository = repository
        apply(repository.currentState)
        watchHandle = repository.watchState { [weak self] state in
            // Kotlin calls back on the main thread (MainScope), but Swift can't know that.
            MainActor.assumeIsolated {
                self?.apply(state)
            }
        }
    }

    deinit {
        watchHandle?.cancel()
    }

    /// Kotlin `LoadState` (sealed interface → separate classes) → Swift `Phase` + tasks.
    private func apply(_ state: any LoadState) {
        if let loaded = state as? LoadStateLoaded {
            tasks = loaded.tasks
            phase = .loaded
            hasLoaded = true
        } else if state is LoadStateError {
            tasks = []
            phase = .error
        } else {
            // LoadStateLoading (no `default`-free switch possible without SKIE).
            tasks = []
            phase = .loading
        }
    }

    // MARK: - Loading

    /// Loads tasks once. Subsequent calls are no-ops after a successful load.
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    /// Loads (or re-loads after an error). Never throws: Kotlin already turns network/decoding
    /// failures into `LoadState.Error`, which arrives through `watchState`.
    func load() async {
        // Kotlin suspend fun → ObjC `load(completionHandler:)` (+ a Swift `async` overload).
        // Kotlin/Native by default only allows starting a suspend call on the MAIN thread, but an
        // imported `async` method is nonisolated, so `try await repository.load()` may hop off
        // the main actor first. Calling the completion-handler form inside
        // `withCheckedContinuation` (whose body runs on the caller's executor, i.e. MainActor)
        // guarantees the Kotlin call starts on the main thread.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            repository.load { _ in
                continuation.resume()
            }
        }
    }

    // MARK: - Queries & mutations (forwarded to Kotlin; UI updates via watchState)

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
