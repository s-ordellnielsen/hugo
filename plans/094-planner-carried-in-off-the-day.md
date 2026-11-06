# Plan 094: Keep carried-in entries off Planner days but in the month's logged total

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat f7d3644..HEAD -- Hugo/Features/Planner/Domain/PlannerMonth.swift Hugo/Features/Planner/Screens/PlannerDaySheet.swift HugoTests/Features/Planner/Domain/PlannerMonthTests.swift`
> Expected: no output. If a file is listed, compare the "Current state" excerpts below with the live code. On any mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW (Planner domain value type and one screen; no schema, string or data change)
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `f7d3644`, 2026-11-06
- **Issue**: [SLN-299](https://linear.app/sebastianln/issue/SLN-299)

## Why this matters

When a user submits a report with the Transfer rounding rule, Hugo creates a **carried-in entry** on the 1st of the next month to hold the transferred minutes. The Planner treats that entry as time the user logged on the 1st:

- the 1st's calendar cell gets an "unplanned" bar for it,
- the 1st's day sheet lists it under "Logged",
- it counts toward plans on the 1st, so a plan can look done when the user did nothing.

The owner decided (2026-11-06): carried-in time stays out of every **day**, but it still counts in the **month's** logged total (status header and pace), because it counts on that month's report.

## Current state

Domain vocabulary (from `CONTEXT.md`, use these words in comments):

> **Carried-in entry**: An entry Hugo creates on the 1st of the next month to hold minutes that were transferred. _Avoid_: Generated entry, carry entry

`Entry.isCarriedIn` already exists (`Hugo/Persistence/SchemaVersions/V11/EntryV11.swift:55`): true when `sourceReportYear` and `sourceReportMonth` are both set. Overview already uses it the same way (`OverviewMetrics.swift:18`: `entries.contains { !$0.isCarriedIn && $0.duration > 0 }`).

- `Hugo/Features/Planner/Domain/PlannerMonth.swift` holds `TimeSplit`, `PlannerDay` and `PlannerMonth`.

  `PlannerDay.make` (lines 41–75) counts every entry it receives:

  ```swift
          var logged = TimeSplit.zero
          var byCategory: [String: LoggedCategoryTime] = [:]
          for entry in entries {
              let seconds = max(entry.duration, 0)
              let category = entry.resolvedCategory()
              logged.add(seconds, type: category.type)
  ```

  `PlannerMonth` (lines 79–116):

  ```swift
  nonisolated struct PlannerMonth: Equatable, Sendable {
      let month: YearMonth
      let today: CalendarDay
      let days: [PlannerDay]

      var hasPlans: Bool { days.contains { $0.planned.total > 0 } }

      var logged: TimeSplit { days.reduce(.zero) { $0 + $1.logged } }
      ...
      /// Logged time plus still-planned time.
      var projected: TimeSplit { logged + stillPlanned }

      /// Entries and items outside `month` are ignored.
      static func make(
          month: YearMonth,
          items: [PlannedItem],
          entries: [Entry],
          trackers: [Tracker] = [],
          now: Date = .now,
          calendar: Calendar = .current
      ) -> PlannerMonth {
          let today = CalendarDay(now, calendar: calendar)
          let entriesByDay = Dictionary(grouping: entries) { CalendarDay($0.date, calendar: calendar) }
          let itemsByDay = Dictionary(grouping: items, by: \.day)
          let days = month.days(calendar: calendar).map { day in
              PlannerDay.make(
                  day: day, items: itemsByDay[day] ?? [], entries: entriesByDay[day] ?? [],
                  trackers: trackers, today: today)
          }
          return PlannerMonth(month: month, today: today, days: days)
      }
  ```

  `PlannerMonth(month:today:days:)` is called only in that one `return`. `stillPlanned` uses each day's `logged`, so with carried-in time off the days it no longer covers plans on the 1st. That is intended. `PlanPace` and `PlannerMonthStatus` read `month.logged`, so they keep counting carried-in time once `logged` includes it. Do not edit them.

- `Hugo/Features/Planner/Screens/PlannerDaySheet.swift` queries all entries on the day and passes them to both the logged list and `PlannerDay.make`:

  ```swift
                      if !entries.isEmpty {
                          PlannerLoggedEntryList(entries: entries, total: plannerDay.logged.total) { entry in
                              selectedEntry = entry
                          }
                      }
  ```

  ```swift
      private var plannerDay: PlannerDay {
          PlannerDay.make(day: day, items: items, entries: entries, trackers: trackers, today: CalendarDay(today))
      }
  ```

- `HugoTests/Features/Planner/Domain/PlannerMonthTests.swift` is the test file. It has helpers `makeMonth(items:entries:)`, `item(_:hours:tracker:id:)`, `date(_:_:_:hour:)`, fixed `calendar` (GMT Gregorian), `november`, `now` = 2026-11-03 12:00, and trackers `main`, `separate`, `phone`. Pattern for a carried-in entry in tests (from `OverviewMetricsTests.swift:37-39`):

  ```swift
          let carried = Entry(date: date(2026, 1, 1), duration: 1_800, tracker: nil)
          carried.sourceReportYear = 2025
          carried.sourceReportMonth = 12
  ```

- Project facts: Swift 6, default actor isolation `MainActor`, Planner domain types are `nonisolated`. Tests use Swift Testing (`@Test`, `#expect`). 4-space indentation.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/PlannerMonthTests -only-testing:HugoTests/PlanPaceTests -only-testing:HugoTests/PlannerMonthStatusTests` | `** TEST SUCCEEDED **` |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Full gate | `Scripts/verify.sh` | exit 0 (several minutes) |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run the same command again.

## Scope

**In scope** (the only files you may modify):
- `Hugo/Features/Planner/Domain/PlannerMonth.swift`
- `Hugo/Features/Planner/Screens/PlannerDaySheet.swift`
- `HugoTests/Features/Planner/Domain/PlannerMonthTests.swift`

**Out of scope**:
- `PlanPace.swift`, `PlannerMonthStatus.swift`, `PlannerTarget.swift`. The yearly goal already comes from reports, and month status reads `month.logged`.
- `PlannerLoggedEntryList.swift` and every other view. No visual or string change. Do not add a "carried in" row anywhere.
- Overview, Reports and persistence code.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- Never stage, edit, stash or discard files in `plans/` or `.claude/`. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage the three in-scope files by explicit path.
- One commit: `fix: keep carried-in entries off Planner days`

## Steps

### Step 1: Write the failing tests

Add these tests inside `struct PlannerMonthTests` in `HugoTests/Features/Planner/Domain/PlannerMonthTests.swift`, before `private func makeMonth`, and add the helper `carriedIn` next to the other private helpers:

```swift
    @Test
    func carriedInEntryLeavesTheFirstWithoutABarOrLoggedTime() {
        let entries = [carriedIn(date(2026, 11, 1), seconds: 1_800, tracker: main)]
        let month = makeMonth(items: [], entries: entries)

        #expect(month.days[0].bars.isEmpty)
        #expect(month.days[0].logged == .zero)
    }

    @Test
    func carriedInEntryStillCountsInTheMonthsLoggedTime() {
        let entries = [
            carriedIn(date(2026, 11, 1), seconds: 1_800, tracker: main),
            carriedIn(date(2026, 11, 1), seconds: 900, tracker: separate),
            Entry(date: date(2026, 11, 2, hour: 10), duration: 3_600, tracker: main),
        ]
        let month = makeMonth(items: [], entries: entries)

        #expect(month.carriedIn == TimeSplit(main: 1_800, separate: 900))
        #expect(month.logged == TimeSplit(main: 5_400, separate: 900))
    }

    @Test
    func carriedInEntryDoesNotCoverAPlanOnTheFirst() {
        let now = date(2026, 11, 1, hour: 8)
        let items = [item(CalendarDay(year: 2026, month: 11, day: 1), hours: 1, tracker: main)]
        let entries = [carriedIn(date(2026, 11, 1), seconds: 3_600, tracker: main)]
        let month = PlannerMonth.make(
            month: november, items: items, entries: entries, now: now, calendar: calendar)

        #expect(month.days[0].bars.first?.filledSeconds == 0)
        #expect(month.stillPlanned == TimeSplit(main: 3_600, separate: 0))
    }
```

```swift
    private func carriedIn(_ date: Date, seconds: TimeInterval, tracker: Tracker?) -> Entry {
        let entry = Entry(date: date, duration: seconds, tracker: tracker)
        entry.sourceReportYear = 2026
        entry.sourceReportMonth = 10
        return entry
    }
```

**Verify**: the focused tests do NOT build, because `PlannerMonth` has no `carriedIn` yet (`** TEST FAILED **` with "value of type 'PlannerMonth' has no member 'carriedIn'"). If they build and pass, STOP and report. If `filledSeconds` does not exist on `PlannerBar`, STOP and report.

### Step 2: Leave carried-in entries off the day and add them to the month

In `Hugo/Features/Planner/Domain/PlannerMonth.swift`:

1. In `PlannerDay.make`, skip carried-in entries. Change the loop header to

   ```swift
           for entry in entries where !entry.isCarriedIn {
   ```

   and extend the doc comment above `static func make` with one line:
   `/// Carried-in entries are skipped: their time was not logged on this day.`

2. In `PlannerMonth`, add a stored property after `let days: [PlannerDay]`:

   ```swift
       /// Time from carried-in entries. It is on no day, but it counts toward
       /// the month, as it does on the month's report.
       let carriedIn: TimeSplit
   ```

   and change `logged` to

   ```swift
       var logged: TimeSplit { days.reduce(carriedIn) { $0 + $1.logged } }
   ```

3. In `PlannerMonth.make`, before `return`, sum the carried-in entries that fall inside the month, then pass the sum:

   ```swift
           let monthDays = Set(days.map(\.id))
           var carriedIn = TimeSplit.zero
           for entry in entries where entry.isCarriedIn && monthDays.contains(CalendarDay(entry.date, calendar: calendar)) {
               carriedIn.add(max(entry.duration, 0), type: entry.resolvedCategory().type)
           }
           return PlannerMonth(month: month, today: today, days: days, carriedIn: carriedIn)
   ```

   If the `for` line exceeds the lint line length, break it the way swift-format suggests. Run the lint to check.

**Verify**: the focused tests → `** TEST SUCCEEDED **`, including the three new tests and all existing ones in `PlannerMonthTests`, `PlanPaceTests` and `PlannerMonthStatusTests`.

### Step 3: Hide carried-in entries from the day sheet's logged list

In `Hugo/Features/Planner/Screens/PlannerDaySheet.swift`, add below the `plannerDay` property:

```swift
    /// The day's entries without carried-in entries, which the Planner keeps off every day.
    private var loggedEntries: [Entry] { entries.filter { !$0.isCarriedIn } }
```

and change the list block in `body` to

```swift
                    let loggedEntries = self.loggedEntries
                    if !loggedEntries.isEmpty {
                        PlannerLoggedEntryList(entries: loggedEntries, total: plannerDay.logged.total) { entry in
                            selectedEntry = entry
                        }
                    }
```

If `let` inside the `VStack` builder does not compile, compute `let loggedEntries = self.loggedEntries` next to `let plannerDay = self.plannerDay` at the top of `body` instead. Leave `plannerDay` passing `entries` unchanged, because `PlannerDay.make` now skips carried-in entries itself.

**Verify**: `xcrun swift-format lint --strict --recursive Hugo HugoTests` → exit 0, no output.

### Step 4: Run the gate and commit

Run `Scripts/verify.sh`. Stage the three in-scope files by path and commit with the message from "Git workflow".

**Verify**: `Scripts/verify.sh` exits 0. `git show --stat HEAD` lists only the three in-scope files.

## Test plan

- `carriedInEntryLeavesTheFirstWithoutABarOrLoggedTime`: no bar and no logged time on the 1st.
- `carriedInEntryStillCountsInTheMonthsLoggedTime`: `carriedIn` is split by kind, and `logged` is days plus carried-in time.
- `carriedInEntryDoesNotCoverAPlanOnTheFirst`: a plan on the 1st stays unfilled and still planned.
- Existing `PlannerMonthTests`, `PlanPaceTests` and `PlannerMonthStatusTests` keep passing.

## Done criteria

- [ ] Step 1's tests failed to build before the change (record the output in your report).
- [ ] `Scripts/verify.sh` exits 0.
- [ ] `grep -n "isCarriedIn" Hugo/Features/Planner/Domain/PlannerMonth.swift Hugo/Features/Planner/Screens/PlannerDaySheet.swift` → three lines (two in `PlannerMonth.swift`, one in `PlannerDaySheet.swift`).
- [ ] `git show --stat HEAD` lists only the three in-scope files.
- [ ] Owner check on device: in a month with a carried-in entry, the 1st has no bar in the Planner calendar and its day sheet shows no carried-in row. The header's "Logged" total for the month still includes the carried-in time.

## STOP conditions

Stop and report back (do not improvise) if:

- The drift check shows changes and the excerpts above no longer match.
- Step 1's tests build and pass before the change.
- `PlannerMonth(month:today:days:)` is called anywhere other than `PlannerMonth.make` (`grep -rn "PlannerMonth(" Hugo HugoTests`).
- The fix seems to need a change outside the three in-scope files.
- A step's verification fails twice after a reasonable fix attempt.

## Maintenance notes

- Any new Planner code that reads entries per day should go through `PlannerDay.make` so carried-in entries stay off days.
- `PlannerMonth.logged` and the sum of `days[].logged` now differ by `carriedIn`. Code that needs "time logged on days" must sum the days, not use `logged`.
- The Overview shows carried-in time as a separate pill. The Planner deliberately shows no such row (owner decision for SLN-299). Revisit only if users ask where the month's extra logged time comes from.
