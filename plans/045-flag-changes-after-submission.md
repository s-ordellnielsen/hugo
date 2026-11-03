# Plan 045: Flag a submitted month whenever its totals change, and warn before re-submitting into a submitted month

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 3f8d48b..HEAD -- Hugo/Features/Reports Hugo/Features/ServiceYear/TheocraticYearReportBuilder.swift Hugo/Resources/Localizable.xcstrings HugoTests/Features/Reports`
> Plans 038 (`MonthlyReportDetailView.swift`), 040 (`ReportingLineCalculator.swift`,
> `MonthlyReportEntryListView.swift`), 042 and 043 (`Localizable.xcstrings`,
> `ReportingLineCard.swift`, `SubmitReportView.swift`) are expected to have
> landed. Compare every excerpt below against the live code by content, not
> line number. STOP on any other mismatch.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/040-resolve-entry-category-in-one-place.md, plans/043-reconnect-rounding-help.md (both edit files here); plans/044-merge-duplicate-reports-and-carry-entries.md recommended first (duplicate carried-in entries would otherwise trigger the new flag)
- **Category**: bug
- **Planned at**: commit `3f8d48b`, 2026-10-12
- **Owner decision (2026-10-12)**: compare totals and warn. Show the "changed since you reported" state whenever a submitted month's current totals differ from what was submitted. Keep today's "new entries" rule for reports whose stored lines cannot be compared. Ask for confirmation before a re-submission changes minutes carried into an already submitted month.

## Why this matters

After a user submits a month, Hugo marks it as needing a new report only when an entry is created later (`createdAt > entriesClosedAt`). These changes go unnoticed:

- editing an entry's duration, date, category or Bible studies in a submitted month;
- deleting an entry, or moving it out of the month;
- an entry logged on another device before the submission, which syncs in afterwards (its `createdAt` is earlier than the cutoff).

In all of these the overseer has a wrong number and nothing prompts a re-submit, while the Year tab keeps showing the old submitted hours.

A chained case exists too. If June transferred 30 minutes into July and July was already submitted with them, re-submitting June with "round up" deletes July's carried-in entry. July stays "Submitted" with stale numbers, and the year total counts the same minutes twice.

After this plan, a submitted month is flagged whenever its current per-line totals or Bible studies differ from what was stored at submission. Because July's totals include its carried-in entry, the same check catches the chained case automatically. Re-submitting June first asks the user to confirm when it would change minutes already reported in July.

## Current state

### The flag

`Hugo/Features/Reports/Domain/ReportReminderSchedule.swift:41-55`:

```swift
/// True when the month has never been submitted (no report, or a sentinel
/// report left by the V8→V9 backfill), or when entries exist that were
/// created after the submission's `entriesClosedAt` cutoff.
static func hasUnreportedEntries(
    report: SubmittedReport?,
    entries: [Entry],
    month: YearMonth,
    calendar: Calendar = .current
) -> Bool {
    guard let report, (report.submittedAt ?? .distantPast) != .distantPast else { return true }

    return entries.contains {
        $0.date.yearMonth(using: calendar) == month && $0.createdAt > (report.entriesClosedAt ?? .distantPast)
    }
}
```

It is called once, from `TheocraticYearReportBuilder.report` (`TheocraticYearReportBuilder.swift:26-31`), with the month's entries (`summary?.entries ?? []`), and stored as `TheocraticYearMonth.hasUnreportedEntries`. That value drives:

- `ServiceYearMonthRow.swift:175-181`: a caption under "Submitted on ..." with key `report.status.unreported-entries`.
- `MonthlyReportDetailView.swift:17-22`: a banner with key `report.detail.unreported.banner` when `month.isSubmitted && month.hasUnreportedEntries`.

`MonthlyReportEntryListView.swift:9-12` separately marks individual entries created after the cutoff with a triangle. That per-entry marker stays as it is.

Current strings:

| Key | en | da |
|---|---|---|
| `report.status.unreported-entries` | New entries are not included in the submitted report | Nye registreringer er ikke med i den indsendte rapport |
| `report.detail.unreported.banner` | Entries added after submission are marked below. Submit an updated report to include them. | Registreringer tilføjet efter indsendelsen er markeret nedenfor. Indsend en opdateret rapport for at medtage dem. |

### What a submission stores

`SubmitReportFormModel.persistSubmission` (`Hugo/Features/Reports/SubmitReportFormModel.swift:143-210`) writes, among others:

```swift
report.actualTotalSeconds = summary?.totalSeconds ?? 0      // sum of all the month's entries
report.totalBibleStudies = summary?.totalBibleStudies ?? 0
report.reportingLines = results.map(\.persisted)             // one per line, durationInSeconds = line.actualSeconds
```

`ReportingLineResult.persisted` (`ReportingLine.swift:44-54`) stores `typeRaw`, `typeName: line.id`, `durationInSeconds: line.actualSeconds`. The stored line's `id` (`SubmittedReportV11.swift:151-155`) is `""` for the main line and `typeName` otherwise, the same as `ReportingLine.id`. Every entry belongs to exactly one line (untracked entries count as main), so for every report written by this code, `sum(reportingLines.durationInSeconds) == actualTotalSeconds`.

Reports migrated from V10 are different. Their lines were rebuilt from legacy category totals (`HugoMigrationPlan.swift:292-358`), and their `actualTotalSeconds` is the V10 value ("grand total incl. carry-in"). When the two disagree, the lines do not represent entry totals and cannot be compared with today's entries. **Comparable report** in this plan means: `!reportingLines.isEmpty` and `abs(sum(reportingLines.durationInSeconds) - (actualTotalSeconds ?? -1)) < 1`. For any other report the old `createdAt` rule applies.

### Current lines for a month

`ReportingLineCalculator.lines(from: [Entry], calendar:) -> [ReportingLine]` (`Hugo/Features/Reports/Domain/ReportingLineCalculator.swift`) returns the main line (`id == ""`, always present) plus one line per separate category name, each with `actualSeconds`. It is `nonisolated` and pure.

### Re-submission and carried-in entries

- `SubmitReportFormModel.existingSubmission` is the canonical report for `month`. `reconcileGeneratedEntries(for:in:)` (`:235-269`) updates, creates or deletes the report's `generatedEntries` (the carried-in entries in the next month) according to the `.transferred(seconds)` dispositions in `results`, keyed by `sourceReportingLineID`.
- `SubmitReportView` (`Hugo/Features/Reports/SubmitReportView.swift:32-42`) queries submissions for the target month and the previous month only:

  ```swift
  let targetYear = month.year
  let targetMonth = month.month
  let prev = YearMonth.previous(before: month)
  let prevYear = prev.year
  let prevMonth = prev.month
  _submissions = Query(
      filter: #Predicate<SubmittedReport> {
          ($0.year == targetYear && $0.month == targetMonth) || ($0.year == prevYear && $0.month == prevMonth)
      },
      sort: \SubmittedReport.year
  )
  ```

  The model receives them in `load(entries:submissions:)` and builds `submissionsByMonth` with `TheocraticYearReportBuilder.canonicalSubmissionsByMonth`.
- The send paths in `SubmitReportView`: `sendViaMessages()` and `copyReport()` call `model.prepareSubmission()` and then present Messages or copy to the pasteboard. The toolbar, the "More" menu and the bottom button all call these two functions.

### Test conventions

- `HugoTests/Features/Reports/ReportReminderScheduleTests.swift`: Swift Testing, fixed UTC Gregorian `calendar`, `date(_:_:_:hour:)` helper, reports built with `SubmittedReport(year:month:firstSubmittedAt:submittedAt:entriesClosedAt:)` (its `reportingLines` default to empty, so existing tests keep the old rule).
- `HugoTests/Features/Reports/SubmitReportFormModelTests.swift`: `makeModel(now:userDefaults:)`, `entry(_:_:_:seconds:createdAt:tracker:source:)`, `mainLineID(in:)`, and in-memory persistence. Exemplar: `resubmittingWithDownRemovesCarryAndUpdatesReportInPlace` (`:152-173`).

### String catalog

Xcode-written JSON. Edit it only through the helper below, which keeps the format byte-identical (2-space indent, `" : "`, unescaped non-ASCII, empty objects as `{` + blank line + `}`, no trailing newline, keys in Xcode's number-aware order).

```python
# /tmp/xcstrings_edit.py  (do not commit)
import json
import re

PATH = "Hugo/Resources/Localizable.xcstrings"


def load():
    with open(PATH, encoding="utf-8") as f:
        return json.loads(f.read())


def save(data):
    out = json.dumps(data, indent=2, separators=(",", " : "), ensure_ascii=False)
    out = re.sub(r"^( *)(.*)\{\}", lambda m: f"{m.group(1)}{m.group(2)}{{\n\n{m.group(1)}}}", out, flags=re.M)
    with open(PATH, "w", encoding="utf-8") as f:
        f.write(out)


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def entry(comment, en, da):
    return {"comment": comment, "localizations": {"da": unit(da), "en": unit(en)}}


def natural(key):
    return [(0, int(t)) if t.isdigit() else (1, t.lower()) for t in re.split(r"(\d+)", key) if t != ""]


def insert_sorted(strings, key, value):
    items = list(strings.items())
    index = next((i for i, (k, _) in enumerate(items) if natural(k) > natural(key)), len(items))
    items.insert(index, (key, value))
    return dict(items)
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/ReportReminderScheduleTests -only-testing:HugoTests/SubmitReportFormModelTests -only-testing:HugoTests/TheocraticYearReportBuilderTests -only-testing:HugoTests/SchemaMigrationTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:

- `Hugo/Features/Reports/Domain/ReportReminderSchedule.swift`
- `Hugo/Features/Reports/SubmitReportFormModel.swift`
- `Hugo/Features/Reports/SubmitReportView.swift`
- `Hugo/Resources/Localizable.xcstrings`
- `HugoTests/Features/Reports/ReportReminderScheduleTests.swift`
- `HugoTests/Features/Reports/SubmitReportFormModelTests.swift`
- `plans/README.md` (status row)

**Out of scope**:

- Renaming `hasUnreportedEntries` or `TheocraticYearMonth.hasUnreportedEntries`. The name stays; its doc comment changes.
- `MonthlyReportEntryListView`'s per-entry triangle (still "created after the cutoff").
- Any schema change, including a `modifiedAt` field.
- `ServiceYearMonthRow` and `MonthlyReportDetailView` code. They pick up the new behavior through the existing flag; only their strings change.
- Blocking re-submission. The warning is a confirmation, not a stop.

## Git workflow

- Branch: `advisor/045-flag-changes-after-submission`
- Commit message style: short imperative sentence, for example `Flag submitted months whose totals changed`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Write the failing tests for the flag

Add to `ReportReminderScheduleTests.swift`. Build a "comparable" report with a helper:

```swift
private func comparableReport(mainSeconds: TimeInterval, bibleStudies: Int = 0) -> SubmittedReport {
    SubmittedReport(
        year: 2026, month: 6,
        firstSubmittedAt: date(2026, 7, 1), submittedAt: date(2026, 7, 1),
        entriesClosedAt: date(2026, 6, 30, hour: 10),
        actualTotalSeconds: mainSeconds,
        totalBibleStudies: bibleStudies,
        reportingLines: [.init(typeRaw: TrackerType.main.rawValue, typeName: "", durationInSeconds: mainSeconds, submittedHours: Int(mainSeconds / 3_600))]
    )
}
```

Each test's entries have `createdAt` before `entriesClosedAt`, so the old rule alone would return `false`:

1. `unchangedComparableMonthIsNotFlagged`: one 3 600 s June entry, report with `mainSeconds: 3_600`. Expect `false`.
2. `editedDurationIsFlagged`: same report, entry now 5 400 s. Expect `true`.
3. `deletedEntryIsFlagged`: report with `mainSeconds: 3_600`, no entries. Expect `true`.
4. `newSeparateLineIsFlagged`: report as in 1; entries are the 3 600 s main entry plus a 1 800 s entry with `tracker: Tracker(name: "Bethel", type: .separate)`. Expect `true`.
5. `changedBibleStudiesIsFlagged`: report with `bibleStudies: 1`; the entry has `bibleStudies: 2`. Expect `true`.
6. `lateSyncedEntryIsFlagged`: report `mainSeconds: 3_600`; entries are the original plus a second 1 800 s entry whose `createdAt` is *before* `entriesClosedAt`. Expect `true`.
7. `nonComparableReportKeepsTheCreatedAtRule`: a report with lines summing to 3 600 but `actualTotalSeconds: 5_400` (a migrated report). An edited entry (5 400 s, old `createdAt`) gives `false`; adding an entry created after the cutoff gives `true`.

Note that `SubmittedReport`'s initializer takes its arguments in declaration order (`year, month, firstSubmittedAt, submittedAt, entriesClosedAt, roundingRuleRaw, fieldServiceSeconds, actualTotalSeconds, submittedHours, ..., totalBibleStudies, categories, reportingLines`), all with defaults. Keep the labels in that order.

**Verify**: focused-tests command → the new tests 2-6 fail, everything else passes. If test 1 or 7 fails before you change any code, STOP.

### Step 2: Implement the comparison

In `ReportReminderSchedule.swift`, keep the signature of `hasUnreportedEntries` and change its body and doc comment:

```swift
/// True when the month needs a (new) report: it was never submitted (no
/// report, or a V8→V9 placeholder), an entry was created after the
/// submission's `entriesClosedAt` cutoff, or the month's current per-line
/// totals or Bible studies differ from what was submitted. The comparison
/// applies only to reports whose stored lines add up to their
/// `actualTotalSeconds`; reports migrated from V10 may not, and keep the
/// creation-time rule alone.
static func hasUnreportedEntries(
    report: SubmittedReport?,
    entries: [Entry],
    month: YearMonth,
    calendar: Calendar = .current
) -> Bool {
    guard let report, (report.submittedAt ?? .distantPast) != .distantPast else { return true }

    let monthEntries = entries.filter { $0.date.yearMonth(using: calendar) == month }
    let cutoff = report.entriesClosedAt ?? .distantPast
    if monthEntries.contains(where: { $0.createdAt > cutoff }) { return true }

    guard isComparable(report) else { return false }
    return hasChangedTotals(report: report, monthEntries: monthEntries, calendar: calendar)
}

private static let toleranceSeconds: TimeInterval = 1

static func isComparable(_ report: SubmittedReport) -> Bool {
    guard !report.reportingLines.isEmpty, let actual = report.actualTotalSeconds else { return false }
    let storedTotal = report.reportingLines.reduce(0) { $0 + $1.durationInSeconds }
    return abs(storedTotal - actual) < toleranceSeconds
}

private static func hasChangedTotals(report: SubmittedReport, monthEntries: [Entry], calendar: Calendar) -> Bool {
    let bibleStudies = monthEntries.reduce(0) { $0 + $1.bibleStudies }
    if bibleStudies != (report.totalBibleStudies ?? 0) { return true }

    let stored = Dictionary(report.reportingLines.map { ($0.id, $0.durationInSeconds) }, uniquingKeysWith: +)
    let current = Dictionary(
        ReportingLineCalculator.lines(from: monthEntries, calendar: calendar).map { ($0.id, $0.actualSeconds) },
        uniquingKeysWith: +)
    let ids = Set(stored.keys).union(current.keys)
    return ids.contains { abs((stored[$0] ?? 0) - (current[$0] ?? 0)) >= toleranceSeconds }
}
```

A stored line with 0 seconds and a missing current line compare equal (both 0), so the always-present main line never causes a false flag.

**Verify**: focused-tests command → `** TEST SUCCEEDED **`, including all existing `TheocraticYearReportBuilderTests` and the migration test `migratingV10StoreDoesNotFalselyFlagReceivingMonthAsUnreported` (`SchemaMigrationTests.swift:726`). If that migration test fails, STOP: the comparability rule does not hold for migrated data.

Commit steps 1-2: `Flag submitted months whose totals changed`.

### Step 3: Update the two status strings

With the catalog helper (save it to `/tmp/xcstrings_edit.py` first):

```python
import sys
sys.path.insert(0, "/tmp")
import xcstrings_edit as x

data = x.load()
s = data["strings"]
s["report.status.unreported-entries"]["localizations"]["en"]["stringUnit"]["value"] = "Changed since the report was submitted"
s["report.status.unreported-entries"]["localizations"]["da"]["stringUnit"]["value"] = "Ændret siden rapporten blev indsendt"
s["report.detail.unreported.banner"]["localizations"]["en"]["stringUnit"]["value"] = "This month has changed since you submitted it. New entries are marked below. Submit an updated report to include the changes."
s["report.detail.unreported.banner"]["localizations"]["da"]["stringUnit"]["value"] = "Denne måned er ændret, siden du indsendte den. Nye registreringer er markeret nedenfor. Indsend en opdateret rapport for at medtage ændringerne."
x.save(data)
```

**Verify**: `git diff --numstat -- Hugo/Resources/Localizable.xcstrings` → 4 added, 4 removed.

### Step 4: Detect a re-submission that changes an already submitted next month

1. In `SubmitReportView.init`, extend the submissions query to the next month as well:

   ```swift
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
   ```

2. In `SubmitReportFormModel`, add:

   ```swift
   /// True when submitting now would change, add or remove minutes carried
   /// into the next month, and the next month already has a real submission.
   var changesSubmittedNextMonth: Bool {
       let next = month.nextMonth(calendar: calendar)
       guard let nextReport = submissionsByMonth[next],
           (nextReport.submittedAt ?? .distantPast) != .distantPast
       else { return false }

       var existing: [String: TimeInterval] = [:]
       for entry in existingSubmission?.generatedEntries ?? [] {
           existing[entry.sourceReportingLineID ?? "", default: 0] += entry.duration
       }
       var planned: [String: TimeInterval] = [:]
       for result in results {
           if case .transferred(let seconds) = result.disposition { planned[result.id] = seconds }
       }
       return existing != planned
   }
   ```

3. Add tests to `SubmitReportFormModelTests.swift`:
   - `resubmissionThatRemovesCarryIntoSubmittedMonthWarns`: persist June with `.transfer` (5 400 s entry → 1 800 s carried), then persist a real July report for 2026-07 (`SubmittedReport(year: 2026, month: 7, firstSubmittedAt: now, submittedAt: now, entriesClosedAt: now)`, inserted into the context). A second June model loaded with `[june entry]` and `[juneReport, julyReport]`, rule `.up`: `changesSubmittedNextMonth == true`. With rule `.transfer` again: `false`.
   - `resubmissionWithoutSubmittedNextMonthDoesNotWarn`: same, but no July report. `.up` gives `false`.
   - `nextMonthIsFlaggedAfterCarryChanges` (end-to-end check of the chain): after the `.up` re-submission persists, `ReportReminderSchedule.hasUnreportedEntries(report: julyReport, entries: <July entries fetched from context>, month: 2026-07, calendar: calendar)` is `true`, given July's report was built comparable (`actualTotalSeconds: 1_800`, one main line of 1 800 s, `entriesClosedAt` after the carried entry's `createdAt`).

**Verify**: focused-tests command → `** TEST SUCCEEDED **`.

### Step 5: Ask before sending

1. Add strings with the helper:

   ```python
   data = x.load()
   s = data["strings"]
   s = x.insert_sorted(s, "report.submit.next-month-warning.message", x.entry(
       "Confirmation shown before re-submitting a month when this changes minutes carried into the next month, which was already submitted.",
       "This changes the minutes carried into next month, which you have already reported. Hugo will mark next month as changed so you can submit it again.",
       "Det ændrer de minutter, der er overført til næste måned, som du allerede har rapporteret. Hugo markerer næste måned som ændret, så du kan indsende den igen.",
   ))
   s = x.insert_sorted(s, "report.submit.next-month-warning.continue", x.entry(
       "Button in the re-submission confirmation that continues sending the report.",
       "Continue",
       "Fortsæt",
   ))
   data["strings"] = s
   x.save(data)
   ```

2. In `SubmitReportView`, add `@State private var pendingSend: (() -> Void)?` and route both send paths through a guard:

   ```swift
   private func confirmIfNeeded(_ action: @escaping () -> Void) {
       if model.changesSubmittedNextMonth {
           pendingSend = action
       } else {
           action()
       }
   }
   ```

   Every button that today calls `sendViaMessages()` or `copyReport()` (toolbar button, both menu items, bottom button) calls `confirmIfNeeded(sendViaMessages)` / `confirmIfNeeded(copyReport)` instead.
3. Present the confirmation:

   ```swift
   .confirmationDialog(
       "report.submit.next-month-warning.message",
       isPresented: Binding(get: { pendingSend != nil }, set: { if !$0 { pendingSend = nil } }),
       titleVisibility: .visible
   ) {
       Button("report.submit.next-month-warning.continue") {
           let action = pendingSend
           pendingSend = nil
           action?()
       }
       Button(role: .cancel) { pendingSend = nil }
   }
   ```

**Verify**: lint exits 0; `Scripts/verify.sh` → exit 0.

Commit steps 3-5: `Warn before a re-submission changes a submitted next month`.

### Step 6 [owner]: Check in the simulator

1. Submit last month. In the Year tab, edit one of its entries (change the duration). The month row shows "Changed since the report was submitted", and Details shows the new banner.
2. Change the duration back. The flag disappears.
3. Submit month A with "Transfer", then submit month A+1. Re-open month A, pick "Round up" and send. The confirmation appears. After continuing, month A+1 shows "Changed since the report was submitted".
4. Months submitted before the V11 build (migrated) behave as before.
5. Review the Danish wording.

## Test plan

- `ReportReminderScheduleTests`: 7 new tests (Step 1).
- `SubmitReportFormModelTests`: 3 new tests (Step 4).
- All existing tests keep passing. Existing reports in tests have empty `reportingLines`, so they use the old rule.

## Done criteria

- [ ] `grep -n 'isComparable\|hasChangedTotals' Hugo/Features/Reports/Domain/ReportReminderSchedule.swift` shows both
- [ ] `grep -n 'changesSubmittedNextMonth' Hugo/Features/Reports/SubmitReportView.swift` shows at least one use
- [ ] `Scripts/verify.sh` exits 0, with 10 more tests than before this plan
- [ ] `git status --porcelain` lists only files from the Scope list
- [ ] `plans/README.md` row for 045 updated

## STOP conditions

Stop and report back if:

- Test 1 or test 7 of Step 1 fails before any code change (the excerpts no longer match the behavior).
- `migratingV10StoreDoesNotFalselyFlagReceivingMonthAsUnreported` or any `TheocraticYearReportBuilderTests` test fails after Step 2.
- `SubmittedReport.SubmittedReportingLine.id` no longer equals `ReportingLine.id` for the same line (main `""`, separate = category name).
- Any send path in `SubmitReportView` bypasses `confirmIfNeeded` and you cannot route it without restructuring the view.

## Maintenance notes

- The comparison relies on `persistSubmission` storing `actualTotalSeconds` equal to the sum of its lines. Any change to what a submission stores must keep that, or every new report becomes non-comparable and silently falls back to the old rule.
- Re-categorizing an entry between two main categories does not flag the month: the report only has one Field Service line, so the report would not change.
- The year totals still use submitted hours for a flagged month. That is intended: they show what was reported until the user re-submits.
