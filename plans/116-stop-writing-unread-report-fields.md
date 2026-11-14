# Plan 116: Stop writing submitted-report fields that nothing reads

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 7e3c4e9..HEAD -- Hugo/Features/Reports/Services/ReportSubmissionService.swift Hugo/Features/Reports/Domain/ReportingLineCalculator.swift HugoTests/Features/Reports/Domain/ReportingLineCalculatorTests.swift HugoTests/Features/Reports/State/SubmitReportFormModelTests.swift HugoTests/Features/Reports/Services/ReportSubmissionServiceTests.swift`
> Expected: no output. Otherwise compare the excerpts below with the live
> files. A mismatch is a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S + owner (the owner confirms no old build is still in use before the build ships)
- **Risk**: LOW. No schema change and nothing visible. The only risk is an old TestFlight build reading these fields through iCloud (see "Why this matters").
- **Depends on**: 114 (the gate)
- **Category**: tech-debt
- **Planned at**: commit `7e3c4e9`, 2026-11-14
- **Issue**: [SLN-290](https://linear.app/sebastianln/issue/SLN-290)

## Why this matters

Every time a report is submitted, `ReportSubmissionService` writes six report-level fields that the current app never reads. Only the schema migrations from V9 and V10 stores read them, and those read the old store's values, not new writes. Writing them keeps an extra hour-splitting algorithm (`ReportingLineCalculator.categoryHours` and its private `distributeHours`) and its tests alive. The report code is harder to follow than it needs to be.

Since schema V11 (2026-08-31) the real record of a submission is `reportingLines`: one line per Field Service or separate category, with its rounding and submitted hours. The Year page, `ServiceMonth` and `ReportAdjustments` all read the lines.

**Old builds.** Builds made before 2026-08-31 (schema V10) displayed some of these fields. A tester who still runs such a build on a second device would see zeros for reports submitted with the new build. TestFlight builds expire 90 days after upload, so every pre-V11 build is gone by 2026-11-29 at the latest. The owner confirms this in App Store Connect before shipping (owner check below). The code change itself is safe to make now.

## Current state

Fields on `SubmittedReport` (schema V13, `Hugo/Persistence/SchemaVersions/V13/SubmittedReportV13.swift`), and who reads them in the app (checked with grep at `7e3c4e9`, excluding `Hugo/Persistence/`):

| Field | Read by the app? | This plan |
|---|---|---|
| `roundingRuleRaw` | no | stop writing |
| `fieldServiceSeconds` | no | stop writing |
| `carriedInSeconds` | no (the per-line `ReportingLine.carriedInSeconds` is a different thing and stays) | stop writing |
| `carriedOutSeconds` | no | stop writing |
| `roundedUpSeconds` | no (`ReportAdjustments.roundedUpSeconds` is computed from the lines and stays) | stop writing |
| `roundedDownSeconds` | no (same as above) | stop writing |
| `categories` | no (`MonthlyReportSummary.categories` is a different type and stays) | stop writing |
| `actualTotalSeconds` | yes, `ServiceMonth.swift:128` | keep writing |
| `submittedHours` | yes, `ServiceMonth.swift:43` | keep writing |
| `totalBibleStudies` | yes, `ServiceMonth.swift:40`, `ServiceYearDetailView.swift:62` | keep writing |
| `reportingLines` | yes | keep writing |

Every one of these properties has a default in `SubmittedReport.init` (`""`, `0` or `[]`), so a new report simply keeps the defaults. **Do not edit the schema file.** `AGENTS.md`: "Never edit a shipped schema version."

`Hugo/Features/Reports/Services/ReportSubmissionService.swift:22-93`, the parts that change:

```swift
    func submit(
        _ results: [ReportingLineResult],
        summary: MonthlyReportSummary?,
        for month: YearMonth,
        replacing existing: SubmittedReport?,
        at now: Date
    ) throws -> SubmittedReport {
        let mainResult = results.first { $0.line.type == .main }
        let categoryHours = ReportingLineCalculator.categoryHours(
            results: results,
            categories: summary?.categories ?? []
        )
        let snapshots = (summary?.categories ?? []).map { category in
            SubmittedReport.SubmittedCategory(
                name: category.name,
                iconName: category.iconName,
                typeRaw: category.type?.rawValue,
                actualSeconds: category.duration,
                submittedHours: categoryHours[category.id] ?? 0
            )
        }
        let carriedInSeconds = results.reduce(0) { $0 + $1.line.carriedInSeconds }
        let carriedOutSeconds = results.reduce(0) { total, result in
            guard case .transferred(let seconds) = result.disposition else { return total }
            return total + seconds
        }
        let roundedUpSeconds = results.reduce(0) { total, result in
            guard case .roundedUp(let seconds) = result.disposition else { return total }
            return total + seconds
        }
        let roundedDownSeconds = results.reduce(0) { total, result in
            guard case .roundedDown(let seconds) = result.disposition else { return total }
            return total + seconds
        }
        let submittedHours = results.reduce(0) { $0 + $1.submittedHours }
        let closedAt = summary?.entries.map(\.createdAt).max() ?? now
        // ... lines 59-76 create or update `report`; unchanged ...
        report.roundingRuleRaw = mainResult?.rule?.rawValue ?? ""
        report.fieldServiceSeconds = mainResult?.line.actualSeconds ?? 0
        report.actualTotalSeconds = summary?.totalSeconds ?? 0
        report.submittedHours = submittedHours
        report.carriedInSeconds = carriedInSeconds
        report.carriedOutSeconds = carriedOutSeconds
        report.roundedUpSeconds = roundedUpSeconds
        report.roundedDownSeconds = roundedDownSeconds
        report.totalBibleStudies = summary?.totalBibleStudies ?? 0
        report.categories = snapshots
        report.reportingLines = results.map(\.persisted)

        reconcileCarriedInEntries(for: report, results: results, month: month, now: now)
        try context.save()
        return report
    }
```

`Hugo/Features/Reports/Domain/ReportingLineCalculator.swift`: `static func categoryHours(results:categories:)` runs from line 125 to line 146, and `private static func distributeHours(submittedHours:categories:)` from line 149 to the closing brace of the `ReportingLineCalculator` enum (around line 196). Nothing else calls either of them. The `private struct Category` after the enum stays.

Tests that use what goes away:
- `HugoTests/Features/Reports/Domain/ReportingLineCalculatorTests.swift:182-227`: `categoryHoursAreDistributedIndependentlyForEachReportingLine` and `categoryHoursReturnsEmptyWhenThereAreNoCategories`, each with its `@Test` line.
- `HugoTests/Features/Reports/State/SubmitReportFormModelTests.swift:138`: `#expect(report.carriedOutSeconds == 1_800)` in `transferPersistsReportingLineAndLinkedNextMonthEntry`. The transfer is already checked through the line and the generated entry on the lines around it.

Test pattern to follow: `HugoTests/Features/Reports/Services/ReportSubmissionServiceTests.swift`. It has the helpers `juneEntry(seconds:)` and `reportingResults(_:rule:)`, and its tests start like this:

```swift
    @Test
    func transferCreatesOneCarriedInEntryInTheNextMonth() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext
        let (results, summary) = reportingResults([juneEntry(seconds: 5_400)], rule: .transfer)

        let report = try ReportSubmissionService(context: context, calendar: calendar)
            .submit(results, summary: summary, for: month, replacing: nil, at: now)
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `xcrun swift-format lint --strict <changed files>` | exit 0, no output |
| Full gate | `Scripts/verify.sh` | exit 0 (several minutes; run with a 600000 ms timeout or in the background) |

## Scope

**In scope**:
- `Hugo/Features/Reports/Services/ReportSubmissionService.swift`
- `Hugo/Features/Reports/Domain/ReportingLineCalculator.swift` (remove `categoryHours` and `distributeHours` only)
- `HugoTests/Features/Reports/Domain/ReportingLineCalculatorTests.swift` (remove the two tests only)
- `HugoTests/Features/Reports/State/SubmitReportFormModelTests.swift` (remove line 138 only)
- `HugoTests/Features/Reports/Services/ReportSubmissionServiceTests.swift` (add one test)

**Out of scope**:
- Everything under `Hugo/Persistence/`, including `SubmittedReportV13.swift` and its doc comments, and `HugoMigrationPlan.swift`. Migrations still read these fields from old stores.
- `HugoTests/Persistence/SchemaMigrationTests.swift`.
- `MonthlyReportSummary`, `MonthlyCategorySummary` and `ServiceYearMonthRow`. They still use `summary.categories`.
- `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` has an uncommitted change by the owner. Never stage, commit, revert or stash it.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- Never stage `plans/`, `.claude/` or `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage files by explicit path.
- One commit: `refactor: stop writing submitted-report fields that nothing reads`

## Steps

### Step 1: Write a test for what a submission stores

Add this test to `ReportSubmissionServiceTests` (after `transferCreatesOneCarriedInEntryInTheNextMonth`):

```swift
    @Test
    func submissionWritesOnlyTheFieldsTheAppReads() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext
        let (results, summary) = reportingResults([juneEntry(seconds: 5_400)], rule: .transfer)

        let report = try ReportSubmissionService(context: context, calendar: calendar)
            .submit(results, summary: summary, for: month, replacing: nil, at: now)

        #expect(report.reportingLines.count == 1)
        #expect(report.submittedHours == 1)
        #expect(report.actualTotalSeconds == 5_400)
        #expect(report.totalBibleStudies == 0)
        // Read only by migrations from V9 and V10 stores, so no longer written.
        #expect(report.roundingRuleRaw == "")
        #expect(report.fieldServiceSeconds == 0)
        #expect(report.carriedInSeconds == 0)
        #expect(report.carriedOutSeconds == 0)
        #expect(report.roundedUpSeconds == 0)
        #expect(report.roundedDownSeconds == 0)
        #expect(report.categories?.isEmpty == true)
    }
```

This test fails before Step 2 (for example `carriedOutSeconds` is 1 800 and `roundingRuleRaw` is `"transfer"`). You will see it pass in Step 4. You don't need to run the tests now.

**Verify**: `grep -c "submissionWritesOnlyTheFieldsTheAppReads" HugoTests/Features/Reports/Services/ReportSubmissionServiceTests.swift` → `1`.

### Step 2: Stop writing the fields

In `ReportSubmissionService.submit`:

1. Delete the locals `mainResult`, `categoryHours`, `snapshots`, `carriedInSeconds`, `carriedOutSeconds`, `roundedUpSeconds` and `roundedDownSeconds` (all the code from `let mainResult` to the end of the `roundedDownSeconds` closure). Keep `submittedHours` and `closedAt`.
2. Delete these seven assignments: `report.roundingRuleRaw = …`, `report.fieldServiceSeconds = …`, `report.carriedInSeconds = …`, `report.carriedOutSeconds = …`, `report.roundedUpSeconds = …`, `report.roundedDownSeconds = …` and `report.categories = snapshots`.
3. The assignment block then reads exactly:

```swift
        report.actualTotalSeconds = summary?.totalSeconds ?? 0
        report.submittedHours = submittedHours
        report.totalBibleStudies = summary?.totalBibleStudies ?? 0
        report.reportingLines = results.map(\.persisted)
```

4. Add one sentence to the doc comment above `submit`, after "…inserted.": `Report-level rounding, carry and category fields are left at their defaults: only migrations from older schema versions read them, and the reporting lines hold the same information.`

**Verify**: `grep -n -E "roundingRuleRaw|fieldServiceSeconds|carriedOutSeconds|roundedUpSeconds|roundedDownSeconds|categoryHours|SubmittedCategory|report\.categories|report\.carriedInSeconds" Hugo/Features/Reports/Services/ReportSubmissionService.swift` → no output. (`result.line.carriedInSeconds` isn't used in this file after the change either.)

### Step 3: Remove the hour-splitting code and its tests

1. In `ReportingLineCalculator.swift`, delete `categoryHours(results:categories:)` and `distributeHours(submittedHours:categories:)` completely, with the blank line between them. The enum's closing brace stays, and so does `private struct Category` below it.
2. In `ReportingLineCalculatorTests.swift`, delete the two tests `categoryHoursAreDistributedIndependentlyForEachReportingLine` and `categoryHoursReturnsEmptyWhenThereAreNoCategories`, each including its `@Test` line.
3. In `SubmitReportFormModelTests.swift`, delete the line `#expect(report.carriedOutSeconds == 1_800)`.

**Verify**: `grep -rn -E "categoryHours|distributeHours" Hugo HugoTests` → no output. `grep -c "carriedOutSeconds == 1_800" HugoTests/Features/Reports/State/SubmitReportFormModelTests.swift` → `0`.

### Step 4: Run the gate and commit

**Verify**:
- `xcrun swift-format lint --strict Hugo/Features/Reports/Services/ReportSubmissionService.swift Hugo/Features/Reports/Domain/ReportingLineCalculator.swift HugoTests/Features/Reports/Domain/ReportingLineCalculatorTests.swift HugoTests/Features/Reports/State/SubmitReportFormModelTests.swift HugoTests/Features/Reports/Services/ReportSubmissionServiceTests.swift` → exit 0.
- `Scripts/verify.sh` → exit 0. The log contains `submissionWritesOnlyTheFieldsTheAppReads` with a pass.

Commit the five files by path.

## Test plan

- New: `ReportSubmissionServiceTests.submissionWritesOnlyTheFieldsTheAppReads` checks that the read fields are still written and the seven unread fields keep their defaults.
- Removed: the two `categoryHours` tests (their code is gone) and one assertion on `carriedOutSeconds`.
- Unchanged and still passing: `SchemaMigrationTests` (migrations still read the old fields from old stores), `ServiceMonthTests`, `ReportAdjustmentsTests`.

## Done criteria

- [ ] `grep -rn -E "categoryHours|distributeHours" Hugo HugoTests` prints nothing
- [ ] `git diff --stat 7e3c4e9..HEAD -- Hugo/Persistence HugoTests/Persistence` prints nothing
- [ ] `Scripts/verify.sh` exits 0
- [ ] `git show --stat HEAD` lists exactly the five in-scope files

## STOP conditions

- The drift check shows changes and the excerpts don't match.
- A grep finds an app reader (outside `Hugo/Persistence/`) of one of the seven fields: `grep -rnE "\.(roundingRuleRaw|fieldServiceSeconds|carriedOutSeconds)\b" Hugo --include='*.swift' | grep -v Persistence/` should only print lines in `ReportSubmissionService.swift` before Step 2.
- A test in `SchemaMigrationTests` fails.
- `Scripts/verify.sh` fails twice. Report the failing test names.

## Owner check

Before a TestFlight build with this change goes out: in App Store Connect → TestFlight, confirm that no build uploaded before 2026-08-31 is still active. After 2026-11-29 none can be, because TestFlight builds expire after 90 days.

## Maintenance notes

- The doc comments in `SubmittedReportV13.swift` still say these fields serve "the current submission workflow". They are stale but live in a schema file, which this plan doesn't touch. Fix them in the next schema version, which can also drop the fields.
- Reports submitted before this change keep their old values in these fields. Nothing reads them, so the mix doesn't matter. A future reader must use `reportingLines`, never these fields.
