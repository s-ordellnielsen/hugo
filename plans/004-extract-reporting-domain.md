# Plan 004: Extract and rename the monthly reporting domain

> **Executor instructions**: Move report computation out of SwiftUI views into
> pure value types, then rename and relocate the feature. Keep persisted model
> names unchanged. Update `plans/README.md` when all gates pass.
>
> **Drift check (run first)**:
> `git diff --stat c047d57..HEAD -- Hugo/Screens/Report Hugo/Utilities/YearMonth.swift Hugo/Utilities/functions.swift HugoTests`
> If Plan 003 has moved persistence as expected, compare symbols rather than old
> paths. Stop if report behavior has materially changed.

## Status

* **Priority**: P1
* **Effort**: L
* **Risk**: MED
* **Depends on**: Plans 001 and 003
* **Category**: tech-debt / performance / tests
* **Planned at**: commit `c047d57`, July 27, 2026

## Why this matters

`MonthlyReportListView` performs grouping, totals, model mapping, locale
formatting, and sorting inside a computed view property. The same 40-line
aggregation is copied into three preview blocks. Detail views then rescan entries
for main/separate totals. This plan makes reporting a tested domain operation,
leaves SwiftUI responsible for presentation, and puts the whole feature under
one predictable folder.

## Current state

* `MonthlyReportList.swift:14-50` groups `Entry` by `YearMonth`, sums duration and Bible studies, builds tracker dictionaries, force unwraps totals, hardcodes `en_US`, and sorts descending.
* `MonthlyReportDetailView.swift:28-93`, `MonthlyReportDetailDailyListView.swift:43-109`, and `MonthlyReportDetailLargeTotalView.swift:75-141` duplicate the same preview fixture and aggregation.
* `MonthlyReportDetailLargeTotalView.swift:14-32` scans `summary.entries` twice for primary and separate totals.
* `MonthlySummaryTracker` retains a live `Tracker`. Deleted trackers are skipped by `guard let tracker = entry.tracker`, even though V8 entries preserve `storedTracker` snapshots.
* `YearMonth` is a useful domain value but lives in `Utilities`.
* `formatDuration` is a global function in lowercase `functions.swift`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan004DerivedData CODE_SIGNING_ALLOWED=NO` | Exit 0 and reporting tests pass |
| Duplicate check | `rg -n 'Dictionary\(grouping: entries\)\|totalsByTrackerID\|trackerByID' Hugo --glob '*.swift'` | Matches only in `MonthlyReportBuilder.swift` |
| Old-name check | `rg -n '\b(ReportView\|MonthlySummaryTracker\|MonthlySummary)\b' Hugo --glob '*.swift'` | No obsolete type names after completion |

## Scope

**In scope**:

* Current `Hugo/Screens/Report/` tree, moved to `Hugo/Features/Reports/`.
* `Hugo/Utilities/YearMonth.swift` → report/domain location.
* `Hugo/Utilities/functions.swift` → named domain formatter.
* `Hugo/PreviewSupport/ReportPreviewFixtures.swift` — create.
* `HugoTests/Features/Reports/MonthlyReportBuilderTests.swift` — create.
* Existing duration and month tests from Plan 001 — rename/move as needed.
* Call sites in `AppRootView`/`ContentView` solely for `ReportsView` rename.
* `plans/README.md` status update.

**Out of scope**:

* Overview progress calculations; Plan 007 owns them.
* Persisting monthly report summaries.
* SMS composition, submission workflows, yearly reports, or theocratic-year UI.
* Renaming persisted `Tracker` or `Entry.tracker`.
* Adding a repository abstraction around `@Query`.

## Target layout and names

```text
Hugo/Features/Reports/
    ReportsView.swift
    Domain/
        YearMonth.swift
        MonthlyReportSummary.swift
        MonthlyReportBuilder.swift
        ServiceDurationFormatter.swift
    MonthlyReportListView.swift
    MonthlyReportRow.swift
    MonthlyReportDetailView.swift
    MonthlyReportTotalsView.swift
    MonthlyReportEntryListView.swift
Hugo/PreviewSupport/
    ReportPreviewFixtures.swift
```

Top-level names replace nested `Row`, `LargeTotal`, and `DailyList`. Keep
`YearMonth`; it is a conventional, precise value name and does not need a
cosmetic rename.

## Git workflow

* Branch: `advisor/004-reporting-domain`
* Commit domain extraction before view renames when practical.
* Suggested messages: `Extracted monthly report aggregation` and `Reorganized monthly report views`.

## Steps

### Step 1: Define report value types independent of view layout

Rename `MonthlySummary` to `MonthlyReportSummary`. It should contain:

* `id: YearMonth`
* total duration
* Bible-study count
* precomputed main-category duration
* precomputed separate-category duration
* sorted category summaries
* entries for detail navigation

Replace `MonthlySummaryTracker` with a value type such as
`MonthlyCategorySummary` containing stable identity, display name, icon, type,
and duration. Do not retain a live `Tracker` solely for presentation.

For live trackers, derive identity from `tracker.id`. For a deleted tracker,
fall back to `entry.storedTracker`; use a deterministic string key based on the
stored snapshot fields. Untracked entries with neither source still contribute
to the overall total and use localized “Untracked” presentation metadata.

**Verify**: New types compile and have no SwiftUI import.

### Step 2: Implement one pure `MonthlyReportBuilder`

Create a stateless type with a function equivalent to:

```swift
static func summaries(
    from entries: [Entry],
    calendar: Calendar = .current,
    locale: Locale = .current
) -> [MonthlyReportSummary]
```

It must group once, aggregate each month in one pass, sort months descending,
and sort category totals descending with a deterministic name tie-breaker.
Generate display names through `YearMonth.monthYearString(locale:)`; remove the
production hardcoded `en_US` locale.

Avoid force unwraps. Use dictionary defaults and explicit fallbacks. Keep the
builder synchronous and pure; do not create an `@Observable` ViewModel.

**Verify**: Builder tests cover empty input, month grouping across a year
boundary, descending order, category totals, main/separate totals, Bible-study
totals, deleted tracker fallback, fully untracked entries, and a fixed locale.
All tests pass.

### Step 3: Replace global duration formatting with a named formatter

Rename `functions.swift` to `ServiceDurationFormatter.swift` and replace the
global function with a small namespaced API, for example:

```swift
enum ServiceDurationFormatter {
    static func string(from duration: TimeInterval) -> String
}
```

Preserve Plan 001's exact `HH:mm` behavior. Update all current callers in report
and entry files. Plan 006 may move remaining entry callers later.

**Verify**: `rg -n '\bformatDuration\b|functions\.swift' Hugo HugoTests` returns
no matches, and duration characterization tests pass.

### Step 4: Make report views presentation-only and use explicit names

Rename and move:

* `ReportView` → `ReportsView`
* nested `MonthlyReportListView.Row` → `MonthlyReportRow`
* nested `MonthlyReportDetailView.LargeTotal` → `MonthlyReportTotalsView`
* nested `MonthlyReportDetailView.DailyList` → `MonthlyReportEntryListView`

`MonthlyReportListView` may keep `@Query`, but its only transformation should be
`MonthlyReportBuilder.summaries(from: entries)`. Child views receive immutable
summary values. Remove unused SwiftData imports from child presentation files.

Do not add ViewModels to simple immutable rows.

**Verify**: Old-name and duplicate checks return no obsolete implementation.
Full tests and build pass.

### Step 5: Deduplicate previews

Create one `@MainActor` report preview fixture using existing preview models and
`MonthlyReportBuilder`. Each report preview should consume that fixture rather
than declaring trackers, entries, dictionaries, and sort logic inline.

Keep previews close to their views, but centralize only the data construction.
Do not add production-only flags for previews.

**Verify**: `rg -n 'let tracker1|var monthlySummaries|Dictionary\(grouping:' Hugo/Features/Reports`
returns no preview duplication. Build succeeds with previews compiled.

## Test plan

* Use fixed Gregorian calendars, time zones, dates, and locales in builder tests.
* Assert values and ordering, including two categories with equal totals.
* Include an entry whose live tracker is `nil` but whose `storedTracker` is populated.
* Retain all Plan 001 duration and `YearMonth` expectations under new names/paths.
* No test may rely on `Date.now` or `Locale.current`.

## Done criteria

* [ ] Report source lives entirely under `Features/Reports` plus shared preview support.
* [ ] Monthly aggregation occurs in exactly one pure builder.
* [ ] Report views contain no dictionary aggregation or forced total unwraps.
* [ ] Deleted-category snapshots are represented in monthly summaries.
* [ ] `ReportsView` and explicit child view names replace generic nested names.
* [ ] The lowercase global `functions.swift` file and `formatDuration` global are gone.
* [ ] Duplicate preview calculations are gone.
* [ ] Complete tests pass.
* [ ] Plan 004 is marked DONE.

## STOP conditions

* The stored tracker snapshot cannot be read without changing the V8 persisted model.
* Aggregation behavior is ambiguous for entries with neither live nor stored category metadata.
* A path move collides with changes from Plan 003.
* The refactor begins adding report persistence or product features not present today.

## Maintenance notes

* Yearly/theocratic reporting should build on report value types, not add calculations back into SwiftUI bodies.
* If category snapshots later gain a persisted UUID, replace the deterministic fallback key and add migration coverage.
* Reviewers should verify locale injection and total conservation: category grouping must never change the overall entry duration.
