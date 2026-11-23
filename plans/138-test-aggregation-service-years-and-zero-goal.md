# Plan 138: Test category aggregation edges, service years, zero-goal publishers and submission state

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 0af2e24..HEAD -- Hugo/Features/ServiceYear Hugo/Features/Entries/Domain Hugo/Features/Overview/Domain Hugo/Features/PublisherStatus Hugo/Features/Reports/Domain/ServiceMonth.swift Hugo/Persistence/SubmittedReportSelection.swift HugoTests/Features/ServiceYear HugoTests/Features/Entries/Domain HugoTests/Features/Overview/Domain HugoTests/Features/PublisherStatus HugoTests/Features/Reports/Domain/ServiceMonthTests.swift`
> Expected: no output. If any file changed, compare it with "Current state" and STOP on a mismatch.
> Also `git status --short` must show only
> `M Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` (the owner's own
> edit; never touch or commit it) and untracked plan files.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: LOW. Tests only. No production code changes.
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `0af2e24`, 2026-11-23
- **Issue**: [SLN-213](https://linear.app/sebastianln/issue/SLN-213)
- **Plan 137 note**: plan 137 will introduce `isSubmitted` and `submittedDate` on the report. The submission-state tests in Steps 5 and 6 are written against today's behavior (`SubmittedReportSelection.isReal`, `ServiceMonth.isSubmitted`) and are the only tests plan 137 may need to touch. They are marked with a `// Plan 137:` comment.

## Why this matters

SLN-213 was written in August and asked for Swift Testing coverage of four
areas that drive the year pager, the Overview and every submitted-state badge:
category aggregation, the available service years, publishers with a monthly
goal of 0, and the theocratic year boundaries. Most of it has since been
covered. This plan first records what is already covered, then fills only the
real gaps. The gaps are small but each one guards a place where a wrong answer
is silent: a year missing from the pager, a Danish publisher's September 1
landing in the wrong year, a report with a missing `submittedAt` counted as
sent, a goal of 0 turning into a division by zero.

### Inventory: what each bullet already has (no new test planned)

| Bullet | Already covered by |
|---|---|
| Category grouping per tracker | `CategoryTotalsTests.liveEntriesGroupByCategory`, `twoLiveCategoriesWithTheSameNameStaySeparate`, `untrackedTimeHasItsOwnRow`; `MonthlyReportBuilderTests.aggregatesCategoryAndBibleStudyTotals` |
| Category summing | same tests (`rows.first { $0.trackerID == first.id }?.duration == 900`, `summary.categories.map(\.duration) == [5_400, 900]`), `MonthlyReportBuilderTests.untrackedTimeCountsAsMainDuration` |
| Category sort order | `CategoryTotalsTests.rowsAreSortedByDurationThenName`, `MonthlyReportBuilderTests.breaksEqualCategoryTotalsDeterministicallyByName` |
| Rounding | `ReportingLineCalculatorTests.computeAppliesEachRemainderDisposition` (up, down, transfer, undecided), `wholeHourLineNeedsNoRoundingAndIgnoresThePassedRule`; `TheocraticYearReportBuilderTests.submittedRoundedUpLineContributesSubmittedHours`. `CategoryTotals` itself never rounds: it sums logged seconds, which `liveEntriesGroupByCategory` shows (600 + 300 seconds stay 900). |
| Category snapshot whose tracker was deleted (live container) | `MonthlyReportBuilderTests.usesStoredTrackerWhenLiveTrackerWasDeleted`; `CategoryDeletionServiceTests` |
| Category snapshot joining a live category or the default | `CategoryTotalsTests.snapshotJoinsTheLiveCategoryWithTheSameNameAndType`, `snapshotJoinsACategoryFoundOnAnotherEntry`, `carriedMainTimeJoinsTheDefaultCategoryWhateverItsName`, `carriedMainTimeWithoutADefaultKeepsItsOwnRow`, `snapshotWithDifferentTypeDoesNotMerge` |
| Years with no entries, oldest entry to current year, future entries | `TheocraticYearTests.availableYearsContainsOnlyCurrentYearWithoutEntries`, `availableYearsIsContiguousFromOldestEntryToCurrentYear`, `availableYearsExtendsToFutureEntries` |
| A month with no submission is not submitted | `TheocraticYearReportBuilderTests.monthsWithoutSubmissionsAreNotSubmitted`; `ServiceMonthTests.unreportedWhenNoReportExists` |
| A year of only unsubmitted months | `TheocraticYearReportBuilderTests.aggregatesTotalsAcrossMonthsAndCategoryTypes` (no submissions, so every month is unsubmitted and totals are logged time), `emptyEntriesProduceTwelveEmptyMonthsAndZeroTotals` |
| Submitted months replace logged time with reported hours | `TheocraticYearReportBuilderTests.submittedRoundedUpLineContributesSubmittedHours`, `legacyRealSubmissionWithoutReportingLinesUsesSubmittedHoursAsMain`, `submittedHoursSplitByReportingLineType`; `ServiceMonthTests.submittedMonthContributesReportedHours` |
| Placeholder (sentinel, `.distantPast`) is not submitted | `TheocraticYearReportBuilderTests.sentinelSubmissionsAreNotTreatedAsSubmitted`, `sentinelSubmissionFallsBackToEntryTotals`, `duplicateSentinelsPreferTheOneWithLatestEntriesClosedAt`; `ServiceMonthTests.placeholderReportIsNotSubmitted`, `unreportedForSentinelReports` |
| A real `submittedAt` marks the month submitted; latest real one wins | `TheocraticYearReportBuilderTests.realSubmissionMarksTheMonthAsSubmittedWithoutWarnings`, `duplicateSubmissionsDoNotCrashAndLatestRealSubmissionWins`, `submissionsAttachToTheirMatchingMonthOnly` |
| A stored report with `year == nil` is ignored | `TheocraticYearReportBuilderTests.invalidOptionalSubmissionIsIgnored` |
| Zero goal in the Overview circle | `MonthlyCircleFillTests.withoutGoalPlansSetTheScale`, `withoutGoalPlansCapAtFull`, `withoutGoalOrPlansAnOwnEntryFillsTheCircle`, `withoutGoalOrPlansNoEntryLeavesItEmpty` |
| Zero goal in the Planner target | `PlannerTargetPreviewTests.noGoalDoesNotInventBarAndUsesAdditionsAsTheTarget`, `PlannerTargetTests.settingSummaryClampsNegativeExtraAndHandlesStatusesWithoutGoals` |
| Zero goal in the yearly goal rule and progress | `YearlyGoalRuleTests.statusesWithoutAYearlyGoalHaveNoRule` (checks the `publisher` status), `YearlyGoalProgressTests.statusWithoutAYearlyGoalHasNoProgress` |
| A missing status in `OverviewMetrics` | `OverviewMetricsTests.missingStatusAndNegativeDurationsAreSafe`, `bufferIsTheWholeGoalWithoutAStatus` |
| `containing` at Aug 31 and Sep 1 of the start year, `contains` at both ends, `dateRange` at the end of the year | `TheocraticYearTests.identifiesYearsAtTheAugustSeptemberBoundary`, `identifiesMonthsInsideTheYear`, `providesTwelveChronologicalMonths`, `rangeRunsFromSeptemberFirstToNextSeptemberFirst` |
| Report builder drops Aug 31 of the start year, keeps Sep 1 | `TheocraticYearReportBuilderTests.excludesEntriesOutsideRequestedYear`, `addsSummaryOnlyForMonthsWithEntries` |

"Category breakdown for a zero-goal publisher" needs no test of its own:
`CategoryTotals.rows` and `MonthlyReportBuilder.summaries` take no goal and no
status, so a goal of 0 cannot reach them. Step 3 adds one `OverviewMetrics`
test that shows time in several categories still counts when the goal is 0.

### Real gaps this plan fills

1. `CategoryTotals`: a deleted category's snapshot keeps one stored row, and entries with the same snapshot add into one row (only the `stored:` id shape for carried time is tested today).
2. `TheocraticYear.availableYears`: the Aug 31 and Sep 1 boundary, two entries with a gap between them, entry dates in any order, and the current year when entries sit in it.
3. `TheocraticYear.containing`: the end of the year (Aug 31 and Sep 1 of the end year), one second either side of midnight, and a non-UTC calendar (a Danish publisher at 00:30 on Sep 1 is already in the new year while it is still Aug 31 in UTC).
4. `TheocraticYearReportBuilder`: end of the year (Aug 31 included, Sep 1 excluded) and a year of only submitted months with no entries left.
5. `OverviewMetrics` and `PublisherStatus` with the real `publisher` status (goal 0), including a Buffer and negative Buffer.
6. Submission state: `submittedAt == nil` (a synced row with a missing field) is not submitted, and invalid year or month values never become a canonical report. `SubmittedReportSelection` has no test file at all.

## Current state

All excerpts verified at `0af2e24`.

`Hugo/Features/ServiceYear/Domain/TheocraticYear.swift`, lines 49 to 66:

```swift
    static func availableYears(
        entryDates: [Date],
        now: Date,
        calendar: Calendar = .current
    ) -> [TheocraticYear] {
        let currentYear = containing(now, calendar: calendar)
        guard let earliest = entryDates.min(), let latest = entryDates.max() else {
            return [currentYear]
        }

        let firstYear = min(containing(earliest, calendar: calendar), currentYear)
        let lastYear = max(containing(latest, calendar: calendar), currentYear)

        return (firstYear.startYear...lastYear.startYear).map(TheocraticYear.init(startYear:))
    }
```

The only caller is `ServiceYearView.years` (line 26), which passes the earliest
and latest `Entry.date` and `.now`. Submitted reports never reach the pager, so
a year that holds only a submitted report and no entries does not get a page.
Do not change that here (see Maintenance notes).

`Hugo/Persistence/SubmittedReportSelection.swift`, lines 9 to 11 and 17 to 36:

```swift
    static func isReal(_ submission: SubmittedReport) -> Bool {
        (submission.submittedAt ?? .distantPast) != .distantPast
    }
```

`canonicalByMonth` skips a report whose `year` or `month` is nil, whose `year`
is not above 0, or whose `month` is outside 1 to 12 (`validYearMonth`, line 38).

`Hugo/Features/Reports/Domain/ServiceMonth.swift`, line 30:

```swift
    var isSubmitted: Bool {
        submittedReport.map(SubmittedReportSelection.isReal) ?? false
    }
```

`Hugo/Features/Overview/Domain/OverviewMetrics.swift`, lines 17 to 21:

```swift
        let goal = Double((status?.monthlyGoal ?? 0) + max(0, bufferHours))
        let days = Double(calendar.range(of: .day, in: .month, for: now)?.count ?? 0)
        let day = Double(calendar.component(.day, from: now))
        let expected = days > 0 ? day / days * goal : 0
```

`PublisherStatus.all` has a status `publisher` with `goalPeriod: .monthly, goal: 0`.
`yearlyGoalRule` is nil unless `goalPeriod == .yearly && goal > 0`.

`Entry.init(date:duration:tracker:bibleStudies:)` copies the tracker into
`storedTracker`. `Entry.resolvedCategory()` returns key
`stored:<name>|<icon>|<type.rawValue>` and `trackerID == nil` when only the
snapshot is left. `SubmittedReport` is a SwiftData `@Model`, but the existing
tests build it with `SubmittedReport(year:month:...)` and never insert it, which
is the fixture style to keep. Its `year`, `month`, `submittedAt` and
`entriesClosedAt` are optional `var`s, so a test can set `submittedAt = nil`.

Existing test helpers to reuse, not duplicate:

- `TheocraticYearTests`: `calendar` (Gregorian, UTC) and `date(_ year, _ month, _ day)`.
- `TheocraticYearReportBuilderTests`: `calendar`, `locale`, `date(_:_:_:)`, `makeReport(entries:)`, `makeReport(entries:submissions:)`, `makeReport(for:entries:)`.
- `CategoryTotalsTests`: `locale`, `day`, and `entry(_ duration:, tracker:, copy:, carried:)`.
- `OverviewMetricsTests`: `calendar`, `date(_:_:_:)`.
- `ServiceMonthTests`: `calendar`, `date(_:_:_:hour:minute:)`, `month(_ entries:, _ submissions:)` (June 2026, now 2026-07-15), `june`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint one file | `xcrun swift-format lint --strict <file>` | exit 0, no output |
| Layout check | `Scripts/check-layout.sh` | exit 0 |
| Whole gate | `Scripts/verify.sh` | exit 0 (layout, lint, all tests, analyze). Takes several minutes. |

## Scope

**In scope** (the only files you may modify or create):

- `HugoTests/Features/Entries/Domain/CategoryTotalsTests.swift` (modify)
- `HugoTests/Features/ServiceYear/Domain/TheocraticYearTests.swift` (modify)
- `HugoTests/Features/ServiceYear/Domain/TheocraticYearReportBuilderTests.swift` (modify)
- `HugoTests/Features/Overview/Domain/OverviewMetricsTests.swift` (modify)
- `HugoTests/Features/PublisherStatus/Domain/PublisherStatusTests.swift` (modify)
- `HugoTests/Features/Reports/Domain/ServiceMonthTests.swift` (modify)
- `HugoTests/Persistence/SubmittedReportSelectionTests.swift` (new)
- `plans/README.md` (status row)

**Out of scope** (do NOT touch):

- Any file under `Hugo/`. If a test fails because production code is wrong, that is a STOP condition, not something to fix.
- `Hugo.xcodeproj`. The test target uses file system synchronized groups in this repo, so a new test file is picked up without a project edit. If `Scripts/verify.sh` does not run the new tests (Step 7 checks), STOP.
- `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`: the owner's uncommitted edit. Never stage it.
- Existing tests: add new tests, never change or delete an existing one.

## Git workflow

- Commit straight to `main`. Do not create a branch or a worktree.
- One commit after `Scripts/verify.sh` exits 0, Conventional Commits: `test: cover category snapshots, service years, zero goals and submission state`.
- Stage by explicit path only (the seven test files). Never `git add -A` or `git add .`. Do not push.

## Steps

In every file below, insert the new tests immediately above the existing
`private func ...` helpers at the bottom of the struct, keeping the helpers
last. Use 4-space indentation. Do not add new `import` lines unless a step says
so. If a helper named in a step has a different signature than in "Current
state", STOP.

### Step 1: `CategoryTotalsTests`, deleted category snapshot

Add to `HugoTests/Features/Entries/Domain/CategoryTotalsTests.swift`:

```swift
    @Test
    func snapshotOfADeletedCategoryKeepsOneStoredRow() {
        let entries = [
            entry(600, copy: ("Deleted", "archivebox", .separate)),
            entry(900, copy: ("Deleted", "archivebox", .separate)),
        ]
        let rows = CategoryTotals.rows(entries: entries, trackers: [], locale: locale)

        #expect(rows.count == 1)
        #expect(rows.first?.id == "stored:Deleted|archivebox|separate")
        #expect(rows.first?.name == "Deleted")
        #expect(rows.first?.iconName == "archivebox")
        #expect(rows.first?.type == .separate)
        #expect(rows.first?.trackerID == nil)
        #expect(rows.first?.duration == 1_500)
    }

    @Test
    func snapshotsWithDifferentIconsStaySeparateWithoutALiveCategory() {
        let entries = [
            entry(600, copy: ("Deleted", "archivebox", .separate)),
            entry(600, copy: ("Deleted", "tray", .separate)),
        ]
        let rows = CategoryTotals.rows(entries: entries, trackers: [], locale: locale)

        #expect(rows.count == 2)
    }
```

**Verify**: `xcrun swift-format lint --strict HugoTests/Features/Entries/Domain/CategoryTotalsTests.swift` exits 0.

### Step 2: `TheocraticYearTests`, boundaries and available years

Add to `HugoTests/Features/ServiceYear/Domain/TheocraticYearTests.swift`:

```swift
    @Test
    func identifiesYearsAtTheEndOfTheYear() {
        #expect(TheocraticYear.containing(date(2027, 8, 31), calendar: calendar).startYear == 2026)
        #expect(TheocraticYear.containing(date(2027, 9, 1), calendar: calendar).startYear == 2027)
    }

    @Test
    func theLastSecondOfAugustBelongsToTheOldYear() {
        let lastSecond = calendar.date(
            from: DateComponents(year: 2027, month: 8, day: 31, hour: 23, minute: 59, second: 59))!
        let firstSecond = calendar.date(
            from: DateComponents(year: 2027, month: 9, day: 1, hour: 0, minute: 0, second: 0))!

        #expect(TheocraticYear.containing(lastSecond, calendar: calendar).startYear == 2026)
        #expect(TheocraticYear.containing(firstSecond, calendar: calendar).startYear == 2027)
        #expect(!TheocraticYear(startYear: 2026).dateRange(calendar: calendar).contains(firstSecond))
        #expect(TheocraticYear(startYear: 2026).dateRange(calendar: calendar).contains(lastSecond))
    }

    @Test
    func theBoundaryFollowsTheCalendarTimeZone() {
        var copenhagen = Calendar(identifier: .gregorian)
        copenhagen.timeZone = TimeZone(identifier: "Europe/Copenhagen")!
        // 22:30 UTC on August 31 is 00:30 on September 1 in Copenhagen (UTC+2).
        let instant = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 31, hour: 22, minute: 30))!

        #expect(TheocraticYear.containing(instant, calendar: calendar).startYear == 2025)
        #expect(TheocraticYear.containing(instant, calendar: copenhagen).startYear == 2026)
        #expect(instant.theocraticYear(using: copenhagen) == TheocraticYear(startYear: 2026))
    }

    @Test
    func availableYearsStaysOnOneYearWhenEntriesAreInTheCurrentYear() {
        let years = TheocraticYear.availableYears(
            entryDates: [date(2025, 9, 1), date(2026, 8, 31)],
            now: date(2026, 8, 31),
            calendar: calendar
        )
        #expect(years.map(\.startYear) == [2025])
    }

    @Test
    func availableYearsAddsTheNewYearOnSeptemberFirst() {
        let years = TheocraticYear.availableYears(
            entryDates: [date(2026, 8, 31)],
            now: date(2026, 9, 1),
            calendar: calendar
        )
        #expect(years.map(\.startYear) == [2025, 2026])
    }

    @Test
    func availableYearsIncludesAnEntryOnSeptemberFirstBeforeItIsCurrent() {
        let years = TheocraticYear.availableYears(
            entryDates: [date(2026, 9, 1)],
            now: date(2026, 8, 31),
            calendar: calendar
        )
        #expect(years.map(\.startYear) == [2025, 2026])
    }

    @Test
    func availableYearsFillsTheGapBetweenEntriesWhatEverTheirOrder() {
        let years = TheocraticYear.availableYears(
            entryDates: [date(2025, 1, 15), date(2022, 10, 1)],
            now: date(2026, 7, 1),
            calendar: calendar
        )
        #expect(years.map(\.startYear) == [2022, 2023, 2024, 2025])
    }

    @Test
    func availableYearsKeepsAnEntryYearThatIsAlreadyPast() {
        let years = TheocraticYear.availableYears(
            entryDates: [date(2026, 11, 10)],
            now: date(2027, 3, 1),
            calendar: calendar
        )
        #expect(years.map(\.startYear) == [2026])
    }
```

Expected values were derived by hand from the source above:

- the gap test: earliest Oct 2022 is year 2022, latest Jan 2025 is year 2024, now Jul 2026 is year 2025, so the range is 2022 to 2025;
- the last test: Nov 2026 and Mar 2027 are both in 2026.

`TheocraticYear` is `Equatable` through `Hashable`, so `==` on years works.

**Verify**: `xcrun swift-format lint --strict HugoTests/Features/ServiceYear/Domain/TheocraticYearTests.swift` exits 0.

### Step 3: `TheocraticYearReportBuilderTests`, year end and a year of submitted months

Add to `HugoTests/Features/ServiceYear/Domain/TheocraticYearReportBuilderTests.swift`:

```swift
    @Test
    func theLastDayOfAugustIsInTheYearAndSeptemberFirstIsNot() throws {
        let report = makeReport(entries: [
            Entry(date: date(2027, 8, 31), duration: 3_600, tracker: nil),
            Entry(date: date(2027, 9, 1), duration: 7_200, tracker: nil),
        ])
        let august = try #require(report.months.last)

        #expect(august.id == YearMonth(year: 2027, month: 8))
        #expect(august.summary?.totalSeconds == 3_600)
        #expect(report.totalSeconds == 3_600)
    }

    @Test
    func aYearOfOnlySubmittedMonthsTotalsTheReportedHoursWithoutEntries() {
        func submission(month: Int, year: Int, hours: Int) -> SubmittedReport {
            SubmittedReport(
                year: year,
                month: month,
                submittedAt: date(year, month + 1, 1),
                reportingLines: [
                    .init(typeRaw: TrackerType.main.rawValue, submittedHours: hours, roundingRaw: "")
                ]
            )
        }
        let report = makeReport(
            entries: [],
            submissions: [
                submission(month: 9, year: 2026, hours: 13),
                submission(month: 10, year: 2026, hours: 7),
            ]
        )

        #expect(report.months.filter(\.isSubmitted).count == 2)
        #expect(!report.hasEntries)
        #expect(report.mainDuration == 20 * 3_600)
        #expect(report.totalSeconds == 20 * 3_600)
    }
```

Before running, open the existing test `submittedRoundedUpLineContributesSubmittedHours` and confirm the
`.init(typeRaw:submittedHours:roundingRaw:)` call compiles as written there. If
`roundingRaw` has no default or a different label in this schema, copy the
existing test's argument list exactly, using `""` for the rounding value only if
that label accepts a `String`; otherwise STOP.

**Verify**: `xcrun swift-format lint --strict HugoTests/Features/ServiceYear/Domain/TheocraticYearReportBuilderTests.swift` exits 0.

### Step 4: `OverviewMetricsTests` and `PublisherStatusTests`, zero goal

Add to `HugoTests/Features/Overview/Domain/OverviewMetricsTests.swift`:

```swift
    @Test
    func aPublisherWithoutAGoalHasNoGoalAndNoExpectedProgress() {
        let publisher = PublisherStatus.status(for: "publisher")
        let metrics = OverviewMetrics.make(
            entries: [Entry(date: date(2026, 1, 1), duration: 7_200, tracker: nil)], status: publisher,
            now: date(2026, 1, 15), calendar: calendar)

        #expect(metrics.monthlyGoal == 0)
        #expect(metrics.expectedProgress == 0)
        #expect(metrics.totalHours == 2)
        #expect(metrics.hasOwnEntries == true)
    }

    @Test
    func aBufferIsTheWholeGoalForAPublisherWithoutAGoal() {
        let publisher = PublisherStatus.status(for: "publisher")
        let metrics = OverviewMetrics.make(
            entries: [], status: publisher, bufferHours: 5, now: date(2026, 1, 15), calendar: calendar)

        #expect(metrics.monthlyGoal == 5)
        #expect(abs(metrics.expectedProgress - (15.0 / 31.0 * 5.0)) < 0.0001)
    }

    @Test
    func aNegativeBufferKeepsAPublisherWithoutAGoalAtZero() {
        let publisher = PublisherStatus.status(for: "publisher")
        let metrics = OverviewMetrics.make(
            entries: [], status: publisher, bufferHours: -3, now: date(2026, 1, 15), calendar: calendar)

        #expect(metrics.monthlyGoal == 0)
        #expect(metrics.expectedProgress == 0)
    }

    @Test
    func timeInEveryCategoryCountsWhenThereIsNoGoal() {
        let main = Tracker(name: "Field Service", type: .main, iconName: "figure.walk")
        let separate = Tracker(name: "Bethel", type: .separate, iconName: "building")
        let entries = [
            Entry(date: date(2026, 1, 1), duration: 3_600, tracker: main),
            Entry(date: date(2026, 1, 2), duration: 1_800, tracker: separate),
            Entry(date: date(2026, 1, 3), duration: 900, tracker: nil),
        ]
        let metrics = OverviewMetrics.make(
            entries: entries, status: PublisherStatus.status(for: "publisher"), now: date(2026, 1, 15),
            calendar: calendar)

        #expect(metrics.totalHours == 1.75)
        #expect(metrics.monthlyGoal == 0)
    }
```

Add to `HugoTests/Features/PublisherStatus/Domain/PublisherStatusTests.swift`:

```swift
    @Test
    func aPublisherWithoutAGoalHasNoMonthlyOrYearlyGoal() throws {
        let publisher = try #require(PublisherStatus.status(for: "publisher"))
        #expect(publisher.goal == 0)
        #expect(publisher.monthlyGoal == 0)
        #expect(publisher.yearlyGoal == 0)
        #expect(publisher.yearlyGoalRule == nil)
    }

    @Test
    func aYearlyStatusWithAGoalOfZeroHasNoRule() {
        let config = PublisherStatus(id: "yearly-zero", nameKey: "", shortName: "", goalPeriod: .yearly, goal: 0)
        #expect(config.monthlyGoal == 0)
        #expect(config.yearlyGoal == 0)
        #expect(config.yearlyGoalRule == nil)
    }
```

**Verify**:
- `xcrun swift-format lint --strict HugoTests/Features/Overview/Domain/OverviewMetricsTests.swift HugoTests/Features/PublisherStatus/Domain/PublisherStatusTests.swift` exits 0.

### Step 5: `SubmittedReportSelectionTests` (new file), submission state

Create `HugoTests/Persistence/SubmittedReportSelectionTests.swift` (it mirrors
`Hugo/Persistence/SubmittedReportSelection.swift`):

```swift
import Foundation
import Testing

@testable import Hugo

@MainActor
struct SubmittedReportSelectionTests {
    private let sent = Date(timeIntervalSince1970: 1_780_000_000)
    private let june = YearMonth(year: 2026, month: 6)

    // Plan 137: this and the next two tests pin today's `isReal`; plan 137 may rename it.
    @Test
    func aMissingSubmittedAtIsNotReal() {
        let report = SubmittedReport(year: 2026, month: 6)
        report.submittedAt = nil

        #expect(!SubmittedReportSelection.isReal(report))
    }

    @Test
    func thePlaceholderDateIsNotReal() {
        let report = SubmittedReport(year: 2026, month: 6, submittedAt: .distantPast)

        #expect(!SubmittedReportSelection.isReal(report))
    }

    @Test
    func anyOtherSubmittedAtIsReal() {
        let report = SubmittedReport(year: 2026, month: 6, submittedAt: sent)

        #expect(SubmittedReportSelection.isReal(report))
    }

    // Plan 137: depends on `isReal`.
    @Test
    func aRealReportBeatsOneWithAMissingSubmittedAtEvenWhenTheOtherClosedLater() {
        let missing = SubmittedReport(year: 2026, month: 6, entriesClosedAt: sent.addingTimeInterval(86_400))
        missing.submittedAt = nil
        let real = SubmittedReport(year: 2026, month: 6, submittedAt: sent, entriesClosedAt: sent)

        let canonical = SubmittedReportSelection.canonical(for: june, in: [missing, real])

        #expect(canonical === real)
    }

    // Plan 137: depends on `isReal`.
    @Test
    func aMonthWithOnlyMissingAndPlaceholderReportsHasNoRealOne() throws {
        let missing = SubmittedReport(year: 2026, month: 6)
        missing.submittedAt = nil
        let placeholder = SubmittedReport(year: 2026, month: 6, submittedAt: .distantPast)

        let canonical = try #require(SubmittedReportSelection.canonical(for: june, in: [missing, placeholder]))

        #expect(!SubmittedReportSelection.isReal(canonical))
    }

    @Test
    func reportsWithAnInvalidYearOrMonthAreNeverIndexed() {
        let noYear = SubmittedReport(year: 2026, month: 6, submittedAt: sent)
        noYear.year = nil
        let noMonth = SubmittedReport(year: 2026, month: 6, submittedAt: sent)
        noMonth.month = nil
        let zeroYear = SubmittedReport(year: 0, month: 6, submittedAt: sent)
        let zeroMonth = SubmittedReport(year: 2026, month: 0, submittedAt: sent)
        let monthThirteen = SubmittedReport(year: 2026, month: 13, submittedAt: sent)

        let byMonth = SubmittedReportSelection.canonicalByMonth([
            noYear, noMonth, zeroYear, zeroMonth, monthThirteen,
        ])

        #expect(byMonth.isEmpty)
    }

    @Test
    func eachMonthKeepsItsOwnCanonicalReport() {
        let june = SubmittedReport(year: 2026, month: 6, submittedAt: sent)
        let july = SubmittedReport(year: 2026, month: 7, submittedAt: sent)

        let byMonth = SubmittedReportSelection.canonicalByMonth([june, july])

        #expect(byMonth.count == 2)
        #expect(byMonth[YearMonth(year: 2026, month: 6)] === june)
        #expect(byMonth[YearMonth(year: 2026, month: 7)] === july)
    }
}
```

Notes for the executor:

- If `SubmittedReport.init` does not accept `submittedAt:` or `entriesClosedAt:` with these labels (existing tests use both), STOP.
- `canonicalByMonth` returns `[YearMonth: SubmittedReport]`; `YearMonth` is `Hashable` (it is a dictionary key in the source).
- The local `june`/`july` constants in the last test shadow the struct's `june` property on purpose only inside that function. If `swift-format` or the compiler complains about shadowing, rename them to `juneReport` and `julyReport`.

**Verify**: `xcrun swift-format lint --strict HugoTests/Persistence/SubmittedReportSelectionTests.swift` exits 0.

### Step 6: `ServiceMonthTests`, a month whose report has no `submittedAt`

Add to `HugoTests/Features/Reports/Domain/ServiceMonthTests.swift`:

```swift
    // Plan 137: pins that a report with no `submittedAt` is treated like a placeholder.
    @Test
    func reportWithoutASubmittedDateIsNotSubmitted() {
        let report = SubmittedReport(year: 2026, month: 6, entriesClosedAt: date(2026, 6, 30))
        report.submittedAt = nil
        let entry = Entry(date: date(2026, 6, 10), duration: 3_600, tracker: nil)
        entry.createdAt = date(2026, 7, 2, hour: 9)

        let m = month([entry], [report])

        #expect(!m.isSubmitted)
        #expect(m.unreportedChange == nil)
        #expect(!m.isUnreported(entry))
        #expect(m.contribution.total == 3_600)
    }
```

**Verify**: `xcrun swift-format lint --strict HugoTests/Features/Reports/Domain/ServiceMonthTests.swift` exits 0.

### Step 7: Run the gate and commit

Run `Scripts/verify.sh`, with the full output redirected to a file under
`/private/tmp/claude-501/-Users-sebastiannielsen-Documents-Areas-Personal-Apps-Hugo/e838d7fa-4b4b-47a9-b236-f61a2004ed12/scratchpad/`
(for example `verify-138.log`), and take the exit code from the script itself.

Confirm the new tests ran:

```
grep -c "snapshotOfADeletedCategoryKeepsOneStoredRow\|theBoundaryFollowsTheCalendarTimeZone\|aMissingSubmittedAtIsNotReal\|aPublisherWithoutAGoalHasNoGoalAndNoExpectedProgress\|aYearOfOnlySubmittedMonthsTotalsTheReportedHoursWithoutEntries\|reportWithoutASubmittedDateIsNotSubmitted" verify-138.log
```

Expect 6 or more (Swift Testing prints each test name once or twice).

If a new test fails, read the assertion first. A failing expectation that was
derived above from the source means the test is wrong: fix the expected value
only if the source clearly supports your fix. A failing expectation where the
source behavior looks wrong for users (for example a Copenhagen instant landing
in the wrong year) is a STOP condition: do not change production code, do not
delete the test, report the failing test name and what it showed.

Then stage the seven test files by explicit path and commit with the message
from "Git workflow".

**Verify**: exit code 0, and the log contains `** TEST SUCCEEDED **` and `** ANALYZE SUCCEEDED **`.

## Test plan

Fixtures are value types: unattached `Entry`, `Tracker` and `SubmittedReport`
objects and a fixed Gregorian UTC calendar (plus one Copenhagen calendar).
None of the new tests needs `InMemoryModelContainer.make()`; the existing
`MonthlyReportBuilderTests.usesStoredTrackerWhenLiveTrackerWasDeleted` already
covers the live-container deletion path. New test count: 2 (CategoryTotals) + 8
(TheocraticYear) + 2 (report builder) + 4 (OverviewMetrics) + 2 (PublisherStatus)
+ 7 (SubmittedReportSelection) + 1 (ServiceMonth) = 26.

Tests plan 137 may need to touch (all marked `// Plan 137:`): the three `isReal`
tests, `aRealReportBeatsOneWithAMissingSubmittedAtEvenWhenTheOtherClosedLater`,
`aMonthWithOnlyMissingAndPlaceholderReportsHasNoRealOne` and
`reportWithoutASubmittedDateIsNotSubmitted`.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0 and the new test names appear in the log.
- [ ] `git diff --stat HEAD~1` lists only the seven test files (and `plans/README.md` if you maintain it).
- [ ] No file under `Hugo/` changed.
- [ ] `plans/README.md` status row updated (unless the reviewer maintains it).

## STOP conditions

Stop and report back (do not improvise) if:

- The code at "Current state" does not match.
- A new test fails and the production behavior looks wrong. Report the test name, the assertion and the value you got. Never fix production code in this plan.
- `Scripts/verify.sh` does not run `SubmittedReportSelectionTests` (the test target would then need a project edit, which is out of scope).
- A `SubmittedReport` initializer label or helper signature differs from what a step assumes and the fix is not a pure spelling change.
- A step's verification fails twice.

## Maintenance notes

- The year pager (`ServiceYearView.years`) is built from entry dates only. A year whose entries were all deleted after a report was submitted gets no page, even though its reported hours still count in `TheocraticYearReportBuilder`. That may be intended; decide before changing it, then add `submissions` to `availableYears` and a test.
- A real report (`submittedAt` set) with `entriesClosedAt == nil` makes every entry in the month count as unreported (`ServiceMonth.isUnreported` compares against `.distantPast`). This plan does not test it because the intended behavior is not documented. If a synced row can arrive that way, decide the rule and add a test.
- When plan 137 lands, update the `// Plan 137:` tests to use `isSubmitted` and `submittedDate` and delete the comments.
- Keep new boundary tests on a fixed calendar. Only the Copenhagen test uses a non-UTC zone, on purpose.
