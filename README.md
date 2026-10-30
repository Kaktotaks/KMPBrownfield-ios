# Tasks — iOS

Native SwiftUI implementation of the Tasks app described in `../SPEC.md`.
This is a Kotlin Multiplatform brownfield practice. Step 1: the Swift `Domain/` layer was
replaced by the KMP library in `../shared`. Step 2: the Swift `Data/` layer (URLSession API,
Codable DTO, repository) was replaced too — see "Shared (KMP) integration". Step 3: SKIE.
Step 4: the screen ViewModels come from `shared` too; Swift keeps only SwiftUI views and thin
wrappers — see "Shared ViewModels (step 4)". An Android twin lives in `../android-app` and follows the same spec.

- iOS 17.0+, Swift 5 mode, SwiftUI app lifecycle, no third-party Swift dependencies
- Domain + Data + ViewModels from Kotlin: `Shared.framework` built from `../shared` on every Xcode build
- Observation framework (`@Observable`) for the generic `SharedViewModel` wrapper
- Data: `GET https://jsonplaceholder.typicode.com/todos?_limit=20`, loaded once on launch,
  then all changes live in memory

## Structure

```
TasksApp.xcodeproj           Xcode project (folder-synchronized groups) + shared scheme
TasksApp/
  App/                       TasksMainApp (@main), RootView (TabView: Tasks, Stats),
                             AppDependencies (repository, validator, load on start, VM factories)
  Shared+Interop.swift       typealiases + Date <-> LocalDate helpers for the Kotlin framework
  UI/SharedViewModel.swift   generic @Observable wrapper around a Kotlin ViewModel
  UI/TaskList/               list screen + row
  UI/TaskDetail/             detail screen
  UI/TaskEditor/             editor sheet
  UI/Stats/                  stats screen
  UI/Components/             PriorityBadge, DueDateLine, loading/error views
  Assets.xcassets
TasksAppTests/               XCTest smoke tests for the Kotlin interop (SharedInteropTests,
                             SharedDataInteropTests with a Swift fake of the Kotlin TaskApi,
                             SharedViewModelInteropTests)
```

Layers:
- **Domain** — Kotlin, from `../shared` (`import Shared`): `TaskItem`, `Priority`,
  `TaskValidator`, `ValidationError`, `TaskFilter` (+ `StatusFilter`, `SortOrder`),
  `StatsCalculator`, `TaskStats`, `DateProvider`/`SystemDateProvider`, `DateFormatting`,
  `TodoMapper`. Its unit tests live in `shared/src/commonTest`.
- **Data** — Kotlin, from `../shared` (`...shared.data`): `TaskApi` (interface, fakeable from
  Swift) / `KtorTaskApi`, `TaskRepository` (single in-memory source of truth, `StateFlow<LoadState>`).
  Swift owns one instance in `AppDependencies`.
- **Presentation** — Kotlin, from `../shared` (`...shared.presentation`): `TaskListViewModel`,
  `TaskDetailViewModel`, `TaskEditorViewModel`, `StatsViewModel` (androidx `ViewModel`, `StateFlow` uiState).
- **UI** — Swift: one folder per screen; each screen holds its Kotlin ViewModel inside a
  `SharedViewModel` wrapper created by `AppDependencies`.

## Shared (KMP) integration

Direct integration (no CocoaPods / SPM): the `TasksApp` target has a first build phase
**"Compile Kotlin Framework"** (before *Compile Sources*) that runs:

```sh
if [ "YES" = "$OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED" ]; then
  echo "Skipping Gradle build task invocation due to OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED environment variable set to \"YES\""
  exit 0
fi
cd "$SRCROOT/../shared"
./gradlew :embedAndSignAppleFrameworkForXcode
```

Gradle builds `Shared.framework` (static) for the current SDK/arch/configuration and puts it
where Xcode links it from, so the Swift code just does `import Shared`.

Requirements:
- `../shared` must sit **next to** `ios-app` (the script uses `$SRCROOT/../shared`).
- A **JDK 17+** must be installed on the machine (Gradle runs from the Xcode build).
  The first build downloads Gradle/Kotlin/Native toolchains and takes a few minutes.
- `ENABLE_USER_SCRIPT_SANDBOXING = NO` (project level): the script writes outside the sandbox.

Swift-side notes:
- Kotlin `Task` is exported as **`TaskItem`** (`@ObjCName(swiftName = "TaskItem")`), because
  `Task` would clash with Swift Concurrency's `Task` ("'Task' is ambiguous"). So the app uses
  plain `Task { }` for concurrency again.
- Kotlin `Int` is `Int32` in Swift (ids, stats); Kotlin enums are classes (switch needs `default`,
  no `allCases`); `object`s are reached via `.shared`; default arguments are not exported.
- kotlinx-datetime `LocalDate` arrives as `Kotlinx_datetimeLocalDate`; `Shared+Interop.swift`
  aliases it to `LocalDate` and converts to/from `Date` via Kotlin `IosDates`. Foundation's
  `SortOrder` is shadowed there by `typealias SortOrder = Shared.SortOrder`.

### Data layer (step 2)

- Networking is Ktor in `commonMain`; on iOS it runs on the **Darwin engine** (NSURLSession under
  the hood), JSON via kotlinx.serialization. `TodoDto` is `internal` in Kotlin — Swift only sees
  `TaskItem`. The app builds `TaskRepository(api: KtorTaskApi(), dateProvider: SystemDateProvider.shared)`.
- **`TaskStore`** (`Data/TaskStore.swift`, removed in step 4) existed because SwiftUI can't observe a Kotlin `StateFlow`
  (and without SKIE its generic is erased: `value: Any?`). It subscribes via the iosMain extension
  `repository.watchState { state in ... }` (callback on the main thread, returns a `WatchHandle`
  cancelled in `deinit`) and mirrors the state into `@Observable` `phase` + `tasks`. Mutations
  (`add/update/toggleDone/delete`) are forwarded to Kotlin; the UI updates through the callback.
- Raw interop limitations (no SKIE):
  - `sealed interface LoadState` → protocol + classes `LoadStateLoading`/`LoadStateError`
    (`.shared`) and `LoadStateLoaded` (`.tasks`); no exhaustive `switch`, so `TaskStore` maps it
    with `is`/`as?` to the Swift `enum Phase`.
  - `suspend fun load()` → `load(completionHandler:)` + an `async` overload. Kotlin/Native by
    default requires suspend calls to *start* on the main thread, while imported `async` methods
    are nonisolated and may hop off the main actor, so `TaskStore.load()` calls the
    completion-handler form inside `withCheckedContinuation` (runs on the calling MainActor).
  - A Swift class can implement the Kotlin `TaskApi` (ObjC protocol, `NSObject` subclass):
    `fetchTasks(today:completionHandler:)` — see `FakeTaskApi` in the tests.

### SKIE (step 3)

`shared` now applies the SKIE plugin, which generates Swift wrappers into `Shared.framework`.
What changed on the Swift side (the "raw interop" notes above are kept for comparison):

| Before (step 2, raw ObjC) | After (step 3, SKIE) |
|---|---|
| `watchState { }` callback bridge in iosMain + `WatchHandle` | `for await state in repository.state` (typed `AsyncSequence`) |
| `state.value` was `Any?`, so `currentState` helper | `repository.state.value` is typed |
| `is`/`as?` checks on `LoadStateLoaded` / `LoadStateError` | `switch onEnum(of: state)` — exhaustive |
| `load(completionHandler:)` in `withCheckedContinuation` (main-thread start) | `try await repository.load()` from any thread, cancellation propagates |
| Kotlin enums are classes → `switch` needs `default` | real Swift enums → exhaustive `switch` (`PriorityBadge`) |

## Shared ViewModels (step 4)

The Swift ViewModels (`UI/*/…ViewModel.swift`) and the `TaskStore` adapter were removed. Filtering
(`TaskFilter`), stats (`StatsCalculator`), live validation (`TaskValidator`), saving and the
loading/error/retry states now live in the Kotlin ViewModels in `shared/.../presentation` — the
same classes the Android app uses.

**`SharedViewModel<VM, UiState>`** (`UI/SharedViewModel.swift`) is the only Swift glue, one
generic class for all four screens (`TaskListModel`, `TaskDetailModel`, `TaskEditorModel`,
`StatsModel` typealiases). It:
- **observes `uiState`**: starts `Task { for await s in vm.uiState { state = s } }` in `init`
  (initial value from `vm.uiState.value`), mirroring it into an `@Observable` `state` SwiftUI can
  track. The loop must keep running: Kotlin uses `stateIn(WhileSubscribed)`, so `uiState` only
  updates while collected;
- **destroys the Kotlin VM**: iOS has no `ViewModelStoreOwner`, so `deinit` cancels the loop and
  calls `viewModel.clear()` (iosMain extension → cancels `viewModelScope`). Without it the VMs and
  their subscriptions to `repository.state` would leak;
- **forwards events**: `model.send { $0.onToggle(id: id) }` calls the Kotlin VM and re-reads
  `uiState.value` synchronously (keeps text fields bound to the editor's `MutableStateFlow` smooth).

`AppDependencies` (`App/`) owns one `TaskRepository` + `TaskValidator(dateProvider:)`, loads tasks
once on start (`RootView.task`) and has a factory per Kotlin VM. Tab and detail screens create their
model in `@State`; the editor model is created by the presenting screen when the sheet opens
(`sheet(item:)`), so there is exactly one Kotlin `TaskEditorViewModel` per presentation, cleared
when the sheet closes. New task → `TaskEditorViewModel.companion.NEW_TASK_ID`.

What stays native (Swift):
- SwiftUI views, navigation (`NavigationStack`, `navigationDestination`, sheets, `dismiss`),
  confirmation dialog;
- `Binding`s: read from `model.state`, write as a Kotlin event; the search text is local `@State`
  forwarded with `onChange` (the list's `uiState` updates asynchronously);
- `Date` ↔ `LocalDate` for the `DatePicker` (`Shared+Interop.swift`, Kotlin `IosDates`);
- segment/menu order of enum pickers (Kotlin enums are not `CaseIterable` in Swift).

## Run

1. Open `TasksApp.xcodeproj` in Xcode (16 or newer — the project uses objectVersion 77).
2. Pick an iOS 17+ simulator.
3. Cmd+R to run, Cmd+U to run the unit tests.

For a physical device, select your team under Signing & Capabilities (development team is empty).

## Next KMP steps

Ship `shared` as an XCFramework via SPM instead of the Run Script.
