# Tasks — iOS

Native SwiftUI implementation of the Tasks app described in `../SPEC.md`.
This is a Kotlin Multiplatform brownfield practice. Step 1 is done: the Swift `Domain/`
layer was replaced by the KMP library in `../shared` (see "Shared (KMP) integration").
Data and UI are still Swift. An Android twin lives in `../android-app` and follows the same spec.

- iOS 17.0+, Swift 5 mode, SwiftUI app lifecycle, no third-party Swift dependencies
- Domain from Kotlin: `Shared.framework` built from `../shared` on every Xcode build
- Observation framework (`@Observable`) for the repository and every ViewModel
- Data: `GET https://jsonplaceholder.typicode.com/todos?_limit=20`, loaded once on launch,
  then all changes live in memory

## Structure

```
TasksApp.xcodeproj           Xcode project (folder-synchronized groups) + shared scheme
TasksApp/
  App/                       TasksMainApp (@main), RootView (TabView: Tasks, Stats)
  Shared+Interop.swift       typealiases + Date <-> LocalDate helpers for the Kotlin framework
  Data/                      TaskApi/URLSessionTaskApi, TodoDto (Codable; mapping via
                             Kotlin TodoMapper), TaskRepository
  UI/TaskList/               list screen, row, ViewModel
  UI/TaskDetail/             detail screen + ViewModel
  UI/TaskEditor/             editor sheet + ViewModel
  UI/Stats/                  stats screen + ViewModel
  UI/Components/             PriorityBadge, DueDateLine, loading/error views
  Assets.xcassets
TasksAppTests/               XCTest smoke tests for the Kotlin interop (SharedInteropTests)
```

Layers:
- **Domain** — Kotlin, from `../shared` (`import Shared`): `TaskItem`, `Priority`,
  `TaskValidator`, `ValidationError`, `TaskFilter` (+ `StatusFilter`, `SortOrder`),
  `StatsCalculator`, `TaskStats`, `DateProvider`/`SystemDateProvider`, `DateFormatting`,
  `TodoMapper`. Its unit tests live in `shared/src/commonTest`.
- **Data** — Swift: network (`TaskApi`, protocol so it can be faked) and `TaskRepository`,
  the single in-memory source of truth, injected via `.environment(...)`.
- **UI** — Swift: one folder per screen; each screen owns an `@Observable` ViewModel that
  receives the repository and the `DateProvider` through its initializer.

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

## Run

1. Open `TasksApp.xcodeproj` in Xcode (16 or newer — the project uses objectVersion 77).
2. Pick an iOS 17+ simulator.
3. Cmd+R to run, Cmd+U to run the unit tests.

For a physical device, select your team under Signing & Capabilities (development team is empty).

## Next KMP steps

`Data/` (network + repository) is the next candidate to move into `shared`.
`UI/` and `App/` stay native SwiftUI and consume the shared code through thin adapters.
