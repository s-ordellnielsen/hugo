# Plan 169: Month grid and hours chart on the Service Year page on wide screens

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat <BASELINE>..HEAD -- Hugo/Features/ServiceYear Hugo/DesignSystem`
> The reviewer sets <BASELINE> at dispatch to the commit after the previous plan in the batch (166–173). Expected: no output. STOP on any output.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit, under `planner.target.*`). Never `git add` that file; Step 2
> stages your two strings with a script.

## Status

- **Priority**: P2
- **Effort**: M + owner
- **Risk**: MEDIUM. The Service Year page's layout changes on wide iPads. The plan keeps one `LazyVGrid` with the same month views in every layout, so rotating does not recreate them (their sheets and zoom transitions keep working).
- **Depends on**: 168 (`TwoColumnBreakpoint`, `HugoLayout.Size.twoColumnMinimumWidth`); runs after 166 and 167
- **Category**: ux
- **Planned at**: commit `16b697c`, 2026-11-26
- **Issue**: [SLN-345](https://linear.app/sebastianln/issue/SLN-345)

## Why this matters

On a wide iPad the Service Year page is one 672-point column with the year's
totals card and twelve tall month cards. In landscape you see two or three
months at a time, and comparing months means scrolling up and down.

After this plan, on a wide container (the same 880-point breakpoint as plan 168):

- The month cards sit in a grid: three columns on an 11" iPad in landscape, two
  with the sidebar shown. Never more than three: the page grows to 1,100 points
  at most, which fits three 300-point cards. These are the same cards as
  today, with the same tap (zoom into the month's page), the same long-press
  menu and the same sheets.
- Above the grid, a card with a bar chart of hours per month and the monthly
  goal as a dashed mint line, in the style of Apple's Health and Screen Time charts.

Narrow widths (iPhone, iPad portrait, split view) look and behave the same as
today. The only difference is that the cards are now built lazily, as the grid
scrolls (see Step 4).

Decisions (owner to confirm):

- **The grid reuses the existing month cards** instead of new compact tiles. The cards already show the hours, the submitted check, the unreported-change warning, and a faded title for future months. One view means one tap behavior and no second design to maintain. The cost is that cards in a row can differ in height (each row is as tall as its tallest card, top-aligned).
- **The chart's bars show the same number as each card's headline** (`ServiceMonth.contribution.total`: reported hours for submitted months, logged time otherwise). Future months get no bar. The x axis still spans September to August.
- **The chart shows only when the year has entries** (`report.hasEntries`, the same condition as the totals card). An empty year shows the empty-year card and the grid, without a chart of nothing.
- **The goal line is the publisher status's monthly goal**, without the Buffer. It is hidden for statuses without a goal.
- **VoiceOver skips the chart** (`accessibilityHidden`), because the month cards right below read the same numbers month by month. A second, chart-shaped reading of twelve values adds length, not information. The chart's title is hidden with it.
- **Bars are `.primary`, the goal line is `hugoAccent`.** Hugo stays monochrome, and mint marks the one thing to compare against.

## Current state

`Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift`, `body` (after plan
167, which added the two hover lines to the totals card; plans 166 and 168 do
not touch this file):

```swift
    var body: some View {
        let report = self.report
        let progress = progress(for: report)
        let creditsByMonth = Dictionary(grouping: schoolCredits, by: \.yearMonth)
        return ScrollView {
            VStack(spacing: HugoLayout.Spacing.card) {
                if report.hasEntries {
                    NavigationLink {
                        ServiceYearDetailView(report: report, progress: progress)
                    } label: {
                        TheocraticYearTotalsView(report: report, progress: progress)
                    }
                    .buttonStyle(.card)
                    .contentShape(.hoverEffect, .rect(cornerRadius: HugoLayout.CornerRadius.card))
                    .hoverEffect(.highlight)
                } else {
                    emptyYearCard
                }

                ForEach(report.months) { month in
                    ServiceYearMonthRow(
                        month: month,
                        schoolCredits: creditsByMonth[month.id] ?? []
                    )
                    .id(month.id)
                }
            }
            .padding()
            .readableContentWidth()
        }
        .frame(maxWidth: .infinity)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 0
        } action: { _, isScrolledFromTop in
            onScrolledFromTopChange?(isScrolledFromTop)
        }
    }
```

The page has `year: TheocraticYear` and `private var status: PublisherStatus?`.
`PublisherStatus.monthlyGoal` is an `Int` (hours, 0 for no goal).
`TheocraticYear.dateRange(calendar:)` returns `Range<Date>`.
`YearMonth.date(day: Int = 1, calendar: Calendar = .current) -> Date`.
`YearMonth` is `nonisolated struct YearMonth: Hashable, Comparable`.

`ServiceMonth` (`Hugo/Features/Reports/Domain/ServiceMonth.swift`) is
`nonisolated struct ServiceMonth: Identifiable` with `id: YearMonth`,
`isFuture: Bool` and `contribution: MonthContribution` (`total: TimeInterval`,
which the month card's headline shows through `MonthHeadline(seconds: month.contribution.total, ...)`).

`ServiceYearMonthRow` (`Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift`)
is the month card. It owns `@Namespace`, two sheet flags, a `NavigationLink` to
`MonthDetailView` with a zoom transition, and a `.contextMenu`. It draws its own
card background and fills the width it gets (`.frame(maxWidth: .infinity, alignment: .leading)`).

`readableContentWidth()` (plan 159) is `.frame(maxWidth: <scaled 672>).frame(maxWidth: .infinity)`.
`ServiceYearMonthRow` after plan 167 has two hover lines after its `.contextMenu`;
it is otherwise as described above.

After plan 168, `HugoLayout.Size.twoColumnMinimumWidth` (880) and
`TwoColumnBreakpoint.usesTwoColumns(availableWidth:minimumWidth:isAccessibilitySize:)`
exist in `Hugo/DesignSystem`.

Swift Charts is not used in the app yet. It is a system framework (`import Charts`),
so no package or project change is needed.

Tests: `HugoTests/Features/ServiceYear/Domain/TheocraticYearReportBuilderTests.swift`
builds reports with a fixed UTC Gregorian calendar, `Locale(identifier: "en_US_POSIX")`,
`TheocraticYear(startYear: 2026)`, `now: date(2026, 10, 15)`, and
`Entry(date:duration:tracker:)`, through
`TheocraticYearReportBuilder.report(for:entries:now:calendar:locale:)`.
Its helpers are all `private`, so you cannot call them from another file: copy
the `calendar` and `locale` properties, the `date(_:_:_:)` helper
(`calendar.date(from: DateComponents(year: year, month: month, day: day))!`) and
the `makeReport(for:entries:now:)` helper into the new test struct.

String catalog: the `year.*` keys start at `"year.detail.credited"`. The owner's
uncommitted edits are around lines 2,900–3,130 (`planner.target.*`).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `xcrun swift-format lint --strict <files>` | exit 0 |
| Format fix | `xcrun swift-format format -i <files>` | then re-run lint; use when `lint --strict` fails on formatting only |

## Scope

**In scope**:

- `Hugo/DesignSystem/Theme/Theme.swift` (three tokens)
- `Hugo/Features/ServiceYear/Domain/YearHoursChartData.swift` (create)
- `HugoTests/Features/ServiceYear/Domain/YearHoursChartDataTests.swift` (create)
- `Hugo/Features/ServiceYear/Views/YearHoursChart.swift` (create)
- `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift`
- `Hugo/Resources/Localizable.xcstrings` (two keys, by script only)

**Out of scope**:

- `ServiceYearMonthRow`, `MonthDetailView`, `TheocraticYearTotalsView`, `ServiceYearView` (the pager), the report builders.

## Git workflow

- Work on `main`. Commit per step, Conventional Commits. Do not push.

## Steps

### Step 1: Chart data, with tests

Create `Hugo/Features/ServiceYear/Domain/YearHoursChartData.swift`:

```swift
import Foundation

/// One bar of the Service Year hours chart.
nonisolated struct YearHoursChartPoint: Identifiable, Equatable {
    let id: YearMonth
    /// The first day of the month, for the chart's date axis.
    let monthStart: Date
    /// The hours the month's card shows: reported hours once submitted,
    /// logged time before that.
    let hours: Double
}

nonisolated enum YearHoursChartData {
    /// One point per month that has started, in the report's order. Future
    /// months get no bar.
    static func points(from months: [ServiceMonth], calendar: Calendar = .current) -> [YearHoursChartPoint] {
        months.filter { !$0.isFuture }.map { month in
            YearHoursChartPoint(
                id: month.id, monthStart: month.id.date(calendar: calendar),
                hours: month.contribution.total / 3_600)
        }
    }
}
```

Create `HugoTests/Features/ServiceYear/Domain/YearHoursChartDataTests.swift`
(`struct`, Swift Testing, the helpers copied from `TheocraticYearReportBuilderTests`
as described under "Current state"). Every test builds its report with
`makeReport(for:entries:now:)` and then calls
`YearHoursChartData.points(from: report.months, calendar: calendar)`, always
passing the fixed UTC `calendar` explicitly (the default `.current` would make
the month starts depend on the machine's time zone):

1. `futureMonthsHaveNoPoints`: empty entries, `now` 2026-10-15 → 2 points (September, October).
2. `pointHoursMatchTheMonthContribution`: one 90-minute entry on 2026-09-03 → the September point has `hours == 1.5`, and `hours * 3_600 == report.months[0].contribution.total`.
3. `pointsStartOnTheFirstOfTheMonth`: the October point's `monthStart` is 2026-10-01 00:00 UTC.
4. `wholeYearInThePastHasTwelvePoints`: `now` 2027-09-15 → 12 points, the last for August 2027.

**Verify**: lint; `Scripts/verify.sh` exits 0 with 4 more tests.
Commit `feat(service-year): add hours chart data`.

### Step 2: Strings

Do this before any step that builds with the new keys (`year.chart.title`,
`year.chart.goal`). A build that sees an unknown key can add it to the catalog
on its own, and this script's `key already present` assertion would then fail.


Run this from the repo root. It adds both keys before `"year.detail.credited"`
in the working file and stages them on top of the committed version, leaving
the owner's edits unstaged:

```sh
python3 - <<'EOF'
import subprocess
path = 'Hugo/Resources/Localizable.xcstrings'
def key(name, comment, en, da):
    return f'''    "{name}" : {{
      "comment" : "{comment}",
      "localizations" : {{
        "da" : {{
          "stringUnit" : {{
            "state" : "translated",
            "value" : "{da}"
          }}
        }},
        "en" : {{
          "stringUnit" : {{
            "state" : "translated",
            "value" : "{en}"
          }}
        }}
      }}
    }},
'''
block = key("year.chart.goal", "Label on the dashed line in the Service Year hours chart: the publisher status's monthly goal.", "Monthly goal", "Månedligt mål") + key("year.chart.title", "Title of the bar chart of hours per month on the Service Year tab (wide iPad screens).", "Hours per month", "Timer pr. måned")
anchor = '    "year.detail.credited" : {\n'
def insert(text):
    assert text.count(anchor) == 1, 'anchor not found exactly once'
    assert '"year.chart.title"' not in text, 'key already present'
    return text.replace(anchor, block + anchor, 1)
work = open(path, encoding='utf-8').read()
open(path, 'w', encoding='utf-8').write(insert(work))
head = subprocess.run(['git', 'show', 'HEAD:' + path], capture_output=True, text=True, check=True).stdout
blob = subprocess.run(['git', 'hash-object', '-w', '--stdin'], input=insert(head),
                      capture_output=True, text=True, check=True).stdout.strip()
subprocess.run(['git', 'update-index', '--cacheinfo', '100644,' + blob + ',' + path], check=True)
EOF
```

Then `git diff --cached Hugo/Resources/Localizable.xcstrings | grep -c '^+'` must
print 35 (two keys of 17 lines, plus the `+++` header line) and nothing else may
be staged, and `git diff Hugo/Resources/Localizable.xcstrings` must still show
the owner's `planner.target` hunks. Otherwise STOP. Never run `git add` on the
catalog. `Scripts/verify.sh` exits 0 with the same test count as after Step 1.
Commit `feat(service-year): add hours chart strings` (the index holds only the
catalog).

### Step 3: Tokens and the chart view

In `Theme.swift`, inside `HugoLayout.Size`, after the plan 168 tokens, add:

```swift
        /// Height of the plot in the Service Year hours chart.
        static let yearChartHeight: CGFloat = 180
        /// Narrowest month card in the Service Year grid on wide screens.
        static let yearMonthCardMinimumWidth: CGFloat = 300
        /// Widest the Service Year page grows on wide screens.
        static let yearGridMaximumWidth: CGFloat = 1_100
```

Create `Hugo/Features/ServiceYear/Views/YearHoursChart.swift`:

```swift
import Charts
import SwiftUI

/// Hours per month of a theocratic year as bars, with the monthly goal as a
/// dashed line. Shown above the month cards on wide screens. VoiceOver skips
/// it: the month cards below read the same numbers.
struct YearHoursChart: View {
    let year: TheocraticYear
    let points: [YearHoursChartPoint]
    /// The publisher status's monthly goal in hours; no line when nil or 0.
    let monthlyGoalHours: Int?

    // Plain strings, not localized keys: the chart is hidden from VoiceOver,
    // and string literals here would add keys to the string catalog.
    private static let monthLabel = "month"
    private static let hoursLabel = "hours"
    private static let goalLabel = "goal"

    var body: some View {
        let range = year.dateRange()
        // The twelve month starts, September to August. Explicit values: a
        // stride over the closed range would also tick September 1 of the next year.
        let monthStarts = year.months.map { $0.date() }
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
            Text("year.chart.title")
                .font(.headline)
            Chart {
                ForEach(points) { point in
                    BarMark(
                        x: .value(Self.monthLabel, point.monthStart, unit: .month),
                        y: .value(Self.hoursLabel, point.hours)
                    )
                    .foregroundStyle(Color.primary)
                    .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.calendarBar))
                }
                if let monthlyGoalHours, monthlyGoalHours > 0 {
                    RuleMark(y: .value(Self.goalLabel, monthlyGoalHours))
                        .foregroundStyle(Color.hugoAccent)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("year.chart.goal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .chartXScale(domain: range.lowerBound...range.upperBound)
            .chartXAxis {
                AxisMarks(values: monthStarts) { _ in
                    AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
                }
            }
            .frame(height: HugoLayout.Size.yearChartHeight)
        }
        .padding(HugoLayout.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
        .accessibilityHidden(true)
    }
}
```

If `.clipShape` is not available on `BarMark`, use `.cornerRadius(HugoLayout.CornerRadius.calendarBar)`
and note it. If `.value(_:_:)` with a `String` constant does not compile, use
`.value(Text(verbatim: "month"), ...)` and note it.

**Verify**: lint; `Scripts/verify.sh` exits 0, same test count. (The view is not
used yet, so it only needs to compile. It uses the two string keys that Step 2
already added.) Stage `Theme.swift` and `YearHoursChart.swift` by path and
commit `feat(service-year): add an hours chart view`.

### Step 4: Use the grid and the chart on the page

In `ServiceYearPageView.swift`:

1. Add state and a scaled readable width next to the other properties:

```swift
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var readableWidth = HugoLayout.Size.readableContentWidth
    /// The page's width inside its padding, measured.
    @State private var availableWidth: CGFloat = 0

    private var isWide: Bool {
        TwoColumnBreakpoint.usesTwoColumns(
            availableWidth: availableWidth, minimumWidth: HugoLayout.Size.twoColumnMinimumWidth,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize)
    }

    /// One column when narrow (today's list), as many 300-point columns as fit when wide.
    private var monthColumns: [GridItem] {
        isWide
            ? [
                GridItem(
                    .adaptive(minimum: HugoLayout.Size.yearMonthCardMinimumWidth),
                    spacing: HugoLayout.Spacing.card, alignment: .top)
            ]
            : [GridItem(.flexible(), alignment: .top)]
    }
```

2. Replace the whole `body`. This is the `body` being replaced (after plan 167):

```swift
    var body: some View {
        let report = self.report
        let progress = progress(for: report)
        let creditsByMonth = Dictionary(grouping: schoolCredits, by: \.yearMonth)
        return ScrollView {
            VStack(spacing: HugoLayout.Spacing.card) {
                if report.hasEntries {
                    NavigationLink {
                        ServiceYearDetailView(report: report, progress: progress)
                    } label: {
                        TheocraticYearTotalsView(report: report, progress: progress)
                    }
                    .buttonStyle(.card)
                    .contentShape(.hoverEffect, .rect(cornerRadius: HugoLayout.CornerRadius.card))
                    .hoverEffect(.highlight)
                } else {
                    emptyYearCard
                }

                ForEach(report.months) { month in
                    ServiceYearMonthRow(
                        month: month,
                        schoolCredits: creditsByMonth[month.id] ?? []
                    )
                    .id(month.id)
                }
            }
            .padding()
            .readableContentWidth()
        }
        .frame(maxWidth: .infinity)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 0
        } action: { _, isScrolledFromTop in
            onScrolledFromTopChange?(isScrolledFromTop)
        }
    }
```

and this is the new `body`. The totals card keeps its two hover lines; the
chart shows only on wide screens and only when the year has entries; the
`ForEach` moves into one grid; `.padding()` and `.readableContentWidth()` become
explicit frames with the measurement:

```swift
    var body: some View {
        let report = self.report
        let progress = progress(for: report)
        let creditsByMonth = Dictionary(grouping: schoolCredits, by: \.yearMonth)
        return ScrollView {
            VStack(spacing: HugoLayout.Spacing.card) {
                if report.hasEntries {
                    NavigationLink {
                        ServiceYearDetailView(report: report, progress: progress)
                    } label: {
                        TheocraticYearTotalsView(report: report, progress: progress)
                    }
                    .buttonStyle(.card)
                    .contentShape(.hoverEffect, .rect(cornerRadius: HugoLayout.CornerRadius.card))
                    .hoverEffect(.highlight)
                } else {
                    emptyYearCard
                }

                if isWide && report.hasEntries {
                    YearHoursChart(
                        year: year, points: YearHoursChartData.points(from: report.months),
                        monthlyGoalHours: status?.monthlyGoal)
                }

                LazyVGrid(columns: monthColumns, spacing: HugoLayout.Spacing.card) {
                    ForEach(report.months) { month in
                        ServiceYearMonthRow(
                            month: month,
                            schoolCredits: creditsByMonth[month.id] ?? []
                        )
                        .id(month.id)
                    }
                }
            }
            .padding(HugoLayout.Spacing.spacious)
            .frame(maxWidth: isWide ? HugoLayout.Size.yearGridMaximumWidth : readableWidth)
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                availableWidth = width - 2 * HugoLayout.Spacing.spacious
            }
        }
        .frame(maxWidth: .infinity)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 0
        } action: { _, isScrolledFromTop in
            onScrolledFromTopChange?(isScrolledFromTop)
        }
    }
```

Why this shape:
- One grid in both layouts, so the month cards are the same views when the column count changes (their sheets, menus and zoom transitions survive a rotation). A `ForEach` in a `VStack` on one side and a grid on the other would recreate them.
- A `LazyVGrid` builds its cards lazily, so on iPhone too the twelve cards are now built as they scroll into view, where the old `VStack` built all twelve at once. This is accepted: the cards look and behave the same.
- `.padding(HugoLayout.Spacing.spacious)` is the same 16 points as `.padding()`.
- The two frames are what `readableContentWidth()` did, with a wider cap on wide screens. `readableWidth` is scaled with Dynamic Type exactly as in `readableContentWidth()`.
- The width is measured outside the cap and padding, then the padding is subtracted, so the breakpoint sees the same content width as plan 168's stack.

**Verify**: lint; `Scripts/verify.sh` exits 0, same test count as after Step 1.
`grep -n "readableContentWidth()" Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift` prints nothing.
Commit `feat(service-year): show months in a grid with an hours chart on wide screens`.

## Test plan

- Four chart data tests. The page is checked on the devices.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, 4 more tests than before this plan
- [ ] The strings commit (Step 2) held exactly the two new keys; the owner's edits are still unstaged
- [ ] No `horizontalSizeClass` in changed files
- [ ] `plans/README.md` row updated

Owner check on the iPad (Sean), light and dark mode:

1. Landscape, sidebar hidden: the totals card, the chart, then three columns of month cards. The bars match each card's hours. The dashed mint line sits at the monthly goal. Future months have no bar.
2. Sidebar shown: two columns. Never more than three columns, even in the widest window.
3. Tap a month: it zooms into the month's page as before. Long-press: the same menu. Add Entry from the menu, then rotate the iPad with the sheet open: the sheet stays.
4. Portrait: one column, no chart, the same as before. A year without entries shows the empty-year card and no chart.
5. VoiceOver in landscape: the chart is skipped. The month cards read as before.
6. Swipe to another theocratic year: the chart and grid follow.

On the iPhone (Mona): the Service Year page looks and scrolls the same as before.

## STOP conditions

Stop and report if:

- Plan 168's `TwoColumnBreakpoint` or `twoColumnMinimumWidth` does not exist.
- The catalog checks in Step 2 differ.
- Rotating with a month sheet open closes the sheet (owner check 3). Report it; do not split the grid into two code paths.
- Charts' API differs beyond the two fallbacks named in Step 3.

## Maintenance notes

- Plan 171 (drag a report out) adds a drag to the month cards. It works the same in the grid because the cards are unchanged views.
- Plan 166 may add context menu items to the month cards; the grid does not affect them.
- If the owner wants the chart on iPhone too, drop the `if isWide` around it. It is plain SwiftUI and works at any width, but iPhone was kept unchanged on purpose.
- If the chart should include the Buffer, pass `status.monthlyGoal + extraHours` when `includeBuffer` is on, matching `YearlyGoalProgress`.
