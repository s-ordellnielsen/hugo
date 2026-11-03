# Plan 049: Date carried-in and time-less entries at midday so time-zone changes cannot move them to another month

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 3f8d48b..HEAD -- Hugo/Domain/YearMonth.swift Hugo/Features/Reports/SubmitReportFormModel.swift Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift Hugo/Persistence/HugoMigrationPlan.swift Hugo/Persistence/SyncDeduplicator.swift`
> Plans 039, 041, 044, 045 and 047 edit some of these files and are expected
> to have landed. Match the excerpts below by content and STOP if the code
> they describe is gone.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/044-merge-duplicate-reports-and-carry-entries.md (adds to its `SyncDeduplicator`), plans/047-safe-saves-names-and-submission-snapshot.md (last edit to `SubmitReportFormModel.swift`)
- **Category**: bug
- **Planned at**: commit `3f8d48b`, 2026-10-12

## Why this matters

Hugo assigns every entry to a month by converting its `date` with the device's current calendar and time zone. Carried-in entries (minutes transferred from the previous month) are dated exactly 00:00 on the 1st, local time. Viewed one or more hours further west (after travel, or on a second device set to another time zone), 00:00 on July 1 becomes June 30. June then shows its own transferred minutes as "carried in from June", its total grows, and re-submitting June transfers them again while July loses them. Entries the user backdates without choosing a time are stored at 00:00 too, so an entry for "October 1" can show up in September. Dating these entries at 12:00 leaves twelve hours of margin in both directions. Existing carried-in entries that already landed in the wrong month are moved back by a repair step.

## Current state

- `Hugo/Domain/YearMonth.swift:102-110`:

  ```swift
  nonisolated func date(day: Int = 1, calendar: Calendar = .current) -> Date {
      var components = DateComponents()
      components.year = year
      components.month = month
      components.day = day
      return calendar.date(from: components) ?? .now
  }
  ```

- `Hugo/Features/Reports/SubmitReportFormModel.swift` (`reconcileGeneratedEntries`):

  ```swift
  let nextMonthStart = month.nextMonth(calendar: calendar).date(calendar: calendar)
  ...
  let entry = Entry(
      date: nextMonthStart,
      duration: seconds,
      tracker: nil,
      source: (submission: report, lineID: result.id)
  )
  ```

- `Hugo/Persistence/HugoMigrationPlan.swift` (`migrateV10toV11.didMigrate`, the `if hasCarryOut` block):

  ```swift
  let nextMonth = YearMonth(
      year: legacyReport.year,
      month: legacyReport.month
  ).nextMonth()
  let nextMonthStart = nextMonth.date()
  let entry = SchemaV11.Entry(
      date: nextMonthStart,
      ...
  )
  ...
  entry.createdAt = nextMonthStart
  ```

  This stage has shipped. Changing its closure only affects stores that have not migrated yet, which is allowed. Keep `createdAt = nextMonthStart` (the "added after submission" check depends on it).
- `Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift` (`inferredTime()`):

  ```swift
  private func inferredTime() -> Date {
      guard calendar.isDate(date, inSameDayAs: now) else {
          return calendar.startOfDay(for: date)
      }
      ...
  ```

- `Hugo/Persistence/SyncDeduplicator.swift` (after plans 041 and 044): a `@MainActor struct` with `run()` calling each maintenance pass and logging, plus `mergeDuplicateCategories()`, `mergeDuplicateMonthlyReports()` and `mergeDuplicateCarryEntries()`. Rule in its doc comment: passes must give the same result on every device.
- Tests that pin the old midnight dates and must be updated:
  - `HugoTests/Features/Reports/SubmitReportFormModelTests.swift` (`transferPersistsReportingLineAndLinkedNextMonthEntry`): `#expect(generated.date == date(2026, 7, 1, hour: 0))`. That file's `date(_:_:_:hour:)` helper uses a UTC calendar, which the model also uses.
  - `HugoTests/Persistence/SchemaMigrationTests.swift` (`migratingV10StoreWithCarryOutCreatesOneGeneratedEntryOnMainLine`): `let expectedDate = YearMonth(year: 2026, month: 8).nextMonth().date()` and `#expect(entry.date == expectedDate)`. The `createdAt` expectations in that test stay.
  - `HugoTests/Features/Entries/AddEntryFormModelTests.swift` (`optionalTimeDefaultsToMidnight`): expects hour 0.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/YearMonthTests -only-testing:HugoTests/SubmitReportFormModelTests -only-testing:HugoTests/AddEntryFormModelTests -only-testing:HugoTests/SchemaMigrationTests -only-testing:HugoTests/SyncDeduplicatorTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:

- `Hugo/Domain/YearMonth.swift`
- `Hugo/Features/Reports/SubmitReportFormModel.swift` (`reconcileGeneratedEntries` only)
- `Hugo/Persistence/HugoMigrationPlan.swift` (the carry entry's `date` only)
- `Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift` (`inferredTime` only)
- `Hugo/Persistence/SyncDeduplicator.swift`
- `HugoTests/Features/Reports/YearMonthTests.swift`
- `HugoTests/Features/Reports/SubmitReportFormModelTests.swift`
- `HugoTests/Persistence/SchemaMigrationTests.swift`
- `HugoTests/Features/Entries/AddEntryFormModelTests.swift`
- `HugoTests/Persistence/SyncDeduplicatorTests.swift`
- `plans/README.md` (status row)

**Out of scope**:

- Entries the user dated with an explicit time. Their dates are the user's choice.
- Moving existing time-less user entries. Only carried-in entries get repaired, because their intended month is known from `sourceReportYear` / `sourceReportMonth`.
- Changing how months are bucketed (`Date.yearMonth(using:)`).

## Git workflow

- Branch: `advisor/049-midday-dates`
- Commit message style: short imperative sentence, for example `Date carried-in entries at midday`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add a midday helper

In `YearMonth.swift`, inside the extension that defines `date(day:calendar:)`:

```swift
/// 12:00 on the first day of the month. Entries that represent "the month"
/// rather than a moment use this, so a time-zone change of up to 12 hours
/// cannot move them into a neighboring month.
nonisolated func middayOnFirst(calendar: Calendar = .current) -> Date {
    let start = date(calendar: calendar)
    return calendar.date(byAdding: .hour, value: 12, to: start) ?? start
}
```

Add `middayOnFirstStaysInMonthAcrossTimeZones` to `HugoTests/Features/Reports/YearMonthTests.swift`: build the date with a Europe/Copenhagen Gregorian calendar for 2026-07, then convert it with a UTC calendar and with a `TimeZone(secondsFromGMT: -10 * 3600)` calendar. Both give `YearMonth(year: 2026, month: 7)`.

**Verify**: focused tests pass.

### Step 2: Use it for new carried-in entries and time-less entries

1. `SubmitReportFormModel.reconcileGeneratedEntries`: rename `nextMonthStart` to `carryDate` and set it to `month.nextMonth(calendar: calendar).middayOnFirst(calendar: calendar)`. Use it for new entries. Leave existing entries' dates alone here (Step 3 repairs only broken ones).
2. `HugoMigrationPlan.swift`: in the carry block, keep `let nextMonthStart = nextMonth.date()` for `createdAt`, and pass `date: nextMonth.middayOnFirst()` to the `SchemaV11.Entry` initializer.
3. `AddEntryFormModel.inferredTime()`: for a day other than today, return `calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: date)) ?? calendar.startOfDay(for: date)`.
4. Update the three tests listed in "Current state":
   - `transferPersistsReportingLineAndLinkedNextMonthEntry`: expect `date(2026, 7, 1, hour: 12)`.
   - `migratingV10StoreWithCarryOutCreatesOneGeneratedEntryOnMainLine`: `expectedDate = YearMonth(year: 2026, month: 8).nextMonth().middayOnFirst()`; keep the `createdAt` checks against the month start (`YearMonth(year: 2026, month: 9).date()`).
   - Rename `optionalTimeDefaultsToMidnight` to `optionalTimeDefaultsToMidday` and expect hour 12, minute 0, second 0.

**Verify**: focused tests pass.

Commit steps 1-2: `Date carried-in and time-less entries at midday`.

### Step 3: Repair carried-in entries that sit in the wrong month

Add to `SyncDeduplicator`:

```swift
/// Moves carried-in entries back into the month after their source report
/// when a time-zone change pushed them out of it. Entries already in the
/// right month are left alone, so devices in different time zones (within
/// 12 hours of each other) never rewrite each other's dates.
@discardableResult
func repairCarryEntryDates(calendar: Calendar = .current) throws -> Int {
    let entries = try context.fetch(
        FetchDescriptor<Entry>(predicate: #Predicate { $0.sourceReportYear != nil && $0.sourceReportMonth != nil }))
    var repaired = 0
    for entry in entries {
        guard let year = entry.sourceReportYear, let month = entry.sourceReportMonth else { continue }
        let intended = YearMonth(year: year, month: month).nextMonth(calendar: calendar)
        guard entry.date.yearMonth(using: calendar) != intended else { continue }
        entry.date = intended.middayOnFirst(calendar: calendar)
        repaired += 1
    }
    if repaired > 0 { try context.save() }
    return repaired
}
```

Call it from `run()` after `mergeDuplicateCarryEntries()`, logging the count like the others. (If plan 044 fetched carried-in entries without a predicate because the predicate did not compile, do the same here.)

Tests in `SyncDeduplicatorTests.swift` (use an explicit UTC Gregorian calendar and pass it in):

1. `carryEntryOutsideItsMonthIsMoved`: report for 2026-06, carried-in entry for it dated 2026-06-30 22:00 UTC. After `repairCarryEntryDates(calendar: utc)`: returns 1, the date is 2026-07-01 12:00 UTC.
2. `carryEntryInsideItsMonthIsUntouched`: same, dated 2026-07-01 00:00 UTC. Returns 0; the date is unchanged.
3. `ordinaryEntriesAreNotRepaired`: an entry without source fields dated 2026-06-30 22:00. Returns 0.

**Verify**: focused tests pass; `Scripts/verify.sh` → exit 0.

Commit: `Move carried-in entries back into their month after a time-zone change`.

## Test plan

- `YearMonthTests`: 1 new test (Step 1).
- `SyncDeduplicatorTests`: 3 new tests (Step 3).
- 3 existing tests updated for the new midday time (Step 2); the test count does not change for them.

## Done criteria

- [ ] `grep -rn 'middayOnFirst' Hugo | wc -l` prints at least 4
- [ ] `grep -n 'startOfDay(for: date)$' Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift` prints nothing (no bare midnight return)
- [ ] `Scripts/verify.sh` exits 0, with 4 more tests than before this plan
- [ ] `git status --porcelain` lists only files from the Scope list
- [ ] `plans/README.md` row for 049 updated

## STOP conditions

Stop and report back if:

- `SyncDeduplicator` or its `run()` does not exist (plans 041 and 044 have not landed).
- Changing the migration's entry date makes any migration test other than the one named above fail.
- A test outside the three named ones asserts a generated entry or time-less entry at hour 0.

## Maintenance notes

- Any future entry that stands for a whole month or day (not a moment) should use `middayOnFirst` or 12:00 on its day.
- Time-less backdated entries now show "12:00" in the by-date list instead of "00:00".
- The repair only runs while devices are within 12 hours of each other's time zone. Larger gaps can still disagree about a carried-in entry's month; that is accepted.
