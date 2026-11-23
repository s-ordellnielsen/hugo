# Plan 136: Remove the nested navigation stacks under the iPad split view

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 0af2e24..HEAD -- Hugo/App/AppRootView.swift Hugo/Features/Overview/Screens/OverviewView.swift Hugo/Features/Overview/Views/OverviewListView.swift Hugo/Features/ServiceYear/Screens/ServiceYearView.swift Hugo/Features/Planner/Screens/PlannerView.swift Hugo/Features/Settings/Screens/SettingsView.swift Hugo/Features/Settings/Views/SettingsButton.swift`
> Expected: no output. If any file changed, compare it with "Current state" and STOP on a mismatch.
> Also `git status --short` must show only untracked plan files and, if
> present, `M Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` (the
> owner's own edit; never touch or commit it).

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MEDIUM. Small diff, but it cannot be covered by a unit test: titles and toolbars on four screens must be checked by hand on iPhone and iPad.
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `0af2e24`, 2026-11-23
- **Issue**: [SLN-200](https://linear.app/sebastianln/issue/SLN-200)

## Why this matters

On iPad (regular width) `AppRootView` shows a `NavigationSplitView` whose detail
column already is a navigation stack. The four tab root screens (Overview, Year,
Planner, Settings) each open their own `NavigationStack` on top of it, so on
iPad every one of them sits in a stack inside a stack. Nested stacks make
toolbar, title and back button ownership ambiguous, and they are the usual
cause of toolbars that duplicate, titles that vanish or pushed screens that
land in the wrong column. The fix is to give each layout exactly one stack: the
compact layout (iPhone, Slide Over) gets one stack per tab from `AppRootView`,
and the regular layout uses the split view's own detail stack. The four screens
stop creating a stack.

### What in the issue is still true, and what is not

The issue was written in August. Re-checked against `0af2e24`:

- **Still true**: Overview, Year and Planner each wrap their body in a
  `NavigationStack`, and the regular layout puts them in the split view detail.
  `SettingsView` does too, and since the Settings work it is the fourth tab
  root, shown only in the regular layout (`AppTab.settings` is
  `.sidebarOnly`). That nests a stack for it as well.
- **Changed**: `SettingsView` is also presented as a sheet by `SettingsButton`
  (with `showDismiss: true`). A sheet needs its own stack, so that one stack
  moves from `SettingsView` into `SettingsButton`. It does not simply go away.
- **Out of scope, not a defect**: the stacks inside sheets. `ServiceYearMonthRow`
  (line 54), `MonthDetailView` (line 46), `ReportReminderCard` (line 63),
  `SubmitReportView` (line 205), `HelpView` (line 52) and every `AddEntryView`,
  form and picker wrap sheet content in a `NavigationStack`. A sheet is a new
  presentation context and must own a stack, so these are correct. The issue's
  "one presentation point per screen instead of a stack per row" would mean
  hoisting the sheets out of `ServiceYearMonthRow` (twelve rows, two sheets
  each) into `ServiceYearPageView` with selection state. That is a separate,
  larger refactor with its own risk to the zoom transition from the row to
  `MonthDetailView`. Do not do it here. Say so in NOTES and leave it for a
  follow-up if the owner wants it.
- **Out of scope**: `OnboardingView` (its own sheet stack with a path) and the
  `#Preview` stacks in files other than the five named below.

## Current state

`Hugo/App/AppRootView.swift`, lines 107 to 129:

```swift
    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(visibleTabs) { tab in
                Tab(tab.titleKey, systemImage: tab.systemImage, value: tab) {
                    tabDestination(for: tab, yearResetToken: yearResetToken, plannerResetToken: plannerResetToken)
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
            tabDestination(for: selectedTab, yearResetToken: yearResetToken, plannerResetToken: plannerResetToken)
        }
    }
```

`tabDestination(for:yearResetToken:plannerResetToken:)` (line 144) is a global
`@ViewBuilder` used only at lines 111 and 127. It returns `OverviewView()`,
`ServiceYearView(resetToken:)`, `PlannerView(resetToken:)` or `SettingsView()`.

The four stacks, all the outermost view of `body`:

- `Hugo/Features/Overview/Screens/OverviewView.swift`: `NavigationStack {` at line 82 (after the `let` statements at lines 76 to 81), closing `}` at line 123 (8 spaces). Inside it: `ScrollView`, `.navigationBarTitleDisplayMode(.inline)` (line 104), `.toolbar` (105), two `.sheet` modifiers and `.onChange`. Preview at lines 127 to 129 is `OverviewView()` with no stack.
- `Hugo/Features/ServiceYear/Screens/ServiceYearView.swift`: `NavigationStack {` at line 83, closing `}` at line 141. Inside it: `ScrollView(.horizontal)`, `.navigationTitle(activeYear.displayName)` (102), `.navigationBarTitleDisplayMode(.inline)` (103), `.toolbar` (105 to 140). The `.onAppear`, `.onChange(of: scrollPosition)` and `.onChange(of: resetToken)` follow the closing brace at the same indentation as the stack. Preview at lines 166 to 169.
- `Hugo/Features/Planner/Screens/PlannerView.swift`: `NavigationStack {` at line 83, closing `}` at line 112. Inside it: `ScrollView(.horizontal)`, `.editorialNavigationTitle(...)` (102), `.navigationSubtitle("tab.planner")` (103), `.toolbar` (107). Then `.onAppear` and two `.onChange` modifiers. Preview at lines 134 to 137.
- `Hugo/Features/Settings/Screens/SettingsView.swift`: `NavigationStack {` at line 51, closing `}` at line 181. Inside it: a `List`, `.editorialNavigationTitle("settings.title")` (172), `.task` and a `.toolbar` that shows a cancel button when `showDismiss` is true. Preview at lines 185 to 188.

`Hugo/Features/Settings/Views/SettingsButton.swift`, lines 15 to 21:

```swift
            .sheet(isPresented: $showAccount) {
                SettingsView(showDismiss: true)
                    .presentationDetents([.large])
            }
```

The button is only added with `sizeClass: .compact` by Overview, Year and
Planner, so the sheet only appears in the compact layout.

Other callers of these four views: only the previews and `AppRootView`
(`grep -rn "OverviewView()\|ServiceYearView(\|PlannerView(\|SettingsView(" --include='*.swift' .`).
`OverviewListView.swift` line 275 to 278 has a second preview that renders
`OverviewView()`.

Convention to match: sheets wrap their content in a `NavigationStack`
(`HelpView` line 52, `SubmitReportView` line 205). A view reached through a
stack never creates one.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format one file | `xcrun swift-format format --in-place <file>` | exit 0, re-indents the body |
| Lint one file | `xcrun swift-format lint --strict <file>` | exit 0, no output |
| Whole gate | `Scripts/verify.sh` | exit 0 (lint, all tests, analyze). Takes several minutes. |
| Build for iPad and iPhone | `xcodebuild build -project Hugo.xcodeproj -scheme Debug -configuration Debug -destination 'generic/platform=iOS Simulator'` | `** BUILD SUCCEEDED **` |

## Scope

**In scope** (the only files you may modify):

- `Hugo/App/AppRootView.swift`
- `Hugo/Features/Overview/Screens/OverviewView.swift`
- `Hugo/Features/Overview/Views/OverviewListView.swift` (its preview only)
- `Hugo/Features/ServiceYear/Screens/ServiceYearView.swift`
- `Hugo/Features/Planner/Screens/PlannerView.swift`
- `Hugo/Features/Settings/Screens/SettingsView.swift`
- `Hugo/Features/Settings/Views/SettingsButton.swift`
- `plans/README.md` (status row)

**Out of scope** (do NOT touch):

- Every stack that lives inside a sheet (see "What in the issue is still true"), including `ServiceYearMonthRow`, `MonthDetailView`, `ReportReminderCard`, `SubmitReportView`, `HelpView`, onboarding and all form screens.
- `AppTab`, `TabPlacement` and the `select(_:)` reset-token logic.
- Titles, toolbars, `navigationBarTitleDisplayMode`, `EditorialNavigationTitle` and every other modifier: they are moved by re-indenting only, never edited.
- `Hugo.xcodeproj` and the owner's `Debug.xcscheme` edit.

## Git workflow

- Commit straight to `main`. Do not create a branch or a worktree.
- One commit after `Scripts/verify.sh` exits 0, Conventional Commits: `refactor: use one navigation stack per tab layout`.
- Stage by explicit path only (the seven source files above). Never `git add -A` or `git add .`. Do not push.

## Steps

### Step 1: Give the compact layout one stack per tab

In `Hugo/App/AppRootView.swift`, in `compactLayout`, replace

```swift
                Tab(tab.titleKey, systemImage: tab.systemImage, value: tab) {
                    tabDestination(for: tab, yearResetToken: yearResetToken, plannerResetToken: plannerResetToken)
                }
```

with

```swift
                Tab(tab.titleKey, systemImage: tab.systemImage, value: tab) {
                    NavigationStack {
                        tabDestination(for: tab, yearResetToken: yearResetToken, plannerResetToken: plannerResetToken)
                    }
                }
```

Do not change `regularLayout`: its `detail:` column is already the one stack
for the regular layout.

**Verify**:
- `xcrun swift-format lint --strict Hugo/App/AppRootView.swift` exits 0. If it reports a line length or wrapping problem, run `xcrun swift-format format --in-place Hugo/App/AppRootView.swift` and re-run the lint.
- `grep -c "NavigationStack" Hugo/App/AppRootView.swift` prints `1`.

### Step 2: Drop the stack in Overview

In `Hugo/Features/Overview/Screens/OverviewView.swift`:

1. Delete the line `        NavigationStack {` (line 82) and its matching closing line `        }` (line 123, the one directly after the `.onChange(of: pace == nil)` block). Keep the `let` lines above it.
2. Run `xcrun swift-format format --in-place Hugo/Features/Overview/Screens/OverviewView.swift`. This moves the body one level left. It must change nothing else.
3. Wrap the preview so the toolbar still renders. The preview becomes:

```swift
#Preview {
    NavigationStack {
        OverviewView()
    }
}
```

In `Hugo/Features/Overview/Views/OverviewListView.swift`, change the preview at the bottom (the one containing `OverviewView()`, lines 275 to 278) the same way, keeping its `.modelContainer(.preview)` on the outside:

```swift
#Preview {
    NavigationStack {
        OverviewView()
    }
    .modelContainer(.preview)
}
```

**Verify**:
- `grep -n "NavigationStack" Hugo/Features/Overview/Screens/OverviewView.swift` shows only the two preview lines.
- `git diff --stat -- Hugo/Features/Overview/Screens/OverviewView.swift` plus `git diff -w -- Hugo/Features/Overview/Screens/OverviewView.swift` (whitespace ignored) shows only the two deleted lines and the preview change.
- `xcrun swift-format lint --strict` on both files exits 0.

### Step 3: Drop the stack in the Year tab

In `Hugo/Features/ServiceYear/Screens/ServiceYearView.swift`:

1. Delete `        NavigationStack {` (line 83) and its matching `        }` (line 141, the line right before `.onAppear`).
2. Run `xcrun swift-format format --in-place Hugo/Features/ServiceYear/Screens/ServiceYearView.swift`.
3. The `.onAppear` and the two `.onChange` modifiers now attach to the `ScrollView` chain instead of the stack. That is intended; do not move them.
4. Preview becomes:

```swift
#Preview {
    NavigationStack {
        ServiceYearView()
    }
    .modelContainer(.preview)
}
```

**Verify**:
- `grep -n "NavigationStack" Hugo/Features/ServiceYear/Screens/ServiceYearView.swift` shows only the preview line.
- `git diff -w -- Hugo/Features/ServiceYear/Screens/ServiceYearView.swift` shows only the two deleted lines and the preview change.
- Lint exits 0.

### Step 4: Drop the stack in the Planner tab

In `Hugo/Features/Planner/Screens/PlannerView.swift`:

1. Delete `        NavigationStack {` (line 83) and its matching `        }` (line 112, the line right before `.onAppear`). Keep `let credited = creditedBeforeCurrentMonth` at line 82.
2. Run `xcrun swift-format format --in-place Hugo/Features/Planner/Screens/PlannerView.swift`.
3. Preview becomes:

```swift
#Preview {
    NavigationStack {
        PlannerView()
    }
    .modelContainer(.preview)
}
```

**Verify**:
- `grep -n "NavigationStack" Hugo/Features/Planner/Screens/PlannerView.swift` shows only the preview line.
- `git diff -w -- Hugo/Features/Planner/Screens/PlannerView.swift` shows only the two deleted lines and the preview change.
- Lint exits 0.

### Step 5: Move the Settings stack into the sheet

In `Hugo/Features/Settings/Screens/SettingsView.swift`:

1. Delete `        NavigationStack {` (line 51) and its matching `        }` (line 181, the last `}` before the closing brace of `body`).
2. Run `xcrun swift-format format --in-place Hugo/Features/Settings/Screens/SettingsView.swift`.
3. Preview becomes:

```swift
#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(.preview)
}
```

In `Hugo/Features/Settings/Views/SettingsButton.swift`, the sheet becomes:

```swift
            .sheet(isPresented: $showAccount) {
                NavigationStack {
                    SettingsView(showDismiss: true)
                }
                .presentationDetents([.large])
            }
```

(The `presentationDetents` moves to the stack, the sheet's root, which is where SwiftUI reads it.)

**Verify**:
- `grep -n "NavigationStack" Hugo/Features/Settings/Screens/SettingsView.swift` shows only the preview line.
- `grep -n "NavigationStack" Hugo/Features/Settings/Views/SettingsButton.swift` shows one line.
- `git diff -w -- Hugo/Features/Settings/Screens/SettingsView.swift` shows only the two deleted lines and the preview change.
- Lint exits 0 on both files.

### Step 6: Build, gate and commit

1. Run the build command from "Commands you will need". It must print `** BUILD SUCCEEDED **`.
2. Run `Scripts/verify.sh`, with the full output redirected to a file under
   `/private/tmp/claude-501/-Users-sebastiannielsen-Documents-Areas-Personal-Apps-Hugo/e838d7fa-4b4b-47a9-b236-f61a2004ed12/scratchpad/`
   (for example `verify-136.log`), and take the exit code from the script itself.
3. Do the manual checks below. They are part of the plan, not optional. If the
   executor cannot run a simulator, report the checks as not run and do not
   claim the plan is verified; the commit may still be made, and the owner
   runs the checklist.
4. Stage the seven source files by explicit path and commit with the message from "Git workflow".

**Verify**: exit code 0, and the log contains `** TEST SUCCEEDED **` and `** ANALYZE SUCCEEDED **`.

## Test plan

No new automated test. The change removes view containers; no seam in this
codebase can observe how many navigation stacks a view hierarchy has, and the
existing tests do not render these screens. Say this in NOTES. The check is
manual. Run it in the Debug build on a simulator or device, in English.

Every item must pass. For each tab, "title" and "toolbar" mean exactly what the
screen showed before this change.

**iPhone (compact, one stack per tab)**

1. Overview: no title text, inline bar, the person icon at the trailing edge opens Settings as a sheet. The month card, plan pace sheet and Add Entry sheet open and close.
2. Year: the year title with its chevron in the center (or the plain title with a single year), Help menu and the person icon at the trailing edge. Swipe between years: the title changes. Tap a month: it pushes `MonthDetailView` with the zoom transition and a back button. Pop back: the title returns.
3. Planner: the month title with the "Planner" subtitle, the person icon. Swipe months: the title changes.
4. Switch tabs back and forth: each tab keeps its title and toolbar. Tap the active Year tab and the active Planner tab again: they still jump back to the current year and month.
5. Settings sheet from the person icon: title "Settings", a cancel button at the leading edge, every row pushes and its back button works (Publisher status, Reports, Categories, General, iCloud sync, Help pages, Privacy Policy). General > Monthly Target and its Counts in page still open. Swipe down or tap cancel: the sheet closes.

**iPad full screen (regular, split view)**

6. Sidebar lists Overview, Planner, Year, Settings. Select each in turn: the detail column shows the same title and toolbar as before. The person icon is not shown on Overview, Year and Planner (it is compact only); Settings has no cancel button.
7. Year: tap a month and the detail column pushes `MonthDetailView` with a back button in the detail column, not the sidebar. Back returns to the Year screen.
8. Settings in the detail column: every row pushes inside the detail column with a working back button.
9. Select a sidebar row while a screen is pushed (for example a month detail): the detail switches to the new tab with its own root title and no leftover back button.
10. Open a sheet from each tab (Add Entry from Overview, Submit Report from a Year month row, Help from the Help menu): each has its title and buttons and dismisses.

**iPad Slide Over and Split View width (compact)**

11. Open Hugo in Slide Over. It should use the compact layout: checks 1 to 5 apply unchanged. Drag it wider into regular width and back while on Year and Settings: no crash and no missing title or toolbar after the layout switches (the pushed screen resetting is acceptable, a missing title is not).

**Dark mode and largest text**

12. Repeat checks 2, 3 and 6 once in dark mode and once at the largest accessibility text size: titles still show, nothing overlaps the toolbar.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0.
- [ ] `grep -c "NavigationStack" Hugo/App/AppRootView.swift` prints `1`.
- [ ] In `OverviewView.swift`, `ServiceYearView.swift`, `PlannerView.swift` and `SettingsView.swift`, `NavigationStack` appears only in the `#Preview` block.
- [ ] `SettingsButton.swift` wraps `SettingsView(showDismiss: true)` in a `NavigationStack`.
- [ ] Only the seven source files changed in the commit.
- [ ] The manual checklist was run, or the report says it was not.
- [ ] `plans/README.md` status row updated (unless the reviewer maintains it).

## STOP conditions

Stop and report back (do not improvise) if:

- The code at "Current state" does not match, for example a fifth tab root appeared, a stack moved, or `tabDestination` has other callers.
- Any screen in the manual checklist loses its title or its toolbar, shows a doubled title or toolbar, or pushes into the wrong column. Do not patch it with extra modifiers; report which screen and which layout, and leave the commit unmade.
- `xcrun swift-format format --in-place` changes anything beyond indentation inside the four `body` properties.
- A build error appears that is not about the lines this plan changes.
- A step's verification fails twice.
- The change appears to need any file outside the scope list, in particular any sheet stack.

## Maintenance notes

- Rule going forward: a screen reached through a stack, or shown in a split view's detail column, never creates its own `NavigationStack`. Only a sheet, popover-like cover or the compact tab wrapper in `AppRootView` does.
- The sheets in `ServiceYearMonthRow` and `MonthDetailView` still carry one `NavigationStack` for `SubmitReportView` each, and each `ServiceYearMonthRow` still owns two sheets. If the owner wants the issue's "one presentation point per screen", hoist those sheets into `ServiceYearPageView` behind a single `@State` item. Re-test the zoom transition from the row to `MonthDetailView` when doing it.
- If a future tab is added, give it a case in `tabDestination`; the compact stack comes from `AppRootView` and the regular one from the split view, so the new root screen needs no stack of its own.
- A reviewer should run checks 6 to 9 on an iPad first, because that is where the nesting was.
