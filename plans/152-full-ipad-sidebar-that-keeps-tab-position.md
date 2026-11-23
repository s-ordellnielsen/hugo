# Plan 152: A full iPad sidebar that keeps each tab's position

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> This plan is large. Commit after every step, and stop at any step marked
> "Owner check" until the owner answers.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 07d4c61..HEAD -- Hugo/App/AppRootView.swift Hugo/Features/Settings Hugo/Features/ServiceYear Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift Hugo/Features/Categories/Screens/CategoryListView.swift`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). Never touch, stage or commit it.

## Status

- **Priority**: P2
- **Effort**: L
- **Risk**: HIGH. It replaces the iPad navigation structure again, turns about a dozen `NavigationLink`s into value links, and most of it cannot be unit tested. Plans 136 and 140 both fixed bugs in this exact area.
- **Depends on**: none
- **Category**: feature (iPad)
- **Planned at**: commit `07d4c61`, 2026-11-23
- **Issue**: [SLN-333](https://linear.app/sebastianln/issue/SLN-333), child of [SLN-323](https://linear.app/sebastianln/issue/SLN-323) (iPad). Ships in V1.0.

## Why this matters

Plan 140 replaced the iPad split view with one `.sidebarAdaptable` `TabView`.
That fixed the lost position, but on iPad the app now starts with a top tab bar
and the sidebar only opens from a toggle. The owner wants a real sidebar that is
always there on iPad, and still wants this:

- Switching tabs keeps each tab's pushed screens.
- Tapping the selected tab again returns it to its root screen, as the iPhone does today through `yearResetToken` and `plannerResetToken`.
- iPhone keeps its tab bar, unchanged.

## What the earlier plans teach (do not bring these bugs back)

- Plan 136, correction: a `NavigationSplitView` detail column is NOT a navigation stack. Without one, `NavigationLink` replaces the detail and there is no back button.
- Plan 136 and 140: the first fix wrapped the detail in one `NavigationStack` with `.id(selectedTab)`. One stack cannot hold a root per tab, and the `.id` reset every tab on every switch. That is the bug plan 140 removed.
- Nested stacks make titles, toolbars and back buttons ambiguous.

Rules for this plan:

1. Exactly one `NavigationStack` per tab. Never wrap a stack in another, and never use `.id` to reset one.
2. Every tab's stack stays alive while another tab is selected.
3. The paths live in one `@Observable @MainActor` class that no view rebuilds.

## Current state

`Hugo/App/AppRootView.swift` (verify before editing). Selection and reset tokens are view `@State`:

```swift
@State private var selectedTab: AppTab = .overview
@State private var yearResetToken = UUID()
@State private var plannerResetToken = UUID()
...
private func select(_ tab: AppTab) {
    if tab == .year && selectedTab == .year { yearResetToken = UUID() }
    if tab == .planner && selectedTab == .planner { plannerResetToken = UUID() }
    selectedTab = tab
}
```

The layout is one adaptable `TabView`, one stack per tab, no path:

```swift
TabView(selection: tabSelection) {
    ForEach(visibleTabs) { tab in
        Tab(tab.titleKey, systemImage: tab.systemImage, value: tab) {
            NavigationStack {
                tabDestination(for: tab, yearResetToken: ..., plannerResetToken: ...)
            }
        }
        .defaultVisibility(tab.placement.showsInTabBar ? .automatic : .hidden, for: .tabBar)
    }
}
.tabViewStyle(.sidebarAdaptable)
.onChange(of: isCompact) { _, compact in
    if compact && !selectedTab.placement.isVisible(compact: true) { selectedTab = .overview }
}
```

`AppTab.placement` is `.all` for Overview, Planner and Year, and `.sidebarOnly` for
Settings. `isVisible(compact:)` hides Settings at compact width, where a person
icon (`SettingsButton(sizeClass: .compact)`) opens Settings as a sheet.

### Every push in the tabs (grep `NavigationLink`, `navigationDestination`)

None of them is value based today. `navigationDestination(for:)` exists only in
`OnboardingView`, which is a sheet and out of scope.

| Tab | Pushed from | Pushes |
|---|---|---|
| Overview | `OverviewView` | nothing (sheets only) |
| Planner | `PlannerView`, `PlannerMonthPage` | nothing (sheets only) |
| Year | `ServiceYearPageView.swift:57` | `ServiceYearDetailView(report:progress:)` |
| Year | `ServiceYearMonthRow.swift:34` | `MonthDetailView(month:schoolCredits:)` with `.navigationTransition(.zoom(sourceID:in:))` |
| Year | `MonthEntriesSection.swift:30` | `EntryDetailView(entry:)` |
| Settings | `SettingsView.swift:53,70,73,76,84,146,151,160` | `PublisherStatusSelectionView`, `ReportSettingsView`, `CategoryListView`, `GeneralSettingsView`, `CloudSyncStatusView`, `HelpView` (privacy, terms), `DebugSettingsView` (debug builds) |
| Settings | `ReportSettingsView.swift:17,29` | `OverseerSettingsView`, `GreetingTemplateView` |
| Settings | `GeneralSettingsView.swift:14` | `PlannerTargetSettingsView` |
| Settings | `PlannerTargetSettingsView.swift:97` | `BufferScopeSettingsView(includeInOverview:includeInYear:)` with two bindings |
| Settings | `CategoryListView.swift:17` | `CategoryDetailView(tracker:)` |

So only Year and Settings need a path. Overview and Planner keep a plain `NavigationStack`.

## Decisions

**Paths are `NavigationPath`, one for Year and one for Settings.** Settings and
Year push several unrelated screen types. One of them (`BufferScopeSettingsView`)
needs bindings to the `@AppStorage` values of its parent page. The memory note
"Pushed pages: no duplicate @AppStorage" says a second `@AppStorage` for those
keys froze the app. So that one destination is registered on `PlannerTargetSettingsView`
itself, with its own route type, and a single `[Route]` array cannot hold two
types. `NavigationPath` can. Tests check `path.count`.

**Routes carry identifiers, never models or computed reports.** A route is a
small `Hashable` value type. A pushed `Tracker` or `Entry` is found again by
`PersistentIdentifier`, and a month by `YearMonth`. A month or year report is
rebuilt from the database in the destination. If the row is gone (CloudKit
removed it), the destination shows `ContentUnavailableView` and the person goes
back with the normal back button.

**Restoring means: in memory only.** A path survives tab switches, rotation and
a change between the compact and regular layout, because both layouts read the
same state class. It is not saved across a launch. Do not add persistence.

**Reselect = pop to root and bump the reset token**, the same two things the
iPhone does today (the pop is new, the token is today's behavior).

**All four stacks stay alive through a bar-less `TabView` as the detail.** In the
regular layout the detail is `TabView(selection:)` with
`.toolbarVisibility(.hidden, for: .tabBar)`. A `TabView` keeps each tab's view
state (so each stack and its path), gives the selected tab hit testing and
accessibility, and hides the others from VoiceOver and touch. Doing this by hand
with a `ZStack` needs `.opacity(0)`, `.allowsHitTesting(false)` and
`.accessibilityHidden(true)` on three stacks, and a hidden stack can still own
the navigation bar. The fallback, if the owner check in Step 6 fails, is that
`ZStack`.

**Sidebar rows are buttons, not a selection binding.** A `List(selection:)`
does not call the setter when the selected row is tapped again, so reselect
could not be detected. Rows are `Button`s that call `navigation.select(tab)`.
The selected row gets a selected background and `.accessibilityAddTraits(.isSelected)`.

**One adaptive wrapper reads the size class.** `AdaptiveAppLayout` (new, in
`Hugo/App`) is the only new place that reads `horizontalSizeClass` for layout.
Compact gets today's `TabView`, regular gets the split view. Existing readers
(`SettingsButton`, `AppRootView.isCompact`) stay as they are, and `isCompact` moves into the wrapper.

## What was learned while building Step 6 (2026-11-23, simulator and iPad checks)

The "Decisions" above about a bar-less `TabView` as the detail did not survive
contact with iPadOS 26. The shipped design at regular width is different, and
plans 153 and 154 build on it:

- A `TabView` in the detail column shows its own top tab bar unless `.toolbarVisibility(.hidden, for: .tabBar)` is on each tab's content. With it, root screens lost their navigation titles, and a re-created stack lost the destinations of its restored path (SwiftUI logged "A NavigationLink is presenting a value of type ... but there is no matching navigationDestination declaration visible" and drew a yellow warning triangle).
- A `ZStack` of four stacks showed the unselected stack's bar over the selected tab and left the same triangle.
- **Shipped:** at regular width the detail is ONE `NavigationStack(path:)` whose root and path both follow the selected tab (`AdaptiveAppLayout.detailPath`). Year and Settings paths still live in `AppNavigationState`, so their pushed pages come back with the tab. The Year page and the Planner month the person is on (`displayedYear`, `displayedMonth`) are hoisted into `AppNavigationState` too, because a tab's own view state is recreated on every switch. Compact width keeps one stack per tab. Rule 1 ("one stack per tab") therefore applies to compact only; at regular width there is exactly one stack for the whole detail.
- Sidebar rows must stay `Button`s: a `List(selection:)` setter calls `select` on the already selected row and pops it.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |

## Scope

**In scope**:

- `Hugo/App/AppNavigationState.swift` (create)
- `Hugo/App/AdaptiveAppLayout.swift` (create)
- `Hugo/App/AppRootView.swift`
- `Hugo/Features/Settings/Domain/SettingsRoute.swift` (create), and the Settings screens named in the table
- `Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift` (the buffer scope link only)
- `Hugo/Features/Categories/Views/CategoryRouteView.swift` (create) and `CategoryListView.swift`
- `Hugo/Features/ServiceYear/Domain/YearRoute.swift` (create), `ServiceYearView.swift`, `ServiceYearPageView.swift`, `ServiceYearMonthRow.swift`, `MonthEntriesSection.swift`, plus one small destination view in `Hugo/Features/ServiceYear/Views/`
- `HugoTests/App/AppNavigationStateTests.swift` (create)

**Out of scope**:

- The look of any screen, the Planner and Service Year layouts (plan 154), and sheets (plan 153).
- `EntryDetailView` wraps its own `NavigationStack` and `MonthEntriesSection` pushes it, so that push already nests a stack. Do not fix it here. Plan 153 and 154 note it.
- Saving paths across launches.
- Any change to what an iPhone user sees or does.

## Git workflow

- Work on `main`. Commit per step, Conventional Commits, for example `refactor: hold tab navigation in one state class`.
- Do not push. Never stage `Hugo/Resources/Localizable.xcstrings`.

## Steps

### Step 0: Owner check before any code

Ask the owner to try this on the iPad and answer in one line. Do not write code
until they answer.

> On the iPad, open the app. Tap the sidebar toggle at the left of the tab bar
> and open the sidebar. Switch tabs in it. Is that sidebar good enough, if it
> could open by default? Or do you want the always visible sidebar of a split
> view?

Also try, on a throwaway branch only, whether `.tabViewStyle(.sidebarAdaptable)`
with `.tabViewSidebarHeader`, `.tabViewSidebarBottomBar` or tab sections gives
the look they want. Do not commit this experiment. I could not verify an API
that opens the sidebar by default, so do not assume one exists.

**STOP if the owner says the adaptable sidebar is enough.** Report that, and
mark the plan obsolete.

### Step 1: Create `AppNavigationState` and test it

Create `Hugo/App/AppNavigationState.swift`. Flat in `App`, next to `AppTab`:

```swift
import SwiftUI

/// Which tab is selected and where each tab's stack is. Owned by `AppRootView`
/// as `@State`, so no layout change rebuilds it.
@Observable
@MainActor
final class AppNavigationState {
    var selectedTab: AppTab
    var yearPath = NavigationPath()
    var settingsPath = NavigationPath()
    private(set) var yearResetToken = UUID()
    private(set) var plannerResetToken = UUID()

    init(selectedTab: AppTab = .overview) { self.selectedTab = selectedTab }

    /// A different tab keeps every stack as it is. The selected tab again goes to its root.
    func select(_ tab: AppTab) {
        guard tab == selectedTab else { selectedTab = tab; return }
        popToRoot(tab)
    }

    func popToRoot(_ tab: AppTab) {
        switch tab {
        case .overview: break
        case .planner: plannerResetToken = UUID()
        case .year: yearPath = NavigationPath(); yearResetToken = UUID()
        case .settings: settingsPath = NavigationPath()
        }
    }

    /// Settings has no tab at compact width. Moves the selection, keeps the path.
    func ensureSelectionVisible(compact: Bool) {
        if !selectedTab.placement.isVisible(compact: compact) { selectedTab = .overview }
    }
}
```

Adjust only what strict concurrency forces. Create `HugoTests/App/AppNavigationStateTests.swift`
(`@MainActor struct`, Swift Testing). Tests:

1. `switchingTabsKeepsPaths`: append a value to `settingsPath` and `yearPath`, `select(.overview)`, `select(.settings)`, expect both counts unchanged.
2. `reselectClearsThatTabsPath`: append to `yearPath`, `select(.year)` twice (the first switches), expect `yearPath.isEmpty` and the other path untouched.
3. `reselectChangesResetToken`: for `.year` and `.planner`, the token differs after reselect and does not change on a plain switch.
4. `reselectOverviewDoesNothing`: no crash, no state change.
5. `compactMovesSettingsToOverviewAndKeepsItsPath`: `selectedTab = .settings`, push a value, `ensureSelectionVisible(compact: true)`, expect `.overview` and the settings path still has 1 element.

**Verify**: `Scripts/verify.sh` exits 0 with 5 more tests.

### Step 2: Use the state class in `AppRootView`, no visible change

Replace `selectedTab`, `yearResetToken`, `plannerResetToken`, `select` and
`tabSelection` in `AppRootView` with `@State private var navigation = AppNavigationState()`.
The `TabView` binding becomes `Binding(get: { navigation.selectedTab }, set: { navigation.select($0) })`.
`tabDestination(...)` takes the tokens from `navigation`. The `onChange(of: isCompact)`
calls `navigation.ensureSelectionVisible(compact:)`. Keep the layout identical.

**Verify**: `Scripts/verify.sh` exits 0. Owner check on iPhone and iPad: the app behaves exactly as before.

### Step 3: Settings pushes become value links

Create `Hugo/Features/Settings/Domain/SettingsRoute.swift`:

```swift
nonisolated enum SettingsRoute: Hashable {
    case publisherStatus, report, categories, general, cloudSync
    case privacyPolicy, termsOfUse, debug
    case overseer, greetingTemplate, plannerTarget
    case category(PersistentIdentifier)
}
```

Guard `.debug` with `#if SHOW_DEBUG_MENU` as the link is today. `SettingsView`
registers one `.navigationDestination(for: SettingsRoute.self)` that returns the
same views the links build today. Replace each `NavigationLink(destination:)`
in the table rows for Settings, `ReportSettingsView`, `GeneralSettingsView` and
`CategoryListView` with `NavigationLink(value:)`. `CategoryListView` pushes
`.category(tracker.persistentModelID)` and a new `CategoryRouteView(id:)`
(`Hugo/Features/Categories/Views`) looks the tracker up and shows
`CategoryDetailView`, or `ContentUnavailableView` if it is gone.

Register the buffer scope destination in `PlannerTargetSettingsView` itself,
with a private `BufferScopeRoute` type, so it keeps using that page's own
bindings. Do not give `BufferScopeSettingsView` its own `@AppStorage`.

The sheet use of `SettingsView` (`SettingsButton`, `showDismiss: true`) has its
own `NavigationStack` and no path. Value links work without a bound path, so it
keeps working. Do not change `SettingsButton`.

**Verify**: `grep -n "NavigationLink(destination" Hugo/Features/Settings Hugo/Features/Categories` returns no matches, `Scripts/verify.sh` exits 0, and `grep -rn "NavigationLink {" Hugo/Features/Settings Hugo/Features/Planner` shows only links you converted. Owner check on iPhone: every Settings page opens, goes back and shows the same content as before.

### Step 4: Year pushes become value links

Create `Hugo/Features/ServiceYear/Domain/YearRoute.swift`:

```swift
nonisolated enum YearRoute: Hashable {
    case yearDetail(TheocraticYear.ID)
    case month(YearMonth)
    case entry(PersistentIdentifier)
}
```

Check that `TheocraticYear.ID` is `Hashable`. The report, progress and
`ServiceMonth` are computed from `@Query` data. A pushed value must not hold a
snapshot, so add a small destination view in `ServiceYear/Views` that takes the
route value, queries what `ServiceYearPageView` queries, builds the report with
`TheocraticYearReportBuilder.report(for:...)` and shows `ServiceYearDetailView`
or `MonthDetailView`. Plan 154 reuses this view as the month column.

`ServiceYearView` registers `.navigationDestination(for: YearRoute.self)` at its
root, outside the `LazyHStack`. Do not register it inside a page.

The zoom transition needs the namespace and the source id in both places.
Move `@Namespace` from `ServiceYearMonthRow` to `ServiceYearView`, pass it down
to the rows, and apply `.navigationTransition(.zoom(sourceID: month, in: namespace))`
in the destination closure. Keep `.matchedTransitionSource` on the card.

**STOP** if the zoom cannot be kept with a value link after one honest attempt.
Ask the owner whether to drop the zoom on the Year tab. If they want to keep it,
leave the Year links destination based, keep only `yearResetToken` for Year
reselect (it cannot pop a pushed month), and say so in NOTES.

**Verify**: `grep -rn "NavigationLink(destination\|NavigationLink {" Hugo/Features/ServiceYear` shows no destination links, and `Scripts/verify.sh` exits 0. Owner check on iPhone: Year totals card, month card (with zoom), an entry row and back all work, and a context menu on a month card still works.

### Step 5: Bind the paths in the existing TabView

Add a small private helper in `AppRootView` (or `AdaptiveAppLayout`, Step 6):

```swift
@ViewBuilder
private func tabStack(for tab: AppTab) -> some View {
    switch tab {
    case .year:
        NavigationStack(path: $navigation.yearPath) { tabDestination(for: tab, ...) }
    case .settings:
        NavigationStack(path: $navigation.settingsPath) { tabDestination(for: tab, ...) }
    case .overview, .planner:
        NavigationStack { tabDestination(for: tab, ...) }
    }
}
```

Use it in the current `TabView`. It is still one stack per tab and the layout is unchanged.

**Verify**: `Scripts/verify.sh` exits 0. Owner check on iPhone and iPad: a pushed Settings page is still there after switching to Overview and back, and tapping the Year tab twice goes to the Year root and the current year.

### Step 6: The adaptive wrapper and the regular layout (prototype)

Create `Hugo/App/AdaptiveAppLayout.swift`. It takes `navigation: AppNavigationState` and a `tabContent: (AppTab) -> some View` closure, reads `horizontalSizeClass` once, and returns:

- compact: today's `TabView` with `.sidebarAdaptable`, filtered by `isVisible(compact: true)`, unchanged.
- regular: a `NavigationSplitView`. The sidebar is a `List` of all tabs as `Button` rows (`Label(tab.titleKey, systemImage: tab.systemImage)`) that call `navigation.select(tab)`. The detail is `TabView(selection:)` of all four tabs, each with `tabContent(tab)`, and `.toolbarVisibility(.hidden, for: .tabBar)`.

`AppRootView` calls `AdaptiveAppLayout` and no longer reads the size class. Move `.onChange(of: isCompact)` into the wrapper.

**Owner check on a real iPad before Step 7**, portrait and landscape, and report:

1. The sidebar is always visible in landscape and can be shown in portrait.
2. No tab bar and no empty gap at the top or bottom of the detail.
3. Each tab shows its own title and toolbar. The Year picker, the Help menu and the Planner title look as they do today.
4. Push two Settings pages, switch to Year and back: both pages are still there. Same for Year.
5. VoiceOver on the detail reads only the selected tab.
6. Slide Over and Split View at compact width show the tab bar, and the stacks are still where they were.

If 2, 3 or 5 fail, switch the detail to the `ZStack` fallback described under
"Decisions" and ask again. If that also fails, STOP.

### Step 7: Reselect in the sidebar and selection style

Give the selected sidebar row a selected background and `.isSelected`. Confirm a
tap on the selected row calls `navigation.select` and goes to the root with the
Year and Planner reset animation. Add a `.accessibilityHint` only if the owner wants one.
Hardware keyboard: arrow keys move focus and Return activates a row.

**Verify**: `Scripts/verify.sh` exits 0. Owner check on iPad: tapping the selected sidebar row pops that tab to its root.

## Test plan

- Five `AppNavigationStateTests` from Step 1.
- Everything else is checked by the owner on devices. Say so in the commit messages.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, with 5 more tests
- [ ] `grep -rn "\.id(selectedTab)" Hugo` returns no matches
- [ ] Each tab has exactly one `NavigationStack` in `Hugo/App` and none is wrapped in another
- [ ] `grep -rn "horizontalSizeClass" Hugo/App` matches only `AdaptiveAppLayout.swift`
- [ ] The owner checks in Steps 2 to 7 are answered
- [ ] `git status --short` shows only in-scope files (plus the owner's `Localizable.xcstrings`, unstaged)
- [ ] `plans/README.md` row updated

## STOP conditions

Stop and report if:

- The owner says in Step 0 that the adaptable sidebar is enough.
- A pushed page ends up in the wrong column, loses its back button, or a toolbar shows twice (the plan 136 symptoms).
- Keeping all four stacks alive needs a second `NavigationStack` around any of them.
- The zoom transition cannot be kept (Step 4).
- You would need `@AppStorage` for the same key in two views (the freeze in the memory note).
- Both the `TabView` detail and the `ZStack` fallback fail the Step 6 check.
- iPhone behavior would change in any way.

## Maintenance notes

- A new pushed screen in Year or Settings adds a case to its route enum and a `navigationDestination` where the pushing page lives. A `NavigationLink(destination:)` in those tabs cannot be popped by reselect, so do not add one.
- If a fifth tab is added, give it a path only if it pushes screens.
- Plans 153 and 154 build on this layout. They must not add a `NavigationStack` inside a column or a detail. At regular width the detail is one stack for all tabs, so a tab's own `@State` is lost on a tab switch: anything the person would miss (a selected page, a filter) belongs in `AppNavigationState`.
- `AppTab.placement.showsInTabBar` is only used by the compact `TabView` after this plan.
