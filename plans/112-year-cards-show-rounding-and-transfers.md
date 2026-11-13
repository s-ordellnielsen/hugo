# Plan 112: Show rounded and transferred minutes on the Year page's month cards

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 3055ae6..HEAD -- Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift Hugo/Features/Reports/Domain/ServiceMonth.swift Hugo/Features/Reports/Domain/ReportAdjustments.swift HugoTests/Features/Reports/Domain`
> Expected: only the files plan 111 added (`CarriedInTime.swift` is not in
> this list; `CarriedInTimeTests.swift` may show). If anything else is listed,
> compare the "Current state" excerpts below with the live code. A mismatch
> is a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S + owner (look at it on a device in English and Danish)
- **Risk**: LOW. One value type, two computed properties and one view. No schema change, no new strings, no change to how time is counted or reported.
- **Depends on**: plan 111 (adds `CarriedInTime` in `Hugo/Features/Reports/Domain/CarriedInTime.swift`). Run 111 first; if that file does not exist, STOP.
- **Category**: direction
- **Planned at**: commit `3055ae6`, 2026-11-13
- **Issue**: [SLN-238](https://linear.app/sebastianln/issue/SLN-238)

## Why this matters

Each month card on the Year page shows the month's **reported hours** in big type, and underneath, the **logged time** per category. When a reporting line was rounded or its remainder transferred, those two numbers disagree and the card doesn't say why. A month with 10 h 40 min logged shows "11 hours" with no explanation, and a month that starts with carried-in time looks like it has more logged time than the user remembers.

After this plan a card adds short gray notes such as "⤒ 20 minutes rounded up", "↗ 40 minutes transferred to next month" and "↘ 30 minutes transferred from October". They use the exact words the Submit Report screen already uses. The rounding notes come from the **submitted report's saved reporting lines**, not from today's entries, so they stay correct if a category is later renamed or deleted.

## Current state

Glossary terms from `CONTEXT.md` to use in names and comments:

- **Reporting line**: "One line of a report: Field Service, which holds all main time, or one separate category. Each line is rounded on its own."
- **Remainder**: "The minutes on a reporting line beyond its whole hours."
- **Rounding rule**: "What happens to a reporting line's remainder: round up, round down or transfer."
- **Reported hours**: "The whole hours on a submitted report's lines." _Avoid_: submitted time.
- **Logged time**: "The sum of entry durations, before any rounding."
- **Carried-in entry**: "An entry Hugo creates on the 1st of the next month to hold minutes that were transferred."

### What a submitted report stores

`SubmittedReport` is `SchemaV13.SubmittedReport` (`Hugo/Persistence/SchemaVersions/V13/SubmittedReportV13.swift`). Its reporting lines (line 51):

```swift
        var reportingLines: [SubmittedReportingLine] = []
```

Each line (lines 124-159, abridged):

```swift
        struct SubmittedReportingLine: Codable, Hashable, Identifiable {
            var typeRaw: String = ""
            var typeName: String = ""
            var durationInSeconds: TimeInterval = 0
            var submittedHours: Int = 0
            var roundingRaw: String = RoundingRule.defaultValue.rawValue
            ...
            var rounding: RoundingRule? {
                RoundingRule(rawValue: roundingRaw)
            }
```

- `durationInSeconds` is the line's logged time at submission, including carried-in time.
- `submittedHours` is the line's reported hours.
- `roundingRaw` is `"up"`, `"down"`, `"transfer"`, or `""` when the line had no remainder (written by `ReportingLineResult.persisted` in `Hugo/Features/Reports/Domain/ReportingLine.swift:44-54`). A line decoded without the key defaults to `"down"` (`RoundingRule.defaultValue`). So a whole-hour line can say `"down"`. The rules in Step 1 handle that by also checking the sign of the difference.

Do not read the report-level `roundedUpSeconds`, `roundedDownSeconds`, `carriedInSeconds` or `carriedOutSeconds`. `plans/README.md` lists them as write-only fields that a later issue (SLN-290) may stop writing.

### `ServiceMonth`

`Hugo/Features/Reports/Domain/ServiceMonth.swift` is the value type every month screen reads. Relevant parts:

```swift
nonisolated struct ServiceMonth: Identifiable {
    ...
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
```

It already reads `submission.reportingLines` in its `contribution` property, and `summary?.entries` holds the month's entries, carried-in ones included.

### The month card

`Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift`. Its body (lines 26-37):

```swift
    var body: some View {
        VStack(alignment: .leading) {
            header

            if month.isSubmitted, let submittedAt = month.submittedReport?.submittedAt {
                submissionStatus(submittedAt)
            }

            if let summary {
                activityBreakdown(summary)
            }
        }
```

The submission status block (lines 162-181) is the style to match: caption font, secondary color, `HugoLayout.Spacing.compact` spacing:

```swift
    @ViewBuilder
    fileprivate func submissionStatus(_ submittedAt: Date) -> some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
            Label(
                "report.status.submitted.\(Self.dateFormatter.string(from: submittedAt))",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.hugoAccent)

            if month.unreportedChange != nil {
                Label(
                    "report.status.unreported-entries",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(.top, HugoLayout.Spacing.compact)
    }
```

### Words and glyphs to reuse (no new strings)

`Hugo/Features/Reports/Views/ReportingLineCard.swift:255-270` shows a line's rounding with these glyphs and keys:

```swift
        case .roundedUp(let seconds):
            dispositionLabel(
                glyph: "⤒",
                text: Text("report.line.rounded-up.\(ServiceDurationFormatter.accessibilityString(from: seconds))")
            )
        case .roundedDown(let seconds):
            dispositionLabel(
                glyph: "⤓",
                text: Text("report.line.rounded-down.\(ServiceDurationFormatter.accessibilityString(from: seconds))")
            )
        case .transferred(let seconds):
            dispositionLabel(
                glyph: "↗",
                text: Text("report.line.transferred.\(ServiceDurationFormatter.accessibilityString(from: seconds))")
            )
```

Catalog values: `report.line.rounded-up.%@` "%@ rounded up" / "%@ rundet op", `report.line.rounded-down.%@` "%@ rounded down" / "%@ rundet ned", `report.line.transferred.%@` "%@ transferred to next month" / "%@ overført til næste måned". Carried-in time uses `CarriedInTime.label()` from plan 111 ("30 minutes transferred from October") with the glyph "↘".

### Conventions

- Pure value types go in a feature's `Domain` folder and are `nonisolated`. The project uses MainActor default isolation and Swift 6 strict concurrency.
- New `.swift` files are picked up automatically (synchronized folders). Do not edit `project.pbxproj`.
- Tests use Swift Testing. `HugoTests/Features/Reports/Domain/ServiceMonthTests.swift` is the pattern. It builds reports in memory like this (lines 95-108):

```swift
    private func comparableReport(mainSeconds: TimeInterval, bibleStudies: Int = 0) -> SubmittedReport {
        SubmittedReport(
            year: 2026,
            month: 6,
            firstSubmittedAt: date(2026, 7, 1),
            submittedAt: date(2026, 7, 1),
            entriesClosedAt: date(2026, 6, 30, hour: 10),
            actualTotalSeconds: mainSeconds,
            totalBibleStudies: bibleStudies,
            reportingLines: [
                .init(
                    typeRaw: TrackerType.main.rawValue, typeName: "", durationInSeconds: mainSeconds,
                    submittedHours: Int(mainSeconds / 3_600))
            ]
        )
    }
```

  and builds a month with `ServiceMonth.make(june, entries:submissions:now:calendar:)` through its private `month(_:_:)` helper (line 30). A carried-in entry is an `Entry` with `sourceReportYear` and `sourceReportMonth` set.

## Owner decisions (recommended defaults, change before executing if wanted)

1. **Notes shown**: rounded up, rounded down and transferred to next month for submitted months, plus "transferred from …" for any month that holds carried-in time, submitted or not. "Transferred from" uses the month's carried-in entries, which Hugo creates and keeps in step with the source month's report.
2. **Wording**: reuse the Submit Report screen's strings, so no new translations are needed.
3. **Amounts are summed across lines.** If Field Service rounds up 20 minutes and Bethel rounds up 10, the card says "30 minutes rounded up". The month detail and the Submit screen still show each line.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/ReportAdjustmentsTests -only-testing:HugoTests/ServiceMonthTests` | `** TEST SUCCEEDED **` |
| Full gate (before each commit) | `Scripts/verify.sh` | exit 0 |
| Whitespace | `git diff --check` | exit 0 |

If plan 102 has renamed the `Hugo` scheme, use the scheme `Scripts/verify.sh` uses now.

## Scope

**In scope** (the only files you may modify or create):

- `Hugo/Features/Reports/Domain/ReportAdjustments.swift` (create)
- `HugoTests/Features/Reports/Domain/ReportAdjustmentsTests.swift` (create)
- `Hugo/Features/Reports/Domain/ServiceMonth.swift` (add two computed properties)
- `HugoTests/Features/Reports/Domain/ServiceMonthTests.swift` (add tests)
- `Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift`

**Out of scope**:

- Every SwiftData model and schema version, `HugoMigrationPlan.swift`, `ReportSubmissionService.swift`. Nothing about saving changes.
- `Localizable.xcstrings`. No new strings are needed. If you think one is, STOP.
- `ReportingLineCard.swift`, `MonthlyReportDetailView.swift`, `MonthlyReportTotalsView.swift`, `ServiceYearDetailView.swift`, `TheocraticYearTotalsView.swift`.
- `CarriedInTime.swift` (plan 111 owns it; use it as it is).
- `Hugo.xcodeproj/project.pbxproj`, `.claude/`, `plans/` (except your status row) and the owner's `Changelog/` changes. Never stage them.

## Git workflow

- Work on `main`. No branch, no worktree, no push. Stage files by path.
- Two commits, each after `Scripts/verify.sh` exits 0:
  1. `feat: read rounding and transfers from a submitted report's lines` (Steps 1-2)
  2. `feat: show rounded and transferred minutes on the Year page month cards` (Step 3)

## Steps

### Step 1: Add `ReportAdjustments` and its tests

Create `Hugo/Features/Reports/Domain/ReportAdjustments.swift`:

```swift
import Foundation

/// What rounding did to a submitted report, summed over its saved reporting
/// lines: minutes added by rounding up, minutes dropped by rounding down and
/// minutes moved to the next month by a transfer. Read from the report's
/// snapshot only, so it stays correct after categories are renamed or deleted.
nonisolated struct ReportAdjustments: Equatable, Sendable {
    var roundedUpSeconds: TimeInterval = 0
    var roundedDownSeconds: TimeInterval = 0
    var transferredSeconds: TimeInterval = 0

    /// Differences under one second are ignored (floating-point noise).
    private static let toleranceSeconds: TimeInterval = 1

    init(lines: [SubmittedReport.SubmittedReportingLine]) {
        for line in lines {
            let difference = TimeInterval(line.submittedHours) * 3_600 - line.durationInSeconds
            switch line.rounding {
            case .up where difference >= Self.toleranceSeconds:
                roundedUpSeconds += difference
            case .down where -difference >= Self.toleranceSeconds:
                roundedDownSeconds += -difference
            case .transfer where -difference >= Self.toleranceSeconds:
                transferredSeconds += -difference
            default:
                break
            }
        }
    }

    var isEmpty: Bool {
        roundedUpSeconds == 0 && roundedDownSeconds == 0 && transferredSeconds == 0
    }
}
```

The `where` guards matter: a whole-hour line decoded with the default `"down"` has `difference == 0` and adds nothing, and a line whose rule disagrees with its numbers adds nothing.

Create `HugoTests/Features/Reports/Domain/ReportAdjustmentsTests.swift` (`@MainActor struct ReportAdjustmentsTests`). Build lines with `SubmittedReport.SubmittedReportingLine(typeRaw:typeName:durationInSeconds:submittedHours:roundingRaw:)`. Tests:

1. `roundUp`: main line, 10 h 40 min (38 400 s), 11 h, `"up"` → `roundedUpSeconds == 1_200`, others 0.
2. `roundDown`: 10 h 40 min, 10 h, `"down"` → `roundedDownSeconds == 2_400`.
3. `transfer`: 10 h 40 min, 10 h, `"transfer"` → `transferredSeconds == 2_400`, `roundedDownSeconds == 0`.
4. `wholeHourLineWithTheDefaultRuleAddsNothing`: 3 600 s, 1 h, rule omitted (defaults to `"down"`) → `isEmpty`.
5. `lineWithoutARuleAddsNothing`: 3 600 s, 1 h, `""` → `isEmpty`.
6. `sumsAcrossLines`: main 10 h 40 min → 11 h `"up"`, plus separate line `typeName: "Bethel"` 2 h 50 min → 3 h `"up"`, plus separate `"LDC"` 1 h 15 min → 1 h `"transfer"` → `roundedUpSeconds == 1_800`, `transferredSeconds == 900`.
7. `noLines`: `[]` → `isEmpty`.

**Verify**: lint exits 0; the focused test command → `** TEST SUCCEEDED **`, with 7 `ReportAdjustmentsTests` passing.

### Step 2: Give `ServiceMonth` the notes' data

Add to `ServiceMonth` (next to `contribution`):

```swift
    /// What rounding did to the month's submitted report, or nil when the
    /// month isn't submitted, its report has no saved lines, or nothing was
    /// rounded or transferred.
    var adjustments: ReportAdjustments? {
        guard isSubmitted, let report = submittedReport, !report.reportingLines.isEmpty else { return nil }
        let adjustments = ReportAdjustments(lines: report.reportingLines)
        return adjustments.isEmpty ? nil : adjustments
    }

    /// The month's carried-in time, or nil when it has none.
    var carriedIn: CarriedInTime? {
        CarriedInTime(entries: summary?.entries ?? [])
    }
```

Add these `@Test`s to `ServiceMonthTests` (reuse its `date`, `june` and `month(_:_:)` helpers):

1. `adjustmentsAreNilWhenNotSubmitted`: no report, one entry → `adjustments == nil`.
2. `adjustmentsAreNilForAPlaceholderReport`: a report built like the existing `placeholderReportIsNotSubmitted` test, but with one line 38 400 s → 11 h `"up"` → `adjustments == nil`.
3. `adjustmentsComeFromTheSubmittedLines`: a submitted report (dates like `comparableReport`) with one main line 38 400 s → 11 h `"up"` and one separate line `"Bethel"` 4 500 s → 1 h `"transfer"` → `adjustments?.roundedUpSeconds == 1_200`, `adjustments?.transferredSeconds == 900` and `adjustments?.roundedDownSeconds == 0`.
4. `adjustmentsAreNilWhenNothingWasRounded`: `comparableReport(mainSeconds: 7_200)` → `adjustments == nil`.
5. `carriedInComesFromTheMonthsCarriedInEntries`: entries in June: one ordinary (3 600 s) and one carried-in (1 800 s, `sourceReportYear = 2026`, `sourceReportMonth = 5`) → `carriedIn?.seconds == 1_800`, `carriedIn?.sourceMonths == [YearMonth(year: 2026, month: 5)]`.

**Verify**: focused tests → `** TEST SUCCEEDED **`. `Scripts/verify.sh` exits 0. Commit 1.

### Step 3: Show the notes on the card

In `ServiceYearMonthRow.swift`:

1. In `body`, add `adjustmentNotes` right after the `submissionStatus` `if` block and before the `activityBreakdown` `if` block.
2. Add an extension with the notes:

```swift
extension ServiceYearMonthRow {
    /// Short notes explaining why reported hours differ from logged time:
    /// time transferred in, then what rounding did to the submitted report.
    @ViewBuilder
    fileprivate var adjustmentNotes: some View {
        let adjustments = month.adjustments
        if month.carriedIn != nil || adjustments != nil {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                if let carriedIn = month.carriedIn {
                    note(glyph: "↘", text: Text(carriedIn.label()))
                }
                if let adjustments {
                    if adjustments.roundedUpSeconds > 0 {
                        note(glyph: "⤒", text: Text("report.line.rounded-up.\(duration(adjustments.roundedUpSeconds))"))
                    }
                    if adjustments.roundedDownSeconds > 0 {
                        note(
                            glyph: "⤓", text: Text("report.line.rounded-down.\(duration(adjustments.roundedDownSeconds))"))
                    }
                    if adjustments.transferredSeconds > 0 {
                        note(
                            glyph: "↗", text: Text("report.line.transferred.\(duration(adjustments.transferredSeconds))"))
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, HugoLayout.Spacing.compact)
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        ServiceDurationFormatter.accessibilityString(from: seconds)
    }

    private func note(glyph: String, text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.compact) {
            Text(verbatim: glyph)
                .accessibilityHidden(true)
            text
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}
```

Let `swift-format` decide the line breaks; the lint must pass. `Text("report.line.rounded-up.\(someString)")` resolves to the catalog key `report.line.rounded-up.%@`, exactly as in `ReportingLineCard`.

**Verify**:
- `Scripts/verify.sh` exits 0.
- `git diff --stat` lists only the in-scope files (plus the owner's untouched `Changelog/` changes, which you must not stage). `git diff --check` exits 0.
- `git diff -- Hugo/Resources/Localizable.xcstrings` is empty.

Commit 2.

## Test plan

- `ReportAdjustmentsTests` (7 tests) cover each rule, the default-rule and no-rule whole-hour lines, summing across lines and the empty case.
- 5 new `ServiceMonthTests` cover when `adjustments` and `carriedIn` are nil and that they come from the snapshot and the carried-in entries.
- The card itself only displays these values. The owner checks it on a device.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `ReportAdjustmentsTests.swift` exists with 7 passing tests; `ServiceMonthTests` has the 5 new tests passing
- [ ] `grep -n "adjustmentNotes" Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift` shows the property and its use in `body`
- [ ] `grep -rn "roundedUpSeconds\|carriedOutSeconds" Hugo/Features/ServiceYear` returns nothing (the card doesn't read the report-level fields)
- [ ] `git diff 3055ae6 -- Hugo/Resources/Localizable.xcstrings` shows no change from this plan
- [ ] `git show --stat HEAD~1 HEAD` lists only in-scope files
- [ ] `plans/README.md` row for 112 updated

## STOP conditions

- `Hugo/Features/Reports/Domain/CarriedInTime.swift` does not exist (plan 111 has not run).
- The drift check shows changes beyond plan 111's files and the excerpts no longer match.
- `SubmittedReport.SubmittedReportingLine` cannot be used from the `nonisolated` `ReportAdjustments` (an isolation error that one `nonisolated` keyword on the new type doesn't fix). `ServiceMonth` already reads these lines from a `nonisolated` type, so this should not happen.
- A note shows a raw key on the simulator instead of the sentence.
- Any step seems to need an out-of-scope file or a new string.

## Maintenance notes

- Owner device check, in English and Danish (Year tab):
  - Submit a month with a remainder rounded up: its card shows "⤒ 20 minutes rounded up" under "Submitted …".
  - Submit a month with **Transfer**: its card shows "↗ … transferred to next month", and the next month's card shows "↘ … transferred from <month>", before and after that month is submitted.
  - A month submitted in whole hours shows no notes.
  - VoiceOver reads each note as one sentence, without the arrow glyph.
- If SLN-290 later stops writing the report-level rounding fields, this plan is unaffected, because it reads `reportingLines` only.
- If a future schema stores per-line carried-in time on the report, `carriedIn` could read the snapshot instead of entries. Today the entries are the only per-month record.
- Re-submitting a month replaces its `reportingLines`, so the notes follow the latest submission. That matches what the Submit screen shows.
