# Plan 044: Merge duplicate monthly reports and carried-in entries created by sync

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 3f8d48b..HEAD -- Hugo/Persistence/HugoMigrationPlan.swift Hugo/Features/Overview/OverviewView.swift Hugo/Features/ServiceYear/TheocraticYearReportBuilder.swift Hugo/Features/Reports/Domain/ReportingLineCalculator.swift`
> Plan 040 changes `ReportingLineCalculator.swift` (category resolution only),
> and plan 041 creates `Hugo/Persistence/SyncDeduplicator.swift`. Those are
> expected. Any other change to an in-scope file is a mismatch: compare
> against the excerpts below and STOP if they differ.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/041-seed-once-and-merge-duplicate-categories.md (extends its `SyncDeduplicator`)
- **Category**: bug
- **Planned at**: commit `3f8d48b`, 2026-10-12

## Why this matters

When a user transfers leftover minutes to the next month, Hugo creates a "carried-in" entry dated the 1st of that month. Two paths create the same carried-in entry more than once when the user has two devices (for example iPhone and iPad) syncing through CloudKit:

1. The V10→V11 schema migration runs separately on each device. Each device inserts its own carried-in entry for every past report that transferred minutes, and sync then delivers both copies to both devices.
2. Two devices can each submit the same month before sync catches up (the second device still shows the reminder). Each submission creates its own report row and its own carried-in entry.

`ReportingLineCalculator` adds every carried-in entry to the next month's total, so that month's report shows the carried minutes twice and the user sends the overseer too many hours. Re-submitting the source month cleans up only the entries attached to one of the duplicate reports. Separately, the Overview reminder card looks up the due month's report with `first(where:)` instead of the existing canonical-report rule, so a leftover "never submitted" placeholder row can keep the reminder visible after the user has submitted. Finally, the V10→V11 migration attaches report lines to whichever row for the month it finds first, which can be such a placeholder instead of the real submission.

After this plan, the merge pass from plan 041 also collapses duplicate report rows and duplicate carried-in entries, the reminder uses the canonical report, and the migration picks the real submission.

## Current state

### Vocabulary

- **Submission / report**: a `SubmittedReport` row for one calendar month (`year`, `month`).
- **Placeholder ("sentinel")**: a `SubmittedReport` with `submittedAt == .distantPast`. The V8→V9 migration inserted one per month that had entries, on each device. It means "never submitted" and is treated exactly like having no report (`ReportReminderSchedule.swift:50`, `TheocraticYearMonth.isSubmitted`).
- **Real submission**: `submittedAt != .distantPast`.
- **Carried-in entry**: an `Entry` with `sourceReportYear`, `sourceReportMonth` and `sourceReportingLineID` set (`""` for the Field Service line, the category name for a separate line), `tracker == nil`, a `storedTracker` snapshot, and `sourceSubmission` pointing at the report that transferred it.

### Model fields (`Hugo/Persistence/SchemaVersions/V11/`; do not edit these files)

```swift
// EntryV11.swift
@Relationship var tracker: Tracker?
var storedTracker: EntryTracker? = nil
@Relationship var sourceSubmission: SubmittedReport?
var sourceReportingLineID: String?
var sourceReportYear: Int?
var sourceReportMonth: Int?
init(date: Date, duration: TimeInterval, tracker: Tracker?, bibleStudies: Int? = nil,
     source: (submission: SubmittedReport, lineID: String)? = nil)
// The init copies source.submission.year/month into sourceReportYear/Month.

// SubmittedReportV11.swift
var year: Int?
var month: Int?
var submittedAt: Date?
var entriesClosedAt: Date?
var reportingLines: [SubmittedReportingLine] = []
@Relationship(deleteRule: .nullify, inverse: \Entry.sourceSubmission) var generatedEntries: [Entry]? = []
```

### Canonical report choice (reuse; do not reimplement)

`Hugo/Features/ServiceYear/TheocraticYearReportBuilder.swift:74-156` provides `static func canonicalSubmission(for month: YearMonth, in submissions: [SubmittedReport]) -> SubmittedReport?` and `canonicalSubmissionsByMonth(_:)`. Rules: rows with invalid year/month are ignored; a real submission beats a placeholder; among real ones the latest `submittedAt` wins; then the latest `entriesClosedAt`; on a full tie the first row seen is kept. The private `isRealSubmission` is `(submission.submittedAt ?? .distantPast) != .distantPast`.

### Where carried-in entries are summed

`Hugo/Features/Reports/Domain/ReportingLineCalculator.swift:27-49`: every entry with `sourceReportYear`/`sourceReportMonth` adds to `carriedInSeconds` of its line. There is no de-duplication.

### The Overview reminder

`Hugo/Features/Overview/OverviewView.swift:26-35`:

```swift
/// The month whose report reminder should show, if any: a month is due
/// (per `ReportReminderSchedule`) and has no real submission. Backfill
/// sentinels (`submittedAt == .distantPast`) count as unsubmitted.
private var reminderMonth: YearMonth? {
    guard let due = ReportReminderSchedule.dueMonth(now: .now, calendar: .current) else { return nil }
    guard let submission = submissions.first(where: { $0.year == due.year && $0.month == due.month }) else {
        return due
    }
    return (submission.submittedAt ?? .distantPast) == .distantPast ? due : nil
}
```

### The V10→V11 migration lookup

`Hugo/Persistence/HugoMigrationPlan.swift:280-290`:

```swift
didMigrate: { context in
    let reports = try context.fetch(FetchDescriptor<SchemaV11.SubmittedReport>())

    for legacyReport in legacyReports {
        guard legacyReport.submittedAt != .distantPast else { continue }

        guard
            let report = reports.first(where: {
                $0.year == legacyReport.year && $0.month == legacyReport.month
            })
        else { continue }
```

`legacyReport.submittedAt` is the real submission's `submittedAt`, captured before the migration. This stage has already shipped. Changing its closure is allowed (stages are identified by their schema versions), and it only affects stores that have not migrated yet.

### `SyncDeduplicator` after plan 041

`Hugo/Persistence/SyncDeduplicator.swift` is a `@MainActor struct` holding a `ModelContext`. It has `func run()` (calls each merge, logs the count, logs errors) and `@discardableResult func mergeDuplicateCategories() throws -> Int`. The app calls `run()` at launch, when the scene becomes active, and after each CloudKit import. Its documented rule: every merge must pick its survivor from synced attributes only, and must not delete when it cannot tell copies apart.

### Test conventions

Swift Testing, `@MainActor struct`, `InMemoryModelContainer.make()` plus `ModelContext(container)`. Migration tests build an old-version store at a temporary URL with `makeV10Store(at:submissions:)`, then open it with `makeCurrentStore(at:)` (both private helpers in `HugoTests/Persistence/SchemaMigrationTests.swift:1052-1100`). Exemplar migration test: `migratingV10StoreWithCarryOutCreatesOneGeneratedEntryOnMainLine` (`SchemaMigrationTests.swift:512-573`).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/SyncDeduplicatorTests -only-testing:HugoTests/SchemaMigrationTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:

- `Hugo/Persistence/SyncDeduplicator.swift`
- `Hugo/Persistence/HugoMigrationPlan.swift` (the `migrateV10toV11` report lookup only)
- `Hugo/Features/Overview/OverviewView.swift` (`reminderMonth` only)
- `Hugo/Features/ServiceYear/TheocraticYearReportBuilder.swift` (only to make `isRealSubmission` non-private, if you need it)
- `HugoTests/Persistence/SyncDeduplicatorTests.swift`
- `HugoTests/Persistence/SchemaMigrationTests.swift` (one new test)
- `plans/README.md` (status row)

**Out of scope**:

- `ReportingLineCalculator.swift`. Do not add read-time de-duplication; the merge removes the duplicates.
- `SubmitReportFormModel.swift` (`reconcileGeneratedEntries`). It keeps working on the canonical report's own entries.
- Any `SchemaVersions/**` file. No schema change.
- Detecting edits made after submission, or warning when re-submitting a month whose next month was already submitted. Those are separate, unplanned findings.

## Git workflow

- Branch: `advisor/044-merge-reports-and-carries`
- Commit message style: short imperative sentence, for example `Merge duplicate monthly reports after sync`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Use the canonical report for the Overview reminder

Replace the body of `reminderMonth` in `OverviewView.swift`:

```swift
private var reminderMonth: YearMonth? {
    guard let due = ReportReminderSchedule.dueMonth(now: .now, calendar: .current) else { return nil }
    guard let submission = TheocraticYearReportBuilder.canonicalSubmission(for: due, in: submissions) else {
        return due
    }
    return (submission.submittedAt ?? .distantPast) == .distantPast ? due : nil
}
```

**Verify**: `grep -n 'submissions.first' Hugo/Features/Overview/OverviewView.swift` → no matches. Lint exits 0.

Commit: `Use the canonical report for the Overview reminder`.

### Step 2: Make the migration attach lines to the real submission

In `migrateV10toV11.didMigrate`, replace the `guard let report = reports.first(where: ...)` block with:

```swift
let sameMonth = reports.filter {
    $0.year == legacyReport.year && $0.month == legacyReport.month
}
guard
    let report = sameMonth.first(where: { $0.submittedAt == legacyReport.submittedAt })
        ?? sameMonth.first
else { continue }
```

Add a test to `SchemaMigrationTests.swift`, modelled on `migratingV10StoreWithCarryOutCreatesOneGeneratedEntryOnMainLine`:

- `migratingV10StoreAttachesLinesToRealSubmissionNotSentinel`: a V10 store with two reports for 2026-08, the placeholder inserted first (`submittedAt: .distantPast`, no categories) and then the real one (`submittedAt: Date(timeIntervalSince1970: 20_000)`, one main category of 7 200 s / 2 h, `carriedOutSeconds: 1_200`). After opening with `makeCurrentStore`: the report with `submittedAt == Date(timeIntervalSince1970: 20_000)` has a non-empty `reportingLines`; the placeholder has empty `reportingLines`; exactly one `Entry` exists, and its `sourceSubmission` is the real report.

Note: SwiftData does not guarantee fetch order, so this test may also pass without the fix. It still pins the intended behavior.

**Verify**: focused-tests command → `** TEST SUCCEEDED **`.

Commit: `Attach migrated report lines to the real submission`.

### Step 3: Merge duplicate report rows

Add `@discardableResult func mergeDuplicateMonthlyReports() throws -> Int` to `SyncDeduplicator`:

1. Fetch all `SubmittedReport` rows. Group them by `YearMonth(year:month:)`, skipping rows whose `year` is nil or not positive, or whose `month` is nil or not in `1...12`. Skip groups with one row.
2. For each group, pick `winner = TheocraticYearReportBuilder.canonicalSubmission(for: month, in: group)`.
3. Safety check: if the winner is a real submission and another real row in the group has the same `submittedAt` and the same `entriesClosedAt`, skip the whole group. The rows cannot be ordered safely. Placeholders that tie are fine to delete: if two devices each delete a different one, the month simply has no placeholder, which means the same thing.
4. Repair misplaced lines: if the winner is real and `winner.reportingLines.isEmpty`, and a placeholder in the group has non-empty `reportingLines`, set `winner.reportingLines` to that placeholder's lines. (The pre-fix V10→V11 migration could attach a real report's lines to a placeholder.)
5. For each other row: move its carried-in entries with `for entry in Array(loser.generatedEntries ?? []) { entry.sourceSubmission = winner }`, then `context.delete(loser)`, and count it.
6. Save if anything changed; return the count.

Call it from `run()` after `mergeDuplicateCategories()`, logging the count the same way.

**Verify**: lint exits 0; it compiles.

### Step 4: Merge duplicate carried-in entries

Add `@discardableResult func mergeDuplicateCarryEntries() throws -> Int`:

1. Fetch carried-in entries: `FetchDescriptor<Entry>(predicate: #Predicate { $0.sourceReportYear != nil && $0.sourceReportMonth != nil })`.
2. Group them by the key `(sourceReportYear!, sourceReportMonth!, sourceReportingLineID ?? "")`. Skip groups with one entry.
3. Fetch all `SubmittedReport` rows once and compute `canonical = TheocraticYearReportBuilder.canonicalSubmissionsByMonth(reports)`.
4. For each group, choose the **template** entry, deterministically and from synced values only:
   - first, entries whose `sourceSubmission` is the canonical report for the source month (`=== canonical[YearMonth(year:month:)]`);
   - then the latest `createdAt` (the latest re-submission);
   - then the larger `duration`;
   - then the earlier `date`.
5. Delete **every** entry in the group, then insert **one** new entry copying the template:

   ```swift
   let replacement: Entry
   if let report = canonical[sourceMonth] {
       replacement = Entry(date: template.date, duration: template.duration, tracker: nil,
                           source: (submission: report, lineID: lineID))
   } else {
       replacement = Entry(date: template.date, duration: template.duration, tracker: nil)
       replacement.sourceReportYear = sourceMonth.year
       replacement.sourceReportMonth = sourceMonth.month
       replacement.sourceReportingLineID = lineID
   }
   replacement.storedTracker = template.storedTracker
   replacement.createdAt = template.createdAt
   context.insert(replacement)
   ```

   Why delete all and insert one, instead of keeping one: copies made by the migration on two devices are identical in every synced field (same date, duration and `createdAt`). If each device kept "its" copy and deleted the other, sync would delete both and the carried minutes would be lost. Deleting all and inserting one always leaves at least one entry on every device; if two devices race, the next run collapses the leftovers again.
   Copying `createdAt` from the template keeps the receiving month's "added after submission" check unchanged.
6. Count the removed entries as `group.count - 1`. Save if anything changed; return the total.

Call it from `run()` after `mergeDuplicateMonthlyReports()` (reports first, so carried-in entries end up linked to the surviving report).

**Verify**: lint exits 0; it compiles.

### Step 5: Tests

Add to `HugoTests/Persistence/SyncDeduplicatorTests.swift` (create rows in an in-memory container; dates via `Date(timeIntervalSince1970:)`):

Reports:

1. `realSubmissionReplacesPlaceholder`: placeholder and real report for 2026-06. After `mergeDuplicateMonthlyReports()`: returns 1; one report remains, and it is the real one.
2. `latestRealSubmissionWinsAndKeepsCarryEntries`: two real reports for 2026-06 (`submittedAt` 1 000 and 2 000). A carried-in entry is linked to the older one. After merging: one report remains (`submittedAt` 2 000) and the entry's `sourceSubmission` is that report.
3. `linesMoveFromPlaceholderToRealReport`: real report with empty `reportingLines`, placeholder for the same month with one main line (`submittedHours: 2`). After merging: the real report has that line.
4. `identicalRealReportsAreKept`: two real reports with equal `submittedAt` and `entriesClosedAt`. Returns 0; both remain.
5. `differentMonthsAreUntouched`.

Carried-in entries:

6. `identicalCarryEntriesCollapseToOne`: a real report for 2026-06 and two entries created with `source: (submission: report, lineID: "")`, 1 800 s each, dated 2026-07-01, equal `createdAt`. After `mergeDuplicateCarryEntries()`: returns 1; one carried-in entry remains with duration 1 800, `sourceReportingLineID == ""`, linked to the report. `ReportingLineCalculator.lines(from:)` on the remaining July entries reports `carriedInSeconds == 1_800` for the main line.
7. `differentLinesAreKept`: one carried-in entry for line `""` and one for line `"Bethel"` from the same report. Returns 0.
8. `entryLinkedToCanonicalReportIsTheTemplate`: two reports for 2026-06 (older and newer real) and two carried-in entries for line `""` with durations 1 200 (linked to the older) and 1 800 (linked to the newer). Returns 1; the remaining entry has duration 1 800.
9. `ordinaryEntriesAreUntouched`: entries without source fields are never deleted.
10. `runIsIdempotent`: build the duplicates of tests 1 and 6, call `run()` twice; the second pass changes nothing (counts via direct calls return 0).

**Verify**: focused-tests command → `** TEST SUCCEEDED **`; then `Scripts/verify.sh` → exit 0.

Commit steps 3-5: `Merge duplicate monthly reports and carried-in entries after sync`.

### Step 6 [owner]: Check on two devices

1. On two devices with the same iCloud account, both on this build: turn on Airplane Mode on device B. On A, submit last month with "Transfer". On B, submit the same month with "Transfer". Turn Airplane Mode off on B and wait for sync.
2. Expected: after both apps return to the foreground, next month shows one carried-in entry (Overview "Carried in" pill and the submit screen's "transferred from" line), and the Year tab shows one submission for that month.
3. Watch Console (subsystem `com.ordellnielsen.Hugo`, category `Sync`) for repeated merges. If the carried-in merge keeps firing on every import for more than a minute, report it: that is the race described in Step 4.

## Test plan

- `SchemaMigrationTests`: 1 new test (Step 2).
- `SyncDeduplicatorTests`: 10 new tests (Step 5).
- Existing `TheocraticYearReportBuilderTests.duplicateSubmissionsDoNotCrashAndLatestRealSubmissionWins` and the `SubmitReportFormModelTests` must keep passing.

## Done criteria

- [ ] `grep -n 'submissions.first' Hugo/Features/Overview/OverviewView.swift` prints nothing
- [ ] `grep -n 'mergeDuplicateMonthlyReports\|mergeDuplicateCarryEntries' Hugo/Persistence/SyncDeduplicator.swift` shows both definitions and both calls in `run()`
- [ ] `Scripts/verify.sh` exits 0, with 11 more tests than before this plan
- [ ] `git status --porcelain` lists only files from the Scope list
- [ ] `plans/README.md` row for 044 updated (DONE, or DONE pending owner Step 6)

## STOP conditions

Stop and report back if:

- `Hugo/Persistence/SyncDeduplicator.swift` does not exist or has no `run()` (plan 041 has not landed).
- `TheocraticYearReportBuilder.canonicalSubmission(for:in:)` or `canonicalSubmissionsByMonth(_:)` no longer exist or changed their rules.
- The `#Predicate` on optional `sourceReportYear` does not compile. Fetch all entries and filter in memory instead, and note it in your report.
- Any existing `SubmitReportFormModelTests` or `TheocraticYearReportBuilderTests` test fails.
- The owner check in Step 6 shows the carried-in merge firing continuously.

## Maintenance notes

- Any new code path that inserts carried-in entries must set all three source fields, so the merge can group it.
- If a future schema version adds a stable synced identifier to `Entry` (for example a UUID), switch Step 4 to "keep the lowest identifier, delete the rest". That removes the race described there.
- Two related problems remain unplanned: edits made to entries after a month was submitted are never flagged, and re-submitting a month can silently change a carried-in entry that the next month's report already included. Both need a product decision on how to warn the user.
