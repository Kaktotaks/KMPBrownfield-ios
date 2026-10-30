# Tasks — iOS

Native SwiftUI implementation of the Tasks app described in `../SPEC.md`.
This is a Kotlin Multiplatform brownfield practice. Step 1: the Swift `Domain/` layer was
replaced by the KMP library in `../shared`. Step 2: the Swift `Data/` layer (URLSession API,
Codable DTO, repository) was replaced too — see "Shared (KMP) integration". UI is still SwiftUI. An Android twin lives in `../android-app` and follows the same spec.

- iOS 17.0+, Swift 5 mode, SwiftUI app lifecycle, no third-party Swift dependencies
- Domain + Data from Kotlin: `Shared.framework` built from `../shared` on every Xcode build
- Observation framework (`@Observable`) for the `TaskStore` adapter and every ViewModel
- Data: `GET https://jsonplaceholder.typicode.com/todos?_limit=20`, loaded once on launch,
  then all changes live in memory

## Structure

```
TasksApp.xcodeproj           Xcode project (folder-synchronized groups) + shared scheme
TasksApp/
  App/                       TasksMainApp (@main), RootView (TabView: Tasks, Stats)
  Shared+Interop.swift       typealiases + Date <-> LocalDate helpers for the Kotlin framework
  Data/TaskStore.swift       @Observable adapter over the Kotlin TaskRepository
  UI/TaskList/               list screen, row, ViewModel
  UI/TaskDetail/             detail screen + ViewModel
  UI/TaskEditor/             editor sheet + ViewModel
  UI/Stats/                  stats screen + ViewModel
  UI/Components/             PriorityBadge, DueDateLine, loading/error views
  Assets.xcassets
TasksAppTests/               XCTest smoke tests for the Kotlin interop (SharedInteropTests,
                             SharedDataInteropTests with a Swift fake of the Kotlin TaskApi)
```

Layers:
- **Domain** — Kotlin, from `../shared` (`import Shared`): `TaskItem`, `Priority`,
  `TaskValidator`, `ValidationError`, `TaskFilter` (+ `StatusFilter`, `SortOrder`),
  `StatsCalculator`, `TaskStats`, `DateProvider`/`SystemDateProvider`, `DateFormatting`,
  `TodoMapper`. Its unit tests live in `shared/src/commonTest`.
- **Data** — Kotlin, from `../shared` (`...shared.data`): `TaskApi` (interface, fakeable from
  Swift) / `KtorTaskApi`, `TaskRepository` (single in-memory source of truth, `StateFlow<LoadState>`).
  Swift keeps only `TaskStore`, a thin `@Observable` adapter injected via `.environment(...)`.
- **UI** — Swift: one folder per screen; each screen owns an `@Observable` ViewModel that
  receives the `TaskStore` and the `DateProvider` through its initializer.

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
- **`TaskStore`** (`Data/TaskStore.swift`) exists because SwiftUI can't observe a Kotlin `StateFlow`
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
- **Next: SKIE.** `for await state in repository.state` + `onEnum(of:)` give a typed
  AsyncSequence and an exhaustive enum; Kotlin suspend functions become proper Swift `async`.
  `watchState`/`WatchHandle` and most of `TaskStore` can then be removed.

## Run

1. Open `TasksApp.xcodeproj` in Xcode (16 or newer — the project uses objectVersion 77).
2. Pick an iOS 17+ simulator.
3. Cmd+R to run, Cmd+U to run the unit tests.

For a physical device, select your team under Signing & Capabilities (development team is empty).

## Next KMP steps

Add SKIE to `shared` to replace the raw interop (`watchState`, `LoadState` casts, continuation
around `load()`). `UI/` and `App/` stay native SwiftUI and consume the shared code through thin adapters.
