# Tasks — iOS (point 0)

Native SwiftUI implementation of the Tasks app described in `../SPEC.md`.
This is "point 0" of a Kotlin Multiplatform brownfield practice: a plain native app
with **no Kotlin**, built so its Domain and Data layers can later be replaced by a
KMP `shared` module. An Android twin lives in `../android-app` and follows the same spec.

- iOS 17.0+, Swift 5 mode, SwiftUI app lifecycle, no third-party dependencies
- Observation framework (`@Observable`) for the repository and every ViewModel
- Data: `GET https://jsonplaceholder.typicode.com/todos?_limit=20`, loaded once on launch,
  then all changes live in memory

## Structure

```
TasksApp.xcodeproj           Xcode project (folder-synchronized groups) + shared scheme
TasksApp/
  App/                       TasksMainApp (@main), RootView (TabView: Tasks, Stats)
  Domain/                    Task, Priority, TaskValidator, ValidationError,
                             TaskFilter (+ StatusFilter, SortOrder), StatsCalculator,
                             TaskStats, Clock/SystemClock, DueDateFormatter
  Data/                      TaskApi/URLSessionTaskApi, TodoDto (+ mapping), TaskRepository
  UI/TaskList/               list screen, row, ViewModel
  UI/TaskDetail/             detail screen + ViewModel
  UI/TaskEditor/             editor sheet + ViewModel
  UI/Stats/                  stats screen + ViewModel
  UI/Components/             PriorityBadge, DueDateLine, loading/error views, display names
  Assets.xcassets
TasksAppTests/               XCTest: validator, filter, stats, DTO mapping (fixed Clock)
```

Layers:
- **Domain** — pure Swift (Foundation only), no SwiftUI. Business rules from the spec.
- **Data** — network (`TaskApi`, protocol so it can be faked) and `TaskRepository`,
  the single in-memory source of truth, injected via `.environment(...)`.
- **UI** — one folder per screen; each screen owns an `@Observable` ViewModel that
  receives the repository and the `Clock` through its initializer.

Naming note: the domain types `Task`, `Clock` and `SortOrder` intentionally match the
spec (and the Android twin). Inside the app module they shadow Swift Concurrency's
`Task`/`Clock` and Foundation's `SortOrder`, so the code uses `_Concurrency.Task { }`
when it needs a concurrency task, and tests use module-qualified aliases
(`TasksApp.Task`, see `TasksAppTests/TestSupport.swift`).

## Run

1. Open `TasksApp.xcodeproj` in Xcode (16 or newer — the project uses objectVersion 77).
2. Pick an iOS 17+ simulator.
3. Cmd+R to run, Cmd+U to run the unit tests.

For a physical device, select your team under Signing & Capabilities (development team is empty).

## Future KMP sharing

`Domain/` and `Data/` are the candidates to move into the Kotlin `shared` module
(types are commented accordingly). `UI/` and `App/` stay native SwiftUI and will
consume the shared code through thin adapters.
