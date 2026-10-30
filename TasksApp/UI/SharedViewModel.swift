import Combine
import Foundation
import SwiftUI
import Shared

// SharedViewModel: the ONE generic bridge around every Kotlin ViewModel from `shared` (step 4).
// Screens do not use it directly: each per-screen Swift ViewModel (`UI/<Screen>/<Screen>ViewModel`)
// owns one and turns its `state` into display-ready values, bindings and intents.
//
// The screens' logic (filtering, stats, validation, saving) lives in Kotlin
// (`...shared.presentation`). Swift still has to:
//   1. Observe `uiState`: SwiftUI only sees Swift `ObservableObject`s, so the Kotlin
//      `StateFlow` is mirrored into the `@Published state` with a `for await` loop (SKIE turns StateFlow into a
//      typed AsyncSequence). The loop must keep running: Kotlin uses `stateIn(WhileSubscribed)`,
//      so `uiState` only updates while someone collects it.
//   2. Destroy the Kotlin ViewModel: iOS has no ViewModelStoreOwner, so `deinit` calls the iosMain
//      extension `viewModel.clear()` (cancels viewModelScope). Without it the VM leaks coroutines.
//   3. Forward UI events: `shared.send { $0.onRetry() }` (called by the Swift ViewModels).
//
// Generic over the sequence type `S` instead of naming SKIE's flow class, so the only contract is
// "an AsyncSequence of UiState" plus a way to read the current `uiState.value`.
@MainActor
final class SharedViewModel<VM: TasksViewModel, UiState>: ObservableObject {
    /// The Kotlin ViewModel. `nonisolated(unsafe)` so the nonisolated `deinit` can `clear()` it
    /// (Swift 5 mode has no `isolated deinit`); everything else uses it on the main actor.
    nonisolated(unsafe) let viewModel: VM

    /// Mirror of Kotlin `viewModel.uiState`. Swift ViewModels re-publish its changes
    /// (they forward this object's `objectWillChange`, see `TaskListViewModel.init`).
    @Published private(set) var state: UiState

    /// Reads `viewModel.uiState.value` (typed thanks to SKIE).
    private let currentValue: () -> UiState
    nonisolated(unsafe) private var observation: Task<Void, Never>?

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

// MARK: - Bindings to Kotlin state

extension SharedViewModel {
    /// A SwiftUI `Binding` that reads a field of the Kotlin `uiState` by key path and writes
    /// changes back as a Kotlin event. Writing goes through `send`, which re-reads `uiState.value`
    /// synchronously, so text fields don't lag.
    ///
    ///     var title: Binding<String> { shared.binding(\.title) { $0.onTitleChange(value: $1) } }
    func binding<T>(
        _ keyPath: KeyPath<UiState, T>,
        _ event: @escaping (VM, T) -> Void
    ) -> Binding<T> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { newValue in self.send { event($0, newValue) } }
        )
    }

    /// Same, with a conversion between the Kotlin and the SwiftUI type
    /// (e.g. Kotlin `LocalDate` ↔ Swift `Date` for `DatePicker`).
    func binding<T, U>(
        _ keyPath: KeyPath<UiState, T>,
        get toUI: @escaping (T) -> U,
        set event: @escaping (VM, U) -> Void
    ) -> Binding<U> {
        Binding(
            get: { toUI(self.state[keyPath: keyPath]) },
            set: { newValue in self.send { event($0, newValue) } }
        )
    }
}

/// `sheet(item:)` needs Identifiable; a class gets `id = ObjectIdentifier(self)` for free.
extension SharedViewModel: Identifiable {}

// One alias per screen: Kotlin ViewModel + its Kotlin UiState.
// The Swift per-screen ViewModels (TaskListViewModel, ...) have the same names as the Kotlin ones,
// so the Kotlin types are module-qualified here: `Shared.TaskListViewModel`. Inside the app module
// an unqualified name means the Swift class (local declarations shadow imported ones).
typealias TaskListModel = SharedViewModel<Shared.TaskListViewModel, TaskListUiState>
typealias TaskDetailModel = SharedViewModel<Shared.TaskDetailViewModel, TaskDetailUiState>
typealias TaskEditorModel = SharedViewModel<Shared.TaskEditorViewModel, TaskEditorUiState>
/// `StatsUiState` is a Kotlin sealed interface → ObjC protocol → existential.
typealias StatsModel = SharedViewModel<Shared.StatsViewModel, any StatsUiState>
