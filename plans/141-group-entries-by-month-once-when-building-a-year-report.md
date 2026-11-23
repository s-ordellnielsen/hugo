# Plan 141: Build a year report by grouping entries by month once

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 5845483..HEAD -- Hugo/Features/ServiceYear/Domain/TheocraticYearReportBuilder.swift Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift Hugo/Features/Overview/Screens/OverviewView.swift`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). Never touch, stage or commit it.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW. Same results, fewer calendar calls. The existing report tests cover the output.
- **Depends on**: none
- **Category**: perf
- **Planned at**: commit `5845483`, 2026-11-23
- **Issue**: [SLN-321](https://linear.app/sebastianln/issue/SLN-321)

## Why this matters

`TheocraticYearReportBuilder.report` filters the year's entries once, then
`ServiceMonth.make` filters the same list again for each of the 12 months. Every
filter converts each entry's date to a `YearMonth` with a `Calendar`. For N
entries in a year that is about 13 x N calendar conversions per report. The
report is built on every render of a Year page, and also by the Planner target
settings screen and by the Planner when the target is a share of the yearly
goal. A past freeze on the owner's iPhone came from this screen building the
report several times per render, so the build must stay cheap. After this plan
each entry's month is computed twice instead of 13 times, with identical output.

Two small repeats in views get the same treatment: the Overview computes its
report reminder twice per render, and each Year month row filters all school
credits again.

## Current state

Files:

- `Hugo/Features/ServiceYear/Domain/TheocraticYearReportBuilder.swift` builds the year report.
- `Hugo/Features/Reports/Domain/ServiceMonth.swift` builds one month (`ServiceMonth.make`, line 99). Do not change it.
- `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift` is one Year page.
- `Hugo/Features/Overview/Screens/OverviewView.swift` is the Overview.

`TheocraticYearReportBuilder.swift` today:

```swift
let yearEntries = entries.filter { year.contains($0.date.yearMonth(using: calendar)) }
let months = year.months.map { month in
    ServiceMonth.make(
        month, entries: yearEntries, submissions: submissions, trackers: trackers,
        schoolCredits: schoolCredits, now: now, calendar: calendar, locale: locale)
}
```

`ServiceMonth.make` (line 109) starts with
`let monthEntries = entries.filter { $0.date.yearMonth(using: calendar) == month }`.
That filter stays. It will now run over a short list, so the cost is about N
conversions in total, not 12 x N.

`ServiceYearPageView.swift` lines 70 to 73:

```swift
ServiceYearMonthRow(
    month: month,
    schoolCredits: schoolCredits.filter { $0.yearMonth == month.id }
)
```

`SchoolCredit.yearMonth` is a non-optional `YearMonth`. `YearMonth` is `Hashable`.

`OverviewView.swift` (inside `OverviewDayView`): `reminderMonth` is a computed
property (line 68). The body reads it at line 91 (`if let reminderMonth`) and
again at line 108 (`.motion(Motion.presence, value: reminderMonth)`), so
`ReportReminderSchedule.reminderMonth` runs twice per render. The body already
caches `metrics` the same way: `let metrics = self.metrics`.

Conventions: Swift 6, 4-space indentation, `swift-format` strict. Domain code is
`nonisolated`. Tests use Swift Testing. Month identity is `YearMonth`
(`Hugo/Domain/YearMonth.swift`). Pass the `Calendar` in; never read
`Calendar.current` in new domain code.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |

`Scripts/verify.sh` runs the tests serially on its own simulator. Run it once
at the end. Do not run two test runs at the same time.

## Scope

**In scope**:

- `Hugo/Features/ServiceYear/Domain/TheocraticYearReportBuilder.swift`
- `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift`
- `Hugo/Features/Overview/Screens/OverviewView.swift`
- `HugoTests/Features/ServiceYear/Domain/TheocraticYearReportBuilderTests.swift`

**Out of scope**:

- `Hugo/Features/Reports/Domain/ServiceMonth.swift` and `MonthlyReportBuilder`. Their signatures are used by other code and tests.
- `PlannerView.swift`. Its year-entries query is a separate, riskier change.
- `Hugo/Resources/Localizable.xcstrings`.
- Any schema, model or `@Query` change.

## Git workflow

- Work on `main`. Commit per step. Use Conventional Commits, for example `perf: group entries by month once in the year report`.
- Do not push.
- Never stage `Hugo/Resources/Localizable.xcstrings`.

## Steps

### Step 1: Group the year's entries by month once

In `TheocraticYearReportBuilder.report`, replace the two lines that filter
`yearEntries` and map the months so that:

1. `yearEntries` is still the entries inside `year` (keep the existing filter, but compute the month once per entry).
2. Build `let entriesByMonth = Dictionary(grouping: yearEntries) { $0.date.yearMonth(using: calendar) }`. This is the single month conversion per entry. Keep the filter's `year.contains(...)` check by grouping all `entries`, then reading only `year.months`:

```swift
let entriesByMonth = Dictionary(grouping: entries) { $0.date.yearMonth(using: calendar) }
let months = year.months.map { month in
    ServiceMonth.make(
        month, entries: entriesByMonth[month] ?? [], submissions: submissions, trackers: trackers,
        schoolCredits: schoolCredits, now: now, calendar: calendar, locale: locale)
}
```

Remove the now-unused `yearEntries` variable. Entries outside the year are
ignored because only `year.months` are read.

**Verify**: `swift-format lint --strict --recursive Hugo/Features/ServiceYear` exits 0.

### Step 2: Add a test that pins the behavior

In `TheocraticYearReportBuilderTests.swift`, add one `@Test` that checks
entries are assigned to the right month at the edges. Model it on
`excludesEntriesOutsideRequestedYear` and use the file's `makeReport`, `date`
helpers. Cover: an entry on 2026-09-01 lands in the September 2026 month, an
entry on 2027-08-31 lands in the August 2027 month, an entry on 2026-08-31 and
one on 2027-09-01 land in no month, and the report total equals the sum of the
two in-year entries. Name it `groupsEntriesByMonthAtYearBoundaries`. Read the
file first to copy the exact helper signatures and the way a month's total is
read from `report.months`.

**Verify**: `Scripts/verify.sh` exits 0 (the new test passes; the 610 existing tests still pass).

### Step 3: Compute the school credits per month once

In `ServiceYearPageView.body`, before the `ScrollView`, add
`let creditsByMonth = Dictionary(grouping: schoolCredits, by: \.yearMonth)`.
Replace `schoolCredits.filter { $0.yearMonth == month.id }` with
`creditsByMonth[month.id] ?? []`. Keep the element order as it was (the filter
kept query order and `Dictionary(grouping:)` keeps it inside each group).

**Verify**: `swift-format lint --strict --recursive Hugo/Features/ServiceYear` exits 0.

### Step 4: Read the Overview reminder once per render

In `OverviewDayView.body`, add `let reminderMonth = self.reminderMonth` next to
the existing `let metrics = self.metrics` line. The local constant shadows the
computed property in the rest of the body. Change nothing else.

**Verify**: `Scripts/verify.sh` exits 0.

## Test plan

- One new test (Step 2). Output of the existing builder, `ServiceMonth`, `YearlyGoalProgress` and Planner tests must not change.
- Views are not unit tested here. The owner checks them by hand (below).

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, with at least one more test than before
- [ ] `grep -n "yearEntries" Hugo/Features/ServiceYear/Domain/TheocraticYearReportBuilder.swift` returns no matches
- [ ] `grep -n "schoolCredits.filter" Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift` returns no matches
- [ ] `git status --short` shows only the four in-scope files (plus the owner's `Localizable.xcstrings`, unstaged)
- [ ] `plans/README.md` row updated

Owner check after the build: open the Year tab on a year with entries and a
school credit, confirm the month totals and school credit rows look as before.
Open the Overview in a month where the report reminder shows and confirm it
still appears and disappears with the animation.

## STOP conditions

Stop and report if:

- `ServiceMonth.make` or `TheocraticYearReportBuilder.report` no longer matches the excerpts.
- An existing test fails after Step 1 and the cause is not a typo in your change. A failing test means the grouping changed behavior, for example a calendar or time-zone difference.
- `SchoolCredit.yearMonth` is optional or not `Hashable` in the live code.
- You need to edit an out-of-scope file.

## Maintenance notes

- `ServiceMonth.make` still filters its input by month. If it later receives pre-grouped input everywhere, that filter can go, but its tests and `SubmitReportFormModelTests` call it directly, so leave it.
- Deferred on purpose: `PlannerPager` loads the whole year's entries even when the target is the monthly goal. Fixing it means moving the query into a child view only built for `.yearlyGoalShare`, which changes view identity and can reset the pager's scroll position. Do it only with an iPad and iPhone check.
- A review should confirm no behavior change for entries that sit exactly on a month boundary in a non-UTC calendar.
