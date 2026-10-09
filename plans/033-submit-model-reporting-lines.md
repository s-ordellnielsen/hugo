# Plan 033: Submit and persist reports as reporting lines with generated carry entries

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat dc0b7f6..HEAD -- Hugo/Features/Reports/SubmitReportFormModel.swift Hugo/Features/Reports/Domain HugoTests/Features/Reports`
> Expected changes: whitespace (plan 031) and the files added by plan 032.
> Any other mismatch with the excerpts below is a STOP condition.

## Status

- **Priority**: P1 (TestFlight blocker)
- **Effort**: L
- **Risk**: HIGH (writes user data that syncs through CloudKit)
- **Depends on**: plans/032-reporting-line-domain.md
- **Category**: bug
- **Planned at**: commit `dc0b7f6`, 2026-10-09

## Why this matters

After the V10→V11 migration, a month's transferred minutes exist twice: once as a generated `Entry` in the next month, and once in `previousSubmission.carriedOutSeconds`, which the form model still adds as carry-in. **Every user who transferred minutes before upgrading gets double-counted carry-in on their next report.** New submissions also never write `reportingLines` or generated entries, so V11 data stays incomplete. This plan moves the submit workflow to reporting lines (plan 032), writes them, and creates or updates the generated next-month entry for each transferring line.

## Current state

`Hugo/Features/Reports/SubmitReportFormModel.swift` (`@MainActor @Observable final class`, 248 lines):

```swift
// :13
var selectedRule: RoundingRule { didSet { recompute() } }
// :44 (init)
self.selectedRule = RoundingRule.defaultValue
// :77-79 — the double-count source
var carriedIn: TimeInterval {
    previousSubmission?.carriedOutSeconds ?? 0
}
// :81
private(set) var computation: RoundingComputation = ...
// :155 persistSubmission(in:) updates `existingSubmission` in place (keeps
// firstSubmittedAt and the CloudKit record identity) or inserts a new
// SubmittedReport, writing legacy fields + `categories` snapshots only.
// :174
existing.entriesClosedAt = monthEntries.map(\.createdAt).max() ?? now
// :229 recompute() sets preparedContent = nil and calls ReportRoundingCalculator.compute
```

- `prepareSubmission()` (:119) calls `ReportComposer.message(summary:computation:template:firstName:lastName:locale:calendar:)`.
- `Hugo/Features/Reports/Domain/ReportComposer.swift` `message(...)`: greeting, blank line, `"\(report.compose.field-service): N \(report.hours.unit)"` summed over `.main` categories, then one `"Name: N h"` line per non-main category, then `"\(report.compose.bible-studies): N"`. `render(template:...)` stays as is.
- Generated carry entries, as the migration creates them (`Hugo/Persistence/HugoMigrationPlan.swift:328-347`). New runtime code must match this shape for the main line:

```swift
let entry = SchemaV11.Entry(
    date: nextMonthStart, duration: legacyReport.carriedOutSeconds, tracker: nil,
    source: (submission: report, lineID: "")
)
entry.storedTracker = .init(name: String(localized: "category.default.label"), icon: "figure.walk", type: .main)
entry.createdAt = nextMonthStart
context.insert(entry)
```

- `SubmittedReport.generatedEntries: [Entry]?` (inverse of `Entry.sourceSubmission`, delete rule `.nullify`).
- No app code reads `SubmittedReport.categories`, `carriedInSeconds`, `carriedOutSeconds`, `roundedUp/DownSeconds`, or `roundingRuleRaw`. `ServiceYearMonthRow.swift:94` reads `submittedHours` (total). Keep writing the legacy fields so old builds syncing the same CloudKit container still see sensible values.
- Plan 032 provides `ReportingLine`, `ReportingLineResult`, `RemainderDisposition`, and `ReportingLineCalculator.lines(from:calendar:)`, `compute(_:rules:)`, `isComplete(_:)`, plus `ReportingLineResult.persisted`.
- Tests: `HugoTests/Features/Reports/SubmitReportFormModelTests.swift` (GMT gregorian calendar, `month = 2026-06`, `now = 1_800_000_000`, `InMemoryModelContainer.make()`). Several tests use `selectedRule` and `carriedOutSeconds` and must be rewritten.

### Product decisions (from the owner, not negotiable in this plan)

1. Each line has its own rule. **No default rule**: a line with a remainder is `undecided` until the user picks one, and the report cannot be sent while any line is undecided. Exception: when re-opening an already submitted month, pre-fill each line's rule from the stored `reportingLines[].roundingRaw`.
2. Carry-in comes **only** from generated entries in this month. `carriedOutSeconds` of the previous submission is never read again.
3. Generated entries count toward the receiving month like any other entry.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan033 -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/SubmitReportFormModelTests -only-testing:HugoTests/ReportComposerTests` | `** TEST SUCCEEDED **` |
| Gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope:**
- `Hugo/Features/Reports/SubmitReportFormModel.swift`
- `Hugo/Features/Reports/Domain/ReportComposer.swift`
- `Hugo/Features/Reports/Domain/ReportRoundingCalculator.swift` (delete in step 5)
- `Hugo/Features/Reports/Domain/ReportingLineCalculator.swift` (add the category-hours helper only, step 4)
- `Hugo/Features/Reports/SubmitReportView.swift`: **only** the minimal compile fixes in step 6
- `HugoTests/Features/Reports/SubmitReportFormModelTests.swift`, `ReportComposerTests.swift`, `ReportRoundingCalculatorTests.swift` (delete)

**Out of scope:**
- `Hugo/Persistence/**`. No schema change.
- The submit UI redesign (plan 034) and year totals (plan 035).
- Making generated entries non-editable (owner's follow-up).

## Git workflow

Branch `advisor/033-submit-reporting-lines`. Commits per step group (`Compose report from reporting lines`, `Persist reporting lines and carry entries`, `Remove report-wide rounding calculator`). Do not push.

## Steps

### Step 1: Replace the single rule with per-line state

In `SubmitReportFormModel`:
- Remove `selectedRule`, `carriedIn`, `previousSubmission`, and `computation`.
- Add:

```swift
private(set) var lines: [ReportingLine] = []
private(set) var results: [ReportingLineResult] = []
private var rules: [String: RoundingRule] = [:]   // keyed by ReportingLine.id

func rule(for lineID: String) -> RoundingRule? { rules[lineID] }
func setRule(_ rule: RoundingRule?, for lineID: String) { rules[lineID] = rule; recompute() }
var isComplete: Bool { ReportingLineCalculator.isComplete(results) }
```

- `load(entries:submissions:)`: after computing `monthEntries`, set `lines = ReportingLineCalculator.lines(from: monthEntries, calendar: calendar)`. **Only on the first load** (track with a private `didSeedRules` flag), seed `rules` from `existingSubmission?.reportingLines` where `rounding != nil`, keyed by line `id`. Later loads must not overwrite the user's choices.
- `recompute()`: `preparedContent = nil; results = ReportingLineCalculator.compute(lines, rules: rules)`.
- `isSubmittable` stays the month check. Add `var canSend: Bool { isSubmittable && isComplete }`. `prepareSubmission()` returns `nil` unless `canSend`.

**Verify:** the file compiles (the focused tests may still fail until step 3).

### Step 2: Compose from lines

Change `ReportComposer.message` to:

```swift
static func message(
    month: YearMonth, results: [ReportingLineResult], bibleStudies: Int,
    template: String, firstName: String, lastName: String,
    locale: Locale = .current, calendar: Calendar = .current
) -> ReportMessageContent
```

Body: greeting, `""`, then one line per result in the given order. The main line label is `String(localized: "report.compose.field-service", locale: locale)`; separate lines use `line.name`. Format: `"<label>: <submittedHours> <report.hours.unit>"`. Then `"<report.compose.bible-studies>: <bibleStudies>"`. A separate line with 0 submitted hours is still listed, as today. Update `prepareSubmission()` to call it, passing `summary?.totalBibleStudies ?? 0`.

Rewrite `ReportComposerTests` for the new signature. Keep the existing `render` tests unchanged.

**Verify:** `-only-testing:HugoTests/ReportComposerTests` → `** TEST SUCCEEDED **`.

### Step 3: Persist lines and legacy fields

In `persistSubmission(in:)` (both branches, update-in-place and insert):
- Guard `canSend`; return `nil` otherwise.
- `reportingLines = results.map(\.persisted)`
- Legacy fields, derived from the results:
  - `roundingRuleRaw` = main line rule raw or `""`
  - `fieldServiceSeconds` = main line `actualSeconds`
  - `actualTotalSeconds` = `summary?.totalSeconds ?? 0` (**no `+ carriedIn`**; carry-in is already part of the entries)
  - `submittedHours` = sum of all `submittedHours`
  - `carriedInSeconds` = sum of `line.carriedInSeconds`
  - `carriedOutSeconds` / `roundedUpSeconds` / `roundedDownSeconds` = sums of the matching dispositions
- `categories`: keep writing one snapshot per `summary.categories` element with `actualSeconds`. Set `submittedHours` from the helper in step 4.
- Keep `firstSubmittedAt`, `submittedAt`, and `entriesClosedAt` logic exactly as today.

### Step 4: Category-hours helper

Move the largest-remainder logic of `ReportRoundingCalculator.distributeHours` (lines 66-123 at `dc0b7f6`, unchanged algorithm) into `ReportingLineCalculator` as

```swift
static func categoryHours(results: [ReportingLineResult], categories: [MonthlyCategorySummary]) -> [String: Int]
```

It distributes each line's `submittedHours` across the categories belonging to that line: the main line takes `.main` and `nil`-type categories; a separate line takes `.separate` categories whose `name == line.id`. The per-line sums must equal the line's `submittedHours`.

### Step 5: Generated carry entries

After writing the report's fields, reconcile generated entries **for this report only**, then save once:

```swift
let nextMonthStart = month.nextMonth(calendar: calendar).date(calendar: calendar)
var existingByLine = Dictionary(grouping: report.generatedEntries ?? [], by: { $0.sourceReportingLineID ?? "" })
for result in results {
    guard case .transferred(let seconds) = result.disposition else { continue }
    if let entry = existingByLine[result.id]?.first {
        if entry.duration != seconds { entry.duration = seconds; entry.createdAt = now }
        existingByLine[result.id]?.removeFirst()
    } else {
        let entry = Entry(date: nextMonthStart, duration: seconds, tracker: nil, source: (submission: report, lineID: result.id))
        entry.storedTracker = result.line.type == .main
            ? .init(name: String(localized: "category.default.label"), icon: "figure.walk", type: .main)
            : .init(name: result.line.name, icon: result.line.iconName, type: .separate)
        entry.createdAt = now
        context.insert(entry)
    }
}
for leftover in existingByLine.values.flatMap({ $0 }) { context.delete(leftover) }
```

For a new report, insert it before creating entries so the relationship target exists. Then delete `ReportRoundingCalculator.swift` and `ReportRoundingCalculatorTests.swift`.

**Verify:** `grep -rn "ReportRoundingCalculator\|carriedOutSeconds ?? 0\|selectedRule" Hugo HugoTests` matches only `Hugo/Persistence/**`, or nothing.

### Step 6: Keep `SubmitReportView` compiling

Make only the edits the compiler forces: replace `model.computation.categoryHours[category.id]` with a temporary lookup through `model.results`, and gate the bottom button on `!model.canSend`. Plan 034 rewrites this view. Do not redesign here.

**Verify:** focused test command → `** TEST SUCCEEDED **`.

### Step 7: Gate

`Scripts/verify.sh` → exit 0.

## Test plan

Rewrite or add tests in `SubmitReportFormModelTests.swift`:

1. 5_400 s of main entries, no rules → `canSend == false`, `prepareSubmission() == nil`.
2. Setting `.down` on line `""` → `canSend`, main line submits 1 h.
3. **Regression (double count):** previous month has a real submission with `carriedOutSeconds = 1_800`, and this month has a generated entry of 1_800 s (`source` set to that submission). Main actual seconds == entries + 1_800 **once**, not 3_600.
4. Persist with `.transfer` on a 5_400 s main line → report has `reportingLines.count == 1` with `roundingRaw "transfer"`; one `Entry` exists at `2026-07-01 00:00 GMT` with duration 1_800, `sourceReportingLineID ""`, `sourceReportYear 2026`, `sourceReportMonth 6`.
5. Resubmit the same month with `.down` → the generated entry is deleted, and the report row count for June stays 1.
6. Resubmit with `.transfer` and an unchanged remainder → still exactly one generated entry, `createdAt` unchanged.
7. Separate line with `.transfer` → generated entry has `storedTracker.type == .separate` and its name equals the line name.
8. Reopening a submitted month seeds rules from `reportingLines`; a second `load` after `setRule` does not reset the choice.
9. Zero-activity month → submittable without a rule (no remainder); persists a main line with 0 h.
10. Existing sentinel/resubmission/`firstSubmittedAt` tests keep their assertions.

## Done criteria

- [ ] `grep -rn "previousSubmission\|ReportRoundingCalculator" Hugo/Features HugoTests` → no matches
- [ ] All tests listed above exist and pass; `Scripts/verify.sh` exits 0
- [ ] `git diff --stat dc0b7f6..HEAD -- Hugo/Persistence` shows only plan 031 whitespace
- [ ] `plans/README.md` row updated

## STOP conditions

- Creating an `Entry` with `source:` before the report is inserted crashes or fails to link in tests.
- `report.generatedEntries` stays empty after save even though an entry with `sourceSubmission == report` exists (inverse not maintained). Report this; do not work around it with a fetch without saying so.
- Any change appears necessary in `Hugo/Persistence/**`.

## Maintenance notes

- When resubmitting month M after month M+1 was already submitted, a changed carry entry gets `createdAt = now`, so M+1 shows "unreported entries". That is intended: M+1's report really is stale.
- The owner plans a visually distinct, non-editable style for generated entries. Until it exists, users can edit or delete them, and a resubmission of the source month will recreate them.
- Reviewers: check that `actualTotalSeconds` no longer adds carry-in, and that no code path still reads `carriedOutSeconds`.
