# Plan 107: Count time without a category as main time everywhere

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 3055ae6..HEAD -- Hugo/Features/Entries/Domain/EntryCategory.swift Hugo/Features/Reports/Domain/MonthlyReportBuilder.swift Hugo/Features/Reports/Domain/MonthlyReportSummary.swift CONTEXT.md HugoTests/Features/Entries/Domain/EntryCategoryTests.swift HugoTests/Features/Reports/Domain/MonthlyReportBuilderTests.swift HugoTests/Features/Reports/Domain/ServiceMonthTests.swift HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift`
> Expected: no output. Otherwise compare the excerpts below with the live
> files. A mismatch is a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW. One rule in one builder, covered by tests. No schema, no UI code.
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `3055ae6`, 2026-11-13
- **Issue**: [SLN-288](https://linear.app/sebastianln/issue/SLN-288)

## Why this matters

An **untracked entry** is an entry with neither a category nor a category snapshot (see `CONTEXT.md`). Hugo treats its time in two different ways:

- The report counts it on the Field Service line, so it is reported.
- The month summary behind the Year page leaves it out of main time. So it never counts toward the yearly goal, the Year page's main total or the Planner target's credit for earlier months.

A pioneer can therefore report hours that never show up in their yearly progress. The owner decided on 2026-11-13 that untracked time counts as **main** time everywhere. The report and the Planner already do this. This plan fixes the one place that doesn't, and gives the rule a single home so the next screen can't get it wrong.

## Current state

Where Hugo decides whether time is main time today (all verified at `3055ae6`):

| Place | Untracked time counts as | Status |
|---|---|---|
| `ReportingLineCalculator.lines` (`Hugo/Features/Reports/Domain/ReportingLineCalculator.swift:19-24`) | main (`resolved.type == nil` becomes a `.main` `Category`) | correct |
| `ReportingLineCalculator.categoryHours` (same file, around line 134) | main (`category.type == .main \|\| category.type == nil`) | correct |
| `TimeSplit.add` (`Hugo/Features/Planner/Domain/PlannerMonth.swift:12-15`) | main (`if type == .separate { separate } else { main }`) | correct |
| `PlanMatcher` (`Hugo/Features/Planner/Domain/PlanMatcher.swift:89-90`) | main (`category.type ?? .main`) | correct |
| `OverviewMetrics.make` (`Hugo/Features/Overview/Domain/OverviewMetrics.swift:13`) | sums every entry, no main/separate split | not affected |
| **`MonthlyReportBuilder.summaries`** (`Hugo/Features/Reports/Domain/MonthlyReportBuilder.swift:25-27`) | **neither main nor separate** | **the bug** |

The bug, `Hugo/Features/Reports/Domain/MonthlyReportBuilder.swift:21-28`:

```swift
            for entry in monthEntries {
                totalSeconds += entry.duration
                bibleStudies += entry.bibleStudies

                let type = entry.resolvedCategory(locale: locale).type
                if type == .main { mainDuration += entry.duration }
                if type == .separate { separateDuration += entry.duration }
            }
```

For an untracked entry `type` is `nil`, so its time lands in `totalSeconds` but in neither `mainDuration` nor `separateDuration`. Everything downstream inherits that:

- `ServiceMonth.contribution` (`Hugo/Features/Reports/Domain/ServiceMonth.swift:60-65`) uses `summary.mainDuration` and `summary.separateDuration` for a month that is not submitted yet.
- `YearlyGoalProgress` (`Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift:56`) and `PlannerTarget.creditedSeconds` (`Hugo/Features/Planner/Domain/PlannerTarget.swift:109-116`) credit `rule.creditedSeconds(main: contribution.main, separate: contribution.separate)`. Untracked time is never credited.
- `TheocraticYearReportBuilder` (`Hugo/Features/ServiceYear/Domain/TheocraticYearReportBuilder.swift:26-27`), `ServiceYearDetailView` (lines 52-56) and `MonthlyReportTotalsView` (lines 22 and 30) show main and separate totals that don't add up to the total.

Submitted months are not affected: they use the reported hours on their reporting lines, which already count untracked time as main.

`EntryCategory`, `Hugo/Features/Entries/Domain/EntryCategory.swift:6-19`:

```swift
nonisolated struct EntryCategory: Hashable {
    /// Grouping key: the tracker's UUID string, `stored:<name>|<icon>|<type>`
    /// for a snapshot, or `untracked`.
    let key: String
    let name: String
    let iconName: String
    /// `nil` only for an untracked entry.
    let type: TrackerType?
    /// Set only when the live tracker is attached.
    let trackerID: UUID?
    /// False only when the live category turned Bible studies off. A
    /// category snapshot and an untracked entry allow them.
    let allowsBibleStudies: Bool
}
```

`TrackerType` (`Hugo/Persistence/Legacy/TrackerType.swift`) has two cases, `.main` and `.separate`. Persistence names keep `Tracker`; the UI and `CONTEXT.md` say "category" (AGENTS.md). Use "main category", "separate category", "untracked entry" and "main time" in comments.

`CONTEXT.md` today:

```markdown
**Untracked entry**:
An entry that has neither a category nor a category snapshot.
```

Leave `type` itself as it is. `CategoryTotals` relies on `type == nil` to give untracked time its own "Untracked" row (`Hugo/Features/Entries/Domain/CategoryTotals.swift:39-42`), and that row should stay so the user can see and fix those entries.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Full gate (lint, layout check, all tests serially, analyze) | `Scripts/verify.sh` | exit 0 |
| Whitespace | `git diff --check` | exit 0 |

`Scripts/verify.sh` runs the whole test suite. There is no faster per-file test command in this repo, so run it once after Step 3 and again before the commit if you changed anything since.

## Scope

**In scope** (the only files you may change):

- `Hugo/Features/Entries/Domain/EntryCategory.swift`
- `Hugo/Features/Reports/Domain/MonthlyReportBuilder.swift`
- `Hugo/Features/Reports/Domain/MonthlyReportSummary.swift` (doc comments only)
- `CONTEXT.md`
- `HugoTests/Features/Entries/Domain/EntryCategoryTests.swift`
- `HugoTests/Features/Reports/Domain/MonthlyReportBuilderTests.swift`
- `HugoTests/Features/Reports/Domain/ServiceMonthTests.swift`
- `HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift`

**Out of scope**:

- `ReportingLineCalculator.swift`, `PlannerMonth.swift`, `PlanMatcher.swift`. They already count untracked time as main. Switching them to the new property is a tidy-up nobody asked for, and each has its own tests that would need review.
- `CategoryTotals.swift`. The "Untracked" row stays.
- Any view. The views read `mainDuration` and `contribution`; fixing the builder fixes them.
- Any SwiftData model or schema. Nothing stored changes.
- `plans/README.md` beyond this plan's own status row, `Hugo.xcodeproj/project.pbxproj`, `.claude/` and the owner's `Changelog/` changes. Never stage them.

## Git workflow

- Work on `main`. No branch, no worktree, no push. Stage files by path.
- One commit after `Scripts/verify.sh` exits 0, Conventional Commits style as in `git log` (for example `b7124c2 feat: show the selected category in its color in Add Entry`). Use: `fix: count time without a category as main time everywhere`.

## Steps

### Step 1: Give the rule one home on `EntryCategory`

In `Hugo/Features/Entries/Domain/EntryCategory.swift`, add a computed property inside `struct EntryCategory`, right after `let type: TrackerType?`:

```swift
    /// What this entry's time counts as. Untracked time counts as main time,
    /// as it does on the Field Service line. Use this, not `type`, whenever
    /// time is split into main and separate.
    var countsAs: TrackerType { type ?? .main }
```

**Verify**: `xcrun swift-format lint --strict Hugo/Features/Entries/Domain/EntryCategory.swift` exits 0.

### Step 2: Use it in `MonthlyReportBuilder`

In `Hugo/Features/Reports/Domain/MonthlyReportBuilder.swift`, replace the three lines

```swift
                let type = entry.resolvedCategory(locale: locale).type
                if type == .main { mainDuration += entry.duration }
                if type == .separate { separateDuration += entry.duration }
```

with

```swift
                switch entry.resolvedCategory(locale: locale).countsAs {
                case .main: mainDuration += entry.duration
                case .separate: separateDuration += entry.duration
                }
```

The `switch` is exhaustive, so `mainDuration + separateDuration` now always equals `totalSeconds`.

In `Hugo/Features/Reports/Domain/MonthlyReportSummary.swift`, add doc comments above the two properties of `MonthlyReportSummary`:

```swift
    /// Logged time in main categories, including untracked time.
    let mainDuration: TimeInterval
    /// Logged time in separate categories.
    let separateDuration: TimeInterval
```

**Verify**: `xcrun swift-format lint --strict --recursive Hugo` exits 0. `grep -n "countsAs" Hugo/Features/Reports/Domain/MonthlyReportBuilder.swift` prints one line.

### Step 3: Add the tests

Use Swift Testing (`import Testing`, `@Test`, `#expect`, `#require`) and match the helpers already in each file.

1. `HugoTests/Features/Entries/Domain/EntryCategoryTests.swift`, add two tests:

```swift
    @Test
    func untrackedTimeCountsAsMain() {
        let entry = Entry(date: .now, duration: 1_800, tracker: nil)
        #expect(entry.resolvedCategory().countsAs == .main)
    }

    @Test
    func categorizedTimeCountsAsItsType() {
        let separate = Entry(date: .now, duration: 1_800, tracker: Tracker(name: "Bethel", type: .separate))
        let snapshot = Entry(date: .now, duration: 1_800, tracker: nil)
        snapshot.storedTracker = Entry.EntryTracker(name: "LDC", icon: "hammer", type: .separate)
        #expect(separate.resolvedCategory().countsAs == .separate)
        #expect(snapshot.resolvedCategory().countsAs == .separate)
    }
```

2. `HugoTests/Features/Reports/Domain/MonthlyReportBuilderTests.swift`, add (it uses the file's `date(_:_:_:)` helper, `calendar` and `locale`):

```swift
    @Test
    func untrackedTimeCountsAsMainDuration() throws {
        let main = Tracker(name: "Field Service", type: .main, iconName: "figure.walk")
        let separate = Tracker(name: "Bethel", type: .separate, iconName: "building")
        let entries = [
            Entry(date: date(2026, 1, 1), duration: 3_600, tracker: main),
            Entry(date: date(2026, 1, 2), duration: 600, tracker: nil),
            Entry(date: date(2026, 1, 3), duration: 900, tracker: separate),
        ]
        let summary = try #require(
            MonthlyReportBuilder.summaries(from: entries, calendar: calendar, locale: locale).first)

        #expect(summary.mainDuration == 4_200)
        #expect(summary.separateDuration == 900)
        #expect(summary.mainDuration + summary.separateDuration == summary.totalSeconds)
    }
```

   Also add `#expect(summary.mainDuration == 600)` at the end of the existing `includesFullyUntrackedEntriesInTotal()` test.

3. `HugoTests/Features/Reports/Domain/ServiceMonthTests.swift`: the existing test `unsubmittedMonthContributesLoggedTime()` builds its month from `oldEntry(seconds: 5_400)`, whose `tracker` defaults to `nil`, so the entry is untracked. Add two lines to it:

```swift
        #expect(m.contribution.main == 5_400)
        #expect(m.contribution.separate == 0)
```

4. `HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift`, add (it uses the file's `makeProgress(entries:now:)` and `date(_:_:_:)` helpers; read `mainOnlyTimeDoesNotShowAYearTotal()` first and match it):

```swift
    @Test
    func untrackedTimeCountsTowardTheYearlyGoal() {
        let entries = [Entry(date: date(2026, 9, 1), duration: 40 * 3_600, tracker: nil)]
        let progress = makeProgress(entries: entries, now: date(2026, 10, 15))
        #expect(progress.creditedSeconds == 40 * 3_600)
        #expect(progress.creditedSeconds == progress.yearTotalSeconds)
        #expect(!progress.showsYearTotal)
    }
```

The new `MonthlyReportBuilder`, `ServiceMonth` and `YearlyGoalProgress` assertions fail without Step 2. That is how you know they test the bug.

**Verify**: `Scripts/verify.sh` exits 0. Then, optionally, to prove the tests catch the bug: `git stash push Hugo/Features/Reports/Domain/MonthlyReportBuilder.swift`, run `Scripts/verify.sh` and see it fail in `untrackedTimeCountsAsMainDuration`, `unsubmittedMonthContributesLoggedTime` and `untrackedTimeCountsTowardTheYearlyGoal`, then `git stash pop`.

### Step 4: Record the rule in `CONTEXT.md`

Replace the **Untracked entry** definition with:

```markdown
**Untracked entry**:
An entry that has neither a category nor a category snapshot. Its time counts as main time everywhere: on the Field Service line, in the month's main total and toward the yearly goal.
```

**Verify**: `grep -n "counts as main time everywhere" CONTEXT.md` prints one line.

### Step 5: Commit

**Verify**: `Scripts/verify.sh` exits 0, `git diff --check` exits 0, and `git status --short` lists only the in-scope files (plus the owner's untouched `Changelog/` changes, which you must not stage). Commit with the message from "Git workflow".

## Test plan

- `EntryCategoryTests`: `untrackedTimeCountsAsMain`, `categorizedTimeCountsAsItsType` (live separate category and separate snapshot).
- `MonthlyReportBuilderTests`: `untrackedTimeCountsAsMainDuration` (main + untracked + separate; main and separate add up to the total), plus one line in `includesFullyUntrackedEntriesInTotal`.
- `ServiceMonthTests`: two lines in `unsubmittedMonthContributesLoggedTime` (untracked time in `contribution.main`).
- `YearlyGoalProgressTests`: `untrackedTimeCountsTowardTheYearlyGoal`.
- Existing tests in `TheocraticYearReportBuilderTests` use untracked entries only in submitted months or only check `totalSeconds`, so they should pass unchanged. If one fails, see STOP conditions.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -n "var countsAs" Hugo/Features/Entries/Domain/EntryCategory.swift` prints one line
- [ ] `grep -n "type == .main\|type == .separate" Hugo/Features/Reports/Domain/MonthlyReportBuilder.swift` prints nothing
- [ ] `grep -rhoE "func (untrackedTimeCountsAsMain|untrackedTimeCountsAsMainDuration|untrackedTimeCountsTowardTheYearlyGoal|categorizedTimeCountsAsItsType)\(" HugoTests | wc -l` prints 4
- [ ] `git show --stat HEAD` lists only in-scope files
- [ ] `plans/README.md` row for 107 updated

## STOP conditions

- The drift check shows changes and an excerpt no longer matches.
- An existing test outside the four test files above fails after Step 2. It may encode the old rule on purpose. Report the test name and assertion. Do not change it.
- The fix seems to need a change in a view, in `ServiceMonth.swift`, or in a SwiftData model.
- `EntryCategory` has gained other uses of `type` for main/separate splitting since `3055ae6` (`grep -rn "resolvedCategory" Hugo` shows a new caller that compares `.type` with `.main` or `.separate`). Report it instead of fixing it.

## Maintenance notes

- New code that splits time into main and separate should use `entry.resolvedCategory().countsAs`, never `.type == .main`. Keep `type` for display, where "Untracked" needs its own row.
- `ReportingLineCalculator`, `TimeSplit.add` and `PlanMatcher` follow the same rule with their own `?? .main` / `else main`. A later tidy-up may switch them to `countsAs`. It changes no behavior.
- After this lands, an unsubmitted month with untracked time shows a higher main total and more credited time on the Year page and in the Planner target. That is the intended fix. Submitted months don't change.
- No owner device check is needed: untracked entries are rare (they need a category deleted before snapshots existed) and the tests cover the numbers.
