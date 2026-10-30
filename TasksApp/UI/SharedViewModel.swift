import Foundation
import Observation
import Shared

// SharedViewModel: the ONE Swift wrapper around every Kotlin ViewModel from `shared` (step 4).
//
// The screens' logic (filtering, stats, validation, saving) lives in Kotlin
// (`...shared.presentation`). Swift still has to:
//   1. Observe `uiState`: SwiftUI only sees Swift `@Observable` objects, so the Kotlin
//      `StateFlow` is mirrored into `state` with a `for await` loop (SKIE turns StateFlow into a
//      typed AsyncSequence). The loop must keep running: Kotlin uses `stateIn(WhileSubscribed)`,
//      so `uiState` only updates while someone collects it.
//   2. Destroy the Kotlin ViewModel: iOS has no ViewModelStoreOwner, so `deinit` calls the iosMain
//      extension `viewModel.clear()` (cancels viewModelScope). Without it the VM leaks coroutines.
//   3. Forward UI events: `model.send { $0.onRetry() }` (or call `model.viewModel` directly).
//
// Generic over the sequence type `S` instead of naming SKIE's flow class, so the only contract is
// "an AsyncSequence of UiState" plus a way to read the current `uiState.value`.
@MainActor
@Observable
final class SharedViewModel<VM: TasksViewModel, UiState> {
    /// The Kotlin ViewModel. `nonisolated(unsafe)` so the nonisolated `deinit` can `clear()` it
    /// (Swift 5 mode has no `isolated deinit`); everything else uses it on the main actor.
    nonisolated(unsafe) let viewModel: VM

    /// Mirror of Kotlin `viewModel.uiState`; SwiftUI views read this.
    private(set) var state: UiState

    /// Reads `viewModel.uiState.value` (typed thanks to SKIE).
    @ObservationIgnored private let currentValue: () -> UiState
    @ObservationIgnored nonisolated(unsafe) private var observation: Task<Void, Never>?

    init<S: AsyncSequence>(
        _ viewModel: VM,
        states: S,
        value: @escaping () -> UiState
    ) where S.Element == UiState {
        self.viewModel = viewModel
        self.currentValue = value
        self.state = value()
        // The Task inherits the main actor from this init, so `state` is written on the main actor.
        observation = Task { [weak self] in
            do {
                for try await newState in states {
                    self?.state = newState
                }
            } catch {
                // SKIE flows don't throw; only reached on cancellation.
            }
        }
    }

    deinit {
        observation?.cancel()
        viewModel.clear()
    }

    /// Sends a UI event to the Kotlin ViewModel and re-reads `uiState.value` right away.
    /// Synchronous re-read matters for text fields bound to a MutableStateFlow (editor):
    /// waiting for the async `for await` hop would make the TextField lag/jump.
    @discardableResult
    func send<T>(_ event: (VM) -> T) -> T {
        let result = event(viewModel)
        state = currentValue()
        return result
    }
}

/// `sheet(item:)` needs Identifiable; a class gets `id = ObjectIdentifier(self)` for free.
extension SharedViewModel: Identifiable {}

// One alias per screen: Kotlin ViewModel + its Kotlin UiState.
typealias TaskListModel = SharedViewModel<TaskListViewModel, TaskListUiState>
typealias TaskDetailModel = SharedViewModel<TaskDetailViewModel, TaskDetailUiState>
typealias TaskEditorModel = SharedViewModel<TaskEditorViewModel, TaskEditorUiState>
/// `StatsUiState` is a Kotlin sealed interface → ObjC protocol → existential.
typealias StatsModel = SharedViewModel<StatsViewModel, any StatsUiState>
