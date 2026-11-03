# Plan 061: Give each month one record that decides submitted, unreported and year contribution

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 26e63f4..HEAD -- Hugo/Features/ServiceYear Hugo/Features/Reports Hugo/Features/Overview/Screens/OverviewView.swift Hugo/Persistence/SyncDeduplicator.swift Hugo/PreviewSupport/ReportPreviewFixtures.swift HugoTests/Features/ServiceYear HugoTests/Features/Reports HugoTests/Persistence/SchemaMigrationTests.swift Hugo/Resources/Localizable.xcstrings CONTEXT.md`
> If any of these changed since this plan was written (other than by plan 060
> creating `CONTEXT.md`), compare the "Current state" excerpts against the
> live code before proceeding. On a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/060-add-context-glossary.md (this plan adds a term to `CONTEXT.md`)
- **Category**: bug + tech-debt
- **Planned at**: commit `26e63f4`, 2026-11-03

## Why this matters

Every screen that shows a month asks the same questions: was it really submitted, has it changed since, which entries are new, and what does it add to the year total. Today each screen answers them with its own code. The check "is this a real submission" (`submittedAt != .distantPast`) is written out in six places. The "changed since submitted" rule exists twice, and the two copies disagree. That causes a visible bug: if the user edits an entry's duration after submitting, the month detail screen shows the banner "New entries are marked below", but no entry is marked, because the row marker only checks for newly created entries.

The rules also live in the wrong place. Canonical-report selection sits in a ServiceYear builder, so `SyncDeduplicator` (Persistence) imports a feature type, and Reports and ServiceYear depend on each other. After this plan, one value type, `ServiceMonth`, answers every question about one month. The banner and the row markers read the same rule, the selection rules live in Persistence, and the tests for all of it go through one interface.

## Current state

### Files and roles

- `Hugo/Features/ServiceYear/Domain/TheocraticYearReport.swift`: defines `TheocraticYearMonth` (the per-month value the year page uses) and `TheocraticYearReport`.
- `Hugo/Features/ServiceYear/Domain/TheocraticYearReportBuilder.swift`: builds the year report. It also holds `contribution(for:)`, `canonicalSubmission(for:in:)`, `canonicalSubmissionsByMonth(_:)`, `isRealSubmission(_:)` and two private helpers (lines 47-156).
- `Hugo/Features/Reports/Domain/ReportReminderSchedule.swift`: `dueMonth(now:calendar:)` (keep), plus `hasUnreportedEntries`, `isComparable` and `hasChangedTotals` (lines 41-82, which move).
- `Hugo/Features/Reports/Screens/MonthlyReportDetailView.swift`: the month detail sheet with the banner.
- `Hugo/Features/Reports/Views/MonthlyReportEntryListView.swift`: the entry list with the per-row warning triangle.
- `Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift`: one month card on the Year page.
- `Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift` and `Hugo/Features/ServiceYear/Screens/ServiceYearDetailView.swift`: call `TheocraticYearReportBuilder.contribution(for:)`.
- `Hugo/Features/Overview/Screens/OverviewView.swift`: computes the reminder month.
- `Hugo/Features/Reports/State/SubmitReportFormModel.swift`: picks the canonical report and checks the next month.
- `Hugo/Persistence/SyncDeduplicator.swift`: merges sync duplicates; calls the builder's selection functions.
- `Hugo/PreviewSupport/ReportPreviewFixtures.swift`: preview data.

### The duplicated "real submission" check

```swift
// TheocraticYearReport.swift:13-16
var isSubmitted: Bool {
    guard let submittedReport else { return false }
    return (submittedReport.submittedAt ?? .distantPast) != .distantPast
}
// TheocraticYearReportBuilder.swift:152-156
static func isRealSubmission(_ submission: SubmittedReport) -> Bool {
    (submission.submittedAt ?? .distantPast) != .distantPast
}
// OverviewView.swift:64
return (submission.submittedAt ?? .distantPast) == .distantPast ? due : nil
// SubmitReportFormModel.swift:114-116
guard let nextReport = submissionsByMonth[next],
    (nextReport.submittedAt ?? .distantPast) != .distantPast
else { return false }
// MonthlyReportEntryListView.swift:10
guard let report, (report.submittedAt ?? .distantPast) != .distantPast else { return false }
// ReportReminderSchedule.swift:54
guard let report, (report.submittedAt ?? .distantPast) != .distantPast else { return true }
```

`SubmitReportFormModel.swift:213` (`existing.firstSubmittedAt == .distantPast`) checks a different field. Leave it alone.

### The two "unreported" rules that disagree

```swift
// ReportReminderSchedule.swift:48-62 (used for the banner and the Year page card)
static func hasUnreportedEntries(
    report: SubmittedReport?, entries: [Entry], month: YearMonth, calendar: Calendar = .current
) -> Bool {
    guard let report, (report.submittedAt ?? .distantPast) != .distantPast else { return true }
    let monthEntries = entries.filter { $0.date.yearMonth(using: calendar) == month }
    let cutoff = report.entriesClosedAt ?? .distantPast
    if monthEntries.contains(where: { $0.createdAt > cutoff }) { return true }
    guard isComparable(report) else { return false }
    return hasChangedTotals(report: report, monthEntries: monthEntries, calendar: calendar)
}

// MonthlyReportEntryListView.swift:9-12 (used for the row triangle)
private func isUnreported(_ entry: Entry) -> Bool {
    guard let report, (report.submittedAt ?? .distantPast) != .distantPast else { return false }
    return entry.createdAt > (report.entriesClosedAt ?? .distantPast)
}
```

`MonthlyReportDetailView.swift:15-24`:

```swift
if month.isSubmitted && month.hasUnreportedEntries {
    Section {
        Label("report.detail.unreported.banner", systemImage: "exclamationmark.triangle.fill")

            .font(.subheadline)
    }
}

MonthlyReportTotalsView(summary: summary)
MonthlyReportEntryListView(summary: summary, report: month.submittedReport)
```

The banner's English text is "This month has changed since you submitted it. New entries are marked below. Submit an updated report to include the changes." When the change is an edit or a deletion, no entry is newer than the report, so nothing is marked below.

### The Year page card

`ServiceYearMonthRow.swift:92-98` reads a different field than the year total does:

```swift
private var displayedHours: Int {
    if month.isSubmitted {
        return month.submittedReport?.submittedHours ?? 0
    }

    return Int((summary?.totalSeconds ?? 0) / 3_600)
}
```

`ServiceYearMonthRow.swift:175` shows the warning only inside `if month.isSubmitted, ...` (line 30): `if month.hasUnreportedEntries {`.

### Callers of the builder's helper functions

```
Hugo/Persistence/SyncDeduplicator.swift:101   TheocraticYearReportBuilder.canonicalSubmission(for: month, in: group)
Hugo/Persistence/SyncDeduplicator.swift:106   TheocraticYearReportBuilder.isRealSubmission(winner)
Hugo/Persistence/SyncDeduplicator.swift:110   TheocraticYearReportBuilder.isRealSubmission(other)
Hugo/Persistence/SyncDeduplicator.swift:121   !TheocraticYearReportBuilder.isRealSubmission($0)
Hugo/Persistence/SyncDeduplicator.swift:161   TheocraticYearReportBuilder.canonicalSubmissionsByMonth(
Hugo/Features/Reports/State/SubmitReportFormModel.swift:61   TheocraticYearReportBuilder.canonicalSubmissionsByMonth(submissions)
Hugo/Features/Overview/Screens/OverviewView.swift:61   TheocraticYearReportBuilder.canonicalSubmission(for: due, in: submissions)
Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift:35   TheocraticYearReportBuilder.contribution(for: month)
Hugo/Features/ServiceYear/Screens/ServiceYearDetailView.swift:73   TheocraticYearReportBuilder.contribution(for: month).total
```

### Conventions to match

- Pure value logic is a `nonisolated` struct or enum with `static func`s that take `now`, `calendar` and `locale` with production defaults. Exemplar: `TheocraticYearReportBuilder.report(for:entries:submissions:now:calendar:locale:)`.
- Persistence model types are `Entry` and `SubmittedReport` (typealiases in `Hugo/Persistence/AppSchema.swift`). Never edit files under `Hugo/Persistence/SchemaVersions/`.
- `Scripts/check-layout.sh` fails if `Hugo/Domain` names `Entry`, `Tracker`, `SubmittedReport`, `TheocraticYear` or `PublisherStatus`, so the new month type goes in `Hugo/Features/Reports/Domain`, and the selection helpers go in `Hugo/Persistence`.
- The Xcode project uses file-system synchronized groups, so new files need no `project.pbxproj` edit.
- Tests use Swift Testing with a fixed UTC Gregorian calendar. Exemplar: `HugoTests/Features/Reports/Domain/ReportReminderScheduleTests.swift` (struct marked `@MainActor`, `calendar` property, `date(_:_:_:hour:minute:)` helper).
- `CONTEXT.md` (added by plan 060) defines the words used here: submitted report, placeholder report, canonical report, unreported change, reported hours, logged time, year total.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Layout | `Scripts/check-layout.sh` | exit 0, no output |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/ServiceMonthTests -only-testing:HugoTests/ReportReminderScheduleTests -only-testing:HugoTests/TheocraticYearReportBuilderTests -only-testing:HugoTests/YearlyGoalProgressTests -only-testing:HugoTests/SubmitReportFormModelTests -only-testing:HugoTests/SyncDeduplicatorTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 |

Until Step 5 creates `ServiceMonthTests`, leave `-only-testing:HugoTests/ServiceMonthTests` out of the focused command.

## Scope

**In scope**:

- `Hugo/Persistence/SubmittedReportSelection.swift` (create)
- `Hugo/Features/Reports/Domain/ServiceMonth.swift` (create)
- `Hugo/Features/ServiceYear/Domain/TheocraticYearReport.swift`
- `Hugo/Features/ServiceYear/Domain/TheocraticYearReportBuilder.swift`
- `Hugo/Features/Reports/Domain/ReportReminderSchedule.swift`
- `Hugo/Features/Reports/Screens/MonthlyReportDetailView.swift`
- `Hugo/Features/Reports/Views/MonthlyReportEntryListView.swift`
- `Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift`
- `Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift`
- `Hugo/Features/ServiceYear/Screens/ServiceYearDetailView.swift`
- `Hugo/Features/Overview/Screens/OverviewView.swift`
- `Hugo/Features/Reports/State/SubmitReportFormModel.swift`
- `Hugo/Persistence/SyncDeduplicator.swift`
- `Hugo/PreviewSupport/ReportPreviewFixtures.swift`
- `Hugo/Resources/Localizable.xcstrings` (one new key)
- `HugoTests/Features/Reports/Domain/ServiceMonthTests.swift` (create)
- `HugoTests/Features/Reports/Domain/ReportReminderScheduleTests.swift`
- `HugoTests/Features/ServiceYear/Domain/TheocraticYearReportBuilderTests.swift`
- `HugoTests/Features/Reports/State/SubmitReportFormModelTests.swift` (one assertion)
- `HugoTests/Persistence/SchemaMigrationTests.swift` (one assertion, around line 824)
- `CONTEXT.md` (one new term)
- `plans/README.md` (status row)

**Out of scope**:

- Anything under `Hugo/Persistence/SchemaVersions/`. No schema change is needed or allowed.
- `SubmitReportFormModel.persistSubmission` and its carried-in entry code (plan 065 moves it).
- The `@Query` setup in views and the month date ranges (plan 062).
- `YearlyGoalProgress` names and the year detail rows (plan 063). Here you only change the one `contribution` call.
- Renaming `TheocraticYearReport` or `TheocraticYearReportBuilder`.
- The survivor rules inside `SyncDeduplicator`. Only the type name in its calls changes.

## Git workflow

- Branch: `advisor/061-service-month`
- Conventional Commits, as in `git log`, for example `refactor: move submitted-report selection into Persistence` and `fix: mark the month changed without claiming new entries when an entry is edited`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Move the selection rules into Persistence

Create `Hugo/Persistence/SubmittedReportSelection.swift`:

```swift
import Foundation

/// Decides which stored report counts for a month. Sync duplicates and upgrade
/// placeholders can leave several rows for one month, and every device and
/// every screen must pick the same one.
nonisolated enum SubmittedReportSelection {
    /// False for a placeholder report (`submittedAt == .distantPast`), which
    /// the V8 to V9 upgrade created for months that were never sent.
    static func isReal(_ submission: SubmittedReport) -> Bool {
        (submission.submittedAt ?? .distantPast) != .distantPast
    }

    static func canonical(for month: YearMonth, in submissions: [SubmittedReport]) -> SubmittedReport? {
        canonicalByMonth(submissions)[month]
    }

    static func canonicalByMonth(_ submissions: [SubmittedReport]) -> [YearMonth: SubmittedReport] {
        // body of TheocraticYearReportBuilder.canonicalSubmissionsByMonth, unchanged
    }

    // validYearMonth(for:) and shouldPrefer(_:over:) moved unchanged as private
    // static functions; inside shouldPrefer, call isReal(_:) instead of
    // isRealSubmission(_:).
}
```

Copy the bodies of `canonicalSubmissionsByMonth`, `validYearMonth` and `shouldPrefer` from `TheocraticYearReportBuilder.swift:81-150` without changing their logic. Then delete lines 74-156 (`canonicalSubmission`, `canonicalSubmissionsByMonth`, `validYearMonth`, `shouldPrefer`, `isRealSubmission`) from `TheocraticYearReportBuilder.swift`, and in that file replace the remaining calls: `canonicalSubmissionsByMonth(submissions)` becomes `SubmittedReportSelection.canonicalByMonth(submissions)` and `isRealSubmission(submission)` becomes `SubmittedReportSelection.isReal(submission)`.

Update every other caller listed in "Callers of the builder's helper functions":

- `SyncDeduplicator.swift`: `TheocraticYearReportBuilder.canonicalSubmission(for:in:)` becomes `SubmittedReportSelection.canonical(for:in:)`, `TheocraticYearReportBuilder.isRealSubmission` becomes `SubmittedReportSelection.isReal`, and `TheocraticYearReportBuilder.canonicalSubmissionsByMonth` becomes `SubmittedReportSelection.canonicalByMonth`.
- `SubmitReportFormModel.swift:61`: `SubmittedReportSelection.canonicalByMonth(submissions)`. Lines 114-116 become:

  ```swift
  guard let nextReport = submissionsByMonth[next], SubmittedReportSelection.isReal(nextReport)
  else { return false }
  ```

- `OverviewView.swift:59-65` becomes:

  ```swift
  /// The month whose report reminder should show, if any: a month is due
  /// (per `ReportReminderSchedule`) and has no real submission.
  private var reminderMonth: YearMonth? {
      guard let due = ReportReminderSchedule.dueMonth(now: .now, calendar: .current) else { return nil }
      guard let submission = SubmittedReportSelection.canonical(for: due, in: submissions) else { return due }
      return SubmittedReportSelection.isReal(submission) ? nil : due
  }
  ```

**Verify**:

- `grep -rn 'TheocraticYearReportBuilder' Hugo/Persistence Hugo/Features/Reports Hugo/Features/Overview` → no output
- `grep -rn 'distantPast' Hugo/Features/Overview Hugo/Features/Reports/State` → only `SubmitReportFormModel.swift` lines with `firstSubmittedAt`
- Build and focused tests pass (the `contribution` callers still compile because `contribution(for:)` is untouched in this step).

Commit: `refactor: move submitted-report selection into Persistence`.

### Step 2: Add `ServiceMonth`

Create `Hugo/Features/Reports/Domain/ServiceMonth.swift`. It replaces `TheocraticYearMonth` and takes over the unreported-change rule and the year contribution.

```swift
import Foundation

/// One month together with its entries and its canonical report. Every screen
/// that shows a month reads submitted state, unreported changes and the year
/// contribution from here.
nonisolated struct ServiceMonth: Identifiable {
    /// How a submitted month differs from the report that was sent.
    enum UnreportedChange: Equatable, Sendable {
        /// At least one entry was created after the report was sent. Those
        /// entries answer true to `isUnreported(_:)`.
        case newEntries
        /// No entry is newer than the report, but the month's line totals or
        /// Bible studies no longer match it (an entry was edited or deleted).
        case changedTotals
    }

    let id: YearMonth
    let displayName: String
    let summary: MonthlyReportSummary?
    let isFuture: Bool
    /// The canonical stored report. It can be a placeholder; use `isSubmitted`.
    let submittedReport: SubmittedReport?
    /// Nil when the month was never submitted or still matches its report.
    let unreportedChange: UnreportedChange?

    var isSubmitted: Bool {
        submittedReport.map(SubmittedReportSelection.isReal) ?? false
    }

    /// True when the month was submitted and `entry` was created after the report was sent.
    func isUnreported(_ entry: Entry) -> Bool {
        guard isSubmitted, let submittedReport else { return false }
        return entry.createdAt > (submittedReport.entriesClosedAt ?? .distantPast)
    }

    /// What this month adds to the year total: reported hours when submitted,
    /// logged time otherwise.
    var contribution: MonthContribution {
        // body of TheocraticYearReportBuilder.contribution(for:) (lines 47-72),
        // reading self instead of `month`, returning MonthContribution values,
        // and using SubmittedReportSelection.isReal(submission).
    }

    static func make(
        _ month: YearMonth,
        entries: [Entry],
        submissions: [SubmittedReport],
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> ServiceMonth {
        let monthEntries = entries.filter { $0.date.yearMonth(using: calendar) == month }
        let summary = MonthlyReportBuilder.summaries(from: monthEntries, calendar: calendar, locale: locale).first
        let report = SubmittedReportSelection.canonical(for: month, in: submissions)
        return ServiceMonth(
            id: month,
            displayName: summary?.displayName ?? month.monthYearString(locale: locale, calendar: calendar),
            summary: summary,
            isFuture: month > now.yearMonth(using: calendar),
            submittedReport: report,
            unreportedChange: unreportedChange(report: report, monthEntries: monthEntries, calendar: calendar)
        )
    }

    private static func unreportedChange(
        report: SubmittedReport?, monthEntries: [Entry], calendar: Calendar
    ) -> UnreportedChange? {
        guard let report, SubmittedReportSelection.isReal(report) else { return nil }
        let cutoff = report.entriesClosedAt ?? .distantPast
        if monthEntries.contains(where: { $0.createdAt > cutoff }) { return .newEntries }
        guard isComparable(report), hasChangedTotals(report: report, monthEntries: monthEntries, calendar: calendar)
        else { return nil }
        return .changedTotals
    }

    // toleranceSeconds, isComparable(_:) and hasChangedTotals(report:monthEntries:calendar:)
    // moved unchanged from ReportReminderSchedule.swift:64-82, all private static.
}

/// What one month adds to the year total.
nonisolated struct MonthContribution: Equatable, Sendable {
    let total: TimeInterval
    let main: TimeInterval
    let separate: TimeInterval
    let bibleStudies: Int
}
```

Copy the doc comment from `ReportReminderSchedule.hasUnreportedEntries` (lines 41-47) onto `unreportedChange(report:monthEntries:calendar:)`, adjusted to describe the two cases. Do not delete anything from `ReportReminderSchedule` yet.

**Verify**: the project builds (run the focused test command; all existing tests still pass).

### Step 3: Switch the year report to `ServiceMonth`

1. In `TheocraticYearReport.swift`, delete `TheocraticYearMonth` and change `let months: [TheocraticYearMonth]` to `let months: [ServiceMonth]`.
2. In `TheocraticYearReportBuilder.report(...)`, replace the body up to `let contributions` with:

   ```swift
   let yearEntries = entries.filter { year.contains($0.date.yearMonth(using: calendar)) }
   let months = year.months.map { month in
       ServiceMonth.make(
           month, entries: yearEntries, submissions: submissions, now: now, calendar: calendar, locale: locale)
   }
   let contributions = months.map(\.contribution)
   ```

   Keep the `TheocraticYearReport(...)` return as it is. Delete `contribution(for:)` from the builder.
3. `YearlyGoalProgress.swift:35`: `let contribution = month.contribution`.
4. `ServiceYearDetailView.swift:73`: `let actual = month.contribution.total`.
5. `ServiceYearMonthRow.swift`: change `let month: TheocraticYearMonth` to `let month: ServiceMonth`. Replace `displayedHours` with:

   ```swift
   private var displayedHours: Int {
       Int(month.contribution.total / 3_600)
   }
   ```

   and at line 175 change `if month.hasUnreportedEntries {` to `if month.unreportedChange != nil {`.
6. `ReportPreviewFixtures.swift`: change the `emptyMonth` and `monthWithActivity` types to `ServiceMonth`. Delete `submittedMonth` and `submittedMonthWithUnreportedEntries` (lines 34-70). They are unused: `grep -rn 'submittedMonth' Hugo HugoTests` shows only their definitions.

**Verify**:

- `grep -rn 'TheocraticYearMonth\|hasUnreportedEntries' Hugo` → only `ReportReminderSchedule.swift` (removed in Step 5) and `MonthlyReportDetailView.swift` (fixed in Step 4)
- The project does not build yet, because `MonthlyReportDetailView` still uses the old type. Continue to Step 4 before building.

### Step 4: Make the banner and the row markers use the same rule

1. `MonthlyReportEntryListView.swift`: replace the `summary` and `report` properties and `isUnreported(_:)` with `let month: ServiceMonth`. In `body`, iterate `ForEach(month.summary?.entries ?? [])` and use `if month.isUnreported(entry) {`. Leave the rest of the row unchanged.
2. `MonthlyReportDetailView.swift`: change `let month: TheocraticYearMonth` to `let month: ServiceMonth`, and replace lines 15-24 with:

   ```swift
   if let change = month.unreportedChange {
       Section {
           Label(bannerKey(for: change), systemImage: "exclamationmark.triangle.fill")
               .font(.subheadline)
       }
   }

   MonthlyReportTotalsView(summary: summary)
   MonthlyReportEntryListView(month: month)
   ```

   and add, below `body`:

   ```swift
   private func bannerKey(for change: ServiceMonth.UnreportedChange) -> LocalizedStringKey {
       switch change {
       case .newEntries: "report.detail.unreported.banner"
       case .changedTotals: "report.detail.changed.banner"
       }
   }
   ```

   Keep the return type `LocalizedStringKey`. A plain `String` would show the key instead of the translation.
3. Add the new key to `Hugo/Resources/Localizable.xcstrings`. Insert it in alphabetical key order (directly before `"report.detail.unreported.banner"`), with the file's own formatting (`" : "` separators, two-space indents):

   ```json
   "report.detail.changed.banner" : {
     "comment" : "Banner at the top of a submitted month's detail view when entries were edited or deleted after the report was sent.",
     "localizations" : {
       "da" : {
         "stringUnit" : {
           "state" : "translated",
           "value" : "Denne måned er ændret, siden du indsendte den. Indsend en opdateret rapport for at medtage ændringerne."
         }
       },
       "en" : {
         "stringUnit" : {
           "state" : "translated",
           "value" : "This month has changed since you submitted it. Submit an updated report to include the changes."
         }
       }
     }
   },
   ```

   Both texts are the existing banner's sentences without the "New entries are marked below" sentence.

**Verify**:

- `python3 -I -c "import json; d=json.load(open('Hugo/Resources/Localizable.xcstrings')); print(d['strings']['report.detail.changed.banner']['localizations']['da']['stringUnit']['value'])"` → prints the Danish sentence
- Focused tests: the build succeeds. Tests that still reference `hasUnreportedEntries` fail to compile; fix them in Step 5.

### Step 5: Move the tests and delete the old rule

1. Create `HugoTests/Features/Reports/Domain/ServiceMonthTests.swift`, a `@MainActor struct ServiceMonthTests` with the same `calendar` and `date(_:_:_:hour:minute:)` helpers as `ReportReminderScheduleTests`. Add a helper:

   ```swift
   private let june = YearMonth(year: 2026, month: 6)

   private func month(_ entries: [Entry], _ submissions: [SubmittedReport]) -> ServiceMonth {
       ServiceMonth.make(june, entries: entries, submissions: submissions, now: date(2026, 7, 15), calendar: calendar)
   }
   ```

2. Move every test from `ReportReminderScheduleTests.swift` line 99 (`unreportedWhenNoReportExists`) to the end of the file into `ServiceMonthTests`, together with the helpers `comparableReport`, `oldEntry` and `flagged`. Translate the expectations as follows. Keep each test's name and data.

   | Old test | New expectation |
   |---|---|
   | `unreportedWhenNoReportExists` | `!m.isSubmitted` and `m.unreportedChange == nil` |
   | `unreportedForSentinelReports` | `!m.isSubmitted` and `m.unreportedChange == nil` |
   | `entriesCreatedAfterTheCutoffAreUnreported` | `[older]` gives `nil`; `[older, newer]` gives `.newEntries`, `m.isUnreported(newer)`, `!m.isUnreported(older)` |
   | `entriesFromOtherMonthsDoNotTriggerTheWarning` | `nil` |
   | `unchangedComparableMonthIsNotFlagged` | `nil` |
   | `editedDurationIsFlagged`, `deletedEntryIsFlagged`, `newSeparateLineIsFlagged`, `changedBibleStudiesIsFlagged`, `lateSyncedEntryIsFlagged` | `.changedTotals` |
   | `nonComparableReportKeepsTheCreatedAtRule` | `nil` |

   Change `flagged(_:_:)` to return `ServiceMonth.UnreportedChange?` via `month(entries, [report]).unreportedChange`.
3. Add these new tests to `ServiceMonthTests`:
   - `editedDurationMarksTheMonthButNoEntry`: the `editedDurationIsFlagged` data. Expect `.changedTotals`, and `entries.allSatisfy { !m.isUnreported($0) }`. This is the regression test for the banner bug.
   - `placeholderReportIsNotSubmitted`: a `SubmittedReport(year: 2026, month: 6, entriesClosedAt: date(2026, 6, 30))` with one entry created later. Expect `!m.isSubmitted`, `m.unreportedChange == nil` and `!m.isUnreported(entry)`.
   - `submittedMonthContributesReportedHours`: a real report with one main line of `submittedHours: 2` and one entry of 5_400 seconds. Expect `m.contribution.total == 7_200` and `m.contribution.main == 7_200`.
   - `unsubmittedMonthContributesLoggedTime`: one entry of 5_400 seconds and no report. Expect `m.contribution.total == 5_400`.
4. Delete `hasUnreportedEntries`, `toleranceSeconds`, `isComparable` and `hasChangedTotals` from `ReportReminderSchedule.swift`. Only `dueMonth` and `previousMonthGraceDays` remain.
5. `TheocraticYearReportBuilderTests.swift`:
   - line 77: `#expect(september.unreportedChange == nil)`, comment `// Never submitted, so there is nothing to compare against.`
   - line 202: `#expect(september.unreportedChange == nil)`, keep the comment about the placeholder.
   - line 220: `#expect(september.unreportedChange == nil)`
   - line 238: `#expect(september.unreportedChange == .newEntries)`
6. `SubmitReportFormModelTests.swift` (around line 242): replace the `ReportReminderSchedule.hasUnreportedEntries(...) == true` expectation with:

   ```swift
   let july = ServiceMonth.make(
       YearMonth(year: 2026, month: 7), entries: julyEntries, submissions: [julyReport],
       now: now.addingTimeInterval(86_400), calendar: calendar)
   #expect(july.unreportedChange != nil)
   ```

7. `SchemaMigrationTests.swift` (around line 824): replace the `!ReportReminderSchedule.hasUnreportedEntries(...)` expectation with:

   ```swift
   let receiving = ServiceMonth.make(receivingMonth, entries: entries, submissions: [migratedReceivingReport])
   #expect(receiving.isSubmitted)
   #expect(receiving.unreportedChange == nil)
   ```

**Verify**:

- `grep -rn 'hasUnreportedEntries\|TheocraticYearMonth\|isRealSubmission\|canonicalSubmission' Hugo HugoTests` → no output
- `grep -rln 'TheocraticYear' Hugo/Features/Reports Hugo/Features/Overview Hugo/Persistence/SyncDeduplicator.swift` → no output
- Focused tests → `** TEST SUCCEEDED **`

Commit: `fix: mark the month changed without claiming new entries when an entry is edited`.

### Step 6: Add the term to the glossary

In `CONTEXT.md`, under `## Reports`, add this entry directly after the **Submitted report** entry:

```markdown
**Service month**:
One month together with its entries and its canonical report. It tells whether the month is submitted, whether it has an unreported change and what it adds to the year total.
```

If `CONTEXT.md` does not exist (plan 060 not done), skip this step and say so in your report.

**Verify**: `grep -c 'Service month' CONTEXT.md` → `1`, then `Scripts/verify.sh` → exit 0.

Commit: `docs: add service month to the glossary`.

### Step 7 [owner]: Check the banner on a device

1. Submit a month, then edit one entry's duration in that month. Open the month from the Year page: the banner reads "This month has changed since you submitted it. Submit an updated report to include the changes." and no row has a triangle.
2. Add a new entry to the same month: the banner now says "New entries are marked below" and only the new entry has a triangle.
3. Check both banners in Danish.

## Test plan

- New `ServiceMonthTests`: 11 moved tests plus 4 new ones (Step 5).
- `ReportReminderScheduleTests`: keeps only the `dueMonth` tests.
- `TheocraticYearReportBuilderTests`, `YearlyGoalProgressTests`, `SubmitReportFormModelTests`, `SyncDeduplicatorTests` and `SchemaMigrationTests` must pass with only the assertion changes listed above. A failure anywhere else means behavior changed.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -rn 'distantPast' Hugo --include='*.swift' | grep -v SchemaVersions | grep -v HugoMigrationPlan` lists only `SubmittedReportSelection.swift`, `ServiceMonth.swift` and the `firstSubmittedAt` line in `SubmitReportFormModel.swift`
- [ ] `grep -rn 'TheocraticYearReportBuilder' Hugo/Persistence Hugo/Features/Reports Hugo/Features/Overview` prints nothing
- [ ] `grep -rn 'hasUnreportedEntries\|TheocraticYearMonth' Hugo HugoTests` prints nothing
- [ ] `HugoTests/Features/Reports/Domain/ServiceMonthTests.swift` exists and contains `editedDurationMarksTheMonthButNoEntry`
- [ ] `git status --porcelain` lists only files from the Scope list
- [ ] `plans/README.md` row for 061 updated

## STOP conditions

Stop and report back if:

- Any test in `SyncDeduplicatorTests` or `SchemaMigrationTests` fails after Step 1. The selection rules must behave exactly as before.
- A `TheocraticYearReportBuilderTests` test other than the four assertions listed in Step 5 fails. That means the year totals changed.
- `ServiceMonth` cannot read `Entry` or `SubmittedReport` properties from a `nonisolated` context (compiler error about actor isolation). The builder does this today, so this should not happen. If it does, report the exact error instead of adding `@MainActor`.
- `TheocraticYearMonth` or `hasUnreportedEntries` is used in a file not listed in Scope.

## Maintenance notes

- `ServiceMonth.make` filters the entries and picks the canonical report itself, so callers may pass a whole year of entries and all submissions. The year builder calls it twelve times. That is fine for one year of data. If profiling shows a cost, build the canonical map once and add an internal initializer, but keep `make` as the one public entry point.
- Plan 062 adds `ServiceMonth` readers for screens. Plan 063 reads `month.contribution` to build per-month goal rows. Plan 064 changes how `summary.categories` groups entries; `ServiceMonth` does not depend on that grouping.
- Reviewer focus: the `shouldPrefer` move must be byte-for-byte the same logic, because every device must choose the same survivor during sync repair.
- `ServiceYearMonthRow` now shows `contribution.total` in whole hours. For a submitted month this is the sum of its reporting lines' hours, which equals the stored `submittedHours` for every report this app writes. Only a damaged legacy row could differ, and then the card now agrees with the year total.
