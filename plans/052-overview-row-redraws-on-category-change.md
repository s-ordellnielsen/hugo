# Plan 052: Make the overview entry row redraw when only its category changes

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 6613507..HEAD -- Hugo/Features/Overview/Views/OverviewListView.swift`
> Plan 042 changed `OverviewCarriedEntriesView` and the line that renders it
> in this file. That is expected. Compare the `DateEntryRow` excerpt below with
> the live code by content, not by line number. On a mismatch, treat it as a
> STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/040-resolve-entry-category-in-one-place.md (DONE)
- **Category**: bug
- **Planned at**: commit `6613507`, 2026-11-03; revised 2026-11-03 at `e96ff45` (plan 042 touched this file; see the note on `DateListItem` below)

## Why this matters

On the Overview tab each entry in a day card is drawn by `DateEntryRow`, which shows the entry's category name. The row is wrapped in `.equatable()` and its `==` compares only `id`, `date` and `duration`. It never compares the category. The `==` is also weak in another way: `entry` is a reference type (a SwiftData `@Model` class), so `lhs.entry` and `rhs.entry` are normally the same object and every field comparison is trivially true. If SwiftUI skips the row because `==` says nothing changed, a user who changes an entry's category in the detail sheet could return to a row that still shows the old name. Whether the skip actually happens when only the observed `Entry` changes is not verified. This plan removes the custom equality, so the row always follows the live entry.

## Current state

- `Hugo/Features/Overview/Views/OverviewListView.swift:164-169`, the call site:

  ```swift
  ForEach(section.entries) { entry in
      DateEntryRow(entry: entry)
          .equatable()
  }
  ```

- `Hugo/Features/Overview/Views/OverviewListView.swift:183-203`, the row (nested private struct inside `OverviewListView`):

  ```swift
  private struct DateEntryRow: View, Equatable {
      var entry: Entry

      var body: some View {
          HStack {
              Text(entry.date, format: .dateTime.hour().minute())
                  .monospacedDigit()
                  .foregroundStyle(.secondary)
              Text(entry.resolvedCategory().name)
              Spacer()
              Text(Duration.seconds(entry.duration).formatted(.time(pattern: .hourMinute)))
                  .monospacedDigit()
          }
      }

      static func == (lhs: Self, rhs: Self) -> Bool {
          lhs.entry.id == rhs.entry.id && lhs.entry.date == rhs.entry.date && lhs.entry.duration == rhs.entry.duration
      }
  }
  ```

- The same file has a second, separate `.equatable()` that this plan does **not** touch. `OverviewDateList` wraps each day card as `DateListItem(section: date).equatable()`, and `DateSection.==` compares only the entries' ids, durations and dates. It can only skip updates that the parent pushes down. A category change on an entry does not change the parent's inputs, so it never reaches that comparison. Leave `DateListItem`, `DateSection` and their `==` exactly as they are.
- `Entry.resolvedCategory()` (in `Hugo/Features/Entries/EntryCategory.swift`, added by plan 040) reads `entry.tracker` and `entry.storedTracker`. `EntryDetailView` changes the category by setting `entry.tracker` and calling `entry.refreshStoredTracker()`.
- Conventions: AGENTS.md requires `@Observable`-based state and no legacy wrappers. `Entry` is an observable SwiftData model, so reading its properties inside `body` is enough for SwiftUI to track them. Other row views in the repo (for example `EntryRow` in `Hugo/Features/Entries/EntryRow.swift`) are plain `View` structs with no `Equatable` conformance. Match that.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Full gate | `Scripts/verify.sh` | exit 0, ends with `** ANALYZE SUCCEEDED **` |

## Scope

**In scope**:

- `Hugo/Features/Overview/Views/OverviewListView.swift` (`DateEntryRow` and its one call site only)
- `plans/README.md` (status row)

**Out of scope**:

- `EntryRow.swift`, `EntryDetailView.swift`, `EntryCategory.swift`. They already behave correctly.
- Any other use of `.equatable()` elsewhere in the repo. Do not search for or change them.
- Adding view tests. There are none in this repo and a redraw cannot be unit tested.

## Git workflow

- Branch: only if the operator told you to. In this repo the operator has been working directly on `main`.
- Commit message style: semantic prefix, for example `fix: redraw the overview entry row when its category changes`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Remove the custom equality

In `DateEntryRow`:

1. Change `private struct DateEntryRow: View, Equatable {` to `private struct DateEntryRow: View {`.
2. Delete the whole `static func == (lhs: Self, rhs: Self) -> Bool { ... }` function.

At the call site, delete the `.equatable()` line so it reads:

```swift
ForEach(section.entries) { entry in
    DateEntryRow(entry: entry)
}
```

**Verify**:

- `grep -n 'DateEntryRow' Hugo/Features/Overview/Views/OverviewListView.swift` → exactly two matches: the call site and `private struct DateEntryRow: View {` (no `Equatable`).
- `grep -n 'equatable()' Hugo/Features/Overview/Views/OverviewListView.swift` → exactly one match, the `DateListItem(section: date)` one.
- `grep -c 'static func ==' Hugo/Features/Overview/Views/OverviewListView.swift` → `1` (only `DateSection.==` remains).
- `xcrun swift-format lint --strict --recursive Hugo HugoTests` exits 0.

### Step 2: Run the gate

**Verify**: `Scripts/verify.sh` exits 0 and ends with `** ANALYZE SUCCEEDED **`. The test count is unchanged from the previous run.

### Step 3 [owner]: Check on a simulator

1. Run the app with at least two categories and one entry in the first.
2. Overview tab, tap the entry, change its category in the detail sheet, close the sheet.
3. Expected: the row in the day card shows the new category name immediately.
4. Edit only the entry's category, not its time or duration, so that the check isolates this bug. If you can, run the same check once on the build before this change; if the old row already updated, this plan is cleanup only (see STOP conditions).

## Test plan

No new tests. The bug is about SwiftUI redraw behavior, which unit tests do not cover. The guards are the two `grep` checks and the owner check in Step 3.

## Done criteria

- [ ] `grep -n 'equatable()' Hugo/Features/Overview/Views/OverviewListView.swift` prints one line (`DateListItem`), and `grep -c 'static func ==' Hugo/Features/Overview/Views/OverviewListView.swift` prints `1` (`DateSection`)
- [ ] `Scripts/verify.sh` exits 0
- [ ] `git status --porcelain` lists only `Hugo/Features/Overview/Views/OverviewListView.swift` and `plans/README.md`
- [ ] `plans/README.md` row for 052 updated (DONE, or DONE with owner repro pending)

## STOP conditions

Stop and report back if:

- `DateEntryRow` no longer matches the excerpt above.
- Removing `Equatable` breaks the build somewhere else (`DateEntryRow` is expected to be used only at the one call site; check with `grep -n 'DateEntryRow' Hugo -r`).
- The owner check in Step 3 shows the row already redrew correctly before this change. Then report it. The change is still harmless cleanup, but the bug claim is wrong and the plan should be marked REJECTED or re-scoped.

## Maintenance notes

- Removing `.equatable()` means each row's body re-runs whenever its parent re-runs. Rows are three `Text` views, so the cost is negligible. If the Overview list grows heavy later, measure first and restore equality by comparing the values the row actually shows (the resolved category name, time and duration as plain values), never by comparing fields on the shared `Entry` reference.
- Reviewers should check that the diff touches only `DateEntryRow` and its call site.
- `DateSection.==` ignores categories on purpose of its origin (it was written for ids, durations and dates). If a future change makes the card depend on category data that the parent reads, add the resolved category name to that comparison.
