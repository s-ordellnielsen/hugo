# Plan 161: Menu bar commands and keyboard shortcuts on iPad

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 23ba2bf..HEAD -- Hugo/App Hugo/Features/Entries/Screens Hugo/Features/Planner/Screens Hugo/Features/ServiceYear/Screens/SchoolCreditFormView.swift Hugo/Features/Settings/Screens Hugo/Features/Categories/Screens Hugo/Features/Reports/Screens`
> Expected: no output. Anything else: compare it with "Current state" and STOP on a mismatch.
> (Plans 159 and 160 landed before `23ba2bf`: many list screens end in
> `.readableListWidth()`, and the Overview's + button opens Add Entry in its
> own popover. Neither changes this plan.)
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). Never stage that file as a whole. See Step 2 for the string.

## Status

- **Priority**: P2
- **Effort**: M + owner
- **Risk**: LOW. Commands and shortcuts only add ways to reach existing screens. Nobody without a keyboard sees a change. The owner check needs a hardware keyboard on the iPad.
- **Depends on**: none
- **Category**: ux, accessibility
- **Planned at**: commit `9a7dc2e`, 2026-11-26; drift baseline refreshed to `23ba2bf` after plans 159 and 160
- **Issue**: [SLN-339](https://linear.app/sebastianln/issue/SLN-339)

## Why this matters

iPadOS 26 shows a menu bar when the user swipes down from the top or moves the
pointer to the top edge. SwiftUI fills it from the app's `.commands`. Hugo
declares none, so its menu bar has only the system defaults. The forms also
ignore the keyboard: Return does not save and Esc does not close.

After this plan:

| Menu | Item | Shortcut | Does |
|---|---|---|---|
| File | Add Entry | ⌘N | Opens Add Entry (replaces the system's New Window item) |
| Hugo (app menu) | Settings | ⌘, | Selects the Settings tab when the sidebar shows it, otherwise opens the settings sheet |
| View | Overview / Planner / Service Year | ⌘1 / ⌘2 / ⌘3 | Selects that tab |
| View | Go to Today | ⌘T | Planner: back to this month. Service Year: back to this year. Disabled on other tabs |

Forms: Return saves where there is a save button, and Esc closes every sheet
with a close button. Submit Report gets Esc only. Return must never send a report.

The menu bar lists each shortcut next to its item, so the shortcuts are
discoverable without a help page.

## Current state

`Hugo/App/HugoApp.swift`: one `WindowGroup` showing `AppRootView` (or
`StoreLoadFailureView`), with no `.commands`.

`Hugo/App/AppRootView.swift`:

- `@State private var selectedTab: AppTab = .overview`, `yearResetToken`, `plannerResetToken` (both `UUID`), `needsOnboarding` (`@AppStorage(UserDefaultsKeys.isOnboarding)`).
- `private var isCompact: Bool { horizontalSizeClass == .compact }`.
- `private func select(_ tab: AppTab)` resets the Year or Planner token when the tab is selected again, then sets `selectedTab`.
- `body` is `tabs` plus `.environment`, `.task`, several `.onReceive`, `.sheet(isPresented: $needsOnboarding) { OnboardingView { ... } }` and `.errorAlert`.
- `enum AppTab: String, CaseIterable, Identifiable, Hashable` with cases `overview`, `planner`, `year`, `settings` in that order, `titleKey` (`tab.overview`, `tab.planner`, `tab.year`, `tab.settings`), `systemImage`, `placement`. `settings` has `.sidebarOnly` placement, so it is not a tab in compact width.
- `ServiceYearView` and `PlannerView` scroll back to the current year or month when their reset token changes.

`Hugo/Features/Settings/Views/SettingsButton.swift` presents settings in compact width as:

```swift
.sheet(isPresented: $showAccount) {
    NavigationStack {
        SettingsView(showDismiss: true)
    }
    .presentationDetents([.large])
}
```

Sheet toolbars at planning time:

| File | Close button | Save button |
|---|---|---|
| `Entries/Screens/AddEntryView.swift` | `Button("navigation.dismiss", systemImage: "xmark", role: .cancel)` | `Button("entry.add.label", systemImage: "plus", action: submit)` |
| `Planner/Screens/PlanFormView.swift` | same close button | `Button("planner.plan.save", systemImage: "checkmark", action: save)` |
| `ServiceYear/Screens/SchoolCreditFormView.swift` | same close button | `Button("schoolCredit.form.save", systemImage: "checkmark", action: save)` |
| `Settings/Screens/OverseerManualEntryView.swift` | `Button(role: .cancel) { dismiss() }` | `Button(role: .confirm, action: save)` |
| `Categories/Screens/AddCategoryView.swift` | none | `Button(role: .confirm, action: submit)` |
| `Categories/Screens/CategoryPicker.swift` | `Button(role: .cancel) { dismiss() }` | none (rows select) |
| `Planner/Screens/PlannerDaySheet.swift` | same close button as Add Entry | none |
| `Settings/Screens/SettingsView.swift` | `Button(role: .cancel) { dismiss() }` in `ToolbarItem(placement: .cancellationAction)`, only when `showDismiss` | none |
| `Reports/Screens/SubmitReportView.swift` | `Button(role: .cancel) { dismiss() }` | send buttons: **no shortcut** |

String catalog: `entry.add.label` is "Add Entry" / "Tilføj til rapport", and
`settings.title` is "Settings" / "Indstillinger". The tab titles exist. No
"Go to Today" string exists.

Rules from `AGENTS.md` that apply: `Hugo/App` is composition only, Swift 6
strict concurrency with main-actor default isolation, tests mirror the source
layout, new strings in English and Danish with a comment, `Scripts/verify.sh`
before each commit.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |

## Scope

**In scope**:

- `Hugo/App/HugoApp.swift`, `Hugo/App/AppRootView.swift`
- `Hugo/App/HugoCommands.swift` (create)
- `HugoTests/App/AppTabTests.swift` (create)
- The nine sheet files in the table above (shortcut modifiers only)
- `Hugo/Resources/Localizable.xcstrings` (one key, see Step 2)

**Out of scope**:

- Arrow-key navigation in the Planner, typed durations, context menus.
- A Submit Report menu item.
- Any change to what a sheet shows or how it saves.
- `StoreLoadFailureView` (no commands while the store failed to load; `actions` is `nil` there, so every item is disabled).

## Git workflow

- Work on `main`. Commit per step. Conventional Commits, for example `feat(app): add menu bar commands`.
- Do not push.

## Steps

### Step 1: Tab shortcut facts, with tests

In `AppRootView.swift`, extend `AppTab` (next to `placement`):

```swift
    /// The digit for ⌘1, ⌘2 and ⌘3, in tab bar order. Settings uses ⌘, instead.
    var commandDigit: Character? {
        switch self {
        case .overview: "1"
        case .planner: "2"
        case .year: "3"
        case .settings: nil
        }
    }

    /// Whether Go to Today does something on this tab.
    var showsTodayCommand: Bool {
        switch self {
        case .planner, .year: true
        case .overview, .settings: false
        }
    }
```

Create `HugoTests/App/AppTabTests.swift` (`struct`, Swift Testing):

1. `tabDigitsFollowTabBarOrder`: overview "1", planner "2", year "3", settings `nil`.
2. `digitsAreUnique`: the non-nil digits of `AppTab.allCases` have no duplicates.
3. `todayCommandOnlyOnPagedTabs`: true for planner and year, false for overview and settings.

**Verify**: `Scripts/verify.sh` exits 0, with 3 more tests. Commit `feat(app): add tab shortcut digits`.

### Step 2: Commands

Create `Hugo/App/HugoCommands.swift`:

```swift
import SwiftUI

/// What the menu bar can ask the focused window to do. `AppRootView` publishes
/// it with `focusedSceneValue`.
struct AppCommandActions {
    var selectedTab: AppTab
    var addEntry: () -> Void
    var select: (AppTab) -> Void
    var showToday: () -> Void
    var showSettings: () -> Void
}

extension FocusedValues {
    @Entry var appCommands: AppCommandActions?
}

/// Hugo's menu bar items on iPad (and keyboard shortcuts on any device with a keyboard).
struct HugoCommands: Commands {
    @FocusedValue(\.appCommands) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("entry.add.label") { actions?.addEntry() }
                .keyboardShortcut("n")
                .disabled(actions == nil)
        }
        CommandGroup(replacing: .appSettings) {
            Button("settings.title") { actions?.showSettings() }
                .keyboardShortcut(",")
                .disabled(actions == nil)
        }
        CommandGroup(before: .sidebar) {
            ForEach(AppTab.allCases.filter { $0.commandDigit != nil }) { tab in
                if let digit = tab.commandDigit {
                    Button(tab.titleKey) { actions?.select(tab) }
                        .keyboardShortcut(KeyEquivalent(digit))
                        .disabled(actions == nil)
                }
            }
            Button("commands.today") { actions?.showToday() }
                .keyboardShortcut("t")
                .disabled(!(actions?.selectedTab.showsTodayCommand ?? false))
            Divider()
        }
    }
}
```

If the closures in `AppCommandActions` cause a Sendable or isolation error, mark
the struct `@MainActor` and the closure types `@MainActor () -> Void`. Do not add
`@unchecked Sendable` or `nonisolated(unsafe)`.

In `HugoApp.swift`, add `.commands { HugoCommands() }` after the `WindowGroup { ... }`.

Add the string `commands.today` to `Localizable.xcstrings`:
English "Go to Today", Danish "Gå til i dag", comment
"Menu bar item on iPad (⌘T). Scrolls the Planner to this month or the Service Year tab to this theocratic year."

Strings: the catalog has the owner's uncommitted edits (around line 2,900, under
`planner.target.*`), and `git add -p` is interactive, so do not use it. Run this
script from the repo root instead. It inserts the key before `"common.add"`
(keys are alphabetical) in the working file, and stages the committed version of
the file plus only your key:

```sh
python3 - <<'EOF'
import subprocess
path = 'Hugo/Resources/Localizable.xcstrings'
block = '''    "commands.today" : {
      "comment" : "Menu bar item on iPad (⌘T). Scrolls the Planner to this month or the Service Year tab to this theocratic year.",
      "localizations" : {
        "da" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Gå til i dag"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Go to Today"
          }
        }
      }
    },
'''
anchor = '    "common.add" : {\n'
def insert(text):
    assert text.count(anchor) == 1, 'anchor not found exactly once'
    assert '"commands.today"' not in text, 'key already present'
    return text.replace(anchor, block + anchor, 1)
work = open(path, encoding='utf-8').read()
open(path, 'w', encoding='utf-8').write(insert(work))
head = subprocess.run(['git', 'show', 'HEAD:' + path], capture_output=True, text=True, check=True).stdout
blob = subprocess.run(['git', 'hash-object', '-w', '--stdin'], input=insert(head),
                      capture_output=True, text=True, check=True).stdout.strip()
subprocess.run(['git', 'update-index', '--cacheinfo', '100644,' + blob + ',' + path], check=True)
EOF
```

Then `git diff --cached Hugo/Resources/Localizable.xcstrings` must show exactly
the 17 added lines of the key and nothing else, and
`git diff Hugo/Resources/Localizable.xcstrings` (unstaged) must still show the
owner's `planner.target` hunks. If an assertion fails or either check differs,
STOP. Never run `git add` on the catalog afterwards: that would stage the owner's
edits. A build may touch the working file again; that is fine, because the staged
version does not change.

**Verify**: `Scripts/verify.sh` exits 0, and `git diff --cached --stat` shows only your key in the catalog. Commit `feat(app): add menu bar commands`.

### Step 3: Wire the commands in the root

In `AppRootView.swift`:

```swift
@State private var isAddingEntry = false
@State private var isShowingSettingsSheet = false
```

```swift
private var commandActions: AppCommandActions {
    AppCommandActions(
        selectedTab: selectedTab,
        addEntry: { if !needsOnboarding { isAddingEntry = true } },
        select: { select($0) },
        showToday: showToday,
        showSettings: showSettings
    )
}

/// Scrolls the Planner or the Service Year back to now, like selecting its tab again.
private func showToday() {
    switch selectedTab {
    case .planner: plannerResetToken = UUID()
    case .year: yearResetToken = UUID()
    case .overview, .settings: break
    }
}

/// The Settings tab when the sidebar lists it, otherwise the same sheet as the
/// toolbar's settings button.
private func showSettings() {
    if AppTab.settings.placement.isVisible(compact: isCompact) {
        select(.settings)
    } else {
        isShowingSettingsSheet = true
    }
}
```

In `body`, on `tabs` before `.environment(syncMonitor)`, add
`.focusedSceneValue(\.appCommands, commandActions)`. Next to the onboarding
sheet, add:

```swift
.sheet(isPresented: $isAddingEntry) { AddEntryView() }
.sheet(isPresented: $isShowingSettingsSheet) {
    NavigationStack {
        SettingsView(showDismiss: true)
    }
    .presentationDetents([.large])
}
```

Known limit, do not work around it: if another sheet or popover is already open,
⌘N and ⌘, do nothing, because SwiftUI presents one sheet at a time from a view.

**Verify**: `Scripts/verify.sh` exits 0. Commit `feat(app): open Add Entry and Settings from the menu bar`.

### Step 4: Return and Esc in forms

Add `.keyboardShortcut(.cancelAction)` to the close button and
`.keyboardShortcut(.defaultAction)` to the save button, exactly as the table in
"Current state" lists them. Put each modifier directly on the `Button`, before
`.buttonStyle`, `.tint` and `.disabled`. A disabled save button ignores Return,
which is what we want.

- `SubmitReportView`: `.cancelAction` on the close button only. Do not touch any send or copy button.
- `SettingsView`: `.cancelAction` on the `showDismiss` button.
- `AddCategoryView`: `.defaultAction` on the confirm button only (it has no close button).
- `CategoryPicker`, `PlannerDaySheet`: `.cancelAction` only.

**Verify**: `Scripts/verify.sh` exits 0, and
`git diff -U0 | grep -c "keyboardShortcut(.defaultAction)"` prints 5 and
`git diff -U0 | grep -c "keyboardShortcut(.cancelAction)"` prints 8
(before committing). Commit `feat: save with Return and close with Esc in forms`.

## Test plan

- The three `AppTab` tests. Menu wiring and shortcuts are checked by the owner.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, with 3 more tests than before
- [ ] `HugoApp` declares `HugoCommands`; `AppRootView` publishes `appCommands`
- [ ] 5 `.defaultAction` and 8 `.cancelAction` shortcuts, none on a send button
- [ ] Only the `commands.today` key is committed in the catalog; the owner's other edits are still unstaged
- [ ] `plans/README.md` row updated

Owner check on the iPad (Sean) with a hardware keyboard, in English and Danish:

1. Swipe down from the top (or move the pointer there). File has Add Entry ⌘N, the Hugo menu has Settings ⌘,, and View has the three tabs and Go to Today ⌘T.
2. ⌘N opens Add Entry. Return adds the entry when a duration is set; Esc closes it.
3. ⌘1, ⌘2, ⌘3 switch tabs. On the Planner, swipe to another month and press ⌘T: back to this month. The same on Service Year. On Overview, Go to Today is greyed out.
4. ⌘, opens the Settings tab. In a narrow window, ⌘, opens the settings sheet, and Esc closes it.
5. Add Plan, school credit, the overseer form: Return saves, Esc closes. Add Category: Return saves once a name is typed. Category picker and a Planner day: Esc closes.
6. Submit Report: Return does nothing. Esc closes.
7. The toolbar buttons look exactly as before.

If the View menu items are missing in step 1, report it (see STOP conditions).

If the iPad has no keyboard, the same checks can run on this Mac as "My Mac
(Designed for iPad)", if the app builds and launches there. Note which way it
was checked.

## STOP conditions

Stop and report if:

- `CommandGroup(replacing: .appSettings)` or `CommandGroup(before: .sidebar)` does not compile for iOS, or the owner check shows its items missing. Report it. Do not invent a new menu: a custom "Go" menu needs a new string and an owner decision.
- `@Entry` on `FocusedValues` does not compile.
- Adding `.keyboardShortcut(.defaultAction)` changes how a toolbar button looks.
- The catalog diff conflicts with the owner's edits.

## Maintenance notes

- New sheets with a close and a save button should get `.cancelAction` and `.defaultAction`. Never put `.defaultAction` on a button that sends something outside the app.
- New menu items go in `HugoCommands` and get their action through `AppCommandActions`. Keep the list short: the menu bar is part of Hugo's simplicity too.
- Arrow keys in the Planner grid and a typed duration field for keyboard users are possible follow-ups, not planned.
