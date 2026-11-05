# Plan 066: Move the duration formatter into `Hugo/Domain` and use it for whole-hour splits

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 26e63f4..HEAD -- Hugo/Features/Reports/Domain/ServiceDurationFormatter.swift HugoTests/Features/Reports/Domain/ServiceDurationFormatterTests.swift Hugo/Features/Reports/Views/ReportingLineCard.swift Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift`
> Plan 061 changes `ServiceYearMonthRow.displayedHours`; the excerpt below
> shows it after plan 061. Any other difference is a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/061-service-month-record.md (edits `ServiceYearMonthRow.swift` first). Run after 063, which also edits ServiceYear files.
- **Category**: tech-debt
- **Planned at**: commit `26e63f4`, 2026-11-03
- **Issue**: [SLN-269](https://linear.app/sebastianln/issue/SLN-269)

## Why this matters

`ServiceDurationFormatter` lives in `Hugo/Features/Reports/Domain`, but Entries, Overview and ServiceYear all call it. AGENTS.md section 7 puts value logic that several features share in `Hugo/Domain`. Next to it, several views split seconds into hours and minutes by hand with `Int(seconds / 3_600)`. Each copy decides on its own whether to clamp negative values. After this plan, the formatter sits in `Hugo/Domain`, it offers the hours/minutes split, and the two view copies use it. Nothing on screen changes. This is the smallest of plans 060 to 066 and can be skipped without affecting the others.

## Current state

- `Hugo/Features/Reports/Domain/ServiceDurationFormatter.swift` (45 lines): `nonisolated enum ServiceDurationFormatter` with `string(from:)` ("01:30"), `accessibilityString(from:locale:)` and `hoursString(from:locale:)`. The first two start with:

  ```swift
  let clamped = max(duration, 0)
  let hours = Int(clamped / 3600)
  let minutes = Int(clamped.truncatingRemainder(dividingBy: 3600) / 60)
  ```

- Its tests: `HugoTests/Features/Reports/Domain/ServiceDurationFormatterTests.swift` (struct `DurationFormattingTests`).
- Callers (they need no edit after a move, since it is one module): `EntryRow.swift`, `CategoryProgressBreakdownView.swift`, `MonthlyReportEntryListView.swift`, `MonthlyReportTotalsView.swift`, `ReportingLineCard.swift`, `ServiceYearDetailView.swift`, `ServiceYearMonthRow.swift`, `TheocraticYearTotalsView.swift`, `YearlyGoalProgress.swift`.
- `Hugo/Features/Reports/Views/ReportingLineCard.swift:168-173`:

  ```swift
  private var actualDurationComponents: (hours: Int, minutes: Int) {
      let seconds = max(result.line.actualSeconds, 0)
      let hours = Int(seconds / 3_600)
      let minutes = Int(seconds.truncatingRemainder(dividingBy: 3_600) / 60)
      return (hours, minutes)
  }
  ```

- `Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift`, after plan 061:

  ```swift
  private var displayedHours: Int {
      Int(month.contribution.total / 3_600)
  }
  ```

- `Scripts/check-layout.sh` fails if a file in `Hugo/Domain` contains the whole word `Entry`, `Tracker`, `SubmittedReport`, `TheocraticYear` or `PublisherStatus`. The formatter file contains none of them.
- The Xcode project uses file-system synchronized groups, so moving a file needs no `project.pbxproj` edit.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Layout | `Scripts/check-layout.sh` | exit 0, no output |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/DurationFormattingTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:

- `Hugo/Features/Reports/Domain/ServiceDurationFormatter.swift` → `Hugo/Domain/ServiceDurationFormatter.swift` (move and edit)
- `HugoTests/Features/Reports/Domain/ServiceDurationFormatterTests.swift` → `HugoTests/Domain/ServiceDurationFormatterTests.swift` (move and add tests)
- `Hugo/Features/Reports/Views/ReportingLineCard.swift` (`actualDurationComponents` only)
- `Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift` (`displayedHours` only)
- `plans/README.md` (status row)

**Out of scope**:

- Any visible format. The README lists "durations appear in four different formats" as a separate, unplanned accessibility finding. That needs a product decision.
- `OverviewListView`'s `Duration.formatted(...)` calls, which use different visible styles.
- `DurationWheelPicker` (picker arithmetic, not display) and `ReportingLineCalculator` (the rounding core).
- Renaming `ServiceDurationFormatter`.

## Git workflow

- Branch: `advisor/066-duration-formatter`
- Conventional Commits, as in `git log`, for example `refactor: move the duration formatter into Domain`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Move the files

```sh
git mv Hugo/Features/Reports/Domain/ServiceDurationFormatter.swift Hugo/Domain/ServiceDurationFormatter.swift
git mv HugoTests/Features/Reports/Domain/ServiceDurationFormatterTests.swift HugoTests/Domain/ServiceDurationFormatterTests.swift
```

**Verify**: `Scripts/check-layout.sh` → exit 0; focused tests pass.

### Step 2: Add the hours/minutes split

In `ServiceDurationFormatter`, add:

```swift
/// Whole hours in `duration`, ignoring minutes and seconds. Negative values count as zero.
static func wholeHours(from duration: TimeInterval) -> Int {
    Int(max(duration, 0) / 3_600)
}

/// Whole minutes left over after `wholeHours(from:)`. Negative values count as zero.
static func remainderMinutes(from duration: TimeInterval) -> Int {
    Int(max(duration, 0).truncatingRemainder(dividingBy: 3_600) / 60)
}
```

Use them in `string(from:)` and `accessibilityString(from:locale:)` instead of the local `hours` and `minutes` computations.

Add to the tests: `wholeHoursDropsMinutesAndClampsNegatives` (`wholeHours(from: 5_400) == 1`, `wholeHours(from: -10) == 0`) and `remainderMinutesDropsSeconds` (`remainderMinutes(from: 5_459) == 30`, `remainderMinutes(from: -10) == 0`).

**Verify**: focused tests pass, 2 more than before.

### Step 3: Use the split in the two views

- `ReportingLineCard.actualDurationComponents`:

  ```swift
  private var actualDurationComponents: (hours: Int, minutes: Int) {
      let seconds = result.line.actualSeconds
      return (
          ServiceDurationFormatter.wholeHours(from: seconds),
          ServiceDurationFormatter.remainderMinutes(from: seconds)
      )
  }
  ```

- `ServiceYearMonthRow.displayedHours`: `ServiceDurationFormatter.wholeHours(from: month.contribution.total)`.

**Verify**:

- `grep -n '/ 3_600\|/ 3600' Hugo/Features/Reports/Views/ReportingLineCard.swift Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift Hugo/Domain/ServiceDurationFormatter.swift` → only the two lines inside `wholeHours` and `remainderMinutes` (as `3_600`)
- `Scripts/verify.sh` → exit 0

Commit: `refactor: move the duration formatter into Domain`.

## Test plan

- `DurationFormattingTests` (moved): 2 new tests; all existing tests unchanged.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `test -f Hugo/Domain/ServiceDurationFormatter.swift && test ! -e Hugo/Features/Reports/Domain/ServiceDurationFormatter.swift && echo ok` prints `ok`
- [ ] `git status --porcelain` lists only files from the Scope list (moves show as renames)
- [ ] `plans/README.md` row for 066 updated

## STOP conditions

Stop and report back if:

- `Scripts/check-layout.sh` rejects the moved file.
- `ServiceYearMonthRow.displayedHours` does not read `month.contribution.total` (plan 061 not done). Then skip that one change and report it.
- Any existing formatter test changes its expected output.

## Maintenance notes

- When the owner settles the duration display formats (the open accessibility finding), add the agreed styles to this formatter and move `OverviewListView` and `ReportingLineCard` onto them.
- New code that needs whole hours from seconds should call `ServiceDurationFormatter.wholeHours(from:)`, except the rounding core in `ReportingLineCalculator`, which has its own tested rules.
