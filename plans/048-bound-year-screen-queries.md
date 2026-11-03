# Plan 048: Load only one service year per Year page and build its report once per render

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 3f8d48b..HEAD -- Hugo/Features/ServiceYear/ServiceYearView.swift Hugo/Features/ServiceYear/ServiceYearPageView.swift Hugo/Features/ServiceYear/TheocraticYear.swift HugoTests/Features/TheocraticYear/TheocraticYearTests.swift`
> If any of these changed since this plan was written, compare the "Current
> state" excerpts against the live code before proceeding. On a mismatch,
> treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/045-flag-changes-after-submission.md (it makes each month's report check heavier, so measure after it)
- **Category**: perf
- **Planned at**: commit `3f8d48b`, 2026-10-12

## Why this matters

The Year tab pages horizontally through service years. Today the tab loads every entry ever recorded, passes the whole array to each page, and each page runs `TheocraticYearReportBuilder.report` three times per render, because `report` is a computed property read three times in `body`. Each run computes a calendar month for every entry ever. That work repeats on every page swipe, on every scroll past the top edge (the parent stores per-page scroll state, which re-renders all pages), and on every CloudKit import that touches an entry. A pioneer logs around a thousand entries a year, so the cost grows every year the app is used. AGENTS.md also asks for no heavy computation in view bodies. After this plan each page queries only its own September-to-August range, and builds its report once per render.

## Current state

- `Hugo/Features/ServiceYear/ServiceYearView.swift:4-19, 37-48`:

  ```swift
  struct ServiceYearView: View {
      @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
      @Query(sort: \SubmittedReport.year) private var submissions: [SubmittedReport]

      @State private var scrollPosition: TheocraticYear.ID?
      @State private var displayedYear: TheocraticYear?
      @State private var scrolledPages: [TheocraticYear.ID: Bool] = [:]

      var resetToken: UUID = UUID()

      private var years: [TheocraticYear] {
          TheocraticYear.availableYears(
              entryDates: entries.map(\.date),
              now: .now
          )
      }
      ...
                      ForEach(years) { year in
                          ServiceYearPageView(
                              year: year,
                              entries: entries,
                              submissions: submissions,
                              onScrolledFromTopChange: { newValue in
                                  scrolledPages[year.id] = newValue
                              }
                          )
                          .containerRelativeFrame(.horizontal)
                      }
  ```

  Callers: `AppRootView.swift:89` `ServiceYearView(resetToken: yearResetToken)` and the file's `#Preview { ServiceYearView().modelContainer(.preview) }`. `years` is also used in `.onChange(of: scrollPosition)`.

- `Hugo/Features/ServiceYear/ServiceYearPageView.swift:4-28` (plus an empty-year card and a `#Preview` that passes `ReportPreviewFixtures.entries` and `submissions: []`):

  ```swift
  struct ServiceYearPageView: View {
      let year: TheocraticYear
      let entries: [Entry]
      let submissions: [SubmittedReport]

      var onScrolledFromTopChange: ((Bool) -> Void)? = nil

      private var report: TheocraticYearReport {
          TheocraticYearReportBuilder.report(
              for: year,
              entries: entries,
              submissions: submissions
          )
      }

      var body: some View {
          ScrollView {
              VStack(spacing: HugoLayout.Spacing.card) {
                  if report.hasEntries {
                      TheocraticYearTotalsView(report: report)
                  } else {
                      emptyYearCard
                  }

                  ForEach(report.months) { month in
  ```

- `Hugo/Features/ServiceYear/TheocraticYear.swift`: `nonisolated struct TheocraticYear` with `startYear`, `months` (Sep..Dec of `startYear`, Jan..Aug of `startYear + 1`), `contains(_:)`, `containing(_:calendar:)` and `availableYears(entryDates:now:calendar:)`, which only uses the minimum and maximum of `entryDates`.
- `YearMonth.date(day:calendar:)` (`Hugo/Domain/YearMonth.swift:102-110`) returns the first instant of a month.
- Bounded-query pattern to copy: `SubmitReportView.init` (`Hugo/Features/Reports/SubmitReportView.swift:24-30`):

  ```swift
  let start = month.date()
  let end = month.nextMonth().date()
  _entries = Query(
      filter: #Predicate<Entry> { $0.date >= start && $0.date < end },
      sort: \Entry.date,
      order: .reverse
  )
  ```

- Tests: `HugoTests/Features/TheocraticYear/TheocraticYearTests.swift` (Swift Testing, UTC Gregorian `calendar`, `date(_:_:_:)` helper). `TheocraticYearReportBuilderTests` (377 lines) covers the builder; it does not change here.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/TheocraticYearTests -only-testing:HugoTests/TheocraticYearReportBuilderTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:

- `Hugo/Features/ServiceYear/TheocraticYear.swift`
- `Hugo/Features/ServiceYear/ServiceYearView.swift`
- `Hugo/Features/ServiceYear/ServiceYearPageView.swift`
- `HugoTests/Features/TheocraticYear/TheocraticYearTests.swift`
- `plans/README.md` (status row)

**Out of scope**:

- `TheocraticYearReportBuilder.swift` and `ServiceYearMonthRow.swift`.
- The paging, scroll-position and toolbar behavior of `ServiceYearView`. Keep them identical.
- Caching reports in an `@Observable` store. Bounded queries are enough at this scale.

## Git workflow

- Branch: `advisor/048-year-queries`
- Commit message style: short imperative sentence, for example `Query one service year per Year page`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add the year's date range

In `TheocraticYear.swift`, add to the struct:

```swift
/// The half-open range from September 1 of `startYear` to September 1 of
/// the following year.
func dateRange(calendar: Calendar = .current) -> Range<Date> {
    let start = YearMonth(year: startYear, month: 9).date(calendar: calendar)
    let end = YearMonth(year: startYear + 1, month: 9).date(calendar: calendar)
    return start..<end
}
```

Add `rangeRunsFromSeptemberFirstToNextSeptemberFirst` to `TheocraticYearTests`: for `TheocraticYear(startYear: 2026)` with the test calendar, `lowerBound == date(2026, 9, 1)`, `upperBound == date(2027, 9, 1)`, the range contains `date(2027, 8, 31)` and does not contain `date(2027, 9, 1)`.

**Verify**: focused tests pass.

### Step 2: Give each page its own bounded queries

Rewrite the top of `ServiceYearPageView`:

```swift
struct ServiceYearPageView: View {
    let year: TheocraticYear
    var onScrolledFromTopChange: ((Bool) -> Void)? = nil

    @Query private var entries: [Entry]
    @Query private var submissions: [SubmittedReport]

    init(year: TheocraticYear, onScrolledFromTopChange: ((Bool) -> Void)? = nil) {
        self.year = year
        self.onScrolledFromTopChange = onScrolledFromTopChange
        let range = year.dateRange()
        let start = range.lowerBound
        let end = range.upperBound
        _entries = Query(filter: #Predicate<Entry> { $0.date >= start && $0.date < end }, sort: \Entry.date)
        _submissions = Query(sort: \SubmittedReport.year)
    }
```

Keep the `report` computed property as is (it now reads the bounded `entries`), but read it once per render: make the first line of `body` `let report = self.report` and use that local everywhere in `body`. (Swift allows a local constant to shadow a property; if the linter objects, name it `yearReport`.)

Update the page's `#Preview` to `ServiceYearPageView(year: ReportPreviewFixtures.currentYear)` inside the existing `NavigationStack` with `.modelContainer(.preview)`.

**Verify**: `grep -n 'TheocraticYearReportBuilder.report' Hugo/Features/ServiceYear/ServiceYearPageView.swift` → exactly one match, and `grep -c 'let report = self.report\|let yearReport = self.report' Hugo/Features/ServiceYear/ServiceYearPageView.swift` → `1`. (The build check comes in Step 3, since `ServiceYearView` still uses the old initializer until then.)

### Step 3: Stop loading all entries in the container view

In `ServiceYearView`:

1. Replace both `@Query` properties with two single-row queries that give the earliest and latest entry dates:

   ```swift
   @Query private var earliestEntry: [Entry]
   @Query private var latestEntry: [Entry]
   ```

   and add an initializer that keeps the existing `resetToken` API:

   ```swift
   var resetToken: UUID

   init(resetToken: UUID = UUID()) {
       self.resetToken = resetToken
       var earliest = FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.date, order: .forward)])
       earliest.fetchLimit = 1
       _earliestEntry = Query(earliest)
       var latest = FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
       latest.fetchLimit = 1
       _latestEntry = Query(latest)
   }
   ```

2. `years` uses `entryDates: (earliestEntry + latestEntry).map(\.date)`.
3. The `ForEach` creates `ServiceYearPageView(year: year, onScrolledFromTopChange: { ... })` with the same closure body as today.

**Verify**:

- `grep -n '@Query(sort: \\Entry.date' Hugo/Features/ServiceYear/ServiceYearView.swift` → no matches.
- `grep -rn 'ServiceYearView(' Hugo` → the same two call sites, unchanged.
- `Scripts/verify.sh` → exit 0.

Commit steps 1-3: `Query one service year per Year page`.

### Step 4 [owner]: Check behavior and cost

1. With data spanning at least two service years, swipe between years: the title, totals and month rows match the previous build.
2. Add an entry in an older year (via a month row's "+"): that page updates.
3. Optional: profile a swipe with Instruments (SwiftUI template) before and after; body evaluations of `ServiceYearPageView` should no longer scale with the total entry count.

## Test plan

- `TheocraticYearTests`: 1 new test (Step 1).
- `TheocraticYearReportBuilderTests` must pass unchanged; the builder's inputs are now pre-filtered, which it already handles.

## Done criteria

- [ ] `grep -n 'entries: entries' Hugo/Features/ServiceYear/ServiceYearView.swift` prints nothing
- [ ] `Scripts/verify.sh` exits 0, with 1 more test than before this plan
- [ ] `git status --porcelain` lists only files from the Scope list
- [ ] `plans/README.md` row for 048 updated

## STOP conditions

Stop and report back if:

- `ServiceYearPageView` is created anywhere other than `ServiceYearView` and its preview.
- `Query(FetchDescriptor)` with `fetchLimit` does not compile or returns all rows (check in the preview with fixture data).
- Any `TheocraticYearReportBuilderTests` test fails.

## Maintenance notes

- Carried-in entries are dated the 1st of a month, so an August transfer lands on September 1 of the next service year and appears on that year's page. That matches how months are bucketed elsewhere.
- If the Year tab later needs data across years (for example a multi-year chart), add a separate bounded query for that view rather than restoring the all-entries query here.
