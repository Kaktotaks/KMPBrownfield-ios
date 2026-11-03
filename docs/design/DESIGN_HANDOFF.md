# Design Handoff — Tasks (Gismart-inspired redesign)

**Source of truth:** Claude Design canvas "Tasks — Gismart-style redesign" (approved by Leonid, 2026-11-03).
Rendered reference screens are in `reference/*.png`, and app icons are in `icons/`.
**Scope:** visual layer only, for `ios-app` (SwiftUI) and `android-app` (Jetpack Compose).
No changes to the KMP `shared` module, its models or its ViewModel state.
**Platforms:** iOS 17+, Android minSdk 26. Phone portrait only; no tablet layout in scope.

---

## 0. Parity principle (read first)

The two apps must look and behave **the same**, the way a real cross-platform product team ships them.

Everything below is identical on both platforms:
- tokens: color, type scale, radii, spacing;
- custom components;
- layout order;
- copy;
- icons;
- animation timings.

Only these may differ:

| Element | iOS | Android |
|---|---|---|
| Status bar, home / gesture bar | System | System |
| Back affordance | Nav bar chevron + "Tasks" label | Top app bar back-arrow icon |
| Bottom navigation chrome | **System `TabView`**: selected item tinted `textPrimary`; no custom lime pill (see note) | M3 `NavigationBar` 80 dp: `indicatorColor = accent`, selected icon `onAccent` |
| Editor container | `.sheet` with system grabber | `ModalBottomSheet` with drag handle |
| Date picker | System `DatePicker` (compact / graphical) | System `DatePickerDialog` |
| Menus, alerts, confirmations | System `Menu` / `.alert` / `.confirmationDialog` | M3 `DropdownMenu` / `AlertDialog` |

> **Note on the iOS tab bar.** The canvas shows a lime pill behind the selected iOS tab. That pill requires replacing the system `TabView`, which costs native behaviour: accessibility, safe areas, and the iOS 26 tab bar appearance. We keep the system bar on iOS; this is an allowed chrome difference.

The **large screen titles ("Tasks", "Stats") are content, not navigation-bar titles**, on both platforms. On iOS the navigation bar stays inline and empty on root screens.

---

## 1. Design tokens

Token names are the same on both platforms; only the values live in each platform's theme.
- iOS: asset-catalog color sets with Any/Dark appearances, exposed as `Color.tk.<name>`.
- Android: `TasksColors` provided through `staticCompositionLocalOf`, plus a mapped `MaterialTheme.colorScheme`. **Dynamic color is off**: the brand palette wins.

### 1.1 Color

| Token | Light | Dark | Usage |
|---|---|---|---|
| `bg` | #F5F5F0 | #000000 | Screen background, sheet background |
| `surface` | #FFFFFF | #151515 | Cards, text fields |
| `surface2` | #EBEBE4 | #232323 | Search field, segmented track, bar track, skeleton |
| `border` | #E2E2DA | #2A2A2A | Field border, row dividers |
| `outline` | #8C8C85 | #8A8A84 | Low-priority bar fill, low-priority dot |
| `textPrimary` | #0A0A0A | #FFFFFF | Titles, body, unchecked checkbox ring, sort pill border |
| `textSecondary` | #4F4F4A | #B3B3AD | Due line, labels, placeholders |
| `textTertiary` | #6E6E68 | #8A8A84 | Completed task title and due line, inactive tab |
| `inverse` / `onInverse` | #0A0A0A / #FFFFFF | #FFFFFF / #0A0A0A | Selected segment (light only), secondary button |
| `accent` | #E3F140 | #E3F140 | Fills only: checked checkbox, primary button, add button, Save pill, selected segment (dark), Done tile, ring |
| `onAccent` | #0A0A0A | #0A0A0A | Content on `accent` |
| `onAccentMuted` | #2E3200 | #2E3200 | Secondary label on `accent` (the "Done" tile label) |
| `danger` | #DC3232 | #FF5A4E | Overdue text and ring, invalid field border, error text |
| `dangerContainer` / `onDangerContainer` | #FDE8E6 / #B42323 | #3A1512 / #FFB4AD | Delete button, error banner, Overdue tile |
| `priorityHigh` / `onPriorityHigh` | #DC3232 / #FFFFFF | #FF5A4E / #000000 | High badge and bar |
| `priorityMedium` / `onPriorityMedium` | #FFB020 / #0A0A0A | #FFB020 / #0A0A0A | Medium badge and bar |
| `priorityLow` / `onPriorityLow` | #E2E2DA / #3A3A36 | #3A3A36 / #E5E5E0 | Low badge (the low bar uses `outline`) |
| `heroBg` | #0A0A0A | #151515 | Detail hero card, Stats completion card |
| `heroText` / `heroTextSecondary` | #FFFFFF / #B3B3AD | #FFFFFF / #B3B3AD | Text on `heroBg` |
| `ringTrack` | #2A2A2A | #2A2A2A | Completion ring track |
| `scrim` | #0A0A0A @ 40% | #000000 @ 60% | Behind sheets |

**Contrast rule:** lime (`accent`) is never used as text or as an icon colour on a light background; it fails contrast. On dark backgrounds lime text is allowed (the Stats percent).

Android `colorScheme` mapping:
- `primary` = `accent`, `onPrimary` = `onAccent`
- `secondary` = `inverse`
- `background` = `bg`, `surface` = `surface`, `surfaceContainer` = `surface2`
- `outline` = `outline`, `outlineVariant` = `border`
- `error` = `danger`, `errorContainer` = `dangerContainer`, `onErrorContainer` = `onDangerContainer`

### 1.2 Typography

Fonts: **Inter** (400, 500, 600, 700) and **Inter Tight** (800), both under the SIL Open Font License; bundle `OFL.txt`.
- **iOS:** use `Font.custom(name, size:, relativeTo:)` so Dynamic Type scales.
- **Android:** sizes in `sp` so text follows the system font scale.

Letter-spacing is given in em; Compose takes `letterSpacing = (-0.03).em`, and iOS needs `.tracking(size * em)`.

| Token | Font | Size / line | Tracking | relativeTo (iOS) | Usage |
|---|---|---|---|---|---|
| `largeTitle` | Inter Tight 800 | 34 / 38 | -0.03 | `.largeTitle` | "Tasks", "Stats" |
| `display` | Inter Tight 800 | 64 / 64 | -0.04 | `.largeTitle` | Stats percent |
| `statNumber` | Inter Tight 800 | 40 / 44 | -0.03 | `.title` | Stat tile numbers |
| `heroTitle` | Inter Tight 800 | 30 / 33 | -0.03 | `.title` | Detail task title |
| `title` | Inter Tight 800 | 24 / 28 | -0.02 | `.title2` | Empty / error headings |
| `sheetTitle` | Inter 700 | 17 / 22 | 0 | `.headline` | Editor header title |
| `headline` | Inter 600 | 17 / 22 | 0 | `.headline` | Task card title |
| `body` | Inter 400 | 16 / 24 | 0 | `.body` | Notes, inputs, info rows |
| `button` | Inter 600 | 16 / 20 | 0 | `.body` | Buttons |
| `subhead` | Inter 500 | 14 / 20 | 0 | `.subheadline` | Due line, filter labels, tile labels |
| `caption` | Inter 500 | 13 / 18 | 0 | `.footnote` | Field error messages |
| `overline` | Inter 700 | 12 / 16, UPPERCASE | +0.06 | `.caption` | Section headers ("NOTES", "BY PRIORITY", field labels) |
| `badge` | Inter 700 | 11 / 14, UPPERCASE | +0.04 | `.caption2` | Priority / status badges |

All numbers that animate or change (percent, stat numbers) use **tabular figures**:
- iOS: `.monospacedDigit()`.
- Compose: `fontFeatureSettings = "tnum"`.

### 1.3 Radius, spacing, elevation

- **Radius:**
  - `xs` 8: badges
  - `s` 12: text fields
  - `m` 16: buttons, add button, error banner
  - `l` 20: cards, tiles
  - `xl` 28: hero cards, sheet top corners
  - `pill` 999: search, segmented control, sort pill, bars, Save button
- **Spacing scale:** 4, 8, 12, 16, 20, 24, 32, 48.
  - Screen gutter is **16**.
  - Card list gap is **8**.
  - Section gap is **12**.
- **Elevation:** flat UI with no card shadows. The only shadow is on the floating add button:
  - light: `0 6 16` @ 22% black;
  - dark: `0 6 16` @ 50% black.
  - On Android use `FloatingActionButtonDefaults.elevation(6.dp)` with the shape `m`.
- **Minimum touch target:** 44 pt on iOS, 48 dp on Android, even where the visible control is smaller (28 checkbox, 36 Save pill).

---

## 2. Components

Specs apply to both platforms unless noted. Light-mode values are shown; dark mode swaps tokens.

| Component | Spec | Notes |
|---|---|---|
| **TaskCard** | `surface`, r `l`, padding 14 v / 16 h, row: CheckCircle + 14 gap + content column (gap 6) | Content: title (`headline`, wraps, never truncated to one line) + PriorityBadge right-aligned top; due line below. The whole card taps to open detail; the checkbox is a separate target. |
| **CheckCircle** | 28 × 28 circle, 44/48 hit area. Unchecked: 2 px ring `textPrimary` (ring `danger` when overdue). Checked: fill `accent`, check icon 16 `onAccent` stroke 3.2 | Title becomes `textTertiary` + strikethrough when done; due line `textTertiary`. |
| **PriorityBadge** | r `xs`, padding 3 v / 8 h, `badge` type, text "HIGH"/"MEDIUM"/"LOW" on `priority*` colors | Always shows the word, never color only. |
| **StatusBadge** (detail hero) | Active: 1.5 px `accent` border, `accent` text (on `heroBg`). Done: `accent` fill, `onAccent` text | Same size as PriorityBadge but 12 pt. |
| **Due line** | `subhead`, `textSecondary`: "Due 5 Nov 2026". Overdue and not done: 14 clock icon + "Due 31 Oct 2026 · Overdue", `danger`, weight 600 | Date format comes from shared (`d MMM yyyy`). |
| **PillSearchField** | h 44, r `pill`, `surface2`, 18 search icon `textSecondary`, padding 14, placeholder "Search tasks" | iOS: a custom view, **not** `.searchable`. Android: custom `BasicTextField`, not M3 `SearchBar`. Clear button appears when not empty. |
| **PillSegmentedControl** | track `surface2`, r `pill`, padding 3, segments h 34 (filter) / 36 (editor priority). Selected: light `inverse` + `onInverse` text, dark `accent` + `onAccent`. Unselected: transparent, `textPrimary`, weight 500 | Used for All/Active/Done and Low/Medium/High (with an 8 dot in the priority color before each label). The selection thumb animates (M3 below). |
| **SortPill** | h 40, r `pill`, 1.5 px `textPrimary` border, sort icon 16 + label + chevron 14, `subhead` 600 | The label is the current sort: "Due date" / "Priority" / "Title". Opens the system menu (iOS `Menu` + `Picker`, Android `DropdownMenu`) with a checkmark on the current option. |
| **FloatingAddButton** | 56 × 56, r `m`, `accent`, "+" 26 `onAccent` stroke 2.6, bottom-right, 16 from the edge and 16 above the bottom bar | **Single add pattern on both** (no nav-bar "+", no extended FAB). Accessibility label "Add task". |
| **PrimaryButton** | h 52, r `m`, `accent` / `onAccent`, `button` type, optional leading icon 20 | Disabled: `surface2` / `textTertiary`. |
| **SecondaryButton** | h 52, r `m`, `inverse` / `onInverse` | Edit, Retry. |
| **DestructiveButton** | h 52, r `m`, `dangerContainer` / `onDangerContainer` | Delete. |
| **SavePill** | h 36, r `pill`, padding 0 × 18, `accent` / `onAccent`, Inter 700 15 | Disabled when `canSave == false`: `surface2` / `textTertiary`. |
| **TasksTextField** | label above (`overline`, `textSecondary`, gap 6). Field h 48 (notes: min 3 lines, padding 12 × 14), r `s`, `surface`, 1.5 px `border`. Focused: 2 px `textPrimary`. Invalid: 2 px `danger` + message below (`caption`, `danger`) | Not M3 `OutlinedTextField`: custom on both, same look. |
| **DateField** | Same as TasksTextField, value "2 Nov 2026" + calendar icon 20 right; tapping opens the system picker | |
| **ErrorBanner** | `dangerContainer`, r `m`, padding 12 × 14, alert icon 20 + text `subhead` `onDangerContainer`: "Fix N fields to save this task." (singular: "Fix 1 field…") | Shown when there are validation errors. Keep the current validation logic as is. |
| **HeroCard** | `heroBg`, r `xl`, padding 22 (detail) / 24 (stats) | |
| **InfoRowsCard** | `surface`, r `l`, horizontal padding 18, rows h 52, 1 px `border` dividers, icon 20 `textSecondary` + label `body` `textSecondary` + value `body` 600 right | Detail: Priority / Due date / Status. |
| **StatTile** | r `l`, padding 16 × 18, label `subhead` + number `statNumber`. Variants: default (`surface`), done (`accent`, label `onAccentMuted`, number `onAccent`), overdue (`dangerContainer` / `onDangerContainer`) | 2 × 2 grid, gap 12. |
| **CompletionRing** | 104 × 104, radius 42, stroke 14, round caps, track `ringTrack`, progress `accent`, starts at 12 o'clock and runs clockwise | iOS `Circle().trim(from: 0, to: p)` rotated −90°; Android `Canvas.drawArc(startAngle = -90f)`. |
| **PriorityBar** | Row: label (`body`-15 600) + right "N tasks" (`subhead`-15 `textSecondary`); bar h 10, r `pill`, track `surface2`, fill `priorityHigh` / `priorityMedium` / `outline` (Low) | **Fill width = priority count ÷ total.** See §5 for the data limitation. |
| **EmptyState** | Centered: 96 illustration (outlined card + lime disc + check, same motif as the icon, drawn with tokens) + `title` + `body` `textSecondary` + optional PrimaryButton | |
| **Skeleton row** | TaskCard shape with `surface2` blocks: circle 26, line 14 h (65–80% width), line 10 h (40–50% width) | Pulses (M7). |

---

## 3. Screens

Reference PNGs: `reference/iOS-*.png` and `reference/Android-*.png`. The iOS screen is 393 × 852 and the Android screen 412 × 915; layouts are identical apart from the chrome.

### 3.1 Task list (tab "Tasks")
From top to bottom:
1. `largeTitle` "Tasks" (padding 2/16/12).
2. PillSearchField.
3. A row with PillSegmentedControl (All / Active / Done, flexible width) + 8 gap + SortPill.
4. A list of TaskCards (top padding 16, gap 8, bottom inset so the last card clears the FloatingAddButton).
5. FloatingAddButton.

Interactions:
- Card tap → detail (push).
- CheckCircle tap → toggle.
- Add → editor sheet (new).
- Search and filter update the list live.

States:

| State | UI |
|---|---|
| Loading | Header + search + filter visible but disabled; 4 skeleton rows; under them a spinner 16 + "Loading tasks…" (`subhead`, `textSecondary`) |
| Empty (no tasks at all) | EmptyState: "No tasks yet" / "Tap + to add your first task." / PrimaryButton "+ Add task" |
| Empty (search or filter matches nothing) | EmptyState without a button: "No matching tasks" / "Try a different search or filter." |
| Error | EmptyState with an error illustration: "Couldn't load tasks" / "Check your connection and try again." / SecondaryButton "↻ Retry". The FloatingAddButton is still shown. |
| Loaded | As in the reference |

### 3.2 Task detail (push from list)
- Chrome: back only ("‹ Tasks" on iOS, back arrow on Android). No Edit in the bar.
- Content (padding 8/16, gap 12):
  1. **HeroCard**:
     - PriorityBadge + StatusBadge;
     - `heroTitle` in `heroText`;
     - due line with a 16 calendar icon, `heroTextSecondary`; `danger` + "· Overdue" when overdue.
  2. **Notes card** (`surface`, r `l`, padding 18): `overline` "NOTES" + `body`. **Hidden when notes are blank.**
  3. **InfoRowsCard:** Priority / Due date / Status.
  4. **Actions:**
     - PrimaryButton full width:
       - "✓ Mark done" when active;
       - "Mark as active" when done (as SecondaryButton style).
     - Below it, a 2-column row: SecondaryButton "✎ Edit" + DestructiveButton "🗑 Delete".
     - Delete asks for system confirmation (iOS `.confirmationDialog`, Android `AlertDialog`): "Delete this task?" / "Delete" (destructive) / "Cancel".
- Not found (the task was deleted): EmptyState "Task not found" / "It may have been deleted." with **no** button. Replaces Android's current wrong "No tasks" text.

### 3.3 Editor (sheet: New task / Edit task)
- Container:
  - sheet with top radius `xl` and `bg` background;
  - iOS: `.presentationDragIndicator(.visible)`, `.presentationCornerRadius(28)`, `.presentationBackground(Color.tk.bg)`, detents `.large`;
  - Android: `ModalBottomSheet(skipPartiallyExpanded = true)`, shape top `xl`, container `bg`.
- Header (3-column grid):
  - "Cancel" (`body` 500, left);
  - title `sheetTitle`: "New task" / "Edit task" (from `screenTitle`);
  - SavePill (right).
- Body (padding 14/16, gap 18):
  1. ErrorBanner, only when errors exist;
  2. Title field (placeholder "What needs doing?");
  3. Notes field;
  4. Priority PillSegmentedControl with colored dots;
  5. DateField.
- Field errors map from the shared `ValidationError`s to the field they belong to (Title / Due date). The text comes from shared.
- Save: if `save()` returns true, dismiss. Cancel: dismiss without saving.
- Keyboard: the content scrolls; on Android `imePadding()`.

### 3.4 Stats (tab "Stats")
From top to bottom:
1. `largeTitle` "Stats".
2. **Completion HeroCard** (r `xl`, padding 24):
   - left column:
     - `overline` "COMPLETION" in `heroTextSecondary`;
     - percent in `display` and `accent`;
     - "N of M tasks done" (`subhead`-15, `heroTextSecondary`);
   - right: CompletionRing.
3. **StatTile grid** 2 × 2: Total / Done (accent variant) / Active / Overdue (overdue variant).
4. **"BY PRIORITY" card** (`surface`, r `l`, padding 18, gap 14): PriorityBar ×3 in the order High, Medium, Low.

States:
- Loading: skeleton hero (r `xl`, h 152, `surface2`) + 4 skeleton tiles.
- Error: EmptyState error with Retry, same as the list.
- Zero tasks: hero shows "0%", ring empty; tiles 0; bars empty, label "0 tasks".

---

## 4. Motion

All timings are **identical on both platforms**. One easing is used everywhere: **`emphasized` = cubic-bezier(0.2, 0, 0, 1)**.
- iOS: `Animation.timingCurve(0.2, 0, 0, 1, duration: d)`.
- Compose: `tween(d, easing = CubicBezierEasing(0.2f, 0f, 0f, 1f))`.

Define the durations once per platform (`Motion.short = 150`, `medium = 250`, `long = 600`, `extraLong = 900`, `stagger = 80`) and use the constants, not literals.

### 4.1 Stats animations (requested: progress and percent must be consistent)

| ID | Element | Trigger | Animation | Duration | Delay | Easing |
|---|---|---|---|---|---|---|
| S1 | CompletionRing progress | Stats becomes **Loaded** while visible, and every time the Stats tab is (re)entered | trim/sweep from **0 → p** | 900 ms | 0 | emphasized |
| S2 | Percent text | same as S1 | counts **0 → p**, integer, `round(v)` + "%" | 900 ms | 0 | emphasized |
| S3 | StatTile numbers | same as S1 | count 0 → value, integer | 600 ms | 0 | emphasized |
| S4 | PriorityBar fills | same as S1 | width 0 → fraction | 600 ms | 150 ms + index × 80 ms (High, Medium, Low) | emphasized |
| S5 | All of the above | data changes **while Stats is visible** (toggle from another tab can't happen, but repository reloads can) | animate **from current value → new value**, no reset to 0 | same as above | 0 | emphasized |

**The consistency rule.** The ring (S1) and the percent text (S2) must be driven by **one animated value**, so the number and the arc can never drift apart.
- **iOS:** an `@State var progress: Double` animated with `withAnimation(.timingCurve(0.2,0,0,1,duration:0.9)) { progress = target }`. The ring reads `progress`. The percent is a small `View` conforming to `Animatable` (`animatableData = progress`) that renders `Text("\(Int((progress * 100).rounded()))%")`.
  - **Do not** use `.contentTransition(.numericText())`: it rolls digits and has no Android equivalent, so the platforms would differ.
- **Android:** `val progress = remember { Animatable(0f) }` and `LaunchedEffect(target) { progress.animateTo(target, tween(900, easing = Emphasized)) }`. The arc uses `progress.value * 360f` and the text uses `"${(progress.value * 100).roundToInt()}%"`.
- **Rounding:**
  - Kotlin `roundToInt()` and Swift `.rounded()` agree for non-negative values.
  - The final frame must equal the shared `completionPercent` exactly: set the final text from the target, not from the float.
- **Replay on tab re-entry:**
  - iOS: in `.onAppear`, reset to 0 without animation and then animate to the target.
  - Android: key the effect on a "visible" counter incremented on each tab selection, or on `LocalLifecycleOwner` RESUMED.
  - Never animate during the Loading state; start when the content first becomes Loaded.

### 4.2 Micro-interactions

| ID | Element | Trigger | Animation | Duration | Easing |
|---|---|---|---|---|---|
| M1 | CheckCircle | toggle | fill `transparent ↔ accent` crossfade; check icon scale 0.6 → 1 | 150 ms fill; scale spring (iOS `.spring(response: 0.3, dampingFraction: 0.6)`, Compose `spring(dampingRatio = 0.6f, stiffness = 500f)`) | — |
| M2 | Task title / due line | toggle | color to/from `textTertiary`, strikethrough appears | 150 ms | emphasized |
| M3 | PillSegmentedControl thumb | selection change | thumb slides to the new segment (iOS `matchedGeometryEffect`; Compose animated offset and width) | 250 ms | emphasized |
| M4 | Task list items | filter / sort / search change, add, delete | insert: fade + 8 pt rise; remove: fade; reorder: move | 250 ms | emphasized (iOS `.animation(value: ids)`; Compose `Modifier.animateItem()`) |
| M5 | Buttons, add button, cards | press | scale 1 → 0.96 → 1 | 100 ms | ease-out |
| M6 | ErrorBanner, field error text | appear / disappear | fade + height expand | 250 ms | emphasized |
| M7 | Skeleton blocks | while loading | opacity 0.45 ↔ 1, repeat, reverse | 1000 ms per half-cycle | ease-in-out |

**Haptics** (same moments on both):
- light impact on checkbox toggle: iOS `.sensoryFeedback(.impact(weight: .light), trigger:)`, Android `HapticFeedbackType.LongPress` or `performHapticFeedback(CONTEXT_CLICK)`;
- success on Save.

### 4.3 Reduced motion
When the user asks for reduced motion, **all S* and M3/M4/M7 animations snap to their final values** (opacity crossfades of 150 ms may remain).
- iOS: `@Environment(\.accessibilityReduceMotion)`.
- Android: `Settings.Global.ANIMATOR_DURATION_SCALE == 0f`, read once into a `CompositionLocal`.

---

## 5. Data mapping and known limitations

- **Visual layer only.** Everything comes from the existing shared UiStates:
  - `TaskListUiState`, `TaskDetailUiState`, `TaskEditorUiState`, `StatsUiState` with `TaskStats`;
  - `TaskStats` fields: `total`, `done`, `active`, `completionPercent`, `low`, `medium`, `high`, `overdue`.
- **"By priority"**: the canvas shows "2 tasks · 0 done". `TaskStats` has no per-priority done count, so the implementation shows **"N tasks"** only, with bar = count ÷ total. Showing "· N done" needs a new field in shared, a separate PR plus a shared release. **Out of scope.**
- **"N of M tasks done"** = `done` of `total`.
- **Overdue** = the existing overdue flag in each app's UI model. Do not recompute it in the view.
- **Copy:** strings shared by both apps are in §6. Text produced by shared stays as is: priority names, validation messages, `screenTitle`.
- **Known open behaviours, not part of this work** (do not fix here):
  - validation errors show immediately on a new task;
  - "today" goes stale after midnight;
  - double Retry triggers two loads.

## 6. Copy (identical on both platforms)

| Key | Text |
|---|---|
| `tasks_title` / `stats_title` | Tasks / Stats |
| `search_placeholder` | Search tasks |
| `filter_all` / `filter_active` / `filter_done` | All / Active / Done |
| `sort_due` / `sort_priority` / `sort_title` | Due date / Priority / Title |
| `due_format` / `overdue_suffix` | Due %s / · Overdue |
| `add_task` | Add task |
| `empty_title` / `empty_body` | No tasks yet / Tap + to add your first task. |
| `no_match_title` / `no_match_body` | No matching tasks / Try a different search or filter. |
| `error_title` / `error_body` / `retry` | Couldn't load tasks / Check your connection and try again. / Retry |
| `loading` | Loading tasks… |
| `notes` / `priority` / `due_date` / `status` | Notes / Priority / Due date / Status |
| `status_active` / `status_done` | Active / Done |
| `mark_done` / `mark_active` / `edit` / `delete` | Mark done / Mark as active / Edit / Delete |
| `delete_confirm_title` | Delete this task? |
| `not_found_title` / `not_found_body` | Task not found / It may have been deleted. |
| `cancel` / `save` | Cancel / Save |
| `title_label` / `title_placeholder` | Title / What needs doing? |
| `fix_fields` | Fix %d field(s) to save this task. (plural-aware) |
| `completion` / `n_of_m_done` | Completion / %d of %d tasks done |
| `total` / `done` / `active` / `overdue` | Total / Done / Active / Overdue |
| `by_priority` / `n_tasks` | By priority / %d task(s) (plural-aware) |

Resource files:
- iOS: `Localizable.xcstrings` (String Catalog).
- Android: `res/values/strings.xml` + `plurals`.

Only English is in scope, but nothing user-facing should be hard-coded in views.

## 7. Accessibility

- **Contrast:** ink on lime is about 16:1. Lime is never used as text on light backgrounds. Priority and overdue are always words, not only colour.
- **Task card:** one accessibility element for the card ("Renew passport photos, High priority, Due 31 Oct 2026, overdue", trait/role button, opens detail). Expose the checkbox as a **custom action** "Mark done" / "Mark as active":
  - iOS `.accessibilityAction(named:)`;
  - Android `Modifier.semantics { customActions = … }`.

  The checkbox itself is also focusable with the label "Mark ‹title› done / not done" and the toggle trait/role. Decorative icons (chevrons, clock, calendar) are hidden from assistive tech.
- **Completion:** ring + percent form one element with the label "Completion" and the value "33 percent, 2 of 6 tasks done". Announce the **final** value only, not the counting frames.
- **Focus order:** title → search → filter → sort → list → add button → tab bar. In the editor: Cancel → title → fields in order → Save.
- **Scaling:** Dynamic Type / fontScale up to the largest accessibility size.
  - Cards grow in height, and titles wrap with no fixed heights on text containers.
  - Stat tiles may become one column when the text doesn't fit; this is optional but must never clip.
- **Targets:** 44 pt / 48 dp minimum for every interactive element.

## 8. Edge cases

- **Long title:** wraps without a line limit in cards and detail. The PriorityBadge stays top-right and doesn't shrink.
- **Long notes:** the detail notes card grows, and the page scrolls.
- **Many tasks:** a lazy list with the add button floating, and a bottom content inset of 16 + 56 + 16.
- **Zero tasks in Stats:** 0%, the ring track only, no division by zero for bar fractions (total == 0 → 0).
- **100%:** the ring closes fully with the round cap; percent "100%" fits in the display size without wrapping (tabular digits, the hero card left column flexes).
- **Slow network:** skeletons until Loaded. Error replaces skeletons. Retry returns to skeletons.
- **Dark mode:** every screen in both appearances; verify the List, Detail, Editor and Stats screens.

## 9. Assets

- **iOS app icon:**
  - `icons/ios/AppIcon-1024.png` (default),
  - `AppIcon-1024-dark.png`,
  - `AppIcon-1024-tinted.png` (grayscale source for tinted).

  Use a single-size `AppIcon.appiconset` with the luminosity appearances "Any", "Dark" and "Tinted". The SVG sources sit next to them.
- **Android adaptive icon:**
  - `icons/android/ic_launcher_foreground.xml` and `ic_launcher_monochrome.xml` → `res/drawable/`;
  - `ic_launcher_background.xml` → `res/values/`;
  - `ic_launcher.xml` → `res/mipmap-anydpi-v26/` as `ic_launcher.xml` **and** `ic_launcher_round.xml`.

  Reference them from the manifest with `android:icon` / `android:roundIcon`. Because minSdk is 26, no PNG mipmaps are needed.
- **Fonts:**
  - Inter 400/500/600/700 + Inter Tight 800, static TTFs, OFL. Source: `github.com/google/fonts` (`ofl/inter`, `ofl/intertight`). These are variable fonts; instantiate the static weights with `fonttools varLib.instancer`, or use the static TTFs from the `rsms/inter` release for Inter.
  - iOS: add the fonts to the target and list them under `UIAppFonts`.
  - Android: put them in `res/font/` with lowercase snake_case names.
  - Include `OFL.txt`.
- **Icons in UI:** 24-grid stroke icons, stroke 2.2, round caps (search, sort, chevron, clock, calendar, flag, check, plus, pencil, trash, refresh, the list/stats tab icons). Copy the SVG paths from the canvas or reference screens.
  - Android: vector drawables or `ImageVector`.
  - iOS: SF Symbols are acceptable **only** where the shape matches (`magnifyingglass`, `chevron.down`, `calendar`, `plus`, `pencil`, `trash`, `arrow.clockwise`, `checkmark`, `clock`, `flag`, `checklist`, `chart.bar`) with weight `.semibold`; otherwise use the same custom paths as Android.
- **Launch / splash:**
  - iOS: launch screen background `bg`.
  - Android: `Theme.SplashScreen` (core-splashscreen) or a DayNight window theme with `windowBackground = bg`, so dark mode doesn't flash white.

## 10. Acceptance criteria

1. iOS and Android screenshots of each screen (List, List-Dark, Detail, Editor with errors, Stats, Empty, Error, Loading) placed side by side differ only in the elements listed in §0.
2. All tokens come from the theme (`Color.tk.*` / `TasksTheme.colors.*` / `MaterialTheme`). No hex literals in views.
3. Stats animations S1–S5 use the same durations and easing; the ring and the percent are driven by one value and land exactly on `completionPercent`. Reduced motion snaps.
4. No user-facing hard-coded strings in views (String Catalog / `strings.xml`).
5. App icons are installed on both platforms (iOS any/dark/tinted; Android adaptive + monochrome).
6. Accessibility per §7: the task-card custom action works in VoiceOver and TalkBack; Stats reads its final value.
7. Existing unit tests still pass. Update UI-model mapper tests where copy or structure changed, and add tests for new pure mappers.
8. iOS: `#Preview`s exist for every screen in light and dark, using a fake-data `AppDependencies.preview`. Android: `@Preview`s for every screen in light and dark.
