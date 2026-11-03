# Plan 065: Move report saving and carried-in entries out of the form model into a Reports service

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 26e63f4..HEAD -- Hugo/Features/Reports/State/SubmitReportFormModel.swift Hugo/Features/Reports/Screens/SubmitReportView.swift Hugo/Persistence/SyncDeduplicator.swift Hugo/Domain/YearMonth.swift HugoTests/Features/Reports/State/SubmitReportFormModelTests.swift HugoTests/Domain/YearMonthTests.swift`
> Plans 061 and 062 edit these files: 061 changes the selection calls in
> `SubmitReportFormModel` and `SyncDeduplicator`, 062 removes two properties
> from the form model, the previous-month query from `SubmitReportView`, and
> replaces `YearMonth.endDate` with `dateRange`. The excerpts below are the
> parts this plan moves, which those plans do not touch. A difference in
> these excerpts is a STOP condition.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/061-service-month-record.md, plans/062-month-ranges-and-reminder-rule.md (both edit the same files first)
- **Category**: tech-debt
- **Planned at**: commit `26e63f4`, 2026-11-03

## Why this matters

`SubmitReportFormModel` is a `State` class: it should hold the submit sheet's state and workflow. It also writes about fourteen fields of a `SubmittedReport` and creates, updates and deletes carried-in entries in a `ModelContext`. AGENTS.md section 7 puts code that writes the SwiftData context in a feature's `Services` folder. The rule for where a carried-in entry is dated ("midday on the 1st of the next month") is also written twice: once in the form model and once in `SyncDeduplicator.repairCarryEntryDates`. After this plan:

- A `ReportSubmissionService` in `Hugo/Features/Reports/Services` owns the save.
- `YearMonth` owns the carried-in date rule.
- The form model keeps only its rules, its prepared message and its pending-load gate.
- The existing 18 form model tests keep passing through the same `persistSubmission` call, which now delegates to the service.

## Current state

- `Hugo/Features/Reports/State/SubmitReportFormModel.swift:171-247` is `persistSubmission(in context: ModelContext) throws -> SubmittedReport?`. It works like this:
  1. It returns nil unless `canSend`.
  2. It computes `categoryHours`, `snapshots`, `carriedInSeconds`, `carriedOutSeconds`, `roundedUpSeconds`, `roundedDownSeconds`, `submittedHours` and `closedAt = monthEntries.map(\.createdAt).max() ?? now`.
  3. It updates `existingSubmission` in place (setting `firstSubmittedAt` when nil or `.distantPast`, plus `submittedAt` and `entriesClosedAt`), or inserts a new `SubmittedReport(year:month:firstSubmittedAt:submittedAt:entriesClosedAt:)`.
  4. It writes `roundingRuleRaw`, `fieldServiceSeconds`, `actualTotalSeconds`, `submittedHours`, `carriedInSeconds`, `carriedOutSeconds`, `roundedUpSeconds`, `roundedDownSeconds`, `totalBibleStudies`, `categories` and `reportingLines`.
  5. It calls `reconcileGeneratedEntries(for:in:)`, runs `try context.save()`, clears `preparedContent` and `pendingLoad`, and returns the report.
- `SubmitReportFormModel.swift:272-306`:

  ```swift
  private func reconcileGeneratedEntries(for report: SubmittedReport, in context: ModelContext) {
      let carryDate = month.nextMonth(calendar: calendar).middayOnFirst(calendar: calendar)
      var existingByLine = Dictionary(grouping: report.generatedEntries ?? [], by: { $0.sourceReportingLineID ?? "" })

      for result in results {
          guard case .transferred(let seconds) = result.disposition else { continue }

          if let entry = existingByLine[result.id]?.first {
              if entry.duration != seconds {
                  entry.duration = seconds
                  entry.createdAt = now
              }
              existingByLine[result.id]?.removeFirst()
          } else {
              let entry = Entry(
                  date: carryDate,
                  duration: seconds,
                  tracker: nil,
                  source: (submission: report, lineID: result.id)
              )
              entry.storedTracker =
                  if result.line.type == .main {
                      .init(name: String(localized: "category.default.label"), icon: "figure.walk", type: .main)
                  } else {
                      .init(name: result.line.name, icon: result.line.iconName, type: .separate)
                  }
              entry.createdAt = now
              context.insert(entry)
          }
      }

      for leftover in existingByLine.values.flatMap({ $0 }) {
          context.delete(leftover)
      }
  }
  ```

- When the model has a summary, `monthEntries` (the month's entries) is the same array as `summary.entries`. When the month has no entries, `summary` is nil and `monthEntries` is empty.
- `Hugo/Features/Reports/Screens/SubmitReportView.swift`, `persist()` (near the end of the file):

  ```swift
  private func persist() {
      do {
          var stored: SubmittedReport?
          try context.performIsolatedChange {
              stored = try model.persistSubmission(in: context)
          }
          ...
  ```

  `performIsolatedChange` (`Hugo/Persistence/ModelContext+IsolatedChange.swift`) saves pending edits first, runs the closure, and rolls back only the closure's changes on failure. Keep it in the view.
- `Hugo/Persistence/SyncDeduplicator.swift:203-219`, `repairCarryEntryDates(calendar:)`:

  ```swift
  let intended = YearMonth(year: year, month: month).nextMonth(calendar: calendar)
  guard entry.date.yearMonth(using: calendar) != intended else { continue }
  entry.date = intended.middayOnFirst(calendar: calendar)
  ```

- `Hugo/Domain/YearMonth.swift:112-118` has `middayOnFirst(calendar:)`. `Scripts/check-layout.sh` fails if a file in `Hugo/Domain` contains the whole word `Entry`, `Tracker`, `SubmittedReport`, `TheocraticYear` or `PublisherStatus` (comments included). Lowercase "entries" is fine.
- Service exemplar: `Hugo/Features/Categories/Services/CategoryDeletionService.swift` (a small type that takes a `ModelContext`), tested in `HugoTests/Features/Categories/Services/CategoryDeletionServiceTests.swift` with `InMemoryModelContainer.make()`.
- `HugoTests/Features/Reports/State/SubmitReportFormModelTests.swift` calls `model.persistSubmission(in: <context>)` 12 times. Its fixtures: `calendar` (UTC Gregorian), `month = YearMonth(year: 2026, month: 6)`, `now`, `entry(_:_:_:seconds:createdAt:tracker:source:)`.
- `SubmittedReport` fields such as `categories`, `carriedInSeconds` and `roundedUpSeconds` are written here but read only by migration code today. Older app builds on other devices may still read them through CloudKit, so this plan keeps writing every field exactly as now.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Layout | `Scripts/check-layout.sh` | exit 0, no output |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/SubmitReportFormModelTests -only-testing:HugoTests/ReportSubmissionServiceTests -only-testing:HugoTests/SyncDeduplicatorTests -only-testing:HugoTests/YearMonthTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 |

Leave `-only-testing:HugoTests/ReportSubmissionServiceTests` out until Step 2 creates the suite.

## Scope

**In scope**:

- `Hugo/Domain/YearMonth.swift` (one new function)
- `Hugo/Features/Reports/Services/ReportSubmissionService.swift` (create; the `Services` folder is new for Reports)
- `Hugo/Features/Reports/State/SubmitReportFormModel.swift`
- `Hugo/Features/Reports/Screens/SubmitReportView.swift` (`persist()` only)
- `Hugo/Persistence/SyncDeduplicator.swift` (`repairCarryEntryDates` only)
- `HugoTests/Domain/YearMonthTests.swift`
- `HugoTests/Features/Reports/Services/ReportSubmissionServiceTests.swift` (create)
- `HugoTests/Features/Reports/State/SubmitReportFormModelTests.swift` (call sites only)
- `plans/README.md` (status row)

**Out of scope**:

- Which `SubmittedReport` fields are written. Keep writing all of them with the same values.
- `ReportingLineCalculator.categoryHours`, even though it only feeds the `categories` field.
- `changesSubmittedNextMonth`, `prepareSubmission`, `load` and the pending-load gate in the form model.
- `SyncDeduplicator.mergeDuplicateCarryEntries`. It copies an existing entry, which is a different job from creating one.
- The name stored on a carried-in main entry (`category.default.label`). Plan 064 handles the display side.

## Git workflow

- Branch: `advisor/065-report-submission-service`
- Conventional Commits, as in `git log`, for example `refactor: save submitted reports through a Reports service`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Give `YearMonth` the carried-in date rule

In `Hugo/Domain/YearMonth.swift`, after `middayOnFirst(calendar:)`, add:

```swift
/// The date for time transferred out of this month: midday on the 1st of
/// the next month, so a time-zone change cannot move it into another month.
nonisolated func carriedInDate(calendar: Calendar = .current) -> Date {
    nextMonth(calendar: calendar).middayOnFirst(calendar: calendar)
}
```

In `SyncDeduplicator.repairCarryEntryDates`, replace the three excerpted lines with:

```swift
let target = YearMonth(year: year, month: month).carriedInDate(calendar: calendar)
guard entry.date.yearMonth(using: calendar) != target.yearMonth(using: calendar) else { continue }
entry.date = target
```

Add `carriedInDateIsMiddayOnTheFirstOfTheNextMonth` to `YearMonthTests`. With `gregorianGMT()`, `YearMonth(year: 2026, month: 12).carriedInDate(calendar:)` has components year 2027, month 1, day 1, hour 12.

**Verify**: `Scripts/check-layout.sh` → exit 0; focused tests (without the new suite) pass, including `SyncDeduplicatorTests`.

Commit: `refactor: give YearMonth the carried-in date rule`.

### Step 2: Create `ReportSubmissionService`

Create `Hugo/Features/Reports/Services/ReportSubmissionService.swift`:

```swift
import Foundation
import SwiftData

/// Saves a month's report and keeps its carried-in entries in the next month
/// in step with the report's transferred minutes.
@MainActor
struct ReportSubmissionService {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    /// Writes the report for `month` from the confirmed line results and saves
    /// the context. `existing` (a real report or a placeholder) is updated in
    /// place so CloudKit keeps one row per month; otherwise a new row is
    /// inserted. Carried-in entries are created, updated or deleted to match
    /// the transferred lines.
    @discardableResult
    func submit(
        _ results: [ReportingLineResult],
        summary: MonthlyReportSummary?,
        for month: YearMonth,
        replacing existing: SubmittedReport?,
        at now: Date
    ) throws -> SubmittedReport {
        // Body: SubmitReportFormModel.persistSubmission from `let mainResult`
        // through `try context.save()`, unchanged except:
        // - `existingSubmission` becomes `existing`
        // - `closedAt` is `summary?.entries.map(\.createdAt).max() ?? now`
        // - `reconcileGeneratedEntries(for: report, in: context)` becomes
        //   `reconcileCarriedInEntries(for: report, results: results, month: month, now: now)`
    }

    // reconcileCarriedInEntries(for:results:month:now:): the body of
    // SubmitReportFormModel.reconcileGeneratedEntries, unchanged except that
    // `carryDate` is `month.carriedInDate(calendar: calendar)` and it reads
    // the `results`, `month` and `now` parameters.
}
```

Do not change any field name, value or order of the writes.

Create `HugoTests/Features/Reports/Services/ReportSubmissionServiceTests.swift` (`@MainActor struct`, UTC Gregorian `calendar`, `InMemoryModelContainer.make()`). Build inputs with the same domain functions the form model uses:

```swift
let entries = [/* June 2026 entries */]
let summary = MonthlyReportBuilder.summaries(from: entries, calendar: calendar).first
let results = ReportingLineCalculator.compute(
    ReportingLineCalculator.lines(from: entries, calendar: calendar), rules: ["": .transfer])
```

Tests:

- `transferCreatesOneCarriedInEntryInTheNextMonth`: one 5_400-second June entry, rule `.transfer` on the main line (id `""`). The saved report has one `generatedEntries` item with `duration == 1_800`, `date == YearMonth(year: 2026, month: 6).carriedInDate(calendar: calendar)` and `storedTracker?.type == .main`.
- `resubmittingUpdatesTheExistingRowInPlace`: submit once, then submit again with `replacing:` the first report and rule `.down`. The same object comes back (`===`), `firstSubmittedAt` is unchanged, `generatedEntries` is empty, and fetching `SubmittedReport` from the context returns 1 row.
- `placeholderGetsItsFirstSubmittedDate`: insert `SubmittedReport(year: 2026, month: 6, entriesClosedAt: date(2026, 6, 1))`, submit `replacing:` it at `now`. `firstSubmittedAt == now`.

**Verify**: focused tests (with `ReportSubmissionServiceTests`) pass, 3 new tests.

### Step 3: Make the form model delegate

In `SubmitReportFormModel.swift`:

1. Replace `persistSubmission(in:)` with:

   ```swift
   /// Saves the submission through `service` once the user has sent the
   /// message. Returns nil when the month is not submittable or a rounding
   /// rule is still undecided.
   @discardableResult
   func persistSubmission(using service: ReportSubmissionService) throws -> SubmittedReport? {
       guard canSend else { return nil }
       let report = try service.submit(
           results, summary: summary, for: month, replacing: existingSubmission, at: now)
       preparedContent = nil
       pendingLoad = nil
       return report
   }
   ```

2. Delete `reconcileGeneratedEntries(for:in:)`.
3. Update the doc comment of `prepareSubmission()` to mention `persistSubmission(using:)`.

In `SubmitReportView.persist()`, change the closure body to `stored = try model.persistSubmission(using: ReportSubmissionService(context: context))`.

In `SubmitReportFormModelTests.swift`, add a helper:

```swift
private func service(_ context: ModelContext) -> ReportSubmissionService {
    ReportSubmissionService(context: context, calendar: calendar)
}
```

and replace each of the 12 `persistSubmission(in: X)` calls with `persistSubmission(using: service(X))`. Change no other line.

**Verify**:

- `grep -rn 'persistSubmission(in:' Hugo HugoTests` → no output
- `grep -n 'ModelContext\|context.insert\|context.delete\|context.save' Hugo/Features/Reports/State/SubmitReportFormModel.swift` → no output
- `grep -rn 'middayOnFirst' Hugo` → only `Hugo/Domain/YearMonth.swift` (its definition and `carriedInDate`) and `Hugo/Persistence/HugoMigrationPlan.swift` (a shipped migration; leave it alone)
- Focused tests pass. All 18 `SubmitReportFormModelTests` tests pass with only the call-site change.

Commit: `refactor: save submitted reports through a Reports service`.

### Step 4: Run the gate

**Verify**: `Scripts/verify.sh` → exit 0.

### Step 5 [owner]: Submit on a device

Submit a month with a transfer, re-submit it with "round down", and submit a zero-activity month. Each saves, the carried-in entry appears and then disappears in the next month, and a second device shows the same after sync.

## Test plan

- `YearMonthTests`: 1 new test.
- New `ReportSubmissionServiceTests`: 3 tests.
- `SubmitReportFormModelTests`: unchanged apart from the call sites; all pass.
- `SyncDeduplicatorTests`: unchanged and passing.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `test -f Hugo/Features/Reports/Services/ReportSubmissionService.swift && echo ok` prints `ok`
- [ ] `grep -c 'carriedInDate' Hugo/Features/Reports/Services/ReportSubmissionService.swift Hugo/Persistence/SyncDeduplicator.swift` prints `1` for each file
- [ ] `grep -n 'ModelContext' Hugo/Features/Reports/State/SubmitReportFormModel.swift` prints nothing
- [ ] `git status --porcelain` lists only files from the Scope list
- [ ] `plans/README.md` row for 065 updated

## STOP conditions

Stop and report back if:

- Any `SubmitReportFormModelTests` test fails after Step 3. The move must not change behavior.
- `SyncDeduplicatorTests` fails after Step 1.
- A test seems to need the service to find the existing report by itself (fetching from the context) instead of receiving `existing`. Keep the caller passing it, and report the case.
- `Scripts/check-layout.sh` rejects `YearMonth.swift` after Step 1 (a capitalized feature type name in the new doc comment).

## Maintenance notes

- To stop writing the legacy `SubmittedReport` fields (`categories`, `carriedInSeconds`, `carriedOutSeconds`, `roundedUpSeconds`, `roundedDownSeconds`, `fieldServiceSeconds`, `roundingRuleRaw`), first confirm that no supported app build reads them through CloudKit. That change then touches only `ReportSubmissionService`, and `ReportingLineCalculator.categoryHours` can go with it.
- Any other code that creates carried-in entries must use `YearMonth.carriedInDate`.
- Reviewer focus: the moved write block must match the old one field for field. Compare `git show 26e63f4:Hugo/Features/Reports/State/SubmitReportFormModel.swift` lines 181-243 with the service body.
