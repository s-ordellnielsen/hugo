# Plan 018: Stop rebuilding report aggregations on every render

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for plan 018
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat d65afec..HEAD -- Hugo/Features/ServiceYear Hugo/Features/Reports/SubmitReportFormModel.swift Hugo/Features/Reports/Domain Hugo/Domain/YearMonth.swift Hugo/Features/Entries/EntryRow.swift`
> If any in-scope file changed, compare the "Current state" excerpts against
> the live code; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/016-green-verification-gate.md
- **Category**: perf
- **Planned at**: commit `d65afec`, 2026-08-06

## Why this matters

The Year screen and the Submit sheet both recompute full report aggregations
inside SwiftUI computed properties, so the work runs on **every body
evaluation** rather than when the data changes. Three multipliers stack:

- `ServiceYearView` renders a paging `TabView` over *all* theocratic years, and
  builds a complete `TheocraticYearReport` per page — each one filtering the
  entire unbounded `entries` array.
- `TheocraticYear.availableYears` runs `Calendar.dateComponents` once per entry,
  every render.
- `SubmitReportFormModel.summary` is a computed property that re-filters and
  re-aggregates on each of its several accesses per interaction.

For a publisher with a few years of history this is thousands of calendar
operations and several dictionary rebuilds per frame, on the two screens that
matter most. Nothing here changes behavior — only when the work happens.

## Current state

### A. `ServiceYearView` — per-page report construction

`Hugo/Features/ServiceYear/ServiceYearView.swift:4-34`:

```swift
struct ServiceYearView: View {
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @Query(sort: \SubmittedReport.year) private var submissions: [SubmittedReport]
    @State private var selectedYear: TheocraticYear?

    var resetToken: UUID = UUID()

    private var years: [TheocraticYear] {
        TheocraticYear.availableYears(entryDates: entries.map(\.date), now: .now)
    }
    …
    var body: some View {
        TabView(selection: yearSelection) {
            ForEach(years) { year in
                NavigationStack {
                    ServiceYearPageView(
                        report: TheocraticYearReportBuilder.report(for: year, entries: entries, submissions: submissions),
                        initialMonth: year == currentYear ? Date().yearMonth() : nil
                    )
```

`TheocraticYear.availableYears` (`Structs/TheocraticYear.swift:30-41`) maps
every entry date through `TheocraticYear.containing`, which calls
`calendar.dateComponents([.year, .month], from:)`.

`TheocraticYearReportBuilder.report` (`Structs/TheocraticYearReportBuilder.swift:5-44`)
filters all entries, calls `MonthlyReportBuilder.summaries`, and builds a
month dictionary.

### B. `canonicalSubmission` rebuilds the whole map for one lookup

`Structs/TheocraticYearReportBuilder.swift:46-51`:

```swift
static func canonicalSubmission(
        for month: YearMonth,
        in submissions: [SubmittedReport]
) -> SubmittedReport? {
        canonicalSubmissionsByMonth(submissions)[month]
}
```

It is called from two computed properties in `SubmitReportFormModel`
(`previousSubmission` line 63, `existingSubmission` line 92), each of which is
read multiple times per interaction.

### C. `SubmitReportFormModel.summary` is computed

`Hugo/Features/Reports/SubmitReportFormModel.swift:57-59` and `218-220`:

```swift
var summary: MonthlyReportSummary? {
    MonthlyReportBuilder.summaries(from: monthEntries, calendar: calendar).first
}
…
private var monthEntries: [Entry] {
    entries.filter { $0.date.yearMonth(using: calendar) == month }
}
```

Read from `body` (via `SubmitReportView.summary`), from `recompute()` (line
242), and twice inside `persistSubmission` (lines 163, 179). The model already
has the right shape for caching: `load(entries:submissions:)` (line 49) is the
single ingestion point and already calls `recompute()`.

### D. Per-call `DateFormatter`

`Hugo/Domain/YearMonth.swift:55-87` — both `monthYearString` and `monthName`
allocate a `DateFormatter` on every call. These are invoked per month row, per
page, and inside every report build.

### E. Shadow per row

`Hugo/Features/Entries/EntryRow.swift:74` — `.shadow(color: .primary.opacity(0.05), radius: 16, y: 12)`
on every row, in a plain `ScrollView` with no cell reuse. Offscreen shadow
rasterization is pure cost.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan018 CODE_SIGNING_ALLOWED=NO` | `TEST SUCCEEDED` |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:
- `Hugo/Features/ServiceYear/ServiceYearView.swift`
- `Hugo/Features/ServiceYear/Structs/TheocraticYearReportBuilder.swift`
- `Hugo/Features/ServiceYear/Structs/TheocraticYear.swift`
- `Hugo/Features/Reports/SubmitReportFormModel.swift`
- `Hugo/Domain/YearMonth.swift`
- `Hugo/Features/Entries/EntryRow.swift`
- `HugoTests/Features/TheocraticYear/TheocraticYearReportBuilderTests.swift`
- `HugoTests/Features/Reports/SubmitReportFormModelTests.swift`
- `HugoTests/Features/Reports/YearMonthTests.swift`

**Out of scope** (do NOT touch):
- `MonthlyReportBuilder` — the aggregation itself is fine; only its call
  frequency is wrong.
- `Hugo/Features/Overview/**` — plan 017 owns the Overview query changes.
- Adding a repository or data-access layer. `plans/README.md` explicitly
  rejected that; keep the caching inside the existing types.
- `Hugo/Persistence/**`.

## Git workflow

- Branch: `advisor/018-reporting-aggregation-performance`
- One commit per step, message style: `` `018` Step N — <summary> ``
- Do NOT push or open a PR.

## Steps

### Step 1: Cache the month formatters

In `Hugo/Domain/YearMonth.swift`, hoist the two `DateFormatter` instances into
cached statics keyed by locale+calendar+format, or replace them with
`Date.FormatStyle`. Prefer the formatter cache — it preserves the exact
`LLLL yyyy` / `LLLL` output, and month-name casing differs between
`FormatStyle` and `dateFormat` in some locales including Danish.

Target shape:

```swift
extension YearMonth {
    private static let formatterCache = FormatterCache()

    private final class FormatterCache: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [String: DateFormatter] = [:]

        func formatter(format: String, locale: Locale, calendar: Calendar) -> DateFormatter {
            let key = "\(format)|\(locale.identifier)|\(calendar.identifier)|\(calendar.timeZone.identifier)"
            lock.lock()
            defer { lock.unlock() }
            if let existing = storage[key] { return existing }
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = format
            storage[key] = formatter
            return formatter
        }
    }
}
```

`monthYearString` and `monthName` then look up `"LLLL yyyy"` / `"LLLL"`.
Keep both methods `nonisolated` — they are called from `nonisolated` contexts.

**Verify**: `HugoTests/Features/Reports/YearMonthTests.swift` (8 existing tests)
→ all pass unchanged. Add one test asserting two calls with the same locale
return identical strings.

### Step 2: Make `canonicalSubmissionsByMonth` the public API

In `TheocraticYearReportBuilder`, change `canonicalSubmissionsByMonth` from
`private` to `static` internal, and keep `canonicalSubmission(for:in:)` as a
thin convenience for tests only. Then update `SubmitReportFormModel` to build
the map **once** in `load(entries:submissions:)` and store it:

```swift
private var submissionsByMonth: [YearMonth: SubmittedReport] = [:]

func load(entries: [Entry], submissions: [SubmittedReport]) {
    self.entries = entries
    self.submissions = submissions
    self.submissionsByMonth = TheocraticYearReportBuilder.canonicalSubmissionsByMonth(submissions)
    recompute()
}
```

`previousSubmission` and `existingSubmission` then index `submissionsByMonth`
instead of rebuilding it. **Preserve the existing semantics exactly**: the
sentinel rule (`submittedAt == .distantPast` means "never submitted"), the
real-beats-sentinel preference, and the newest-wins tiebreak all live in
`canonicalSubmissionsByMonth` and must not be reimplemented at the call site.

**Verify**: `grep -n "canonicalSubmissionsByMonth" Hugo` → 2 call sites (builder
+ form model). All 13 tests in `SubmitReportFormModelTests.swift` pass unchanged.

### Step 3: Cache `summary` and `monthEntries` in the form model

Convert both to stored properties refreshed by `load()`:

```swift
private(set) var summary: MonthlyReportSummary?
private var monthEntries: [Entry] = []

func load(entries: [Entry], submissions: [SubmittedReport]) {
    self.entries = entries
    self.submissions = submissions
    self.submissionsByMonth = TheocraticYearReportBuilder.canonicalSubmissionsByMonth(submissions)
    self.monthEntries = entries.filter { $0.date.yearMonth(using: calendar) == month }
    self.summary = MonthlyReportBuilder.summaries(from: monthEntries, calendar: calendar).first
    recompute()
}
```

`recompute()` then reads the stored `summary` instead of recomputing it.

**Careful**: `summary` is currently `var summary: MonthlyReportSummary?` and is
read by `SubmitReportView.summary` (line 21-23). Making it `private(set) var`
keeps that working. `SubmitReportView` already calls `syncModel()` on appear
and on both `@Query` changes (lines 149-151), so the cache is refreshed
whenever the data does.

**Verify**: all 13 `SubmitReportFormModelTests` pass. Add a test asserting that
`summary` is non-nil after `load(entries:submissions:)` with in-month entries,
and nil before any `load`.

### Step 4: Build each year's report once, not per render

In `ServiceYearView`, replace the two computed properties with state refreshed
on data change:

```swift
@State private var years: [TheocraticYear] = []
@State private var reportsByYear: [TheocraticYear: TheocraticYearReport] = [:]

private func rebuild() {
    let available = TheocraticYear.availableYears(entryDates: entries.map(\.date), now: .now)
    years = available
    reportsByYear = Dictionary(
        uniqueKeysWithValues: available.map {
            ($0, TheocraticYearReportBuilder.report(for: $0, entries: entries, submissions: submissions))
        }
    )
}
```

driven by `.onAppear { rebuild() }`, `.onChange(of: entries) { rebuild() }`,
`.onChange(of: submissions) { rebuild() }`. The `ForEach` then reads
`reportsByYear[year]`.

This still builds all years up front. That is acceptable and much cheaper than
the status quo — but if `years.count` is large the eager build is wasteful, so
guard it: build the active year plus its immediate neighbours eagerly and fill
the rest lazily **only if** a measurement shows it matters. Do not add that
complexity speculatively.

Additionally, `TheocraticYear.availableYears` only needs the min and max entry
date. Change it to compute those in one pass instead of mapping every date
through `containing`:

```swift
static func availableYears(entryDates: [Date], now: Date, calendar: Calendar = .current) -> [TheocraticYear] {
    let currentYear = containing(now, calendar: calendar)
    guard let earliest = entryDates.min(), let latest = entryDates.max() else {
        return [currentYear]
    }
    let firstYear = min(containing(earliest, calendar: calendar), currentYear)
    let lastYear = max(containing(latest, calendar: calendar), currentYear)
    return (firstYear.startYear...lastYear.startYear).map(TheocraticYear.init(startYear:))
}
```

This reduces N `dateComponents` calls to 2.

**Verify**: all 8 tests in `HugoTests/Features/TheocraticYear/TheocraticYearTests.swift`
pass unchanged — they already cover the empty-entries and spanning cases.

### Step 5: Drop the per-row shadow

In `EntryRow.swift`, remove `.shadow(color: .primary.opacity(0.05), radius: 16, y: 12)`
(line 74). The rows already sit on `Color(.systemGroupedBackground)` with a
`secondarySystemBackground` fill, which provides the separation the shadow was
adding. If the design genuinely needs depth, use a 1pt
`.stroke(Color(.separator), lineWidth: 0.5)` on the shape instead — it does not
trigger offscreen rasterization.

**Verify**: `grep -n "shadow" Hugo/Features/Entries/EntryRow.swift` → no matches.
Manual: scroll a list of 20+ entries — no visual regression beyond the shadow.

## Test plan

New tests (Swift Testing — model after
`HugoTests/Features/TheocraticYear/TheocraticYearReportBuilderTests.swift`,
which uses plain `struct` + `@Test` + `#expect`):

- `HugoTests/Features/Reports/YearMonthTests.swift`
  - `repeatedMonthNameCallsReturnIdenticalStrings` — cache correctness.
  - `monthNameRespectsExplicitLocale` — asserts a Danish locale still yields
    the Danish month name, proving the cache key includes locale.
- `HugoTests/Features/Reports/SubmitReportFormModelTests.swift`
  - `summaryIsNilBeforeLoad`
  - `summaryIsPopulatedAfterLoad`
  - `existingSubmissionPrefersRealOverSentinel` — pins the semantics Step 2
    must not break (a sentinel with `submittedAt == .distantPast` and a real
    submission for the same month → the real one wins).
- `HugoTests/Features/TheocraticYear/TheocraticYearTests.swift`
  - `availableYearsWithNoEntriesReturnsCurrentYearOnly` — guards the new
    `guard let earliest` branch.

Verification: test command → `TEST SUCCEEDED`, 6 more tests than before.

## Done criteria

ALL must hold:

- [ ] `grep -n "var summary: MonthlyReportSummary? {" Hugo/Features/Reports/SubmitReportFormModel.swift` → no match (it is now stored)
- [ ] `grep -n "canonicalSubmissionsByMonth(submissions)\[month\]" Hugo` → at most one match, inside the test-convenience method
- [ ] `grep -n "TheocraticYearReportBuilder.report(for:" Hugo/Features/ServiceYear/ServiceYearView.swift` → no match inside the `ForEach` body
- [ ] `grep -n "shadow" Hugo/Features/Entries/EntryRow.swift` → no matches
- [ ] `Scripts/verify.sh` exits 0
- [ ] Test count increased by 6; all pass
- [ ] `git status` shows no files outside the in-scope list
- [ ] `plans/README.md` row for 018 updated

## STOP conditions

Stop and report if:

- Any existing test in `SubmitReportFormModelTests.swift` or
  `TheocraticYearReportBuilderTests.swift` fails. Those 27 tests encode the
  sentinel/canonical-submission semantics from plans 012–015; a failure means
  the cache changed behavior, which is not allowed here.
- Making `summary` a stored property causes an `@Observable` update loop
  (symptom: the Submit sheet re-renders continuously). If `load()` is being
  called from `body`, stop — the fix is in the view, not the model, and needs
  a decision.
- `Step 4`'s `.onChange(of: entries)` does not fire because `[Entry]` equality
  is reference-based and SwiftData returns a new array each time — if you
  observe a render loop, stop and report rather than switching to a polling
  workaround.
- The formatter cache changes any month string in any locale.

## Maintenance notes

- The cache invariant is: **`SubmitReportFormModel` state is only valid after
  `load()`.** Any new derived property must be refreshed there, not computed
  ad hoc. Add new ones next to `summary` in `load()`.
- `ServiceYearView.rebuild()` is now the single place year data is derived. A
  future backfill feature that lets users add entries to old years must call it.
- The `FormatterCache` is `@unchecked Sendable` with an `NSLock`. If Swift 6
  gains a first-class cached-formatter API, replace it.
- Deliberately deferred: lazy per-page report construction, and bounding the
  `ServiceYearView` `@Query` by date. Both are only worth it if profiling after
  this plan still shows a problem.
- Reviewer should scrutinize: Step 2 and Step 3 together must not change which
  `SubmittedReport` wins for a month. That logic caused plan 014 to be
  abandoned; treat it as load-bearing.
