# Brownfield migration log — iOS

The iOS side of moving the Tasks app onto a Kotlin Multiplatform core one layer at a time, with the
app shippable after every step. The full overview (including the Android side) is in
[shared's migration log](https://github.com/Kaktotaks/KMPBrownfield-shared/blob/main/docs/MIGRATION.md).

| Step | iOS change | Commits |
|---|---|---|
| 0 | Native SwiftUI app from the spec | `8dddcc6` |
| 1 | Swift `Domain/` replaced by Kotlin (direct framework integration) | `a61013b` |
| 2 | Swift `Data/` replaced by Kotlin (Ktor, `TaskRepository`) via a `TaskStore` adapter | `472fcab` |
| 3 | SKIE: `for await`, `onEnum`, `async` | `d89df6f` |
| 4 | Swift ViewModels replaced by shared Kotlin ViewModels + `SharedViewModel` bridge | `d9b6845`, `cd59057` |
| 5 | Body-only SwiftUI views over per-screen Swift ViewModels (Combine) | `5b6f88e` … `bb03972` |
| 6 | `Shared` via SPM binary XCFramework; Gradle Run Script removed | `a16543c` |

## Step 0 — native baseline
SwiftUI app with `Domain/`, `Data/` (URLSession + Codable) and `@Observable` ViewModels, built from
the [spec](https://github.com/Kaktotaks/KMPBrownfield-shared/blob/main/docs/SPEC.md) with the same type
names as the Android app.

## Step 1 — domain from Kotlin
`Domain/` was deleted; types come from `import Shared`. The framework was built from `../shared` on
every Xcode build by a Run Script calling `./gradlew :embedAndSignAppleFrameworkForXcode` (JDK
required, user script sandboxing off). Interop lessons: Kotlin `Task` became `TaskItem`
(`@ObjCName`), `Int` is `Int32`, `object`s are `.shared`, default arguments are not exported,
`LocalDate` is `Kotlinx_datetimeLocalDate` (aliased in `Shared+Interop.swift`), Foundation's
`SortOrder` needed a typealias.

## Step 2 — data from Kotlin (plain ObjC interop)
Networking moved to Ktor (Darwin engine on iOS) and the repository to Kotlin. Without SKIE, SwiftUI
could not observe a Kotlin `StateFlow` (its generic was erased to `Any?`), so a `TaskStore` adapter
subscribed through a small iosMain callback bridge and mirrored the state into `@Observable`
properties. Other plain-interop constraints at this stage:
- `sealed interface LoadState` exported as separate classes — no exhaustive `switch`, mapped with `is`/`as?`;
- `suspend fun load()` had to *start* on the main thread, so it was called through the
  completion-handler form inside `withCheckedContinuation`;
- a Swift class can implement the Kotlin `TaskApi` (ObjC protocol, `NSObject` subclass) — used for
  `FakeTaskApi` in the tests.

## Step 3 — SKIE

| Plain ObjC export (step 2) | With SKIE (step 3) |
|---|---|
| callback bridge + handle cancelled in `deinit` | `for await state in repository.state` (typed `AsyncSequence`) |
| `state.value` is `Any?` | `repository.state.value` is typed |
| `is`/`as?` on `LoadStateLoaded` / `LoadStateError` | `switch onEnum(of: state)` — exhaustive |
| `load(completionHandler:)` + main-thread start | `try await repository.load()` from any thread, cancellation propagates |
| Kotlin enums are classes → `switch` needs `default` | real Swift enums → exhaustive `switch` |

The callback bridge was deleted. One gotcha: to *implement* a Kotlin `suspend` interface in Swift you
implement SKIE's `__`-prefixed requirement (`__fetchTasks(today:)`).

## Step 4 — ViewModels from Kotlin
The hand-written Swift ViewModels and `TaskStore` were removed; filtering, stats, validation, saving
and loading/error/retry now live in the Kotlin ViewModels shared with Android. The generic
`SharedViewModel<VM, UiState>` mirrors `uiState`, forwards events with `send {}`, and calls
`viewModel.clear()` on deinit because iOS has no `ViewModelStoreOwner`. `AppDependencies` became the
composition root.

## Step 5 — UI-only SwiftUI views
Views were reduced to `body`; display mapping, bindings, intents and child-ViewModel creation moved
into per-screen Swift ViewModels (`TaskListViewModel`, …). Bindings to Kotlin state became one-liners
via `SharedViewModel.binding(_:_:)`. Detail and root ViewModels are created once
(`navigationDestination(item:)`, `@StateObject` autoclosure), tests use fixed dates, and the Swift
ViewModels switched from `@Observable` to Combine `ObservableObject`, the more common choice in
brownfield codebases.

## Step 6 — binary distribution via SPM
The Gradle Run Script was removed (user script sandboxing is back on). The app depends on the
`KMPBrownfield-shared` Swift package (*Up to Next Minor* from `0.5.0`), whose `Package.swift` is a
`binaryTarget(url:checksum:)` pointing at `Shared.xcframework.zip` in the GitHub Release. The
XCFramework is built with library evolution, so it works with a different Xcode than CI's. iOS
developers no longer need a JDK or Gradle.
