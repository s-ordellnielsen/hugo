# Plan 137: Replace the `.distantPast` submission sentinel with one vocabulary

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 0af2e24..HEAD -- Hugo/Persistence Hugo/Features/Reports Hugo/Features/ServiceYear HugoTests/Persistence HugoTests/Features/Reports`
> Expected: no output. If anything changed, compare it with "Current state" and STOP on a mismatch.
> Also `git status --short` must show only
> `M Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` (the owner's own
> edit; never touch or commit it) and untracked plan files.

## Status

- **Priority**: P3 (Medium)
- **Effort**: M
- **Risk**: MED. No schema change, but one step rewrites two synced date fields on every device (see "Risk to already-synced data").
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `0af2e24`, 2026-11-23
- **Issue**: [SLN-202](https://linear.app/sebastianln/issue/SLN-202)

## Why this matters

"This month was never submitted" is stored two ways on `SubmittedReport`: as
`nil` and as `Date.distantPast`. Older data upgraded from V8 to V9 left
placeholder reports whose `submittedAt` and `firstSubmittedAt` are
`.distantPast`, and the V14 initializer still defaults every date to
`.distantPast`. Because the stored fields are optional (`Date?`), every reader
has to defend against both, and it does so in six separate places with
expressions such as `(submission.submittedAt ?? .distantPast) != .distantPast`.
A reader that forgets one half is a bug waiting to happen (a placeholder shown
as "submitted on 1 January 0001", or a duplicate merge that prefers the wrong
row).

After this plan there is one vocabulary on `SubmittedReport`:
`isSubmitted: Bool`, `submittedDate: Date?` and `firstSubmittedDate: Date?`.
The sentinel is interpreted in exactly one place (a new extension file), and a
launch-time repair rewrites stored `.distantPast` values to `nil`.

The issue text was written in August and names files that no longer exist
(for example `MonthlyReportEntryListView`). Every use below was re-derived with
`grep` at `0af2e24`.

## Decision: no new schema version (no V15)

Decided by checking the current code, not assumed:

1. **The V14 fields are already optional.** `SubmittedReportV14.swift` lines
   15 to 21 declare `var firstSubmittedAt: Date?`, `var submittedAt: Date?` and
   `var entriesClosedAt: Date?`. They have been optional since V10 (the V9 to V10
   stage, `migrateV9toV10`, was exactly the "make it CloudKit-eligible" change).
   `nil` is therefore a legal stored value in every schema version a user can be
   on. The model's shape does not change, so there is nothing for a
   `VersionedSchema` to describe.
2. **A schema version cannot rewrite values anyway.** `.lightweight` stages
   change shape only. A `.custom` stage needs two different versions, so a V15
   identical to V14 would exist only to carry a data pass, would add four
   copied model files (V13 and V14 both had to copy `Entry`, `Tracker`,
   `SubmittedReport`, `Plan` for the relationship), and would force a CloudKit
   schema redeploy for nothing. A custom stage also runs only once per device
   when it upgrades, so a placeholder arriving later by sync would never be
   cleaned.
3. **The V14 shape is shipped** (`git branch --contains 7a0bc9e` includes
   `testflight`). `AGENTS.md` forbids editing it. That is also why the
   `.distantPast` default in the V14 initializer stays; the reader-side accessor
   absorbs it.
4. **Rewriting `distantPast` to `nil` is safe for devices on the previous
   build.** Every reader in the previous build treats `nil` and `.distantPast`
   the same (`?? .distantPast`, and `ReportSubmissionService` checks both), and
   the previous build never writes `.distantPast` from production code (it only
   passes real dates to the initializer; only the V8 to V9 migration creates
   placeholders). So a `nil` arriving by sync changes nothing on an old build,
   and an old build cannot rewrite it back.
5. **No CloudKit deploy is needed.** No record type and no field is added or
   changed. `CD_submittedAt` and `CD_firstSubmittedAt` already exist in the
   Production schema (they have held real dates since V10); a record whose value
   is `nil` simply has the field unset.

So the stored-value rewrite is a safe, idempotent, launch-time normalization in
`SyncDeduplicator`, which `AppRootView` already runs at launch, on every
foreground and after every CloudKit import. Running it repeatedly matters: a
placeholder can still arrive later, for example from a device that upgrades from
an old store after this one.

## Current state

The sentinel has two meanings, and this plan handles them differently:

- **Submission sentinel** (`submittedAt`, `firstSubmittedAt` equal to
  `.distantPast`): means "never submitted". Replaced by this plan.
- **Cutoff floor** (`entriesClosedAt ?? .distantPast`): means "no entry is
  covered yet". A placeholder's `entriesClosedAt` is a real date (the newest
  entry's `createdAt` at upgrade time), and the V14 initializer default of
  `.distantPast` means "covers nothing". This is a comparison floor, not a
  submission marker. It stays, but moves behind one accessor.

Complete list of uses outside the historical schema folders, from
`grep -rn --include='*.swift' "distantPast" Hugo | grep -v SchemaVersions/`
at `0af2e24`:

| File and line | Code | Action |
|---|---|---|
| `Hugo/Persistence/SubmittedReportSelection.swift:7-10` | `isReal`: `(submission.submittedAt ?? .distantPast) != .distantPast` | Replace by `SubmittedReport.isSubmitted` |
| `Hugo/Persistence/SubmittedReportSelection.swift:67-68` | `candidate.submittedAt ?? .distantPast` | Use `submittedDate` |
| `Hugo/Persistence/SubmittedReportSelection.swift:77-78` | `entriesClosedAt ?? .distantPast` | Use `entriesCutoff` |
| `Hugo/Features/Reports/Domain/ServiceMonth.swift:44` | `entriesClosedAt ?? .distantPast` | Use `entriesCutoff` |
| `Hugo/Features/Reports/Domain/ServiceMonth.swift:140` | `entriesClosedAt ?? .distantPast` | Use `entriesCutoff` |
| `Hugo/Features/Reports/Services/ReportSubmissionService.swift:38` | `firstSubmittedAt == nil \|\| firstSubmittedAt == .distantPast` | Use `firstSubmittedDate == nil` |
| `Hugo/Persistence/HugoMigrationPlan.swift:187, 276, 286` | V8 to V9 and V10 to V11 migrations | Leave. They read old-schema classes and describe what those versions stored. |

Callers of `SubmittedReportSelection.isReal` (all become `.isSubmitted`):
`Hugo/Persistence/SubmittedReportSelection.swift` (lines 57-58),
`Hugo/Features/Reports/Domain/ServiceMonth.swift` (31, 50, 139),
`Hugo/Features/Reports/State/SubmitReportFormModel.swift` (112),
`Hugo/Features/Reports/Domain/ReportReminderSchedule.swift` (43),
`Hugo/Persistence/SyncDeduplicator.swift` (106, 110, 121). No test calls `isReal`.

Readers of the raw date that show it (they sit behind `month.isSubmitted`, so
they never see the sentinel today, but they should use the new accessor):
`Hugo/Features/ServiceYear/Screens/MonthDetailView.swift:89` and
`Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift:64`, both
`month.submittedReport?.submittedAt`.

`SubmittedReportSelection.swift` lines 1 to 11 today:

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
```

and lines 55 to 83 (`shouldPrefer`):

```swift
        let candidateIsReal = isReal(candidate)
        let existingIsReal = isReal(existing)

        // A real submission always wins over a migration sentinel.
        if candidateIsReal != existingIsReal {
            return candidateIsReal
        }

        if candidateIsReal {
            // Among real submissions, retain the most recent submission.
            let candidateDate = candidate.submittedAt ?? .distantPast
            let existingDate = existing.submittedAt ?? .distantPast

            if candidateDate != existingDate {
                return candidateDate > existingDate
            }
        }

        // Among sentinels, retain the one that covers the most recently created
        // pre-existing entry.
        let candidateClosedAt = candidate.entriesClosedAt ?? .distantPast
        let existingClosedAt = existing.entriesClosedAt ?? .distantPast

        if candidateClosedAt != existingClosedAt {
            return candidateClosedAt > existingClosedAt
        }
```

`SyncDeduplicator.swift` lines 104 to 125 (inside `mergeDuplicateMonthlyReports`):

```swift
            let winnerIsReal = SubmittedReportSelection.isReal(winner)
            if winnerIsReal {
                let tied = group.contains { other in
                    other !== winner
                        && SubmittedReportSelection.isReal(other)
                        && other.submittedAt == winner.submittedAt
                        && other.entriesClosedAt == winner.entriesClosedAt
                }
                if tied { continue }
            }
```

`run()` is at lines 22 to 43 of `SyncDeduplicator.swift`; it ends with
`repairCarryEntryDates()` and a single `catch`.

`SubmittedReport` is `typealias SubmittedReport = CurrentSchema.SubmittedReport`
(`Hugo/Persistence/AppSchema.swift:165`). An `extension SubmittedReport` on the
typealias is legal and attaches to the V14 class.

Persistence has no role folders; files sit directly in `Hugo/Persistence`
(`ModelContext+IsolatedChange.swift` is the naming pattern for an extension
file).

Existing tests keep working unchanged, because the stored value of a
placeholder is still `.distantPast` until the repair runs:
`ServiceMonthTests` (placeholders built with `SubmittedReport(year:month:entriesClosedAt:)`),
`ReportReminderScheduleTests`, `ReportSubmissionServiceTests.placeholderGetsItsFirstSubmittedDate`,
and the `SchemaMigrationTests` assertions at lines 154, 155, 219, 220, 657 and
1174 that check what the historical migrations stored. Do not edit them.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint changed files | `xcrun swift-format lint --strict <files>` | exit 0, no output |
| Remaining sentinel uses | `grep -rn --include='*.swift' "distantPast" Hugo \| grep -v SchemaVersions/` | see Step 7 |
| Whole gate | `Scripts/verify.sh` | exit 0 (lint, all tests, analyze). Takes several minutes. |

Run `Scripts/verify.sh` with its full output redirected to a file under the
scratchpad directory (for example `verify-137.log`) and take the exit code from
the script itself.

## Scope

**In scope:**

- `Hugo/Persistence/SubmittedReport+Submission.swift` (create)
- `Hugo/Persistence/SubmittedReportSelection.swift`
- `Hugo/Persistence/SyncDeduplicator.swift`
- `Hugo/Features/Reports/Domain/ServiceMonth.swift`
- `Hugo/Features/Reports/Domain/ReportReminderSchedule.swift`
- `Hugo/Features/Reports/State/SubmitReportFormModel.swift`
- `Hugo/Features/Reports/Services/ReportSubmissionService.swift`
- `Hugo/Features/ServiceYear/Screens/MonthDetailView.swift`
- `Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift`
- `HugoTests/Persistence/SubmittedReportSubmissionTests.swift` (create)
- `HugoTests/Persistence/SyncDeduplicatorTests.swift`
- `HugoTests/Persistence/SchemaMigrationTests.swift`
- `plans/README.md` (status row)

**Out of scope (do NOT touch):**

- Anything under `Hugo/Persistence/SchemaVersions/`. Shipped schemas never change, including the `.distantPast` defaults in their initializers.
- `Hugo/Persistence/AppSchema.swift` and `HugoMigrationPlan.swift`. No new schema version, no new stage. The three `distantPast` mentions in `HugoMigrationPlan.swift` describe what old versions stored and stay.
- `HugoTests` assertions that read `.distantPast` from a store just migrated from an old version (`SchemaMigrationTests` lines 154, 155, 219, 220, 657, 1174). They prove what the historical migrations produce.
- `Hugo/Resources/Localizable.xcstrings`, `CONTEXT.md` (no new domain term; "Placeholder report" already exists and is the word to use in comments, not "sentinel").
- `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`: the owner's uncommitted edit. Never stage it.

## Git workflow

- Commit straight to `main`. Do not create a branch or a worktree.
- One commit after `Scripts/verify.sh` exits 0, Conventional Commits: `refactor: read the submission date through one accessor and clear stored placeholder dates`.
- Stage by explicit path only (the files in "In scope" that changed, never `plans/`). Never `git add -A` or `git add .`. Do not push.

## Steps

### Step 1: Create the single place that interprets the sentinel

Create `Hugo/Persistence/SubmittedReport+Submission.swift`:

```swift
import Foundation

/// The one place that knows a placeholder report can store its submission
/// dates as `nil` or as `Date.distantPast`. Older data, and the initializer
/// default of every schema version, use `.distantPast`; `SyncDeduplicator`
/// rewrites stored values to `nil`, but a device on an older build can still
/// sync an unrewritten one in. Read the dates through these properties and
/// never compare a stored date with `.distantPast` anywhere else.
extension SubmittedReport {
    /// When the report was last sent, or nil for a placeholder report.
    var submittedDate: Date? {
        Self.sent(submittedAt)
    }

    /// When the month was first sent, or nil for a placeholder report.
    var firstSubmittedDate: Date? {
        Self.sent(firstSubmittedAt)
    }

    /// False for a placeholder report: a saved report for a month that was
    /// never sent, which the V8 to V9 upgrade created.
    var isSubmitted: Bool {
        submittedDate != nil
    }

    /// Entries created after this moment are unreported. This is a comparison
    /// floor, not a submission marker: a report with no recorded cutoff covers
    /// no entries, so every entry is newer than `.distantPast`.
    var entriesCutoff: Date {
        entriesClosedAt ?? .distantPast
    }

    private static func sent(_ date: Date?) -> Date? {
        guard let date, date != .distantPast else { return nil }
        return date
    }
}
```

**Verify**: `xcrun swift-format lint --strict Hugo/Persistence/SubmittedReport+Submission.swift` exits 0.

### Step 2: Use it in `SubmittedReportSelection`

In `Hugo/Persistence/SubmittedReportSelection.swift`:

1. Delete the `isReal` function and its two-line doc comment (lines 7 to 11, plus the blank line after).
2. In `shouldPrefer`, replace lines 55 to 83 (everything from `let candidateIsReal = isReal(candidate)` through the closing brace of `if candidateClosedAt != existingClosedAt { ... }`) with:

```swift
        let candidateIsSubmitted = candidate.isSubmitted
        let existingIsSubmitted = existing.isSubmitted

        // A submitted report always wins over a placeholder report.
        if candidateIsSubmitted != existingIsSubmitted {
            return candidateIsSubmitted
        }

        if let candidateDate = candidate.submittedDate,
            let existingDate = existing.submittedDate,
            candidateDate != existingDate
        {
            // Among submitted reports, retain the most recent submission.
            return candidateDate > existingDate
        }

        // Among placeholders, retain the one that covers the most recently
        // created pre-existing entry.
        if candidate.entriesCutoff != existing.entriesCutoff {
            return candidate.entriesCutoff > existing.entriesCutoff
        }
```

Keep the final `// Equal records are semantically equivalent for this purpose.` and `return false` exactly as they are. Also change the doc comment on the type only if it still says "real" (it does not; leave it).

**Verify**: `grep -n "isReal\|distantPast" Hugo/Persistence/SubmittedReportSelection.swift` prints nothing.

### Step 3: Update `SyncDeduplicator` and add the repair

In `Hugo/Persistence/SyncDeduplicator.swift`:

1. In `mergeDuplicateMonthlyReports`, replace the block at lines 104 to 114 (from `let winnerIsReal` through the closing brace of `if winnerIsReal { ... }`) with:

```swift
            let winnerIsSubmitted = winner.isSubmitted
            if winnerIsSubmitted {
                let tied = group.contains { other in
                    other !== winner
                        && other.isSubmitted
                        && other.submittedDate == winner.submittedDate
                        && other.entriesCutoff == winner.entriesCutoff
                }
                if tied { continue }
            }
```

   Using `entriesCutoff` (not the raw field) means two submitted rows whose cutoff is `nil` on one and `.distantPast` on the other now count as tied, so neither is deleted. That is the conservative choice and matches the file's own rule that rows that cannot be ordered safely are kept.

2. In the next block, replace `if winnerIsReal, winner.reportingLines.isEmpty,` with `if winnerIsSubmitted, winner.reportingLines.isEmpty,` and `!SubmittedReportSelection.isReal($0) && !$0.reportingLines.isEmpty` with `!$0.isSubmitted && !$0.reportingLines.isEmpty`.

3. Add this method directly after `mergeDuplicateMonthlyReports` (before the `/// Collapses carried-in entries` doc comment):

```swift
    /// Rewrites the earliest-possible placeholder dates that the V8 to V9
    /// upgrade (and every schema initializer's default) stored in
    /// `submittedAt` and `firstSubmittedAt` to `nil`. Readers already treat both
    /// the same through `SubmittedReport.submittedDate`; this only makes the
    /// stored data match. It never changes which row survives a merge, so it
    /// needs no tie-break. Returns the number of rewritten reports. Safe to call
    /// often: a second call finds nothing.
    @discardableResult
    func normalizePlaceholderReports() throws -> Int {
        let reports = try context.fetch(FetchDescriptor<SubmittedReport>())
        var rewritten = 0
        for report in reports {
            var changed = false
            if report.submittedAt == .distantPast {
                report.submittedAt = nil
                changed = true
            }
            if report.firstSubmittedAt == .distantPast {
                report.firstSubmittedAt = nil
                changed = true
            }
            if changed { rewritten += 1 }
        }
        if rewritten > 0 { try context.save() }
        return rewritten
    }
```

4. In `run()`, add after the `repairedCarries` block (the last `if repairedCarries > 0 { ... }`), still inside the `do`:

```swift
            let normalizedReports = try normalizePlaceholderReports()
            if normalizedReports > 0 {
                Self.logger.info("Cleared the stored dates of \(normalizedReports) placeholder reports")
            }
```

Do not touch `entriesClosedAt` in the repair: its `.distantPast` means "covers nothing" and is read through `entriesCutoff`.

**Verify**:
- `grep -n "isReal" Hugo/Persistence/SyncDeduplicator.swift` prints nothing.
- `xcrun swift-format lint --strict Hugo/Persistence/SyncDeduplicator.swift Hugo/Persistence/SubmittedReportSelection.swift` exits 0.

### Step 4: Update the Reports feature

1. `Hugo/Features/Reports/Domain/ServiceMonth.swift`:
   - Line 31: `submittedReport.map(SubmittedReportSelection.isReal) ?? false` becomes `submittedReport?.isSubmitted ?? false`.
   - Line 44: `return entry.createdAt > (submittedReport.entriesClosedAt ?? .distantPast)` becomes `return entry.createdAt > submittedReport.entriesCutoff`.
   - Line 50: `if let submission = submittedReport, SubmittedReportSelection.isReal(submission) {` becomes `if let submission = submittedReport, submission.isSubmitted {`.
   - Line 139: `guard let report, SubmittedReportSelection.isReal(report) else { return nil }` becomes `guard let report, report.isSubmitted else { return nil }`.
   - Line 140: `let cutoff = report.entriesClosedAt ?? .distantPast` becomes `let cutoff = report.entriesCutoff`.
2. `Hugo/Features/Reports/Domain/ReportReminderSchedule.swift` line 43: `return SubmittedReportSelection.isReal(submission) ? nil : due` becomes `return submission.isSubmitted ? nil : due`.
3. `Hugo/Features/Reports/State/SubmitReportFormModel.swift` line 112: `guard let nextReport = submissionsByMonth[next], SubmittedReportSelection.isReal(nextReport)` becomes `guard let nextReport = submissionsByMonth[next], nextReport.isSubmitted`.
4. `Hugo/Features/Reports/Services/ReportSubmissionService.swift` line 38: `if existing.firstSubmittedAt == nil || existing.firstSubmittedAt == .distantPast {` becomes `if existing.firstSubmittedDate == nil {`.

**Verify**:
- `grep -rn --include='*.swift' "isReal" Hugo HugoTests` prints nothing.
- `xcrun swift-format lint --strict` on the four files above exits 0.

### Step 5: Read the date through the accessor in the two display views

1. `Hugo/Features/ServiceYear/Screens/MonthDetailView.swift` line 89: replace `if month.isSubmitted, let submittedAt = month.submittedReport?.submittedAt {` with `if let submittedAt = month.submittedReport?.submittedDate {`. The next lines (`Text("report.status.submitted.\(submittedAt.formatted(...))")`) stay as they are.
2. `Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift` line 64: replace `if month.isSubmitted, let submittedAt = month.submittedReport?.submittedAt {` with `if let submittedAt = month.submittedReport?.submittedDate {`.

`month.submittedReport` is the canonical report, and `submittedDate` is nil exactly when `isSubmitted` is false, so behavior does not change.

**Verify**: `grep -rn --include='*.swift' "\.submittedAt" Hugo | grep -v SchemaVersions/` prints only lines in `SubmittedReport+Submission.swift`, `SyncDeduplicator.swift` (the repair, plus its `submittedAt` use if any remains), `ReportSubmissionService.swift` (the writes `existing.submittedAt = now`) and `HugoMigrationPlan.swift`. No display or comparison reads the raw field.

### Step 6: Tests

**6a. New file `HugoTests/Persistence/SubmittedReportSubmissionTests.swift`** (mirrors `Hugo/Persistence`):

```swift
import Foundation
import Testing

@testable import Hugo

@MainActor
struct SubmittedReportSubmissionTests {
    private let sent = Date(timeIntervalSince1970: 1_000)

    @Test
    func backfilledPlaceholderIsNotSubmitted() {
        // The initializer default, and what the V8 to V9 upgrade stored.
        let report = SubmittedReport(year: 2026, month: 6, entriesClosedAt: sent)

        #expect(report.submittedAt == .distantPast)
        #expect(!report.isSubmitted)
        #expect(report.submittedDate == nil)
        #expect(report.firstSubmittedDate == nil)
    }

    @Test
    func reportWithNilDatesIsNotSubmitted() {
        let report = SubmittedReport(year: 2026, month: 6)
        report.submittedAt = nil
        report.firstSubmittedAt = nil

        #expect(!report.isSubmitted)
        #expect(report.submittedDate == nil)
        #expect(report.firstSubmittedDate == nil)
    }

    @Test
    func genuinelySubmittedReportExposesItsDates() {
        let first = Date(timeIntervalSince1970: 500)
        let report = SubmittedReport(year: 2026, month: 6, firstSubmittedAt: first, submittedAt: sent)

        #expect(report.isSubmitted)
        #expect(report.submittedDate == sent)
        #expect(report.firstSubmittedDate == first)
    }

    @Test
    func missingCutoffCoversNoEntries() {
        let withDefault = SubmittedReport(year: 2026, month: 6)
        let withNil = SubmittedReport(year: 2026, month: 6)
        withNil.entriesClosedAt = nil
        let withDate = SubmittedReport(year: 2026, month: 6, entriesClosedAt: sent)

        #expect(withDefault.entriesCutoff == .distantPast)
        #expect(withNil.entriesCutoff == .distantPast)
        #expect(withDate.entriesCutoff == sent)
    }
}
```

**6b. `HugoTests/Persistence/SyncDeduplicatorTests.swift`**: insert these tests immediately before the line `    @Test` that precedes `func realSubmissionReplacesPlaceholder()` (use the existing `makeContext()`, `makeReport(...)`, `early` and `late` helpers):

```swift
    @Test
    func normalizingClearsPlaceholderDatesAndKeepsSubmittedOnes() throws {
        let context = try makeContext()
        let placeholder = makeReport(month: 5, submittedAt: .distantPast, entriesClosedAt: early, in: context)
        placeholder.firstSubmittedAt = .distantPast
        let nilDates = makeReport(month: 6, submittedAt: early, in: context)
        nilDates.submittedAt = nil
        nilDates.firstSubmittedAt = nil
        let submitted = makeReport(month: 7, submittedAt: late, entriesClosedAt: late, in: context)
        submitted.firstSubmittedAt = early
        try context.save()

        let rewritten = try SyncDeduplicator(context: context).normalizePlaceholderReports()

        #expect(rewritten == 1)
        #expect(placeholder.submittedAt == nil)
        #expect(placeholder.firstSubmittedAt == nil)
        #expect(placeholder.entriesClosedAt == early)
        #expect(!placeholder.isSubmitted)
        #expect(nilDates.submittedAt == nil)
        #expect(!nilDates.isSubmitted)
        #expect(submitted.submittedAt == late)
        #expect(submitted.firstSubmittedAt == early)
        #expect(submitted.isSubmitted)
    }

    @Test
    func normalizingPlaceholderDatesIsIdempotent() throws {
        let context = try makeContext()
        _ = makeReport(submittedAt: .distantPast, in: context)
        try context.save()
        let deduplicator = SyncDeduplicator(context: context)

        #expect(try deduplicator.normalizePlaceholderReports() == 1)
        #expect(try deduplicator.normalizePlaceholderReports() == 0)
    }

    @Test
    func submittedReportStillWinsOverANormalizedPlaceholder() throws {
        let context = try makeContext()
        let placeholder = makeReport(submittedAt: .distantPast, in: context)
        _ = makeReport(submittedAt: early, in: context)
        try context.save()
        try SyncDeduplicator(context: context).normalizePlaceholderReports()

        let removed = try SyncDeduplicator(context: context).mergeDuplicateMonthlyReports()

        let reports = try context.fetch(FetchDescriptor<SubmittedReport>())
        #expect(removed == 1)
        #expect(reports.count == 1)
        #expect(reports.first?.submittedDate == early)
        #expect(reports.first !== placeholder)
    }
```

Check the helper's actual parameter order in the file before pasting
(`makeReport(month:submittedAt:entriesClosedAt:lines:in:)`, line 159 to 168).

**6c. `HugoTests/Persistence/SchemaMigrationTests.swift`**: add this test right after `currentStoreRoundTripsSchoolCreditsAndReportCreditHours()`. It proves the rewrite survives a real store round trip and that no schema version is involved (it uses `makeCurrentStore`, the same helper as the V14 test):

```swift
    @Test
    func clearedPlaceholderDatesSurviveReopeningTheStore() throws {
        let store = try TemporaryStore()
        defer { store.remove() }
        let closedAt = Date(timeIntervalSince1970: 3_000)
        let sentAt = Date(timeIntervalSince1970: 20_000)

        let container = try makeCurrentStore(at: store.storeURL)
        let context = container.mainContext
        context.insert(SubmittedReport(year: 2026, month: 5, entriesClosedAt: closedAt))
        context.insert(
            SubmittedReport(
                year: 2026, month: 6, firstSubmittedAt: sentAt, submittedAt: sentAt, entriesClosedAt: closedAt))
        try context.save()
        #expect(try SyncDeduplicator(context: context).normalizePlaceholderReports() == 1)

        let reopened = try makeCurrentStore(at: store.storeURL)
        let reports = try reopened.mainContext.fetch(FetchDescriptor<SubmittedReport>())
        let placeholder = try #require(reports.first { $0.month == 5 })
        let submitted = try #require(reports.first { $0.month == 6 })

        #expect(placeholder.submittedAt == nil)
        #expect(placeholder.firstSubmittedAt == nil)
        #expect(placeholder.entriesClosedAt == closedAt)
        #expect(!placeholder.isSubmitted)
        #expect(submitted.submittedAt == sentAt)
        #expect(submitted.isSubmitted)
    }
```

**Verify**: `xcrun swift-format lint --strict HugoTests/Persistence/SubmittedReportSubmissionTests.swift HugoTests/Persistence/SyncDeduplicatorTests.swift HugoTests/Persistence/SchemaMigrationTests.swift` exits 0.

### Step 7: Confirm no sentinel use is left, run the gate, commit

1. `grep -rn --include='*.swift' "distantPast" Hugo | grep -v SchemaVersions/` must show only:
   - `Hugo/Persistence/SubmittedReport+Submission.swift` (the `date != .distantPast` check and the `entriesCutoff` floor),
   - `Hugo/Persistence/SyncDeduplicator.swift` (the two `== .distantPast` checks in `normalizePlaceholderReports`),
   - `Hugo/Persistence/HugoMigrationPlan.swift` lines 187, 276 and 286 (historical migrations).
   Anything else: STOP.
2. Run `Scripts/verify.sh` (redirect to a log in the scratchpad).
3. Stage the changed source and test files by explicit path and commit with the message from "Git workflow". Do not stage `plans/` or the `.xcscheme`.

**Verify**: exit code 0, and the log contains `** TEST SUCCEEDED **` and `** ANALYZE SUCCEEDED **`.

## Test plan

- **Backfilled placeholder** (stored `.distantPast`): `backfilledPlaceholderIsNotSubmitted`, and the placeholder cases in `normalizingClearsPlaceholderDatesAndKeepsSubmittedOnes`.
- **Nil record**: `reportWithNilDatesIsNotSubmitted`, and the `nilDates` report in the normalize test.
- **Genuinely submitted record**: `genuinelySubmittedReportExposesItsDates`, and `submitted` in the normalize test, which must come out unchanged.
- **Stored-value rewrite**: idempotence, merge order unchanged (a submitted report still beats a normalized placeholder), and survival across a real SQLite store reopen in `SchemaMigrationTests`.
- Existing coverage that must keep passing without edits: `ServiceMonthTests`, `ReportReminderScheduleTests`, `ReportSubmissionServiceTests.placeholderGetsItsFirstSubmittedDate`, `TheocraticYearReportBuilderTests` (sentinel cases), `SyncDeduplicatorTests`, the `SchemaMigrationTests` history tests.
- No test counts view renders; the two display-view edits are covered by the unchanged `ServiceMonth` behavior. Say so in NOTES.

## Risk to already-synced data

This is the one part of the plan that touches user data on every device, so
read it before executing:

1. **What is rewritten.** Only `submittedAt` and `firstSubmittedAt` values that
   equal `Date.distantPast`, only on `SubmittedReport` rows, set to `nil`. Real
   dates, `entriesClosedAt`, reporting lines and every other model are not
   touched.
2. **Sync traffic.** Each rewritten row is a normal SwiftData save, so CloudKit
   exports it once and other devices import a `nil`. Only placeholders are
   affected (months with entries from before V9 that were never sent), so the
   count is small. After import the repair finds nothing to do, so devices do not
   ping-pong.
3. **Devices on the previous build** read `nil` and `.distantPast` identically
   (`?? .distantPast`; `ReportSubmissionService` checks both), and the previous
   build never writes `.distantPast` from production code. If such a device
   re-submits a placeholder month, it writes a real date, which wins like any
   other edit. A V8-era store upgraded later on any device recreates sentinels;
   the next launch of a current build rewrites them again.
4. **Conflict risk.** Two devices rewriting the same field to the same value
   (`nil`) converge. A device submitting at the same moment as another device
   rewrites the placeholder is a normal last-writer-wins edit of the same row,
   the same exposure that already exists today; the submitted date is a later,
   real value and the repair never touches a value other than `.distantPast`.
5. **Merge choice.** The repair does not choose a surviving row, so it does not
   fall under the `SyncDeduplicator` rule about synced attributes. The one merge
   change (`entriesCutoff` in the tie check) can only turn a delete into a keep,
   never the reverse.
6. **Rollback.** If this change is reverted, stored `nil` values are still read
   correctly by the old code. Nothing in the store needs undoing.

**CloudKit deploy note for the owner: none.** No model, attribute or record type
is added, removed or changed, so nothing needs to be created in the CloudKit
Development schema or deployed to Production for this build. The `CD_submittedAt`
and `CD_firstSubmittedAt` fields already exist in Production. (Contrast plan
124, where `CD_SchoolCredit` had to be deployed first.)

## Done criteria

- [ ] `Scripts/verify.sh` exits 0.
- [ ] `grep -rn --include='*.swift' "isReal" Hugo HugoTests` prints nothing.
- [ ] The `distantPast` grep in Step 7 shows only the three allowed files.
- [ ] `git diff --stat HEAD~1 -- Hugo/Persistence/SchemaVersions Hugo/Persistence/AppSchema.swift Hugo/Persistence/HugoMigrationPlan.swift` prints nothing.
- [ ] The commit contains only files from "In scope" (no `plans/`, no `.xcscheme`).
- [ ] `plans/README.md` status row updated (unless the reviewer maintains it).

## STOP conditions

Stop and report back (do not improvise) if:

- Any excerpt in "Current state" does not match, in particular if `submittedAt` or `firstSubmittedAt` is no longer optional in `SubmittedReportV14.swift`, or a V15 schema already exists in `AppSchema.swift`.
- `extension SubmittedReport` on the typealias does not compile. Do not move the properties into the V14 class (a shipped schema file); report instead.
- The Step 7 grep shows a use of `distantPast` not listed in "Current state".
- A step's verification fails twice.
- Any existing test outside the new ones fails and the fix would mean editing a shipped schema file or an assertion listed as out of scope.
- The change appears to need a new schema version, a CloudKit schema change, or any file outside the scope list.

## Maintenance notes

- Do not add a new `?? .distantPast` or `== .distantPast` for a report date anywhere. Use `isSubmitted`, `submittedDate`, `firstSubmittedDate` and `entriesCutoff`. A grep for `distantPast` outside `SchemaVersions/` and `HugoMigrationPlan.swift` should only ever show `SubmittedReport+Submission.swift` and the repair in `SyncDeduplicator`.
- The `.distantPast` defaults in the shipped initializers (V9 to V14) stay forever. When a future schema version has to copy `SubmittedReport` anyway, change that version's initializer defaults to `nil` and keep the accessor and the repair until no store can contain the old value; removing them earlier would resurrect the bug.
- `entriesClosedAt` is deliberately not rewritten: a missing cutoff and `.distantPast` both mean "covers no entry", and `entriesCutoff` is the only reader. If a later change gives it a stricter meaning, revisit this.
- A reviewer should check, on a device with a real store, that months with entries from before V9 still show "not submitted" and still show the reminder, and that a submitted month still shows its date in the Year list and month detail.
