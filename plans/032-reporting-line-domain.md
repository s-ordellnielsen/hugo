# Plan 032: Compute reports as V11 reporting lines with per-line rounding

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat dc0b7f6..HEAD -- Hugo/Features/Reports/Domain HugoTests/Features/Reports`
> Whitespace-only differences from plan 031 are expected. Any other mismatch
> with the excerpts below is a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW (pure value logic, nothing calls it until plan 033)
- **Depends on**: plans/031-formatting-and-verification-baseline.md
- **Category**: direction
- **Planned at**: commit `dc0b7f6`, 2026-10-09

## Why this matters

Schema V11 stores a report as **reporting lines**: one aggregate "Field Service" line for all `.main` categories, plus one line per `.separate` category. Each line has its own rounding rule, and a transferred remainder becomes a generated `Entry` in the next month. The domain code still rounds a single report-wide total (`ReportRoundingCalculator`). This plan adds the pure value types and calculator that plans 033 and 034 build on. It does not change any caller.

## Current state

- `Hugo/Features/Reports/Domain/ReportRoundingCalculator.swift`: `compute(summary:carriedIn:rule:)` rounds `summary.totalSeconds + carriedIn` once with one rule, then spreads whole hours across categories with a private largest-remainder helper `distributeHours(submittedHours:categories:)`. **Keep this file unchanged in this plan.** Plan 033 deletes it.
- Persisted line shape, `Hugo/Persistence/SchemaVersions/V11/SubmittedReportV11.swift:124-171` (read only, do not edit):

```swift
struct SubmittedReportingLine: Codable, Hashable, Identifiable {
    var typeRaw: String = ""
    /// Unused for aggregate `.main` line; always "" there.
    var typeName: String = ""
    var durationInSeconds: TimeInterval = 0
    var submittedHours: Int = 0
    var roundingRaw: String = RoundingRule.defaultValue.rawValue
    // id: "" for .main, otherwise typeName
    // remainder: |duration - submittedHours * 3600|
}
```

- `Entry` (V11, `Hugo/Persistence/SchemaVersions/V11/EntryV11.swift`) has `tracker: Tracker?`, `storedTracker: EntryTracker?` (`name`, `icon`, `type: TrackerType`), and carry linkage `sourceSubmission`, `sourceReportingLineID: String?`, `sourceReportYear: Int?`, `sourceReportMonth: Int?`. The migration stage sets all four on generated carry entries. `sourceSubmission` is nullified if the report is deleted, so **`sourceReportYear`/`sourceReportMonth` are the durable marker** of a generated entry.
- `TrackerType` has `.main` and `.separate`. `RoundingRule` has `.up`, `.down`, `.transfer` (`Hugo/Domain/RoundingRule.swift`).
- How the V10→V11 migration (`Hugo/Persistence/HugoMigrationPlan.swift:292-357`) builds lines. New runtime code must produce the same shape:
  - separate line: `typeRaw "separate"`, `typeName = category name`, `durationInSeconds = actual seconds`
  - main line: `typeRaw "main"`, `typeName ""`, sums all `.main` categories
  - `roundingRaw`: `"up"`, `"down"`, `"transfer"`, or `""` when there was no remainder
- Untracked entries (no `tracker`, no `storedTracker`) date from V1, before categories existed, and were field service. **They belong to the main line.**
- Conventions: domain types are `nonisolated` structs/enums with static functions (see `MonthlyReportBuilder.swift`). Tests use Swift Testing (`import Testing`, `@Test`, `#expect`); pattern: `HugoTests/Features/Reports/ReportRoundingCalculatorTests.swift`.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan032 -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/ReportingLineCalculatorTests` | `** TEST SUCCEEDED **` |
| Gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope:**
- `Hugo/Features/Reports/Domain/ReportingLine.swift` (create)
- `Hugo/Features/Reports/Domain/ReportingLineCalculator.swift` (create)
- `HugoTests/Features/Reports/ReportingLineCalculatorTests.swift` (create)

**Out of scope:**
- `ReportRoundingCalculator.swift`, `ReportComposer.swift`, `SubmitReportFormModel.swift`, every view (plans 033/034).
- Anything under `Hugo/Persistence/**`.

## Git workflow

Branch `advisor/032-reporting-lines`. One commit: `Add reporting-line calculator`. Do not push.

## Steps

### Step 1: Add the value types

Create `Hugo/Features/Reports/Domain/ReportingLine.swift`:

```swift
import Foundation

/// One line of a monthly report: the aggregate Field Service line
/// (`id == ""`) or one separate category (`id == category name`).
nonisolated struct ReportingLine: Identifiable, Hashable, Sendable {
    let id: String
    let type: TrackerType
    let name: String              // separate: category name; main: "" (UI localizes)
    let iconName: String
    /// All seconds logged on this line in the month, including carried-in entries.
    let actualSeconds: TimeInterval
    /// The part of `actualSeconds` that came from generated carry entries.
    let carriedInSeconds: TimeInterval
    /// Source months of the carried-in seconds, for "↘ 15 min from May".
    let carriedInFrom: [YearMonth]

    var remainderSeconds: TimeInterval { actualSeconds.truncatingRemainder(dividingBy: 3_600) }
    var needsRule: Bool { remainderSeconds > 0 }
}

nonisolated enum RemainderDisposition: Hashable, Sendable {
    case none                                  // whole hours, nothing to decide
    case undecided(seconds: TimeInterval)      // remainder exists, no rule picked
    case roundedUp(seconds: TimeInterval)      // seconds added to reach the next hour
    case roundedDown(seconds: TimeInterval)
    case transferred(seconds: TimeInterval)
}

nonisolated struct ReportingLineResult: Identifiable, Hashable, Sendable {
    let line: ReportingLine
    let rule: RoundingRule?
    let submittedHours: Int
    let disposition: RemainderDisposition
    var id: String { line.id }
}
```

`YearMonth` must be `Hashable` and `Sendable` already. If it isn't, STOP.

**Verify:** the project builds (run the focused test command; a "no tests" result is fine at this point).

### Step 2: Build lines from entries

In `ReportingLineCalculator.swift`, add `nonisolated enum ReportingLineCalculator` with:

```swift
static func lines(from entries: [Entry], calendar: Calendar = .current) -> [ReportingLine]
```

Rules:
1. Resolve each entry's category: `tracker` (name, iconName, type) if present, else `storedTracker` (name, icon, type), else untracked (type `.main`).
2. Main line: every entry whose resolved type is `.main` or untracked. `id ""`, `type .main`, `name ""`, `iconName "figure.walk"`. **Always emit the main line, even with zero seconds**, because zero-activity months can still be submitted.
3. Separate lines: entries with resolved type `.separate`, **grouped by name** (two trackers with the same name merge, since the line id is the name). Icon: the icon of the first entry in date order. Emit only names that have at least one entry.
4. An entry is a generated carry entry when `sourceReportYear != nil && sourceReportMonth != nil`. Add its duration to its line's `carriedInSeconds`, and append `YearMonth(year:month:)` to `carriedInFrom` (deduplicated, ascending).
5. Order: main line first, then separate lines by `name.localizedStandardCompare`.

### Step 3: Compute one line

```swift
static func compute(_ line: ReportingLine, rule: RoundingRule?) -> ReportingLineResult
```

With `whole = Int(line.actualSeconds / 3_600)` and `r = line.remainderSeconds`:

| Condition | submittedHours | disposition | stored rule |
|---|---|---|---|
| `r == 0` | `whole` | `.none` | `nil` (ignore the passed rule) |
| `r > 0`, rule `nil` | `whole` | `.undecided(r)` | `nil` |
| `.up` | `whole + 1` | `.roundedUp(3_600 - r)` | `.up` |
| `.down` | `whole` | `.roundedDown(r)` | `.down` |
| `.transfer` | `whole` | `.transferred(r)` | `.transfer` |

Also add:

```swift
static func compute(_ lines: [ReportingLine], rules: [String: RoundingRule]) -> [ReportingLineResult]
static func isComplete(_ results: [ReportingLineResult]) -> Bool  // false if any .undecided
```

### Step 4: Persisted-line mapping

```swift
extension ReportingLineResult {
    var persisted: SubmittedReport.SubmittedReportingLine {
        .init(
            typeRaw: line.type.rawValue,
            typeName: line.id,
            durationInSeconds: line.actualSeconds,
            submittedHours: submittedHours,
            roundingRaw: rule?.rawValue ?? ""
        )
    }
}
```

This matches the migration's encoding (`""` when no remainder).

### Step 5: Tests

Create `HugoTests/Features/Reports/ReportingLineCalculatorTests.swift` (`@MainActor struct`, because it builds `Entry`/`Tracker` models; use `InMemoryModelContainer.make()` from `HugoTests/TestSupport` if inserting is required, otherwise construct without inserting). Cases:

1. Empty entries → exactly one main line, 0 seconds.
2. Two `.main` trackers plus an untracked entry → one main line with the summed seconds.
3. Two separate trackers with the same name → one separate line.
4. A generated entry (`sourceReportYear 2026`, `sourceReportMonth 5`, 900 s) → `carriedInSeconds == 900`, `carriedInFrom == [YearMonth(year: 2026, month: 5)]`, and those 900 s are also included in `actualSeconds`.
5. Line order: main first, then separate lines alphabetically.
6. Compute table: 5_400 s with `nil` → `.undecided(1_800)`, 1 h; `.up` → 2 h, `.roundedUp(1_800)`; `.down` → 1 h; `.transfer` → 1 h, `.transferred(1_800)`; 7_200 s with `.up` → 2 h, `.none`, rule `nil`.
7. `isComplete` is false with one undecided line and true once every remainder line has a rule.
8. `persisted` of a main line has `typeName == ""` and `id == ""`; a whole-hour line has `roundingRaw == ""`.

**Verify:** focused test command → `** TEST SUCCEEDED **`.

### Step 6: Gate

`Scripts/verify.sh` → exit 0.

## Test plan

See step 5. Model the structure after `ReportRoundingCalculatorTests.swift`.

## Done criteria

- [ ] The three new files exist; no other file is modified (`git status`)
- [ ] `ReportingLineCalculatorTests` passes with at least 8 tests
- [ ] `Scripts/verify.sh` exits 0
- [ ] `plans/README.md` row updated

## STOP conditions

- `SubmittedReport.SubmittedReportingLine` is not reachable as written in step 4 (alias mismatch in `Hugo/Persistence/AppSchema.swift`).
- `YearMonth` is not `Hashable`/`Sendable`.
- A step seems to require editing `Hugo/Persistence/**`.

## Maintenance notes

- Separate lines are keyed by **category name**, because the shipped V11 schema keys them that way. Renaming a separate category between a transfer and the next submission orphans the carried minutes onto a line with the old name. Moving to stable category IDs needs a schema change and is deliberately deferred.
- Untracked entries count as Field Service. If that assumption changes, change step 2 rule 2 and test 2.
