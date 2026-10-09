# Plan 035: Base theocratic-year totals on submitted reports

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat dc0b7f6..HEAD -- Hugo/Features/ServiceYear HugoTests/Features/TheocraticYear`
> Whitespace-only changes from plan 031 are expected.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/031-formatting-and-verification-baseline.md (independent of 032–034)
- **Category**: bug
- **Planned at**: commit `dc0b7f6`, 2026-10-09

## Why this matters

Year totals currently sum raw entries. Transferred minutes now exist as generated entries in the receiving month, and rounding means submitted hours differ from logged time. The owner's rule:
- For a month **with a real submission**, use the submitted hours.
- For a month **without one**, use the entry sum.

A transferred remainder then counts once, in the receiving month. Without this change, the yearly total disagrees with the per-month hours `ServiceYearMonthRow` already shows (`submittedHours` when submitted).

## Current state

`Hugo/Features/ServiceYear/TheocraticYearReportBuilder.swift`:

```swift
return TheocraticYearReport(
    year: year,
    months: months,
    totalSeconds: summaries.reduce(0) { $0 + $1.totalSeconds },
    totalBibleStudies: summaries.reduce(0) { $0 + $1.totalBibleStudies },
    mainDuration: summaries.reduce(0) { $0 + $1.mainDuration },
    separateDuration: summaries.reduce(0) { $0 + $1.separateDuration }
)
```

- `months[i].submittedReport` is the canonical submission (`canonicalSubmissionsByMonth`). A real submission has `submittedAt != .distantPast`. Sentinels (`.distantPast`) are **not** real and must fall back to entries.
- V11 `SubmittedReport.reportingLines: [SubmittedReportingLine]`. Each line has `type` (`.main`/`.separate`) and `submittedHours`. The migration populated lines for every real V10 submission. A real submission with **empty** `reportingLines` can still exist if it came from a pre-plan-033 V11 build; fall back to legacy `submittedHours` (all of it as main) for those.
- `ServiceYearMonthRow.swift:92-98` already shows `submittedReport.submittedHours` for submitted months.
- `TheocraticYearTotalsView` renders `totalSeconds`, `totalBibleStudies`, `mainDuration`, `separateDuration`. Its formatting stays unchanged.
- Tests: `HugoTests/Features/TheocraticYear/TheocraticYearReportBuilderTests.swift` (has `makeReport` helpers).

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan035 -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/TheocraticYearReportBuilderTests` | `** TEST SUCCEEDED **` |
| Gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope:** `TheocraticYearReportBuilder.swift`, `TheocraticYearReportBuilderTests.swift`.

**Out of scope:** `TheocraticYearReport.swift` field names, `TheocraticYearTotalsView`, `ServiceYearMonthRow`, `Hugo/Persistence/**`.

## Git workflow

Branch `advisor/035-year-totals`. Commit `Use submitted hours in theocratic-year totals`. Do not push.

## Steps

### Step 1: Per-month contribution

Add a private helper that returns `(total, main, separate, bibleStudies)` for one `TheocraticYearMonth`:
- Real submission with non-empty `reportingLines`: main = Σ `submittedHours * 3600` over `.main` lines, separate = the same over `.separate` lines, total = main + separate, studies = `totalBibleStudies ?? 0`.
- Real submission with empty `reportingLines`: total = main = `(submittedHours ?? 0) * 3600`, separate = 0, studies = `totalBibleStudies ?? 0`.
- Otherwise: the summary's `totalSeconds`, `mainDuration`, `separateDuration`, `totalBibleStudies` (zeros if no summary).

### Step 2: Sum contributions

Build the four totals from `months.map(contribution)` instead of `summaries`.

### Step 3: Tests

Add:
1. A submitted month with logged 12 h 40 min, main line 12 h `.transfer`; the next month has entries of 5 h including a 40 min generated entry and is unsubmitted → year total = 12 h + 5 h (the 40 min counted once).
2. A submitted month with line `.up` 13 h for 12 h 40 min logged → contributes 13 h.
3. A sentinel submission → falls back to entries.
4. A real submission with empty `reportingLines` and `submittedHours = 7` → contributes 7 h to total and main.
5. Main/separate split follows line types.

Existing tests whose expectations assumed entry sums for submitted months: update the expectations, and note each one in the commit message.

**Verify:** focused tests → `** TEST SUCCEEDED **`.

### Step 4: Gate

`Scripts/verify.sh` → exit 0.

## Done criteria

- [ ] Five new tests pass; `Scripts/verify.sh` exits 0
- [ ] `git status` shows only the two in-scope files
- [ ] `plans/README.md` row updated

## STOP conditions

- More than three existing tests need their expectations changed. That suggests the year view relies on entry sums somewhere this plan didn't anticipate.
- `TheocraticYearMonth` doesn't expose `submittedReport`/`summary` as described.

## Maintenance notes

- `totalSeconds` for submitted months is now whole hours. If a future UI shows minutes in the year total, they come only from unsubmitted months, and that is correct.
- Bible studies use the submitted value for submitted months, so they also match the report.
