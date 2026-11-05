# Plan 064: Group time by category with one rule, so carried-in time lands in the same row on every screen

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 26e63f4..HEAD -- Hugo/Features/Entries/Domain Hugo/Features/Reports/Domain/MonthlyReportBuilder.swift Hugo/Features/Reports/Domain/ServiceMonth.swift Hugo/Features/ServiceYear/Domain/TheocraticYearReportBuilder.swift Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift Hugo/Features/Overview/Domain/OverviewMetrics.swift HugoTests/Features/Overview/Domain/OverviewMetricsTests.swift HugoTests/Features/Reports/Domain/MonthlyReportBuilderTests.swift`
> Plans 061 to 063 change `TheocraticYearReportBuilder.swift`,
> `ServiceYearPageView.swift` and `OverviewMetrics.swift` and create
> `ServiceMonth.swift`. Compare the "Current state" excerpts with the live
> code; a difference in the excerpted lines is a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/061-service-month-record.md (`ServiceMonth.make`), plans/062-month-ranges-and-reminder-rule.md (edits `OverviewMetrics.swift` first)
- **Category**: bug + tech-debt
- **Planned at**: commit `26e63f4`, 2026-11-03
- **Issue**: [SLN-267](https://linear.app/sebastianln/issue/SLN-267)

## Why this matters

When the user transfers leftover minutes, Hugo creates a carried-in entry in the next month. That entry has no live category, only a copy of a category name. Two pieces of code group time by category, and they treat that entry differently:

- The Overview breakdown merges it into a live category with the same name and type.
- The Year page month card always shows it as its own row.

The Overview merge also works only in English. A carried-in main entry is named after the string `category.default.label` ("Field Service" / Danish "Tjeneste"), but the default category is named after `tracker.fieldservice.name` ("Field Service" / Danish "Forkyndelse"). So in Danish, the Overview also shows a separate "Tjeneste" row next to "Forkyndelse".

The owner decided (2026-11-03) that carried-in time merges everywhere:

- Carried-in main time counts under the default main category.
- Any other category copy merges into the live category with the same name and type.
- A row of its own appears only when no matching category exists.

After this plan, one function decides which row an entry belongs to, and both screens use it.

## Current state

### The category of one entry

`Hugo/Features/Entries/Domain/EntryCategory.swift` resolves an entry's category: live `tracker` first, then the `storedTracker` copy, then "untracked". The `key` is the tracker's UUID string, `stored:<name>|<icon>|<type>` for a copy, or `untracked`:

```swift
nonisolated struct EntryCategory: Hashable {
    let key: String
    let name: String
    let iconName: String
    /// `nil` only for an untracked entry.
    let type: TrackerType?
    /// Set only when the live tracker is attached.
    let trackerID: UUID?
}
extension Entry {
    nonisolated func resolvedCategory(locale: Locale = .current) -> EntryCategory { ... }
}
```

`Entry.isCarriedIn` (in `Hugo/Persistence/SchemaVersions/V11/EntryV11.swift`) is true when `sourceReportYear` and `sourceReportMonth` are set. Carried-in entries have `tracker == nil`. Their `storedTracker` is built in `SubmitReportFormModel.reconcileGeneratedEntries`:

```swift
entry.storedTracker =
    if result.line.type == .main {
        .init(name: String(localized: "category.default.label"), icon: "figure.walk", type: .main)
    } else {
        .init(name: result.line.name, icon: result.line.iconName, type: .separate)
    }
```

`Tracker` has `id: UUID`, `name`, `type: TrackerType` (`.main` / `.separate`), `isDefault: Bool`, `iconName`, `hue`/`sat`/`bri` and `createdAt`. Initializer order: `Tracker(id:name:type:allowBibleStudies:isDefault:iconName:hue:sat:bri:)`, all optional.

### Grouper 1: month summary (Year page cards, month detail)

`Hugo/Features/Reports/Domain/MonthlyReportBuilder.swift:19-43` groups by `category.key`, so a copy never merges:

```swift
var categories: [String: (name: String, iconName: String, type: TrackerType?, duration: TimeInterval)] = [:]
for entry in monthEntries {
    ...
    let category = entry.resolvedCategory(locale: locale)
    ...
    categories[metadata.key, default: (metadata.name, metadata.iconName, metadata.type, 0)].duration +=
        entry.duration
}
let categorySummaries = categories.map { key, value in
    MonthlyCategorySummary(
        id: key, name: value.name, iconName: value.iconName, type: value.type, duration: value.duration)
}.sorted {
    if $0.duration != $1.duration { return $0.duration > $1.duration }
    if $0.name != $1.name { return $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    return $0.id < $1.id
}
```

It is called from `ServiceMonth.make` (`Hugo/Features/Reports/Domain/ServiceMonth.swift`, added by plan 061), `SubmitReportFormModel.load` and `ReportPreviewFixtures.summary`. `TheocraticYearReportBuilder.report(for:entries:submissions:now:calendar:locale:)` calls `ServiceMonth.make` for each month.

### Grouper 2: Overview breakdown

`Hugo/Features/Overview/Domain/OverviewMetrics.swift`, `CategoryProgressAggregator.rows(entries:trackers:locale:)` (about lines 44-100 after plan 062 removes `CurrentMonthInterval`). It merges a copy into the first live tracker with the same name and type, and orders rows as: live trackers in `trackers` array order, then copies sorted by name, then one `untracked` row. Each row gets a `CategoryProgressColor` from the live tracker's `hue`/`sat`/`bri` (nil when invalid). `CategoryProgressBreakdownView` calls it with `@Query private var trackers: [Tracker]`.

### What does not change

`ReportingLineCalculator.lines(from:calendar:)` puts all main and untracked time on one Field Service line and groups separate time by category name. That already matches the decision, so leave it alone.

### Tests that pin current behavior

- `HugoTests/Features/Overview/Domain/OverviewMetricsTests.swift`: color tests, `untrackedEntriesBecomeFallbackRows`, `carriedEntryMergesIntoLiveCategoryWithSameNameAndType`, `orphanedSnapshotGetsItsOwnNamedRow`, `snapshotWithDifferentTypeDoesNotMerge` (expects the live row first, then the copy).
- `HugoTests/Features/Reports/Domain/MonthlyReportBuilderTests.swift`: `usesStoredTrackerWhenLiveTrackerWasDeleted`, `includesFullyUntrackedEntriesInTotal`, `breaksEqualCategoryTotalsDeterministicallyByName`.

All of them must keep passing unchanged. They describe cases the decision does not change.

### Conventions

- Pure value logic: `nonisolated enum` with `static func`s and a `locale` parameter defaulting to `.current`. Exemplar: `MonthlyReportBuilder`.
- Tests: Swift Testing, fixed UTC Gregorian calendar, `Locale(identifier: "en_US_POSIX")`. Exemplar: `MonthlyReportBuilderTests`.
- `CONTEXT.md` terms: category, main category, separate category, default category, category snapshot, carried-in entry, untracked entry.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/CategoryTotalsTests -only-testing:HugoTests/MonthlyReportBuilderTests -only-testing:HugoTests/OverviewMetricsTests -only-testing:HugoTests/TheocraticYearReportBuilderTests -only-testing:HugoTests/ServiceMonthTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 |

Leave `-only-testing:HugoTests/CategoryTotalsTests` out until Step 1 creates the suite.

## Scope

**In scope**:

- `Hugo/Features/Entries/Domain/CategoryTotals.swift` (create)
- `Hugo/Features/Reports/Domain/MonthlyReportBuilder.swift`
- `Hugo/Features/Reports/Domain/ServiceMonth.swift` (pass `trackers` through)
- `Hugo/Features/ServiceYear/Domain/TheocraticYearReportBuilder.swift` (pass `trackers` through)
- `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift` (add a trackers query)
- `Hugo/Features/Overview/Domain/OverviewMetrics.swift` (`CategoryProgressAggregator` only)
- `HugoTests/Features/Entries/Domain/CategoryTotalsTests.swift` (create)
- `HugoTests/Features/Reports/Domain/MonthlyReportBuilderTests.swift` (one new test)
- `plans/README.md` (status row)

**Out of scope**:

- `ReportingLineCalculator` and the reporting lines (see "What does not change").
- `SubmitReportFormModel` and how carried-in entries are named. Changing the stored name would not fix entries already saved.
- Any schema change, and any change to stored data. This plan changes only how rows are grouped for display.
- Merging two live categories that share a name. They stay separate rows (plan 041 decided not to merge categories by name).
- Untracked time. It keeps its own row. Whether it counts as main time is a separate open question (see Maintenance notes).

## Git workflow

- Branch: `advisor/064-category-totals`
- Conventional Commits, as in `git log`, for example `fix: show carried-in time under its category on every screen`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add `CategoryTotals`

Create `Hugo/Features/Entries/Domain/CategoryTotals.swift`:

```swift
import Foundation

/// Time per category for a set of entries. Every screen that splits time by
/// category uses this, so an entry lands in the same row everywhere.
nonisolated struct CategoryTotal: Identifiable {
    /// The live category's UUID string, `stored:<name>|<icon>|<type>` for a
    /// category snapshot with no live match, or `untracked`.
    let id: String
    let name: String
    let iconName: String
    /// Nil only for untracked time.
    let type: TrackerType?
    let duration: TimeInterval
    /// The live category the row belongs to, if any.
    let trackerID: UUID?
}

nonisolated enum CategoryTotals {
    /// Groups `entries` by category. An entry without a live category joins a
    /// live one when it can:
    /// - carried-in main time joins the default main category;
    /// - any other category snapshot joins the live category with the same
    ///   name and type.
    /// `trackers` are the live categories to match against; categories attached
    /// to `entries` are always considered as well. Rows are sorted by
    /// duration (longest first), then name, then id.
    static func rows(entries: [Entry], trackers: [Tracker] = [], locale: Locale = .current) -> [CategoryTotal]
}
```

Implementation rules, in this order, for each entry (`let category = entry.resolvedCategory(locale: locale)`):

1. `category.trackerID != nil`: the row is that live category. Key `category.key`, name and icon from `category`.
2. `category.type == nil`: the `untracked` row (key `category.key`, which is `"untracked"`).
3. `entry.isCarriedIn && category.type == .main`, and a live candidate with `isDefault && type == .main` exists: that candidate's row.
4. A live candidate with `name == category.name && type == category.type` exists: that candidate's row.
5. Otherwise: its own row, key `category.key`, name and icon from `category`, `trackerID: nil`.

"Live candidates" means `trackers` plus every `entry.tracker` in `entries`, without duplicates by `id`. When several candidates match a rule, pick the first after sorting by `isDefault` (true first), then `createdAt` (earliest first), then `id.uuidString`. A row that belongs to a live category uses that category's `id.uuidString` as `id`, its `name`, `iconName` and `type`, and `trackerID: tracker.id`.

Create `HugoTests/Features/Entries/Domain/CategoryTotalsTests.swift` with these tests. Use `Entry(date:duration:tracker:)`, set `storedTracker = Entry.EntryTracker(name:icon:type:)` for copies, and set `sourceReportYear = 2026` and `sourceReportMonth = 5` to make an entry carried in.

- `liveEntriesGroupByCategory`: two entries on one tracker and one on another give two rows with the right durations and `trackerID`s.
- `snapshotJoinsTheLiveCategoryWithTheSameNameAndType`: a "Bethel"/`.separate` copy plus `trackers: [bethel]` (no entry on `bethel`) gives one row with `trackerID == bethel.id`.
- `snapshotJoinsACategoryFoundOnAnotherEntry`: the same with `trackers: []`, but another entry is on `bethel`. One row.
- `carriedMainTimeJoinsTheDefaultCategoryWhateverItsName`: default tracker `Tracker(name: "Forkyndelse", type: .main, isDefault: true)`; a carried-in entry with copy `("Tjeneste", "figure.walk", .main)`. One row, `name == "Forkyndelse"`, duration is the sum. This is the Danish regression test.
- `carriedMainTimeWithoutADefaultKeepsItsOwnRow`: the same carried entry with no default tracker and no name match. Its own row, `id == "stored:Tjeneste|figure.walk|main"`.
- `snapshotThatIsNotCarriedDoesNotJoinTheDefaultByType`: a non-carried copy `("Old", "tag", .main)` and a default tracker "Field Service". Two rows.
- `snapshotWithDifferentTypeDoesNotMerge`: tracker "Bethel"/`.main`, copy "Bethel"/`.separate`. Two rows.
- `twoLiveCategoriesWithTheSameNameStaySeparate`: two trackers both named "Bethel"/`.separate`, one entry each. Two rows.
- `untrackedTimeHasItsOwnRow`: `tracker: nil`, no copy. One row with `id == "untracked"` and `type == nil`.
- `rowsAreSortedByDurationThenName`: check the order.

**Verify**: focused tests (with `CategoryTotalsTests`) → `** TEST SUCCEEDED **`.

### Step 2: Build month summaries from `CategoryTotals`

In `MonthlyReportBuilder.summaries`, add a parameter `trackers: [Tracker] = []` after `locale`. Keep the loop that adds `totalSeconds`, `bibleStudies`, `mainDuration` and `separateDuration`, but delete the `categories` dictionary and its sort. Build the categories as:

```swift
let categorySummaries = CategoryTotals.rows(entries: monthEntries, trackers: trackers, locale: locale).map {
    MonthlyCategorySummary(id: $0.id, name: $0.name, iconName: $0.iconName, type: $0.type, duration: $0.duration)
}
```

Pass trackers through:

- `ServiceMonth.make`: add `trackers: [Tracker] = []` after `submissions` and pass it to `MonthlyReportBuilder.summaries`.
- `TheocraticYearReportBuilder.report`: add `trackers: [Tracker] = []` after `submissions` and pass it to `ServiceMonth.make`.
- `ServiceYearPageView`: add `@Query private var trackers: [Tracker]` next to the other queries (no filter; there are only a handful of categories), and pass `trackers: trackers` in its `TheocraticYearReportBuilder.report` call.

Add to `MonthlyReportBuilderTests`: `carriedMainTimeMergesIntoTheDefaultCategory`. A default tracker "Field Service"/`.main` with one 3_600-second entry, plus a carried-in entry of 1_800 seconds with copy `("Field Service", "figure.walk", .main)`. Expect `summary.categories.count == 1` and its duration `5_400`.

**Verify**: focused tests pass, including every existing `MonthlyReportBuilderTests` test unchanged.

### Step 3: Build the Overview rows from `CategoryTotals`

Rewrite `CategoryProgressAggregator.rows(entries:trackers:locale:)` as a projection of `CategoryTotals.rows(entries:trackers:locale:)`:

- Map each `CategoryTotal` to `CategoryProgressRow(id:name:iconName:duration:color:)`. The color comes from the matching tracker in `trackers` (by `trackerID`) through `CategoryProgressColor(hue:saturation:brightness:)`, or `nil`.
- Drop rows with `duration <= 0`, as today.
- Keep today's order: rows whose `trackerID` is in `trackers` come first, in `trackers` order. Then other non-untracked rows sorted by name with `localizedStandardCompare`. Then the `untracked` row.

**Verify**: every existing `OverviewMetricsTests` test passes without edits; `grep -n 'trackers.first(where' Hugo/Features/Overview/Domain/OverviewMetrics.swift` → no output.

Commit steps 1-3: `fix: show carried-in time under its category on every screen`.

### Step 4: Run the gate

**Verify**: `Scripts/verify.sh` → exit 0.

### Step 5 [owner]: Check both languages on a device

1. In English, transfer minutes from one month. In the next month, the Year page card and the Overview breakdown each show one "Field Service" row that includes the carried minutes.
2. Switch the device to Danish: both screens show the carried minutes under "Forkyndelse", with no "Tjeneste" row.
3. Delete a separate category that has entries, then open a month with those entries: its time still shows under the deleted category's name.

## Test plan

- New `CategoryTotalsTests`: 10 tests (Step 1).
- `MonthlyReportBuilderTests`: 1 new test (Step 2); existing tests unchanged.
- `OverviewMetricsTests`, `TheocraticYearReportBuilderTests`, `ServiceMonthTests`: unchanged and passing.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -rn 'categories\[metadata.key' Hugo` prints nothing
- [ ] `grep -c 'CategoryTotals.rows' Hugo/Features/Reports/Domain/MonthlyReportBuilder.swift Hugo/Features/Overview/Domain/OverviewMetrics.swift` prints `1` for each file
- [ ] `git diff --stat 03eb5c3..HEAD -- HugoTests/Features/Overview/Domain/OverviewMetricsTests.swift` prints nothing (this plan does not edit that file; `03eb5c3` is `main` after plan 063)
- [ ] `git status --porcelain` lists only files from the Scope list
- [ ] `plans/README.md` row for 064 updated

## STOP conditions

Stop and report back if:

- An existing `OverviewMetricsTests` or `MonthlyReportBuilderTests` test fails and passing it would need a test edit. That means the rule differs from the agreed one.
- Reading `Tracker` or `Entry` properties inside the `nonisolated enum CategoryTotals` gives an actor-isolation error. `MonthlyReportBuilder` already does this, so report the exact error instead of changing isolation.
- `ServiceMonth.make` or `TheocraticYearReportBuilder.report` does not exist with the parameters named in Step 2 (plans 061 or 062 not done).

## Maintenance notes

- Main time with no category at all ("untracked") is inconsistent today. Reporting lines count it as Field Service time. Month summaries leave it out of `mainDuration`, so it is not credited toward the yearly goal. That is a product decision this plan does not make. If the owner decides, change `CategoryTotals` and `MonthlyReportBuilder` together.
- Any new screen that splits time by category must call `CategoryTotals.rows`, not group by `resolvedCategory().key` itself.
- Reviewer focus: the tie-break when several live categories match (default first, then oldest). Display rows only, so a different pick on another device does no harm, but the order must be deterministic.
