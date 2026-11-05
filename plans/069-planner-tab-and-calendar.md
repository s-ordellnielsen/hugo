# Plan 069: Add the Planner tab with a swipeable month calendar

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 2e8a451..HEAD -- Hugo/App/AppRootView.swift Hugo/DesignSystem/Theme/Theme.swift Hugo/PreviewSupport/PreviewModelContainer.swift Hugo/Features/ServiceYear/Screens/ServiceYearView.swift Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift Hugo/Features/Overview/Screens/OverviewView.swift Hugo/Resources/Localizable.xcstrings`
> Plans 067 and 068 must be DONE first. For any change to the files above,
> compare the "Current state" excerpts against the live code; on a mismatch,
> treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW (new screen; the only edit to existing UI is one tab case)
- **Depends on**: plans/067-plan-model-schema-v12.md, plans/068-planner-domain-math.md
- **Category**: direction
- **Planned at**: commit `2e8a451`, 2026-11-04
- **Issue**: [SLN-272](https://linear.app/sebastianln/issue/SLN-272)

## Why this matters

The Planner needs a home: its own tab with a month calendar that shows, for
each day, the time planned and the time logged. Users swipe sideways between
months, the same gesture they already use between years on the Year tab. This
plan builds the tab, the paging and a read-only calendar. Plan 070 makes days
tappable (a sheet to add plans and entries), plan 071 adds the status header.
Do not ship a build between 069 and 070: the intro card says "Tap a day".

## Product rules (decided with the owner, do not change)

1. The Planner tab is always visible (no setting to hide it). It comes after
   the Year tab: Overview, Year, Planner (and Settings in the iPad sidebar).
   Tab title "Planner", SF Symbol `calendar`.
2. The Planner pages through the current month and the next 11 months
   (`PlannerMonth.reachableMonths`). No past months; the Year tab covers history.
   Tapping the Planner tab while it is already selected scrolls back to the
   current month (same as the Year tab).
3. Each day cell shows the day number and the day's **bars**
   (`PlannerDay.bars` from plan 068), stacked top to bottom like events in
   Apple Calendar's month view:
   - A **plan** bar is a rounded rectangle with a 1 pt outline in the category
     color and a translucent tint (category color at 15 %). Logged time fills it
     from left to right in the category color at 55 % (`PlannerBar.fraction`).
     Owner's example: 2 h Field Service and 1 h LDC planned, 1 h of each logged:
     the Field Service bar is half full, the LDC bar is full.
   - An **unplanned** bar (logged time no plan covers) is drawn the same way, full.
   - Inside each bar: the category icon and the bar's hours
     (`PlannerHoursText.short(bar.seconds)`), falling back to hours only, then
     icon only, when the cell is too narrow (`ViewThatFits`).
   - At most three bars; with four or more, show the first two and a "+N" line.
   - Category color: the tracker's stored color (`CategoryProgressColor`) when it
     has one, otherwise `Color.hugoAccent`. Most existing categories have no
     stored color, which is why the icon is in every bar.
   Today's number sits in a filled `.primary` circle with inverted text, like
   iOS Calendar. Past days' numbers use `.secondary`. No red or green: a "short"
   color could discourage users who are behind (see the comment in
   `MonthlyProgressCard.swift` around line 30); an unfilled part already shows it.
4. **Entries always show**, whether or not the day has plans (as unplanned bars).
5. A legend under the grid shows an empty bar ("Planned") and a full bar
   ("Logged"). When the month has no plans, an intro card under the calendar
   explains the Planner in one sentence.
6. Hugo's chrome is monochrome (`.primary`); `.hugoAccent` is only for progress
   and completion markers, and category colors are content. The bars are both.

## Current state

- `Hugo/App/AppRootView.swift` builds the tabs. Relevant parts:

  ```swift
  @State private var selectedTab: AppTab = .overview
  @State private var yearResetToken = UUID()
  ...
  private func select(_ tab: AppTab) {
      if tab == .year && selectedTab == .year {
          yearResetToken = UUID()
      }
      selectedTab = tab
  }
  ...
  Tab(tab.titleKey, systemImage: tab.systemImage, value: tab) {
      tabDestination(for: tab, yearResetToken: yearResetToken)
  }
  ...
  } detail: {
      tabDestination(for: selectedTab, yearResetToken: yearResetToken)
  }
  ...
  @ViewBuilder
  func tabDestination(for tab: AppTab, yearResetToken: UUID) -> some View {
      switch tab {
      case .overview: OverviewView()
      case .year: ServiceYearView(resetToken: yearResetToken)
      case .settings: SettingsView()
      }
  }

  enum AppTab: String, CaseIterable, Identifiable, Hashable {
      case overview
      case year
      case settings
      ...
      var titleKey: LocalizedStringKey {
          switch self {
          case .overview: return "tab.overview"
          case .year: return "tab.year"
          case .settings: return "tab.settings"
          }
      }

      var systemImage: String {
          switch self {
          case .overview: "house"
          case .year: "tray.full.fill"
          case .settings: "switch.2"
          }
      }

      var placement: TabPlacement {
          switch self {
          case .overview: .all
          case .year: .all
          case .settings: .sidebarOnly
          }
      }
  }
  ```

- `Hugo/Features/ServiceYear/Screens/ServiceYearView.swift` is the paging
  pattern to copy: a `NavigationStack` holding `ScrollView(.horizontal)` →
  `LazyHStack(spacing: 0)` → `ForEach(years)` of pages with
  `.containerRelativeFrame(.horizontal)`, then `.scrollTargetLayout()`,
  `.scrollTargetBehavior(.paging)`, `.scrollPosition(id: $scrollPosition)`,
  `.scrollIndicators(.hidden)`, `.background(Color(.systemGroupedBackground))`,
  `.navigationTitle(...)`, `.navigationSubtitle("year.subtitle")`,
  `.navigationBarTitleDisplayMode(.inline)`, a `.principal` toolbar item with
  the title in `.font(.system(.headline, design: .serif, weight: .bold))`, and
  `ToolbarItem { SettingsButton(sizeClass: .compact) }`. On appear it sets
  `scrollPosition` to the current id; `.onChange(of: scrollPosition)` updates
  `displayedYear` inside `withAnimation(.snappy)`; `.onChange(of: resetToken)`
  scrolls back to the current year.
- `Hugo/Features/Overview/Screens/OverviewView.swift` shows how a screen keeps
  "today" fresh: `@State private var today = Calendar.current.startOfDay(for: .now)`,
  a private child view built with `today` and `.id(today)`, refreshed on
  `scenePhase == .active` and on `UIApplication.significantTimeChangeNotification`
  (`import Combine`, `import UIKit`).
- `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift` `emptyYearCard`
  is the card style for the intro card:

  ```swift
  VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
      Image(systemName: "calendar")
          .font(.largeTitle)
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(.secondary)
      Text("year.empty.title")
          .font(.title3)
          .fontWeight(.semibold)
      Text("year.empty.description")
          .font(.subheadline)
          .foregroundStyle(.secondary)
  }
  .padding(HugoLayout.Spacing.card)
  .frame(maxWidth: .infinity, alignment: .leading)
  .background(Color(.secondarySystemGroupedBackground))
  .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
  ```

- `Hugo/DesignSystem/Theme/Theme.swift`: `HugoLayout.Spacing` (`tight` 4, `small` 6,
  `compact` 8, `regular` 12, `spacious` 16, `roomy` 20, `card` 24, `section` 32),
  `HugoLayout.CornerRadius.card` (32), `HugoLayout.Size` (for example
  `entryIcon: CGFloat = 32`, `minimumHitTarget: CGFloat = 44`), `Color.hugoAccent`.
- `Hugo/PreviewSupport/PreviewModelContainer.swift` builds `ModelContainer.preview`
  with two trackers (`field`, `phone`) and three entries.
- Plan 068 types you will use: `CalendarDay`, `PlannedItem(plan, trackers:)`,
  `PlannerMonth.make(month:items:entries:trackers:now:calendar:)`, `PlannerMonth.reachableMonths(from:)`,
  `PlannerDay` (`id: CalendarDay`, `bars: [PlannerBar]`, `isToday`, `isPast`),
  `PlannerBar` (`id`, `kind` `.plan`/`.unplanned`, `categoryName`, `categoryIconName`,
  `color: CategoryProgressColor?`, `seconds`, `filledSeconds`, `fraction`),
  `PlannerMonth.hasPlans`.
- `Hugo/Features/Overview/Views/CategoryProgressBreakdownView.swift` turns a
  category color into a SwiftUI color; copy it:

  ```swift
  guard let color = row.color else { return .hugoAccent }
  return Color(hue: color.hue, saturation: color.saturation, brightness: color.brightness)
  ```
- `ServiceDurationFormatter.accessibilityString(from:)` (`Hugo/Domain`) speaks a
  duration ("2 hours, 30 minutes").
- Strings live in `Hugo/Resources/Localizable.xcstrings` (source `en`, also `da`).
  Each entry has a `comment` and `en`/`da` `stringUnit`s with `"state" : "translated"`;
  keys are sorted alphabetically; separators are `" : "` with two-space indents.
  Example:

  ```json
  "year.header.ahead" : {
    "comment" : "Counted time is ahead of the expected time. The argument is a duration such as 3 hours.",
    "localizations" : {
      "da" : {
        "stringUnit" : {
          "state" : "translated",
          "value" : "%@ foran"
        }
      },
      "en" : {
        "stringUnit" : {
          "state" : "translated",
          "value" : "%@ ahead"
        }
      }
    }
  },
  ```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Layout | `Scripts/check-layout.sh` | exit 0, no output |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/PlannerHoursTextTests -only-testing:HugoTests/CalendarGridLayoutTests -only-testing:HugoTests/PlannerMonthTests` | `** TEST SUCCEEDED **` |
| Strings valid JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | no output |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Suggested executor toolkit

- If the `write-swift` skill is available, use it for SwiftUI and Swift 6 questions.

## Scope

**In scope**:
- `Hugo/App/AppRootView.swift`
- `Hugo/DesignSystem/Theme/Theme.swift` (two size tokens)
- `Hugo/PreviewSupport/PreviewModelContainer.swift` (two preview plans)
- `Hugo/Resources/Localizable.xcstrings` (new keys only)
- Create: `Hugo/Features/Planner/Domain/PlannerHoursText.swift`,
  `Hugo/Features/Planner/Domain/CalendarGridLayout.swift`,
  `Hugo/Features/Planner/Screens/PlannerView.swift`,
  `Hugo/Features/Planner/Views/PlannerMonthPage.swift`,
  `Hugo/Features/Planner/Views/PlannerCalendarGrid.swift`,
  `Hugo/Features/Planner/Views/PlannerDayCell.swift`,
  `Hugo/Features/Planner/Views/PlannerBarView.swift`,
  `Hugo/Features/Planner/Views/PlannerLegend.swift`,
  `Hugo/Features/Planner/Views/PlannerIntroCard.swift`,
  `HugoTests/Features/Planner/Domain/PlannerHoursTextTests.swift`,
  `HugoTests/Features/Planner/Domain/CalendarGridLayoutTests.swift`

**Out of scope**:
- Tapping a day (plan 070), the status header (plan 071), Overview (plan 072).
- `ServiceYearView`, `OverviewView`: patterns to copy, not files to change.
- Any change to plan 068's domain types. If one is wrong, STOP.

## Git workflow

- Branch: `advisor/069-planner-tab-and-calendar`
- Conventional Commits, for example `feat: add the planner tab with a month calendar`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Two small formatting helpers, with tests

`Hugo/Features/Planner/Domain/PlannerHoursText.swift`:

```swift
import Foundation

nonisolated enum PlannerHoursText {
    /// A short duration for a calendar cell, such as "2h", "1h 30m" or "45m".
    /// Seconds are dropped.
    static func short(_ seconds: TimeInterval, locale: Locale = .current) -> String {
        let wholeMinutes = Int(max(seconds, 0) / 60)
        var style = Duration.UnitsFormatStyle(
            allowedUnits: [.hours, .minutes], width: .narrow, zeroValueUnits: .hide)
        style.locale = locale
        return Duration.seconds(wholeMinutes * 60).formatted(style)
    }
}
```

`Hugo/Features/Planner/Domain/CalendarGridLayout.swift`:

```swift
import Foundation

/// Where a month's days fall in a seven-column calendar grid.
nonisolated enum CalendarGridLayout {
    /// Very short weekday names, starting at the calendar's first weekday.
    static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Empty cells before the month's first day.
    static func leadingBlankDays(in month: YearMonth, calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: month.date(calendar: calendar))
        return (weekday - calendar.firstWeekday + 7) % 7
    }
}
```

Tests (Swift Testing; a Gregorian calendar in UTC with
`calendar.locale = Locale(identifier: "en_US_POSIX")`):

- `PlannerHoursTextTests`, with `Locale(identifier: "en_US")`: 7_200 → `"2h"`,
  5_400 → `"1h 30m"`, 2_700 → `"45m"`, 5_430 → `"1h 30m"` (seconds dropped).
  If Foundation renders these with different spacing on the simulator (for
  example `"1h30m"`), use the actual output in the expectation and note it in
  the commit message. Do not hand-build the string.
- `CalendarGridLayoutTests`: with `firstWeekday = 1`, symbols start with `"S"` and
  have 7 items; with `firstWeekday = 2`, they start with `"M"` and end with `"S"`.
  1 November 2026 is a Sunday, so November 2026 has 6 leading blanks with
  `firstWeekday = 2` and 0 with `firstWeekday = 1`. December 2026 has 1 with `firstWeekday = 2`.

**Verify**: Focused tests → `** TEST SUCCEEDED **`.

### Step 2: Size tokens

In `HugoLayout.Size` (`Hugo/DesignSystem/Theme/Theme.swift`) add, after `goalKnobDiameter`:

```swift
        static let calendarDayNumber: CGFloat = 32
        static let calendarDayMinHeight: CGFloat = 64
        static let calendarBarHeight: CGFloat = 16
```

and in `HugoLayout.CornerRadius` add `static let calendarBar: CGFloat = 4`.

### Step 3: The bar, legend and intro card

`Hugo/Features/Planner/Views/PlannerBarView.swift`:

```swift
import SwiftUI

/// The rounded rectangle behind a bar: outline and tint in `color`, filled from
/// the left up to `fraction`. Also drawn on its own in legends.
struct PlannerBarShape: View {
    let fraction: Double
    let color: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: HugoLayout.CornerRadius.calendarBar)
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                shape.fill(color.opacity(0.15))
                Rectangle()
                    .fill(color.opacity(0.55))
                    .frame(width: proxy.size.width * min(1, max(0, fraction)))
            }
        }
        .clipShape(shape)
        .overlay { shape.strokeBorder(color, lineWidth: 1) }
    }
}

/// One plan, or unplanned logged time, in a calendar day.
struct PlannerBarView: View {
    let bar: PlannerBar

    @ScaledMetric(relativeTo: .caption2) private var height = HugoLayout.Size.calendarBarHeight

    private var color: Color {
        guard let color = bar.color else { return .hugoAccent }
        return Color(hue: color.hue, saturation: color.saturation, brightness: color.brightness)
    }

    var body: some View {
        let hours = Text(PlannerHoursText.short(bar.seconds)).monospacedDigit()
        let icon = Image(systemName: bar.categoryIconName)
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 2) {
                icon
                hours
            }
            hours
            icon
        }
        .font(.caption2)
        .fontWeight(.semibold)
        .lineLimit(1)
        .foregroundStyle(.primary)
        .padding(.horizontal, 3)
        .frame(maxWidth: .infinity, minHeight: height)
        .background { PlannerBarShape(fraction: bar.fraction, color: color) }
    }
}
```

`Hugo/Features/Planner/Views/PlannerLegend.swift`: an `HStack(spacing: HugoLayout.Spacing.spacious)`
with two items, each an `HStack(spacing: HugoLayout.Spacing.small)` of a
`PlannerBarShape` framed `width: 24, height: 12` and a `Text` in `.caption` /
`.secondary`: `PlannerBarShape(fraction: 0, color: .hugoAccent)` with
`"planner.legend.planned"`, and `PlannerBarShape(fraction: 1, color: .hugoAccent)`
with `"planner.legend.logged"`. Mark the shapes `.accessibilityHidden(true)`; the
texts stay readable.

`Hugo/Features/Planner/Views/PlannerIntroCard.swift`: copy the `emptyYearCard`
layout from "Current state" with `Image(systemName: "calendar.badge.plus")`,
`Text("planner.intro.title")` and `Text("planner.intro.description")`.

### Step 4: The day cell and the grid

`Hugo/Features/Planner/Views/PlannerDayCell.swift`:

```swift
import SwiftUI

struct PlannerDayCell: View {
    let day: PlannerDay

    @ScaledMetric(relativeTo: .body) private var numberDiameter = HugoLayout.Size.calendarDayNumber
    @ScaledMetric(relativeTo: .body) private var minHeight = HugoLayout.Size.calendarDayMinHeight

    var body: some View {
        VStack(spacing: HugoLayout.Spacing.tight) {
            Text(String(day.id.day))
                .font(.body)
                .fontWeight(day.isToday ? .bold : .regular)
                .monospacedDigit()
                .foregroundStyle(numberStyle)
                .frame(width: numberDiameter, height: numberDiameter)
                .background {
                    if day.isToday {
                        Circle().fill(.primary)
                    }
                }
            ForEach(visibleBars) { bar in
                PlannerBarView(bar: bar)
            }
            if hiddenBarCount > 0 {
                Text(verbatim: "+\(hiddenBarCount)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .top)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(day.id.startDate(), format: .dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue(Text(accessibilityValue))
    }

    /// Up to three bars; with four or more, the first two and a "+N" line.
    private var visibleBars: [PlannerBar] {
        day.bars.count > 3 ? Array(day.bars.prefix(2)) : day.bars
    }

    private var hiddenBarCount: Int { day.bars.count - visibleBars.count }

    private var numberStyle: AnyShapeStyle {
        if day.isToday { return AnyShapeStyle(Color(.systemBackground)) }
        return day.isPast ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary)
    }

    /// Every bar, also the hidden ones, so VoiceOver users get the whole day.
    private var accessibilityValue: String {
        guard !day.bars.isEmpty else {
            return String(
                localized: "planner.day.a11y.empty", defaultValue: "Nothing planned or logged",
                comment: "VoiceOver value of a calendar day with no plans and no entries.")
        }
        return day.bars.map { bar in
            let name = bar.categoryName
            let logged = ServiceDurationFormatter.accessibilityString(from: bar.filledSeconds)
            switch bar.kind {
            case .plan:
                let planned = ServiceDurationFormatter.accessibilityString(from: bar.seconds)
                return String(
                    localized: "planner.bar.a11y.plan", defaultValue: "\(name): \(logged) of \(planned) logged",
                    comment: "VoiceOver text for one plan in a calendar day. Category name, logged duration, planned duration.")
            case .unplanned:
                return String(
                    localized: "planner.bar.a11y.unplanned", defaultValue: "\(name): \(logged) logged, not planned",
                    comment: "VoiceOver text for logged time that no plan covers. Category name, logged duration.")
            }
        }
        .joined(separator: ". ")
    }
}
```

`Hugo/Features/Planner/Views/PlannerCalendarGrid.swift`:

```swift
import SwiftUI

struct PlannerCalendarGrid: View {
    let month: PlannerMonth

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: HugoLayout.Spacing.tight), count: 7)

    var body: some View {
        VStack(spacing: HugoLayout.Spacing.regular) {
            LazyVGrid(columns: columns, spacing: HugoLayout.Spacing.compact) {
                ForEach(Array(CalendarGridLayout.weekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                ForEach(0..<CalendarGridLayout.leadingBlankDays(in: month.month), id: \.self) { _ in
                    Color.clear.accessibilityHidden(true)
                }
                ForEach(month.days) { day in
                    PlannerDayCell(day: day)
                }
            }
            PlannerLegend()
        }
        .padding(HugoLayout.Spacing.regular)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
    }
}
```

### Step 5: The month page

`Hugo/Features/Planner/Views/PlannerMonthPage.swift`:

```swift
import SwiftData
import SwiftUI

struct PlannerMonthPage: View {
    let month: YearMonth
    let today: Date

    @Query private var entries: [Entry]
    @Query private var plans: [Plan]
    @Query private var trackers: [Tracker]

    init(month: YearMonth, today: Date) {
        self.month = month
        self.today = today
        let range = month.dateRange()
        let start = range.lowerBound
        let end = range.upperBound
        _entries = Query(filter: #Predicate<Entry> { $0.date >= start && $0.date < end }, sort: \Entry.date)
        _plans = Query(filter: #Predicate<Plan> { $0.date >= start && $0.date < end }, sort: \Plan.date)
    }

    private var plannerMonth: PlannerMonth {
        PlannerMonth.make(
            month: month, items: plans.map { PlannedItem($0, trackers: trackers) }, entries: entries,
            trackers: trackers, now: today)
    }

    var body: some View {
        let plannerMonth = self.plannerMonth
        ScrollView {
            VStack(spacing: HugoLayout.Spacing.card) {
                PlannerCalendarGrid(month: plannerMonth)
                if !plannerMonth.hasPlans {
                    PlannerIntroCard()
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
    }
}
```

### Step 6: The tab root

`Hugo/Features/Planner/Screens/PlannerView.swift`: a public `PlannerView` that
owns "today" (copy the `OverviewView` pattern: `@State today`, `.id(today)`,
refresh on `scenePhase` and `significantTimeChangeNotification`) and a
`private struct PlannerPager: View` in the same file that owns the paging
(copy the `ServiceYearView` pattern):

```swift
struct PlannerView: View {
    var resetToken: UUID

    @Environment(\.scenePhase) private var scenePhase
    @State private var today = Calendar.current.startOfDay(for: .now)

    init(resetToken: UUID = UUID()) {
        self.resetToken = resetToken
    }

    var body: some View {
        PlannerPager(today: today, resetToken: resetToken)
            .id(today)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshToday() }
            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: UIApplication.significantTimeChangeNotification)
                    .receive(on: RunLoop.main)
            ) { _ in
                refreshToday()
            }
    }

    private func refreshToday() {
        let start = Calendar.current.startOfDay(for: .now)
        if start != today { today = start }
    }
}

private struct PlannerPager: View {
    let today: Date
    let resetToken: UUID

    @State private var scrollPosition: YearMonth?
    @State private var displayedMonth: YearMonth?

    private var months: [YearMonth] { PlannerMonth.reachableMonths(from: today) }
    private var currentMonth: YearMonth { today.yearMonth() }
    private var activeMonth: YearMonth { displayedMonth ?? currentMonth }

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(months, id: \.self) { month in
                        PlannerMonthPage(month: month, today: today)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollPosition)
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(activeMonth.monthYearString())
            .navigationSubtitle("tab.planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(activeMonth.monthYearString())
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                ToolbarItem {
                    SettingsButton(sizeClass: .compact)
                }
            }
        }
        .onAppear {
            if scrollPosition == nil {
                scrollPosition = currentMonth
                displayedMonth = currentMonth
            }
        }
        .onChange(of: scrollPosition) { _, newValue in
            guard let newValue, months.contains(newValue) else { return }
            withAnimation(.snappy) {
                displayedMonth = newValue
            }
        }
        .onChange(of: resetToken) {
            withAnimation {
                scrollPosition = currentMonth
                displayedMonth = currentMonth
            }
        }
    }
}

#Preview {
    PlannerView()
        .modelContainer(.preview)
}
```

Imports at the top: `Combine`, `SwiftUI`, `UIKit` (as in `OverviewView.swift`).

### Step 7: Register the tab

In `Hugo/App/AppRootView.swift`:

1. Add `@State private var plannerResetToken = UUID()` under `yearResetToken`.
2. In `select(_:)`, add `if tab == .planner && selectedTab == .planner { plannerResetToken = UUID() }`.
3. Change `tabDestination(for:yearResetToken:)` to
   `tabDestination(for tab: AppTab, yearResetToken: UUID, plannerResetToken: UUID)`,
   add `case .planner: PlannerView(resetToken: plannerResetToken)`, and pass
   `plannerResetToken: plannerResetToken` at both call sites.
4. In `AppTab`, add `case planner` between `year` and `settings`;
   `titleKey` → `"tab.planner"`; `systemImage` → `"calendar"`; `placement` → `.all`.

### Step 8: Preview data

In `Hugo/PreviewSupport/PreviewModelContainer.swift`, after the entries, insert
two plans for `field`: 3 hours today (`Plan(date: CalendarDay(.now).midday(), duration: 10_800, tracker: field)`;
the existing 2-hour Phone Service entry today fills it two thirds, which shows a
partly filled bar) and 3 hours starting at 10:00 one week from now
(`startMinute: 600`; compute the day with `Calendar.current.date(byAdding: .day, value: 7, to: .now)`).
Insert before `try context.save()`.

### Step 9: Strings

Add these keys to `Hugo/Resources/Localizable.xcstrings` in the file's format
(see "Current state"), each with a short `comment`, `en` and `da`,
`"state" : "translated"`, in alphabetical key order. Edit with a small script
or careful insertions; do not reformat the rest of the file.

| Key | English | Danish |
|---|---|---|
| `tab.planner` | Planner | Planlægger |
| `planner.legend.planned` | Planned | Planlagt |
| `planner.legend.logged` | Logged | Udført |
| `planner.intro.title` | Plan your month | Planlæg din måned |
| `planner.intro.description` | Tap a day to add the time you want to spend in service. Hugo compares your plan with the time you log. | Tryk på en dag for at tilføje den tid, du vil bruge i tjenesten. Hugo sammenligner din plan med den tid, du registrerer. |
| `planner.bar.a11y.plan` | %1$@: %2$@ of %3$@ logged | %1$@: %2$@ af %3$@ udført |
| `planner.bar.a11y.unplanned` | %1$@: %2$@ logged, not planned | %1$@: %2$@ udført, ikke planlagt |
| `planner.day.a11y.empty` | Nothing planned or logged | Intet planlagt eller udført |

**Verify**: JSON check prints nothing, and
`python3 -I -c "import json; s=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings']; print(all(k in s and 'da' in s[k]['localizations'] for k in ['tab.planner','planner.legend.planned','planner.legend.logged','planner.intro.title','planner.intro.description','planner.bar.a11y.plan','planner.bar.a11y.unplanned','planner.day.a11y.empty']))"`
→ `True`.

### Step 10: Full gate

**Verify**: `Scripts/verify.sh` → exit 0.

## Test plan

- `PlannerHoursTextTests` and `CalendarGridLayoutTests` (Step 1).
- Plan 068's `PlannerMonthTests` covers the numbers the cells show.
- Manual (owner, simulator or device): the Planner tab appears third; swiping
  shows November 2026 through October 2027; today's number is in a filled
  circle; today's 3-hour plan is two thirds filled; next week's plan is an empty
  outlined bar; yesterday's entries show as a full unplanned bar; a day with
  four bars shows two and "+2"; re-tapping the tab returns to the current month;
  VoiceOver reads "Wednesday, 4 November, Field Service: 2 hours of 3 hours
  logged"; at the largest Dynamic Type size the grid grows taller and the bars
  fall back to icon only.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -n "case planner" Hugo/App/AppRootView.swift` → one match
- [ ] `find Hugo/Features/Planner -type d` lists only `Planner`, `Domain`, `Screens`, `Views`
- [ ] All eight string keys exist with `en` and `da`
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- Plans 067 or 068 are not DONE.
- `AppRootView.swift` does not match the excerpt (for example a tab was added).
- `@Query` with a `#Predicate<Plan>` on `date` does not compile.
- Paging does not settle on whole months in the simulator, or `scrollPosition`
  never updates. Report what you see; do not replace the paging approach.
- You find yourself adding tap handling or a sheet. That is plan 070.

## Maintenance notes

- Plan 070 turns `PlannerDayCell` into a button and adds the day sheet; plan 071
  inserts the status header above the grid in `PlannerMonthPage` and moves the
  year-wide queries into `PlannerPager`.
- Each month page runs its own month-bounded `@Query`, the same pattern as
  the Year pages, so CloudKit imports refresh the calendar automatically.
- `PlannerHoursText` uses Foundation's narrow unit names. Ask the owner to check
  the Danish output in a Danish-language simulator.
- The legend and intro card exist because My Service users asked "What are those
  numbers above the calendar?" in reviews. Keep labels next to every number.
- Bars use the category's stored color, which most categories lack today (a
  category color picker is a deferred item in `plans/README.md`). When a picker
  ships, the bars pick up the colors with no change here.
- What fills a bar is decided by `PlanMatcher` (plan 068), not by this view.
