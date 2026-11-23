# Plan 140: Keep each tab's position on iPad with one sidebar-adaptable TabView

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 5aaebc1..HEAD -- Hugo/App/AppRootView.swift`
> Expected: no output. If the file changed, compare it with "Current state" and STOP on a mismatch.
> Also `git status --short` may show `M Hugo/Resources/Localizable.xcstrings`
> (the owner's own edit; never touch, stage or commit it) and untracked plan files.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: MEDIUM. One file, but it replaces the iPad navigation structure and UI cannot be unit tested. The owner checks it by hand on an iPad.
- **Depends on**: none
- **Category**: bug (follow-up to plan 136)
- **Planned at**: commit `5aaebc1`, 2026-11-23
- **Issue**: [SLN-319](https://linear.app/sebastianln/issue/SLN-319)

## Why this matters

On iPad, `AppRootView.regularLayout` shows a `NavigationSplitView` whose detail
column holds one `NavigationStack` with `.id(selectedTab)`. The `.id` is there
because a single stack cannot hold a different root per tab, so it resets the
stack on every sidebar selection. Result: from Settings > General > Monthly
Target, tapping Year in the sidebar sends Settings back to its root. On iPhone
the compact layout is a `TabView`, and a `TabView` keeps one stack per tab, so
the position survives. The owner wants the same on iPad.

Decision (owner, 2026-11-23): replace the split view with one `TabView` using
`.tabViewStyle(.sidebarAdaptable)`. It is Apple's own pattern. The same
`TabView` then serves iPhone (bottom tab bar) and iPad (top tab bar with a
toggle that opens a sidebar), every tab keeps its own `NavigationStack`, and
`compactLayout`, `regularLayout`, `sidebarSelection` and the `.id` all go away.

Accepted trade-off: on iPad the app starts with a top tab bar and the sidebar
opens from a toggle, instead of an always visible sidebar. Do not try to force
the sidebar open.

Settings stays reachable on iPad: it is a normal tab in the iPad tab bar and in
the sidebar, and it is hidden from the tab bar on iPhone (where Settings opens
as a sheet from the person icon), exactly as `TabPlacement.sidebarOnly` meant.

## Current state

`Hugo/App/AppRootView.swift` (verify before editing).

Lines 8 to 12 and 30 to 33:

```swift
struct AppRootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
```

```swift
    private var isCompact: Bool { horizontalSizeClass == .compact }

    private var visibleTabs: [AppTab] {
        AppTab.allCases.filter { $0.placement.isVisible(compact: isCompact) }
    }
```

Lines 35 to 49 (`select` resets the Year and Planner screens when the active tab is
chosen again, and `tabSelection` routes a `TabView` selection through it):

```swift
    private func select(_ tab: AppTab) {
        if tab == .year && selectedTab == .year {
            yearResetToken = UUID()
        }
        if tab == .planner && selectedTab == .planner {
            plannerResetToken = UUID()
        }
        selectedTab = tab
    }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { select($0) }
        )
    }
```

Lines 51 to 59 (the layout switch at the top of `body`):

```swift
    var body: some View {
        Group {
            if isCompact {
                compactLayout
            } else {
                regularLayout
            }
        }
        .environment(syncMonitor)
```

Lines 107 to 143 (the two layouts and the sidebar binding):

```swift
    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(visibleTabs) { tab in
                Tab(tab.titleKey, systemImage: tab.systemImage, value: tab) {
                    NavigationStack {
                        tabDestination(for: tab, yearResetToken: yearResetToken, plannerResetToken: plannerResetToken)
                    }
                }
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List(
                visibleTabs,
                id: \.self,
                selection: sidebarSelection
            ) { tab in
                Label(tab.titleKey, systemImage: tab.systemImage)
            }
        } detail: {
            NavigationStack {
                tabDestination(for: selectedTab, yearResetToken: yearResetToken, plannerResetToken: plannerResetToken)
            }
            .id(selectedTab)
        }
    }

    private var sidebarSelection: Binding<AppTab?> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if let newValue {
                    select(newValue)
                }
            }
        )
    }
```

Lines 175 to 202 (the tab placement types):

```swift
    var placement: TabPlacement {
        switch self {
        case .overview: .all
        case .year: .all
        case .planner: .all
        case .settings: .sidebarOnly
        }
    }
}

enum TabPlacement {
    case sidebarOnly
    case all

    func isVisible(compact: Bool) -> Bool {
        switch self {
        case .sidebarOnly: !compact
        case .all: true
        }
    }
}
```

Nothing else uses `AppTab`, `TabPlacement`, `tabDestination`, `visibleTabs`,
`isCompact` or the two layouts: `grep -rn "AppTab\|TabPlacement\|tabDestination" Hugo HugoTests --include='*.swift'`
matches only `AppRootView.swift`. The three tab screens show a person icon
through `SettingsButton(sizeClass: .compact)` (Overview line 106, Year line 137,
Planner line 108). Leave those alone.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint one file | `xcrun swift-format lint --strict <file>` | exit 0, no output |
| Whole gate | `Scripts/verify.sh` | exit 0 (lint, all tests, analyze). Takes several minutes. |

## Scope

**In scope** (the only files you may modify):

- `Hugo/App/AppRootView.swift`
- `plans/README.md` (status row)

**Out of scope** (do NOT touch):

- The four tab screens, `SettingsButton`, and every other view. They are already correct for one stack per tab.
- `Hugo/Resources/Localizable.xcstrings`, `Hugo.xcodeproj` and the owner's scheme edit. Never stage them.
- Any attempt to open the sidebar by default or to add a custom sidebar.

## Git workflow

- Commit straight to `main`. Do not create a branch or a worktree.
- One commit after `Scripts/verify.sh` exits 0, Conventional Commits: `refactor: use one sidebar-adaptable TabView for iPhone and iPad`.
- Stage `Hugo/App/AppRootView.swift` by explicit path only. Never `git add -A` or `git add .`. Do not push. No Co-Authored-By trailer.

## Steps

### Step 1: Replace the two layouts with one TabView

In `Hugo/App/AppRootView.swift`:

1. In `body`, replace the `Group { if isCompact { compactLayout } else { regularLayout } }` block (lines 52 to 58) with a single `tabs` view, keeping every modifier that follows it (`.environment(syncMonitor)` and everything after) exactly as it is:

```swift
    var body: some View {
        tabs
            .environment(syncMonitor)
```

   The rest of the `body` chain (`.task`, `.onChange`, `.onReceive`, `.sheet`, `.errorAlert`) stays unchanged and still attaches to the result.

2. Delete `compactLayout`, `regularLayout` and `sidebarSelection` completely, and in their place add:

```swift
    private var tabs: some View {
        TabView(selection: tabSelection) {
            ForEach(AppTab.allCases) { tab in
                Tab(tab.titleKey, systemImage: tab.systemImage, value: tab) {
                    NavigationStack {
                        tabDestination(for: tab, yearResetToken: yearResetToken, plannerResetToken: plannerResetToken)
                    }
                }
                .defaultVisibility(tab.placement.isVisible(compact: isCompact) ? .automatic : .hidden, for: .tabBar)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .onChange(of: isCompact) { _, compact in
            if compact && !selectedTab.placement.isVisible(compact: true) {
                selectedTab = .overview
            }
        }
    }
```

   The `onChange` handles a window that becomes compact (Slide Over) while Settings is selected: Settings has no tab bar item there, so the selection falls back to Overview.

3. Delete `visibleTabs` (it is no longer used). Keep `isCompact`, `select`, `tabSelection` and `tabDestination` as they are.

**Verify**:
- `grep -n "compactLayout\|regularLayout\|sidebarSelection\|visibleTabs\|NavigationSplitView" Hugo/App/AppRootView.swift` prints nothing.
- `grep -c "NavigationStack" Hugo/App/AppRootView.swift` prints `1`.
- `xcrun swift-format lint --strict Hugo/App/AppRootView.swift` exits 0 (if it reports wrapping, run `xcrun swift-format format --in-place Hugo/App/AppRootView.swift` and lint again).

### Step 2: Rename the placement case so the name is true

`sidebarOnly` no longer means "only in the sidebar": the tab is now also in the iPad tab bar, and only hidden on iPhone. In the same file:

1. In `AppTab.placement`, change `case .settings: .sidebarOnly` to `case .settings: .regularOnly`.
2. In `TabPlacement`, rename `case sidebarOnly` to `case regularOnly`, and in `isVisible(compact:)` change `case .sidebarOnly: !compact` to `case .regularOnly: !compact`.

**Verify**: `grep -n "sidebarOnly" Hugo/App/AppRootView.swift` prints nothing, and `grep -rn "sidebarOnly" Hugo HugoTests --include='*.swift'` prints nothing.

### Step 3: Build, gate and commit

1. Run `Scripts/verify.sh`, with the full output redirected to a file under
   `/private/tmp/claude-501/-Users-sebastiannielsen-Documents-Areas-Personal-Apps-Hugo/e838d7fa-4b4b-47a9-b236-f61a2004ed12/scratchpad/`
   (for example `verify-140.log`), and take the exit code from the script itself. In a Rex session, run it in a Rex pane.
2. Do not claim the manual checks below passed. You cannot run an iPad. Report them as not run.
3. Stage `Hugo/App/AppRootView.swift` by explicit path and commit with the message from "Git workflow".

**Verify**: exit code 0, and the log contains `** TEST SUCCEEDED **` and `** ANALYZE SUCCEEDED **`.

## Test plan

No automated test. The change swaps the container that holds the screens, and no
seam in this codebase can observe navigation structure. Say this in NOTES. The
owner runs this checklist on an iPad and an iPhone (Debug build, English). Every
item must pass.

**iPad full screen**

1. The top tab bar shows Overview, Planner, Year and Settings. Each tab shows the same title and toolbar as before. No person icon on Overview, Year or Planner.
2. The sidebar toggle opens a sidebar that lists the same four tabs. Selecting a row switches tabs.
3. Position is kept: Settings > General > Monthly Target, then tap Year, then tap Settings again. Settings is still on Monthly Target. Do the same with Year > a month detail, then Overview, then back to Year.
4. Push destinations land in the right place with a back button: a Year month, a Settings row, a Categories row.
5. Tap the active Year tab and the active Planner tab again. They still jump back to the current year and month. If a repeat tap does nothing on iPad, report it, do not patch it.
6. Titles and toolbars: no doubled or missing title or toolbar on any tab, with the tab bar and with the sidebar open.
7. Sheets (Add Entry, Submit Report, Help) open, show their title and buttons, and dismiss.

**iPhone and Slide Over (compact)**

8. A bottom tab bar with Overview, Planner and Year only. No Settings tab. The person icon opens Settings as a sheet, and everything in the Settings sheet pushes and goes back.
9. Position is kept per tab as before.
10. Drag Hugo from Slide Over to full width and back, once on Settings (full width) and once on Year. No crash, no missing title. If Settings is selected when it becomes compact, the app shows Overview.

**Dark mode and largest text**

11. Repeat checks 1 and 3 in dark mode and at the largest accessibility text size.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0.
- [ ] `grep -n "NavigationSplitView\|compactLayout\|regularLayout\|sidebarSelection\|visibleTabs\|sidebarOnly" Hugo/App/AppRootView.swift` prints nothing.
- [ ] `grep -c "NavigationStack" Hugo/App/AppRootView.swift` prints `1`.
- [ ] Only `Hugo/App/AppRootView.swift` changed in the commit.
- [ ] The report says the manual checklist was not run, unless it was.
- [ ] `plans/README.md` status row updated (unless the reviewer maintains it).

## STOP conditions

Stop and report back (do not improvise) if:

- The code at "Current state" does not match.
- `.tabViewStyle(.sidebarAdaptable)` or `.defaultVisibility(_:for: .tabBar)` does not compile. Do not search for substitutes, do not use `#available`, and do not keep the old layouts: report the compiler message.
- `xcrun swift-format format --in-place` changes anything beyond layout of the edited lines.
- A step's verification fails twice.
- The change appears to need any file outside the scope list.

## Maintenance notes

- Rule going forward: every tab owns exactly one `NavigationStack`, created in `AppRootView.tabs`. A screen reached from a tab never creates a stack, only a sheet does (this supersedes the "detail column" wording in plan 136, which was wrong).
- `Tab` visibility: `.defaultVisibility(..., for: .tabBar)` decides who appears in the tab bar. The sidebar always lists every tab. To add a tab that is iPhone-only or iPad-only, add a `TabPlacement` case and keep using `isVisible(compact:)`.
- Re-selecting the active tab calls `select(_:)` only if SwiftUI calls the `TabView` binding's setter. Check item 5 on a device. If it does not fire on iPad, the fix belongs in a follow-up, not in this plan.
- If the owner later wants an always-open sidebar on iPad, the options are the value-based path refactor (one `NavigationPath` per tab, 16 `NavigationLink`s to convert, `ServiceYearMonthRow` has a zoom transition) or going back to a split view with per-tab stacks kept alive. Both were considered and rejected for this plan.
