# Tasks — iOS

Native SwiftUI implementation of the Tasks app described in `../SPEC.md`.
This is a Kotlin Multiplatform brownfield practice. Step 1: the Swift `Domain/` layer was
replaced by the KMP library in `../shared`. Step 2: the Swift `Data/` layer (URLSession API,
Codable DTO, repository) was replaced too — see "Shared (KMP) integration". Step 3: SKIE.
Step 4: the screen ViewModels come from `shared` too; Swift keeps only SwiftUI views and thin
wrappers — see "Shared ViewModels (step 4)". Step 5: UI-only SwiftUI views over per-screen Swift
view models — see "Screen models (step 5)". An Android twin lives in `../android-app` and follows the same spec.

- iOS 17.0+, Swift 5 mode, SwiftUI app lifecycle, no third-party Swift dependencies
- Domain + Data + ViewModels from Kotlin: `Shared.framework` built from `../shared` on every Xcode build
- Observation framework (`@Observable`) for the view models and the generic `SharedViewModel` bridge
- Data: `GET https://jsonplaceholder.typicode.com/todos?_limit=20`, loaded once on launch,
  then all changes live in memory

## Structure

```
TasksApp.xcodeproj           Xcode project (folder-synchronized groups) + shared scheme
TasksApp/
  App/                       TasksMainApp (@main), RootView (TabView: Tasks, Stats),
                             AppDependencies (repository, validator, load on start,
                             Kotlin VM + view model factories)
  Shared+Interop.swift       typealiases + Date <-> LocalDate helpers for the Kotlin framework
  UI/SharedViewModel.swift   generic @Observable bridge around a Kotlin ViewModel (observe + clear)
  UI/TaskList/               TaskListViewModel, TaskRowItem, list screen (+ small subviews), row
  UI/TaskDetail/             TaskDetailViewModel, detail screen
  UI/TaskEditor/             TaskEditorViewModel, editor sheet
  UI/Stats/                  StatsViewModel (+ StatsSummary), stats screen
  UI/Components/             PriorityBadge, Priority+UI (badge color), DueDateLine,
                             loading/error views, SegmentedPicker, PickerOption
  Assets.xcassets
TasksAppTests/               XCTest smoke tests for the Kotlin interop (SharedInteropTests,
                             SharedDataInteropTests with a Swift fake of the Kotlin TaskApi,
                             SharedViewModelInteropTests) + ViewModelTests (mapping, bindings)
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
- **UI** — Swift: one folder per screen; each SwiftUI screen holds a Swift view model that owns
  its Kotlin ViewModel through a `SharedViewModel` bridge, all created by `AppDependencies`.

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

What stays native (Swift): SwiftUI views, navigation (`NavigationStack`, `navigationDestination`,
sheets, `dismiss`), confirmation dialog, and the view models below.

## Screen models (step 5)

SwiftUI views are **UI only**: just `body` — no private funcs/computed sub-views, no computed
`Binding`s, no `switch onEnum`, no mapping/formatting, no closures that talk to the Kotlin VM.
Everything else moved into a per-screen Swift **view model** ("local ViewModel", SwiftUI-style).

```
SwiftUI View (UI only)              TaskListScreen, TaskDetailScreen, TaskEditorScreen, StatsScreen
   │  @State / @Bindable, $model.x
   ▼
ViewModel (Swift, @MainActor      TaskListViewModel, TaskDetailViewModel,
 @Observable)                       TaskEditorViewModel, StatsViewModel
   │  platform presentation: display-ready state, bindings, formatting,
   │  Date ↔ LocalDate, picker options, navigation/sheet factories
   ▼
SharedViewModel<VM, UiState>        generic bridge: mirrors `uiState` (for await), `send {}`,
   │                                `clear()` on deinit
   ▼
Kotlin ViewModel (shared)           business/presentation logic shared with Android
```

Each view model exposes:
- **display-ready state** — e.g. `TaskListViewModel.content`
  (`.loading / .error / .empty / .loaded([TaskRowItem])`, mapped from the Kotlin sealed type via
  `onEnum` here), `TaskRowItem` (`dueText` "Due 29 Oct 2026" via shared `DateFormatting`,
  `isOverdue`, `toggleTitle` "Mark as done"/"Mark as active"), `TaskDetailViewModel.details`
  ("Done"/"Active", notes or `nil` → "No notes"), editor `screenTitle` / `canSave` /
  `errorMessages`, `StatsSummary` rows;
- **bindable properties** — computed properties whose setter sends the Kotlin event, so views
  write `$model.status`, `$model.sort`, `$model.query`, `$model.title`, `$model.notes`,
  `$model.priority`, `$model.dueDate` (a Swift `Date`; `LocalDate` conversion lives in the model).
  The editor's setters go through `send`, which re-reads the `MutableStateFlow` synchronously, so
  text fields don't lag. The search text is stored in the list model and forwarded to Kotlin on
  set (the list's `uiState` is `stateIn`, i.e. asynchronous);
- **intents** — `retry()`, `toggle(id:)`, `toggleDone()`, `delete()`, `save() -> Bool`,
  `showNewTaskEditor()` / `showEditor()` (set the `sheet(item:)` model → one Kotlin editor VM per
  presentation), `makeDetail(taskId:)` for `navigationDestination`; picker option lists
  (`statusOptions`, `sortOptions`, `priorityOptions` — Kotlin enums are not `CaseIterable`).

Views only branch on the display state and compose small View structs (`StatusFilterBar`,
`SortMenu`, `TaskRowsList`, `TaskDetailContent`, `StatsSummaryList`, `SegmentedPicker`). View-local
presentational state stays in the view (`@State isConfirmingDelete`, `@Environment(\.dismiss)`),
and inline closures call a single intent (`{ model.retry() }`, `{ if model.save() { dismiss() } }`).
`PriorityBadge`'s color comes from `Priority.badgeColor` (`UI/Components/Priority+UI.swift`).
`AppDependencies` builds view models (`makeTaskListViewModel()` …) and passes itself to the
ones that create child models (list → detail/editor, detail → editor).

## Run

1. Open `TasksApp.xcodeproj` in Xcode (16 or newer — the project uses objectVersion 77).
2. Pick an iOS 17+ simulator.
3. Cmd+R to run, Cmd+U to run the unit tests.

For a physical device, select your team under Signing & Capabilities (development team is empty).

## Next KMP steps

Ship `shared` as an XCFramework via SPM instead of the Run Script.
