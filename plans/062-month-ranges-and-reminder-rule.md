# Plan 062: Compute month date ranges in one place and move the reminder rule out of the Overview view

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 26e63f4..HEAD -- Hugo/Domain/YearMonth.swift Hugo/Features/Overview Hugo/Features/Reports/Screens/SubmitReportView.swift Hugo/Features/Reports/State/SubmitReportFormModel.swift Hugo/Features/Reports/Domain/ReportReminderSchedule.swift HugoTests/Domain/YearMonthTests.swift HugoTests/Features/Overview HugoTests/Features/Reports/Domain/ReportReminderScheduleTests.swift`
> Plan 061 changes `OverviewView.swift`, `SubmitReportFormModel.swift`,
> `ReportReminderSchedule.swift` and `ReportReminderScheduleTests.swift`; the
> excerpts below show those files *after* plan 061. Any other difference from
> the excerpts is a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/061-service-month-record.md (it introduces `SubmittedReportSelection`, used below)
- **Category**: tech-debt
- **Planned at**: commit `26e63f4`, 2026-11-03

## Why this matters

Four screens each work out "the dates in this month" with their own code before they query SwiftData, and the Overview decides which report reminder to show inside the view. None of that code is reachable from a test. One query also fetches a month nobody reads: `SubmitReportView` asks for the previous month's submissions, but its form model only looks at this month and the next. After this plan, `YearMonth` owns the month's date range (tested once), the reminder rule is a tested function in `ReportReminderSchedule`, and the form model drops two properties it writes but never reads.

This plan keeps `@Query` in the views. `@Query` refreshes the screen when CloudKit imports changes; fetching through a `ModelContext` from a state object would lose that and need extra change tracking.

## Current state

- `Hugo/Domain/YearMonth.swift:41-44` has `endDate(calendar:)` (the last second of the month). Only `HugoTests/Domain/YearMonthTests.swift:100-112` (`endDateIsTheLastInstantOfTheMonth`) uses it.
- `Hugo/Features/Overview/Domain/OverviewMetrics.swift:3-12`:

  ```swift
  struct CurrentMonthInterval: Equatable {
      let start: Date
      let end: Date

      static func current(now: Date, calendar: Calendar) -> CurrentMonthInterval {
          let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
          let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
          return CurrentMonthInterval(start: start, end: end)
      }
  }
  ```

  Used by `OverviewView.swift:44` and `HugoTests/Features/Overview/Domain/OverviewMetricsTests.swift:14-21` (`currentMonthUsesHalfOpenIntervalAcrossDecember`).
- `Hugo/Features/Overview/Screens/OverviewView.swift:42-48` (inside `OverviewDayView.init(today:)`):

  ```swift
  let interval = CurrentMonthInterval.current(now: today, calendar: .current)
  let start = interval.start
  let end = interval.end
  _entries = Query(
      filter: #Predicate<Entry> { $0.date >= start && $0.date < end }, sort: \Entry.date, order: .reverse)
  ```

  and, after plan 061, `reminderMonth` (around line 56):

  ```swift
  private var reminderMonth: YearMonth? {
      guard let due = ReportReminderSchedule.dueMonth(now: .now, calendar: .current) else { return nil }
      guard let submission = SubmittedReportSelection.canonical(for: due, in: submissions) else { return due }
      return SubmittedReportSelection.isReal(submission) ? nil : due
  }
  ```

- `Hugo/Features/Overview/Views/CategoryProgressBreakdownView.swift:9-13`:

  ```swift
  init(month: YearMonth = Date().yearMonth()) {
      let start = month.date()
      let end = month.nextMonth().date()
      _entries = Query(filter: #Predicate<Entry> { $0.date >= start && $0.date < end })
  }
  ```

- `Hugo/Features/Reports/Screens/SubmitReportView.swift:23-50`:

  ```swift
  init(month: YearMonth) {
      _model = State(initialValue: SubmitReportFormModel(month: month))

      let start = month.date()
      let end = month.nextMonth().date()
      _entries = Query(
          filter: #Predicate<Entry> { $0.date >= start && $0.date < end },
          sort: \Entry.date,
          order: .reverse
      )

      let targetYear = month.year
      let targetMonth = month.month
      let prev = YearMonth.previous(before: month)
      let prevYear = prev.year
      let prevMonth = prev.month
      let next = month.nextMonth()
      let nextYear = next.year
      let nextMonth = next.month
      _submissions = Query(
          filter: #Predicate<SubmittedReport> {
              ($0.year == targetYear && $0.month == targetMonth)
                  || ($0.year == prevYear && $0.month == prevMonth)
                  || ($0.year == nextYear && $0.month == nextMonth)
          },
          sort: \SubmittedReport.year
      )
  }
  ```

- `Hugo/Features/Reports/State/SubmitReportFormModel.swift` reads `submissionsByMonth[month]` (`existingSubmission`) and `submissionsByMonth[month.nextMonth(calendar:)]` (`changesSubmittedNextMonth`) only. Lines 28-29 declare `private var entries: [Entry] = []` and `private var submissions: [SubmittedReport] = []`. `load(entries:submissions:)` assigns them (lines 59-60) and nothing reads them.
- `#Predicate` closures cannot call methods on captured values, so date bounds must be copied into local `let` constants before the `Query(...)` call, as all excerpts above do.
- Tests use Swift Testing with a fixed UTC Gregorian calendar. `YearMonthTests` has a `gregorianGMT()` helper. `ReportReminderScheduleTests` is `@MainActor` and has `calendar` and `date(_:_:_:hour:minute:)` helpers.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/YearMonthTests -only-testing:HugoTests/OverviewMetricsTests -only-testing:HugoTests/ReportReminderScheduleTests -only-testing:HugoTests/SubmitReportFormModelTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:

- `Hugo/Domain/YearMonth.swift`
- `Hugo/Features/Overview/Domain/OverviewMetrics.swift`
- `Hugo/Features/Overview/Screens/OverviewView.swift`
- `Hugo/Features/Overview/Views/CategoryProgressBreakdownView.swift` (the `init` only)
- `Hugo/Features/Reports/Screens/SubmitReportView.swift` (the `init` only)
- `Hugo/Features/Reports/State/SubmitReportFormModel.swift` (two properties)
- `Hugo/Features/Reports/Domain/ReportReminderSchedule.swift`
- `HugoTests/Domain/YearMonthTests.swift`
- `HugoTests/Features/Overview/Domain/OverviewMetricsTests.swift`
- `HugoTests/Features/Reports/Domain/ReportReminderScheduleTests.swift`
- `plans/README.md` (status row)

**Out of scope**:

- `TheocraticYear.dateRange` and `ServiceYearPageView`. The year range is already in one place.
- Replacing `@Query` with fetches in state objects (see "Why this matters").
- Bounding the Overview's or the Year page's all-submissions query. Submissions are one row per month, so the cost is small.
- `OverviewMetrics.expectedProgress` and the commented-out use in `MonthlyProgressCard`. The owner parked that UI.
- `CategoryProgressBreakdownView.body` (plan 064 changes how its rows are built).

## Git workflow

- Branch: `advisor/062-month-ranges`
- Conventional Commits, as in `git log`, for example `refactor: compute month date ranges in YearMonth`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add `YearMonth.dateRange` and replace `endDate`

In `Hugo/Domain/YearMonth.swift`, replace `endDate(calendar:)` with:

```swift
/// The half-open range from the first instant of this month to the first
/// instant of the next month. Use it for "entries in this month" queries.
nonisolated func dateRange(calendar: Calendar = .current) -> Range<Date> {
    date(calendar: calendar)..<nextMonth(calendar: calendar).date(calendar: calendar)
}
```

In `YearMonthTests.swift`, replace `endDateIsTheLastInstantOfTheMonth` with `dateRangeCoversTheWholeMonthHalfOpen`: for `YearMonth(year: 2026, month: 12)` with `gregorianGMT()`, `lowerBound` is 2026-12-01 00:00, `upperBound` is 2027-01-01 00:00, the range contains 2026-12-31 23:59:59 and does not contain the upper bound.

**Verify**: `grep -rn 'endDate(' Hugo HugoTests` → only `Hugo/App/AppRootView.swift` (an unrelated `event.endDate`); focused tests pass.

### Step 2: Use it in the three month queries

1. `OverviewView.swift`, `OverviewDayView.init(today:)`:

   ```swift
   let range = today.yearMonth(using: .current).dateRange(calendar: .current)
   let start = range.lowerBound
   let end = range.upperBound
   ```

2. `CategoryProgressBreakdownView.init(month:)`: `let range = month.dateRange()`, then `start`/`end` from its bounds.
3. `SubmitReportView.init(month:)`: same for the entries query. For submissions, keep only this month and the next:

   ```swift
   let targetYear = month.year
   let targetMonth = month.month
   let next = month.nextMonth()
   let nextYear = next.year
   let nextMonth = next.month
   _submissions = Query(
       filter: #Predicate<SubmittedReport> {
           ($0.year == targetYear && $0.month == targetMonth)
               || ($0.year == nextYear && $0.month == nextMonth)
       },
       sort: \SubmittedReport.year
   )
   ```

4. Delete `CurrentMonthInterval` from `OverviewMetrics.swift` and the test `currentMonthUsesHalfOpenIntervalAcrossDecember` from `OverviewMetricsTests.swift` (Step 1's test covers the December case).

**Verify**:

- `grep -rn 'CurrentMonthInterval\|nextMonth().date()' Hugo HugoTests` → no output
- `grep -rn 'prevYear\|prevMonth' Hugo/Features/Reports` → no output
- Focused tests pass.

Commit: `refactor: compute month date ranges in YearMonth`.

### Step 3: Drop the form model's unread properties

In `SubmitReportFormModel.swift`, delete `private var entries: [Entry] = []` and `private var submissions: [SubmittedReport] = []`, and the two assignments `self.entries = entries` and `self.submissions = submissions` in `load(entries:submissions:)`.

**Verify**: `grep -n 'self.entries\|self.submissions' Hugo/Features/Reports/State/SubmitReportFormModel.swift` → no output; `SubmitReportFormModelTests` pass.

### Step 4: Move the reminder rule into `ReportReminderSchedule`

Add to `ReportReminderSchedule` (in `Hugo/Features/Reports/Domain/ReportReminderSchedule.swift`):

```swift
/// The month whose report reminder should show: the due month, unless it
/// already has a real submission. A placeholder report counts as not sent.
static func reminderMonth(
    now: Date, submissions: [SubmittedReport], calendar: Calendar = .current
) -> YearMonth? {
    guard let due = dueMonth(now: now, calendar: calendar) else { return nil }
    guard let submission = SubmittedReportSelection.canonical(for: due, in: submissions) else { return due }
    return SubmittedReportSelection.isReal(submission) ? nil : due
}
```

In `OverviewView.swift`, replace the `reminderMonth` property body with:

```swift
ReportReminderSchedule.reminderMonth(now: .now, submissions: submissions, calendar: .current)
```

Keep the property, since `body` uses it twice. Replace its three-line doc comment (which still mentions `submittedAt == .distantPast`) with:

```swift
/// The month whose report reminder should show, if any. See
/// `ReportReminderSchedule.reminderMonth(now:submissions:calendar:)`.
```

Add to `ReportReminderScheduleTests` (use dates where `dueMonth` returns June 2026, for example `now = date(2026, 6, 30)`):

- `reminderShowsForADueMonthWithoutAReport`: `submissions: []` → June.
- `reminderHidesOnceTheMonthIsSubmitted`: a real June report (`submittedAt: date(2026, 6, 30)`) → `nil`.
- `reminderShowsWhenOnlyAPlaceholderExists`: `SubmittedReport(year: 2026, month: 6, entriesClosedAt: date(2026, 6, 1))` → June.
- `noReminderWhenNothingIsDue`: `now = date(2026, 6, 15)` → `nil`.

**Verify**: `grep -n 'SubmittedReportSelection' Hugo/Features/Overview/Screens/OverviewView.swift` → no output; focused tests pass, including 4 new tests.

Commit: `refactor: move the report reminder rule out of the Overview view`.

### Step 5: Run the gate

**Verify**: `Scripts/verify.sh` → exit 0.

## Test plan

- `YearMonthTests`: 1 test replaced (Step 1).
- `OverviewMetricsTests`: 1 test removed, covered by Step 1.
- `ReportReminderScheduleTests`: 4 new tests (Step 4).
- `SubmitReportFormModelTests`: unchanged and passing.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -rn 'CurrentMonthInterval\|func endDate' Hugo HugoTests` prints nothing
- [ ] `grep -c 'reminderMonth(now:' Hugo/Features/Reports/Domain/ReportReminderSchedule.swift` prints `1`
- [ ] `git status --porcelain` lists only files from the Scope list
- [ ] `plans/README.md` row for 062 updated

## STOP conditions

Stop and report back if:

- `SubmittedReportSelection` does not exist (plan 061 not done).
- Any code other than the test in Step 1 calls `YearMonth.endDate`.
- `SubmitReportFormModel` reads `submissionsByMonth` for a month other than `month` and `month.nextMonth(...)`. Then the previous-month query is needed after all.

## Maintenance notes

- New screens that query one month should use `month.dateRange()`; year screens use `TheocraticYear.dateRange()`.
- If the submit sheet ever shows the previous month's report (for example "carried in from May"), add that month back to the submissions predicate.
- The reminder rule is now testable, but the `@Query` predicates in views are still not. That is the accepted cost of keeping `@Query`'s automatic refresh.
