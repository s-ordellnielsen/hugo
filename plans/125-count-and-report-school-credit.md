# Plan 125: Count school credit toward the year and send it on the month's report

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 9d5a547..HEAD -- Hugo/Features/Reports Hugo/Features/ServiceYear/Domain Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift Hugo/Features/Planner/Domain/PlannerTarget.swift Hugo/Features/Planner/Screens/PlannerView.swift Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift`
> Expected: no output. Plan 124 must already be committed (`grep -n "typealias SchoolCredit" Hugo/Persistence/AppSchema.swift` → one match). If either check fails, STOP.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED. Changes the numbers on the Year page, the Planner's adjusted target and the report message. Every change is covered by tests.
- **Depends on**: 124 (the `SchoolCredit` model, `SubmittedReport.schoolCreditHours`, `School`)
- **Category**: direction
- **Planned at**: commit `9d5a547`, 2026-11-16
- **Issue**: [SLN-156](https://linear.app/sebastianln/issue/SLN-156)

## Why this matters

Plan 124 stores school credits, but nothing reads them yet. After this plan:

- A month's school credit counts toward the yearly goal **in full, like main time**. It is not limited by the separate allowance. (Owner, 2026-11-16: "PSS credit counts 100% towards your yearly goal, in the same way as main field service".)
- It counts in the year total and in the Planner's adjusted target.
- The month's report message gets one line per school, e.g. `Pioneer Service School: 30 h`, placed after the reporting lines and before Bible studies.
- The submit sheet shows each school credit as a read-only row, with a note that credits are added on the Year page.
- The sent report saves the credit hours in `schoolCreditHours`. A submitted month whose credits change afterwards shows an unreported change, the same as an edited entry.

The UI to add credits comes in plan 126.

## Current state

### `MonthContribution` and `ServiceMonth` (`Hugo/Features/Reports/Domain/ServiceMonth.swift`)

```swift
/// What one month adds to the year total.
nonisolated struct MonthContribution: Equatable, Sendable {
    let total: TimeInterval
    let main: TimeInterval
    let separate: TimeInterval
    let bibleStudies: Int
}
```

`ServiceMonth.contribution` (lines 36-66) returns reported hours for a submitted month and logged time otherwise:

```swift
    var contribution: MonthContribution {
        if let submission = submittedReport, SubmittedReportSelection.isReal(submission) {
            let studies = submission.totalBibleStudies ?? 0

            guard !submission.reportingLines.isEmpty else {
                let main = TimeInterval(submission.submittedHours ?? 0) * 3_600
                return MonthContribution(total: main, main: main, separate: 0, bibleStudies: studies)
            }

            let main = submission.reportingLines
                .filter { $0.type == .main }
                .reduce(0) { $0 + TimeInterval($1.submittedHours) * 3_600 }
            let separate = submission.reportingLines
                .filter { $0.type == .separate }
                .reduce(0) { $0 + TimeInterval($1.submittedHours) * 3_600 }
            return MonthContribution(total: main + separate, main: main, separate: separate, bibleStudies: studies)
        }

        guard let summary else {
            return MonthContribution(total: 0, main: 0, separate: 0, bibleStudies: 0)
        }

        return MonthContribution(
            total: summary.totalSeconds,
            main: summary.mainDuration,
            separate: summary.separateDuration,
            bibleStudies: summary.totalBibleStudies
        )
    }
```

`ServiceMonth.make(_:entries:submissions:trackers:now:calendar:locale:)` (lines 82-104) builds the month and calls `unreportedChange(report:monthEntries:calendar:)` (lines 114-122):

```swift
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
```

The stored properties of `ServiceMonth` are `id`, `displayName`, `summary`, `isFuture`, `submittedReport`, `unreportedChange`.

### Year report (`Hugo/Features/ServiceYear/Domain/`)

`TheocraticYearReportBuilder.report(for:entries:submissions:trackers:now:calendar:locale:)` maps `year.months` through `ServiceMonth.make` and sums `contributions` into `TheocraticYearReport(year:months:totalSeconds:totalBibleStudies:mainDuration:separateDuration:)`.

`YearlyGoalRule.swift`:

```swift
nonisolated struct YearlyGoalRule: Equatable, Sendable {
    let monthlyGoalSeconds: TimeInterval
    /// Separate-category time that may count on top of the monthly goal.
    let separateAllowanceSeconds: TimeInterval

    /// All main time counts. Separate time counts only up to
    /// `monthlyGoalSeconds + separateAllowanceSeconds` in total.
    func creditedSeconds(main: TimeInterval, separate: TimeInterval) -> TimeInterval {
        let room = max(0, monthlyGoalSeconds + separateAllowanceSeconds - main)
        return main + min(separate, room)
    }
}
```

It's called from a contribution in exactly two places:
- `YearlyGoalProgress.swift:56`: `creditedSeconds: rule.creditedSeconds(main: contribution.main, separate: contribution.separate),`
- `PlannerTarget.swift:114`: `return total + rule.creditedSeconds(main: contribution.main, separate: contribution.separate)`

`PlannerTarget.creditedBeforeCurrentMonth(entries:submissions:trackers:status:now:calendar:locale:)` (lines 90-105) builds the year report. Its callers are `PlannerView.swift:73-77` and `PlannerTargetSettingsView.swift:40-44`; both have `@Query private var submissions: [SubmittedReport]` next to which you add a credits query.

`ServiceYearPageView.swift:27-34` builds the report from its `@Query` arrays:

```swift
    private var report: TheocraticYearReport {
        TheocraticYearReportBuilder.report(
            for: year,
            entries: entries,
            submissions: submissions,
            trackers: trackers
        )
    }
```

### Report message (`Hugo/Features/Reports/Domain/ReportComposer.swift`)

`ReportComposer.message(month:results:bibleStudies:template:firstName:lastName:locale:calendar:)` builds lines:

```swift
        for result in results {
            let label = ...
            lines.append("\(label): \(result.submittedHours) \(hoursUnit)")
        }

        let studiesLabel = String(localized: LocalizedStringResource("report.compose.bible-studies", locale: locale))
        lines.append("\(studiesLabel): \(bibleStudies)")
```

### Submission (`Hugo/Features/Reports/Services/ReportSubmissionService.swift`)

```swift
    func submit(
        _ results: [ReportingLineResult],
        summary: MonthlyReportSummary?,
        for month: YearMonth,
        replacing existing: SubmittedReport?,
        at now: Date
    ) throws -> SubmittedReport {
        ...
        report.actualTotalSeconds = summary?.totalSeconds ?? 0
        report.submittedHours = submittedHours
        report.totalBibleStudies = summary?.totalBibleStudies ?? 0
        report.reportingLines = results.map(\.persisted)
```

### Form model (`Hugo/Features/Reports/State/SubmitReportFormModel.swift`)

```swift
    private var pendingLoad: (entries: [Entry], submissions: [SubmittedReport])?
    ...
    func load(entries: [Entry], submissions: [SubmittedReport]) {
        guard preparedContent == nil else {
            pendingLoad = (entries, submissions)
            return
        }
        ...
    }

    func cancelPreparedSubmission() {
        preparedContent = nil
        if let pending = pendingLoad {
            pendingLoad = nil
            load(entries: pending.entries, submissions: pending.submissions)
        }
    }
```

`prepareSubmission()` calls `ReportComposer.message(month:results:bibleStudies:template:firstName:lastName:locale:calendar:)` and `persistSubmission(using:)` calls `service.submit(results, summary: summary, for: month, replacing: existingSubmission, at: now)`.

### Submit sheet (`Hugo/Features/Reports/Screens/SubmitReportView.swift`)

Queries entries and submissions in `init(month:)` with `#Predicate`s, and calls `model.load(entries: entries, submissions: submissions)` from `syncModel()` on appear and on `.onChange(of: entries)` / `.onChange(of: submissions)`. In `body`, after the `ForEach(orderedResults)` of `ReportingLineCard`s and the optional rounding help button, comes `Spacer(minLength: HugoLayout.Spacing.section)` and then the Bible studies row:

```swift
                HStack {
                    Label("report.bible-studies", systemImage: "book")
                    Spacer()
                    Text(String(summary?.totalBibleStudies ?? 0))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.compactCard))
```

### From plan 124

- `SchoolCredit` (`@Model`): `schoolID: String`, `year: Int`, `month: Int`, `hours: Int`, `yearMonth: YearMonth`.
- `SubmittedReport.schoolCreditHours: Int?` (nil = none).
- `School` enum in `Hugo/Features/SchoolCredits/Domain/School.swift`: `School.allCases`, `School(rawValue:)`, `School.name(forID:locale:)`.

### Conventions

- Domain types are `nonisolated` and take `calendar`/`locale`/`now` as parameters with defaults. `ServiceMonth` already reads `@Model` properties from a `nonisolated` static function, so doing the same in new domain code compiles.
- New parameters get default values (`= []`, `= 0`) so existing callers and tests keep compiling.
- Tests: Swift Testing; fixed Gregorian calendar in UTC as in `ServiceMonthTests`.
- 4-space indentation.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full gate | `Scripts/verify.sh` | exit 0 |
| Lint only | `swift-format lint --strict --recursive Hugo HugoTests` | no output |
| Catalog JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0 |

## Scope

**In scope:**
- `Hugo/Features/SchoolCredits/Domain/SchoolCreditLine.swift` (create)
- `Hugo/Features/Reports/Domain/ServiceMonth.swift`
- `Hugo/Features/Reports/Domain/ReportComposer.swift`
- `Hugo/Features/Reports/Services/ReportSubmissionService.swift`
- `Hugo/Features/Reports/State/SubmitReportFormModel.swift`
- `Hugo/Features/Reports/Screens/SubmitReportView.swift`
- `Hugo/Features/ServiceYear/Domain/YearlyGoalRule.swift`
- `Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift`
- `Hugo/Features/ServiceYear/Domain/TheocraticYearReport.swift`
- `Hugo/Features/ServiceYear/Domain/TheocraticYearReportBuilder.swift`
- `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift` (query + pass credits only)
- `Hugo/Features/Planner/Domain/PlannerTarget.swift`
- `Hugo/Features/Planner/Screens/PlannerView.swift` (query + pass credits only)
- `Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift` (query + pass credits only)
- `Hugo/Resources/Localizable.xcstrings` (1 new key)
- Tests: `HugoTests/Features/SchoolCredits/Domain/SchoolCreditLineTests.swift` (create), `HugoTests/Features/Reports/Domain/ServiceMonthTests.swift`, `HugoTests/Features/Reports/Domain/ReportComposerTests.swift`, `HugoTests/Features/Reports/Services/ReportSubmissionServiceTests.swift`, `HugoTests/Features/Reports/State/SubmitReportFormModelTests.swift`, `HugoTests/Features/ServiceYear/Domain/YearlyGoalRuleTests.swift`

**Out of scope:**
- `ServiceYearDetailView`, `ServiceYearMonthRow`, any editor screen, help articles. Plan 126 does those.
- `PlannerMonthStatus` / the Planner's current-month bar. It shows logged and planned time for the month; school credit isn't logged time. Leave it.
- `Hugo/Features/Settings/Domain/CurrentMonthCalculation.swift`. It builds a report with no entries to preview pacing; credits don't matter there.
- `SubmittedReport.submittedHours` and `actualTotalSeconds`. Keep them as the sum of reporting lines only; the credit lives in `schoolCreditHours`.
- `ServiceMonth.hasChangedTotals` and `isComparable`. The credit check is separate (step 3).
- Anything under `Hugo/Persistence`.

## Git workflow

- Work on `main` directly. No branch, no worktree.
- One commit after `Scripts/verify.sh` exits 0: `feat: count school credit toward the yearly goal and send it on the report`.
- Never stage `.claude/`, `plans/` or `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`. Do not push.

## Steps

### Step 1: `SchoolCreditLine`

Create `Hugo/Features/SchoolCredits/Domain/SchoolCreditLine.swift`:

```swift
import Foundation

/// One school's credit hours in one month, as a report shows them.
nonisolated struct SchoolCreditLine: Identifiable, Equatable, Sendable {
    let schoolID: String
    let hours: Int

    var id: String { schoolID }

    /// The school credits of `month`, one line per school with its hours
    /// summed. Known schools come first in `School.allCases` order; schools
    /// this build doesn't know follow, sorted by id.
    static func lines(from credits: [SchoolCredit], in month: YearMonth) -> [SchoolCreditLine] {
        var hoursBySchool: [String: Int] = [:]
        for credit in credits where credit.yearMonth == month {
            hoursBySchool[credit.schoolID, default: 0] += credit.hours
        }
        let known = School.allCases.map(\.rawValue)
        return hoursBySchool
            .map { SchoolCreditLine(schoolID: $0.key, hours: $0.value) }
            .sorted { a, b in
                let ia = known.firstIndex(of: a.schoolID) ?? known.count
                let ib = known.firstIndex(of: b.schoolID) ?? known.count
                return ia != ib ? ia < ib : a.schoolID < b.schoolID
            }
    }

    /// Total hours over `lines`.
    static func totalHours(_ lines: [SchoolCreditLine]) -> Int {
        lines.reduce(0) { $0 + $1.hours }
    }
}
```

Create `HugoTests/Features/SchoolCredits/Domain/SchoolCreditLineTests.swift` with:
- `sumsCreditsOfTheSameSchoolInTheMonth`: credits of 15 and 10 h for `pioneer-service-school` in October 2026 → one line with 25 h.
- `ignoresOtherMonths`: a November credit doesn't appear in October's lines.
- `knownSchoolsComeBeforeUnknownOnes`: credits for `"zzz-school"` and `"pioneer-service-school"` → `pioneer-service-school` first.

`SchoolCredit` can be created without a container: `SchoolCredit(schoolID:month:hours:)`.

**Verify**: build passes (`xcodebuild build -project Hugo.xcodeproj -scheme Debug -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | grep -c "error:"` → `0`).

### Step 2: Add school credit to `MonthContribution` and `ServiceMonth`

In `ServiceMonth.swift`:

1. Add a field to `MonthContribution`, declared `var` with a default so the memberwise initializer keeps working for existing callers:

```swift
/// What one month adds to the year total.
nonisolated struct MonthContribution: Equatable, Sendable {
    let total: TimeInterval
    let main: TimeInterval
    let separate: TimeInterval
    let bibleStudies: Int
    /// School credit in seconds. Counts toward the yearly goal like main time
    /// and is part of `total`.
    var schoolCredit: TimeInterval = 0
}
```

2. Add a stored property to `ServiceMonth`, after `unreportedChange`:

```swift
    /// Whole hours of school credit the month has now, summed over its
    /// school credits. A submitted month counts its report's
    /// `schoolCreditHours` instead; a difference is an unreported change.
    let schoolCreditHours: Int
```

3. Rewrite `contribution` so every path includes the credit. The submitted paths use the report's snapshot; the unsubmitted paths use `schoolCreditHours`:

```swift
    var contribution: MonthContribution {
        if let submission = submittedReport, SubmittedReportSelection.isReal(submission) {
            let studies = submission.totalBibleStudies ?? 0
            let credit = TimeInterval(submission.schoolCreditHours ?? 0) * 3_600

            guard !submission.reportingLines.isEmpty else {
                let main = TimeInterval(submission.submittedHours ?? 0) * 3_600
                return MonthContribution(
                    total: main + credit, main: main, separate: 0, bibleStudies: studies, schoolCredit: credit)
            }

            let main = ...   // unchanged
            let separate = ...   // unchanged
            return MonthContribution(
                total: main + separate + credit, main: main, separate: separate, bibleStudies: studies,
                schoolCredit: credit)
        }

        let credit = TimeInterval(schoolCreditHours) * 3_600
        guard let summary else {
            return MonthContribution(total: credit, main: 0, separate: 0, bibleStudies: 0, schoolCredit: credit)
        }

        return MonthContribution(
            total: summary.totalSeconds + credit,
            main: summary.mainDuration,
            separate: summary.separateDuration,
            bibleStudies: summary.totalBibleStudies,
            schoolCredit: credit
        )
    }
```

Update the doc comment above `contribution` to: `/// What this month adds to the year total: reported hours and reported school credit when submitted, logged time and current school credit otherwise.`

4. In `make`, add a parameter `schoolCredits: [SchoolCredit] = []` after `trackers`, compute `let schoolCreditHours = SchoolCreditLine.totalHours(SchoolCreditLine.lines(from: schoolCredits, in: month))`, pass it to the initializer and to `unreportedChange`.

### Step 3: Flag a changed credit as an unreported change

Change `unreportedChange` to take `schoolCreditHours: Int` and check it right after the `.newEntries` line:

```swift
        if monthEntries.contains(where: { $0.createdAt > cutoff }) { return .newEntries }
        if (report.schoolCreditHours ?? 0) != schoolCreditHours { return .changedTotals }
        guard isComparable(report), ...
```

Update the `.changedTotals` doc comment in `UnreportedChange` to: `/// No entry is newer than the report, but the month's line totals, Bible studies or school credit no longer match it.`

**Verify** (steps 2-3): build passes as in step 1. If any other file constructs `ServiceMonth(` directly, the build tells you; `grep -rn "ServiceMonth(" Hugo HugoTests` should show only `ServiceMonth.swift`. If tests construct it directly, STOP.

### Step 4: Credit school credit like main time

In `YearlyGoalRule.swift`, add below `creditedSeconds(main:separate:)`:

```swift

    /// Credited time of one month. School credit counts in full, like main time.
    func creditedSeconds(for contribution: MonthContribution) -> TimeInterval {
        creditedSeconds(main: contribution.main + contribution.schoolCredit, separate: contribution.separate)
    }
```

Then replace the two call sites:
- `YearlyGoalProgress.swift`: `creditedSeconds: rule.creditedSeconds(main: contribution.main, separate: contribution.separate),` → `creditedSeconds: rule.creditedSeconds(for: contribution),`
- `PlannerTarget.swift`: `return total + rule.creditedSeconds(main: contribution.main, separate: contribution.separate)` → `return total + rule.creditedSeconds(for: contribution)`

**Verify**: `grep -rn "creditedSeconds(main: contribution" Hugo` → no output.

### Step 5: Pass credits through the year report

- `TheocraticYearReport`: add `let schoolCreditSeconds: TimeInterval` after `separateDuration`.
- `TheocraticYearReportBuilder.report`: add parameter `schoolCredits: [SchoolCredit] = []` after `trackers`; pass `schoolCredits: schoolCredits` to `ServiceMonth.make`; set `schoolCreditSeconds: contributions.reduce(0) { $0 + $1.schoolCredit }`.
- `PlannerTarget.creditedBeforeCurrentMonth`: add parameter `schoolCredits: [SchoolCredit] = []` after `trackers` and pass it to the builder.
- `ServiceYearPageView`, `PlannerView`, `PlannerTargetSettingsView`: add `@Query private var schoolCredits: [SchoolCredit]` next to the submissions query (no filter; the table holds a handful of rows) and pass `schoolCredits: schoolCredits` to `TheocraticYearReportBuilder.report` / `PlannerTarget.creditedBeforeCurrentMonth`.

If any other code constructs `TheocraticYearReport(` directly (`grep -rn "TheocraticYearReport(" Hugo HugoTests`), add `schoolCreditSeconds: 0` there.

**Verify**: build passes.

### Step 6: Report message

In `ReportComposer.message`, add parameter `schoolCredits: [SchoolCreditLine] = []` directly after `results`. After the `for result in results` loop and before the Bible studies line, add:

```swift
        for credit in schoolCredits {
            lines.append("\(School.name(forID: credit.schoolID, locale: locale)): \(credit.hours) \(hoursUnit)")
        }
```

### Step 7: Save the credit with the report

In `ReportSubmissionService.submit`, add parameter `schoolCreditHours: Int = 0` after `summary`, and next to `report.totalBibleStudies = ...` add `report.schoolCreditHours = schoolCreditHours`. Add to the doc comment: `` `schoolCreditHours` is the month's school credit included in the message. ``

### Step 8: Form model

In `SubmitReportFormModel`:
- Add `private(set) var schoolCreditLines: [SchoolCreditLine] = []`.
- Change `pendingLoad` to `(entries: [Entry], submissions: [SubmittedReport], schoolCredits: [SchoolCredit])?`.
- Change `load` to `func load(entries: [Entry], submissions: [SubmittedReport], schoolCredits: [SchoolCredit] = [])`. In the guard, store all three. After `self.lines = ...`, set `self.schoolCreditLines = SchoolCreditLine.lines(from: schoolCredits, in: month)`.
- In `cancelPreparedSubmission`, pass `schoolCredits: pending.schoolCredits`.
- In `prepareSubmission`, pass `schoolCredits: schoolCreditLines` to `ReportComposer.message`.
- In `persistSubmission`, pass `schoolCreditHours: SchoolCreditLine.totalHours(schoolCreditLines)` to `service.submit`.

### Step 9: Submit sheet

In `SubmitReportView`:
- Add `@Query private var schoolCredits: [SchoolCredit]`. In `init(month:)`, after the entries query, add:

```swift
        _schoolCredits = Query(
            filter: #Predicate<SchoolCredit> { $0.year == targetYear && $0.month == targetMonth }
        )
```

  Move the `let targetYear = month.year` / `let targetMonth = month.month` lines above it if needed.
- `syncModel()` → `model.load(entries: entries, submissions: submissions, schoolCredits: schoolCredits)`.
- Add `.onChange(of: schoolCredits) { syncModel() }` next to the other `.onChange` calls.
- In `body`, between the rounding help button block and the `Spacer(minLength: HugoLayout.Spacing.section)` before Bible studies, add:

```swift
                if !model.schoolCreditLines.isEmpty {
                    Spacer(minLength: HugoLayout.Spacing.section)

                    ForEach(model.schoolCreditLines) { credit in
                        HStack {
                            Label(School.name(forID: credit.schoolID), systemImage: "graduationcap")
                            Spacer()
                            Text(ServiceDurationFormatter.hoursString(from: TimeInterval(credit.hours) * 3_600))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.compactCard))
                    }

                    Text("schoolCredit.submit.footer")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
```

Add the key to `Localizable.xcstrings` in sorted position (`en`/`da` translated, with comment):

| Key | English | Danish | Comment |
|---|---|---|---|
| `schoolCredit.submit.footer` | School credit is part of this report. To change it, open the month's menu on the Year tab. | Skolekredit er en del af denne rapport. Du kan ændre den i månedens menu under Tjenesteår. | Note under the school credit rows on the submit report sheet. "Year" / "Tjenesteår" is the tab name (key tab.year). |

**Verify**: catalog JSON command → exit 0; build passes.

### Step 10: Tests

Add these tests (match each file's existing helpers and style):

`ServiceMonthTests.swift` (uses `june` = June 2026; build credits with `SchoolCredit(schoolID: "pioneer-service-school", month: june, hours: 30)`, pass them through `ServiceMonth.make(..., schoolCredits:)`; add a parameter to the private `month(_:_:)` helper with a default `[]`):
- `unsubmittedMonthCountsCurrentSchoolCredit`: no entries, no report, one 30-h credit → `contribution.schoolCredit == 108_000`, `contribution.total == 108_000`.
- `submittedMonthCountsTheReportedCredit`: `comparableReport(mainSeconds: 3_600)` with `schoolCreditHours = 30`, matching entry and credit → `unreportedChange == nil`, `contribution.total == 3_600 + 108_000`.
- `creditAddedAfterSubmittingIsAnUnreportedChange`: report with `schoolCreditHours` nil, matching entry, one 30-h credit → `unreportedChange == .changedTotals`, and `contribution.schoolCredit == 0` (the report's snapshot, not the current credit).

`YearlyGoalRuleTests.swift`:
- `schoolCreditCountsInFullLikeMainTime`: rule with monthly goal 50 h and allowance 5 h; contribution main 40 h, separate 20 h, school credit 30 h → `creditedSeconds(for:)` == 70 h (separate gets no room because main + credit is already above 55 h).

`ReportComposerTests.swift`:
- `messageListsSchoolCreditBeforeBibleStudies`: compose with `schoolCredits: [SchoolCreditLine(schoolID: "pioneer-service-school", hours: 30)]`, `locale: Locale(identifier: "en")` → the body contains the line `Pioneer Service School: 30 h`, and it comes before the Bible studies line.

`ReportSubmissionServiceTests.swift`:
- `submissionStoresSchoolCreditHours`: submit with `schoolCreditHours: 30` → the fetched report has `schoolCreditHours == 30`.

`SubmitReportFormModelTests.swift`:
- `schoolCreditGoesIntoTheMessageAndTheSavedReport`: load one entry and one 30-h credit for the model's month; `prepareSubmission()` body contains `30`-hour credit line; `persistSubmission(using:)` stores `schoolCreditHours == 30`. Copy the setup of an existing test in the file that calls `persistSubmission`.

**Verify**: `Scripts/verify.sh` → exit 0.

### Step 11: Commit

Commit only in-scope files with the message from "Git workflow".

## Test plan

Listed in step 10: 3 `SchoolCreditLine` tests, 3 `ServiceMonth` tests, 1 rule test, 1 composer test, 1 service test, 1 form model test. All existing tests must still pass unchanged; the defaults (`= []`, `= 0`) exist so they do.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -rn "creditedSeconds(for: contribution)" Hugo` → 2 matches
- [ ] `grep -n "schoolCreditHours" Hugo/Features/Reports/Services/ReportSubmissionService.swift` → at least 1 match
- [ ] `grep -n "schoolCredits" Hugo/Features/Reports/Screens/SubmitReportView.swift` → at least 3 matches
- [ ] `git status --short` shows no modified files outside the in-scope list, except the owner's `Debug.xcscheme`

## STOP conditions

- Plan 124 isn't in the history (no `SchoolCredit` typealias).
- Code at the excerpted locations differs from this plan.
- An existing test fails because a total now includes school credit and you can't tell whether the test or the change is wrong.
- A `#Predicate` on `SchoolCredit` fails to compile.
- The change seems to need `ServiceYearDetailView`, `ServiceYearMonthRow` or a schema file.

## Maintenance notes

- The single rule for crediting is `YearlyGoalRule.creditedSeconds(for:)`. Any new place that credits a month must call it, never `creditedSeconds(main:separate:)` with a contribution's fields.
- `SubmittedReport.submittedHours` stays the sum of reporting lines. Code that wants "everything the report counted" reads `ServiceMonth.contribution.total`.
- If the owner confirms that a school spanning two months must be split equally, that's a UI rule for plan 126's editor, not a change here.
