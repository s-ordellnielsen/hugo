# Plan 068: Add the Planner's day, month, target and pace calculations

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 2e8a451..HEAD -- Hugo/Domain Hugo/Features/ServiceYear/Domain Hugo/Features/PublisherStatus/Domain Hugo/Features/Entries/Domain/EntryCategory.swift Hugo/Features/Reports/Domain/ServiceMonth.swift Hugo/Features/Overview/Domain/OverviewMetrics.swift HugoTests/Features/Overview/Domain/OverviewMetricsTests.swift CONTEXT.md`
> Plan 067 must be DONE first (it adds `Plan` and changes `CONTEXT.md`; those
> changes are expected). For any other change, compare the "Current state"
> excerpts against the live code; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW (new pure value types and tests only; nothing existing changes behavior)
- **Depends on**: plans/067-plan-model-schema-v12.md
- **Category**: direction
- **Planned at**: commit `2e8a451`, 2026-11-04
- **Issue**: [SLN-271](https://linear.app/sebastianln/issue/SLN-271)

## Why this matters

The Planner (plans 067-072) compares what a user planned with what they logged,
shows how many hours the month still needs, and tells the Overview whether the
user is ahead of or behind their plan. All of that is arithmetic over days. This
plan puts every rule into small `nonisolated` value types with tests, so the
views in plans 069-072 only display numbers. Getting these rules right and
tested once is what keeps the Planner trustworthy for users who check it
against their own tally.

## Product rules (decided with the owner, do not change)

1. **Logged time per day** is the sum of entry durations on that calendar day.
   Untracked entries (no category) count as **main** time, the same way
   `ReportingLineCalculator` counts them on the Field Service line.
2. **Still planned** (per day, per kind of time, main or separate):
   - days before today: 0,
   - today and later: `max(0, planned - logged)`.
   So today's plan is reduced by what is already logged today, and a day that
   is over the plan contributes nothing extra.
3. **Projected time** for a month = logged time + still-planned time.
4. **Monthly target** = base + extra hours, where the user picks the base:
   - `monthlyGoal`: the publisher status's monthly goal (`PublisherStatus.monthlyGoal`;
     50 h for a regular pioneer, 30 h for an auxiliary pioneer, 0 for a publisher).
   - `yearlyGoalShare`: only for statuses with a yearly goal (today only the
     regular pioneer). For months in the **current** theocratic year:
     `ceil((yearlyGoal - creditedBeforeCurrentMonth) / monthsLeft)` whole hours,
     where `monthsLeft` counts the months from the current month through August,
     including the current month, and the subtraction never goes below zero.
     The same share applies to every remaining month of the year (if each month
     meets the share, the share stays the same). For months in a **later**
     theocratic year, the base is the monthly goal. For statuses without a
     yearly goal, `yearlyGoalShare` falls back to the monthly goal.
   - Extra hours (0 or more, whole hours) are added to either base. A publisher
     with no goal can use extra hours as a personal target.
   - A target of 0 means "no target" (nil).
   Example (regular pioneer, 600 h/year, now 3 Nov 2026, 10 months left):
   credited before November 95 h -> 505 / 10 = 50.5 -> **51 h**; 100 h -> 50 h;
   110 h -> 49 h; 700 h -> 0 h (nil unless extra hours are set).
5. **Header numbers with a yearly goal**: for statuses with a yearly goal, the
   header counts credited time with the existing `YearlyGoalRule` (all main time,
   separate time only up to monthly goal + 5 h allowance). Without a yearly goal,
   header numbers are plain totals.
6. **Plan pace (Overview)**, current month only, plain totals (no credit rule):
   `expected = planned on days before today + min(planned today, logged today)`,
   `difference = logged this month - expected`. So a planned day never shows the
   user as behind until the day is over, and logging more than today's plan
   shows them ahead. Nil when the month has no plans.
7. **Bars (what a calendar day shows).** Each plan is a bar that fills from left
   to right as logged time covers it. Logged time is matched to a day's plans in
   two passes:
   - Pass 1: logged time fills plans of the **same category**.
   - Pass 2: logged time still unused fills plans still not full that have the
     **same kind** (main or separate). All main categories land on the same
     Field Service report line, so planning "Field Service" and logging "Phone
     Witnessing" counts as doing the plan.
   Within each pass, plans are filled in order of start time (plans without one
   last), then in the order given. Logged time that is still unused after both
   passes becomes one **unplanned** bar per category, already full. This
   includes time logged beyond a plan.
   Example (owner's): plans of 2 h Field Service and 1 h LDC; logged 1 h Field
   Service and 1 h LDC → Field Service bar 50 % full, LDC bar full, no unplanned bar.
   The two passes make the bars agree with rule 2: for each kind, the planned
   time the bars leave empty equals `max(0, planned - logged)`.
8. **Entries always show.** A day with entries and no plans shows unplanned bars.

The owner also wants, later and not in this plan: suggestion pills in the Add
Entry form built from plans that are not full yet. Keep `PlannerDay.make` and
`PlannerBar` usable from any feature for that.

## Current state

- `Hugo/Domain/YearMonth.swift`: `nonisolated struct YearMonth: Hashable, Comparable { let year: Int; let month: Int }`
  with `nextMonth(calendar:)`, `lastDay(calendar:) -> Int`, `dateRange(calendar:) -> Range<Date>`,
  `date(day: Int = 1, calendar:) -> Date` (start of that day), `monthYearString(locale:calendar:)`,
  and `Date.yearMonth(using:)`.
- `Hugo/Features/ServiceYear/Domain/TheocraticYear.swift`:
  `TheocraticYear.containing(_ date:calendar:)`, `months: [YearMonth]` (Sep...Aug),
  `contains(_ month: YearMonth) -> Bool`, `dateRange(calendar:)`.
- `Hugo/Features/ServiceYear/Domain/YearlyGoalRule.swift`:

  ```swift
  nonisolated struct YearlyGoalRule: Equatable, Sendable {
      let monthlyGoalSeconds: TimeInterval
      let separateAllowanceSeconds: TimeInterval

      func creditedSeconds(main: TimeInterval, separate: TimeInterval) -> TimeInterval {
          let room = max(0, monthlyGoalSeconds + separateAllowanceSeconds - main)
          return main + min(separate, room)
      }
  }
  ```

- `Hugo/Features/PublisherStatus/Domain/PublisherStatus.swift`: `monthlyGoal: Int`,
  `yearlyGoal: Int`, `yearlyGoalRule: YearlyGoalRule?` (non-nil only for yearly
  statuses with a goal), `static func status(for identifier: String) -> PublisherStatus?`.
  Ids: `"regular-pioneer"` (yearly 600), `"auxiliary-pioneer"` (monthly 30), `"publisher"` (monthly 0).
- `Hugo/Features/ServiceYear/Domain/TheocraticYearReport.swift`: `months: [ServiceMonth]`.
  Each `ServiceMonth` (`Hugo/Features/Reports/Domain/ServiceMonth.swift`) has
  `id: YearMonth` and `contribution: MonthContribution` (`total`, `main`, `separate`,
  `bibleStudies`), which is reported hours for submitted months and logged
  time otherwise. `YearlyGoalProgress.make` (same folder as `YearlyGoalRule`)
  credits each month with `rule.creditedSeconds(main: contribution.main, separate: contribution.separate)`.
  Reuse that exact formula.
- `Hugo/Features/Entries/Domain/EntryCategory.swift`: `Entry.resolvedCategory(locale:) -> EntryCategory`
  is `nonisolated` and returns `key`, `name`, `iconName`, `type: TrackerType?`
  (nil only for an untracked entry) and `trackerID: UUID?`. The `key` is the
  tracker's `id.uuidString` for a live category,
  `"stored:\(name)|\(icon)|\(type.rawValue)"` for a snapshot, or `"untracked"`.
  Plans use the same key format so entries and plans can be matched.
- `Hugo/Features/Overview/Domain/OverviewMetrics.swift` lines 20-33 define the
  category color value type, which the Planner also needs:

  ```swift
  nonisolated struct CategoryProgressColor: Equatable, Sendable {
      let hue: Double
      let saturation: Double
      let brightness: Double

      init?(hue: Double, saturation: Double, brightness: Double) {
          guard (0...1).contains(hue), (0...1).contains(saturation), (0...1).contains(brightness),
              brightness > 0
          else { return nil }
          self.hue = hue
          self.saturation = saturation
          self.brightness = brightness
      }
  }
  ```

  `CategoryProgressAggregator` in the same file builds it with
  `CategoryProgressColor(hue: $0.hue, saturation: $0.sat, brightness: $0.bri)`
  from a `Tracker`. It returns nil for most existing categories (the V6 to V7
  migration reset `hue`, and `bri` defaults to 0), and views then fall back to
  `.hugoAccent`. Plan 072 makes Overview use Planner types, so the Planner must
  not use an Overview type: Step 1 moves this struct to `Hugo/Domain`, which
  AGENTS.md reserves for value types shared by several features.
- `Plan` (from plan 067, `Hugo/Persistence/SchemaVersions/V12/PlanV12.swift`):
  `id: UUID`, `date: Date` (12:00 on the day), `duration`, `startMinute: Int?`,
  `categoryID: UUID?`, `categoryName`, `categoryIconName`, `categoryType: TrackerType`.
- Domain value types in this repo are `nonisolated struct ...: Equatable, Sendable`
  with static `make(...)` factories that take `now` and `calendar` (see
  `YearlyGoalProgress.make` and `ServiceMonth.make`). AGENTS.md: "Types with time-
  or locale-dependent logic take `now`, `calendar`, `locale` ... as parameters
  with production defaults. Tests pass fixed values."
- Test style: `HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift`.
  Swift Testing (`import Testing`, `@Test`, `#expect`, `#require`), a private
  fixed calendar, and a private date helper:

  ```swift
  private let calendar: Calendar = {
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = TimeZone(secondsFromGMT: 0)!
      return calendar
  }()
  private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
      calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
  }
  ```

  `Entry(date:duration:tracker:)` and `Tracker(name:type:iconName:)` can be
  created in tests without a container (that file does so).
- `Scripts/check-layout.sh` requires every feature file to sit in a role folder
  (`Screens`, `Views`, `State`, `Domain`, `Services`) and forbids feature type
  names in `Hugo/Domain`. All new types go in `Hugo/Features/Planner/Domain`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Layout | `Scripts/check-layout.sh` | exit 0, no output |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/OverviewMetricsTests -only-testing:HugoTests/CalendarDayTests -only-testing:HugoTests/PlanMatcherTests -only-testing:HugoTests/PlannerMonthTests -only-testing:HugoTests/PlannerTargetTests -only-testing:HugoTests/PlannerMonthStatusTests -only-testing:HugoTests/PlanPaceTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 |

Run the focused command with only the suites that exist so far.

## Scope

**In scope**:
- `Hugo/Domain/CategoryProgressColor.swift` (create; moved, unchanged)
- `Hugo/Features/Overview/Domain/OverviewMetrics.swift` (delete the moved struct only)
- `Hugo/Features/Planner/Domain/CalendarDay.swift`
- `Hugo/Features/Planner/Domain/PlannedItem.swift`
- `Hugo/Features/Planner/Domain/PlanMatcher.swift`
- `Hugo/Features/Planner/Domain/PlannerMonth.swift`
- `Hugo/Features/Planner/Domain/PlannerTarget.swift`
- `Hugo/Features/Planner/Domain/PlannerMonthStatus.swift`
- `Hugo/Features/Planner/Domain/PlanPace.swift`
- `HugoTests/Features/Planner/Domain/CalendarDayTests.swift`
- `HugoTests/Features/Planner/Domain/PlanMatcherTests.swift`
- `HugoTests/Features/Planner/Domain/PlannerMonthTests.swift`
- `HugoTests/Features/Planner/Domain/PlannerTargetTests.swift`
- `HugoTests/Features/Planner/Domain/PlannerMonthStatusTests.swift`
- `HugoTests/Features/Planner/Domain/PlanPaceTests.swift`
- `CONTEXT.md` (add terms)

**Out of scope**:
- Any view, `UserDefaultsKeys`, strings. The settings keys and sentences come in plan 071.
- `YearlyGoalProgress`, `YearlyGoalRule`, `ServiceMonth`: reuse, do not change.
- `Hugo/Domain/`: only `CategoryProgressColor` moves there. `CalendarDay` stays
  in the Planner feature; move it only when a second feature needs it.
- Everything else in `OverviewMetrics.swift` and `CategoryProgressBreakdownView.swift`.

## Git workflow

- Branch: `advisor/068-planner-domain-math`
- Conventional Commits, for example `feat: add the planner month and target calculations`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 0: Move `CategoryProgressColor` to `Hugo/Domain`

Cut the `CategoryProgressColor` struct (shown in "Current state") out of
`Hugo/Features/Overview/Domain/OverviewMetrics.swift` and paste it unchanged
into a new file `Hugo/Domain/CategoryProgressColor.swift` with `import Foundation`
and this doc comment above it:

```swift
/// A category's stored color, or nil when the stored channels are unset or out
/// of range. Views fall back to `.hugoAccent` for nil.
```

Nothing else changes; the type keeps its name, so `OverviewMetrics` and
`CategoryProgressBreakdownView` compile as before.

**Verify**: `Scripts/check-layout.sh` → exit 0; focused tests (only
`OverviewMetricsTests`) → `** TEST SUCCEEDED **`.

### Step 1: `CalendarDay`

Create `Hugo/Features/Planner/Domain/CalendarDay.swift`:

```swift
import Foundation

/// One day on the calendar, without a time of day.
nonisolated struct CalendarDay: Hashable, Comparable, Identifiable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    var id: Self { self }

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year ?? 0, month: components.month ?? 0, day: components.day ?? 0)
    }

    var yearMonth: YearMonth { YearMonth(year: year, month: month) }

    /// The first instant of the day.
    func startDate(calendar: Calendar = .current) -> Date {
        yearMonth.date(day: day, calendar: calendar)
    }

    /// 12:00 on the day. Plans store this, so a time-zone change cannot move
    /// them to another day.
    func midday(calendar: Calendar = .current) -> Date {
        let start = startDate(calendar: calendar)
        return calendar.date(byAdding: .hour, value: 12, to: start) ?? start
    }

    /// The half-open range from the start of this day to the start of the next.
    func dateRange(calendar: Calendar = .current) -> Range<Date> {
        let start = startDate(calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return start..<end
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

extension YearMonth {
    /// Every day of the month, in order.
    nonisolated func days(calendar: Calendar = .current) -> [CalendarDay] {
        (1...lastDay(calendar: calendar)).map { CalendarDay(year: year, month: month, day: $0) }
    }
}
```

Tests in `CalendarDayTests` (UTC calendar as above):
- `CalendarDay(date(2026, 11, 4, hour: 23))` equals `CalendarDay(year: 2026, month: 11, day: 4)`.
- `midday` of 4 Nov 2026 equals `date(2026, 11, 4, hour: 12)`.
- `dateRange` of 30 Nov 2026 is `date(2026, 11, 30)..<date(2026, 12, 1)`.
- Ordering: 31 Oct 2026 < 1 Nov 2026 < 2 Nov 2026; 31 Dec 2026 < 1 Jan 2027.
- `YearMonth(year: 2026, month: 11).days(calendar:)` has 30 items, first day 1, last day 30;
  February 2028 has 29.

**Verify**: Focused tests (only `CalendarDayTests`) → `** TEST SUCCEEDED **`.

### Step 2: `PlannedItem`

Create `Hugo/Features/Planner/Domain/PlannedItem.swift`:

```swift
import Foundation

/// One plan as the Planner reads it. Today every item comes from a `Plan` row.
/// Repeating plans will produce items too, without storing rows, so Planner
/// math and lists read items, never `Plan` directly.
nonisolated struct PlannedItem: Identifiable, Equatable, Sendable {
    /// The plan's `id` as a string. Repeating plans will use their own scheme.
    let id: String
    let day: CalendarDay
    let duration: TimeInterval
    /// Minutes after midnight, or nil.
    let startMinute: Int?
    let categoryName: String
    let categoryIconName: String
    let categoryType: TrackerType
    /// The live category's id, or nil when the category no longer exists.
    let trackerID: UUID?
    /// The live category's color, or nil (views use `.hugoAccent`).
    let color: CategoryProgressColor?

    /// The same key `Entry.resolvedCategory()` produces for this category, so
    /// logged time can be matched to the plan.
    var categoryKey: String {
        if let trackerID { return trackerID.uuidString }
        return "stored:\(categoryName)|\(categoryIconName)|\(categoryType.rawValue)"
    }
}

extension PlannedItem {
    /// Uses the live category when `trackers` has one with the plan's
    /// `categoryID`, otherwise the plan's snapshot.
    nonisolated init(_ plan: Plan, trackers: [Tracker], calendar: Calendar = .current) {
        let live = plan.categoryID.flatMap { id in trackers.first { $0.id == id } }
        self.init(
            id: plan.id.uuidString,
            day: CalendarDay(plan.date, calendar: calendar),
            duration: max(plan.duration, 0),
            startMinute: plan.startMinute,
            categoryName: live?.name ?? plan.categoryName,
            categoryIconName: live?.iconName ?? plan.categoryIconName,
            categoryType: live?.type ?? plan.categoryType,
            trackerID: live?.id,
            color: live.flatMap { CategoryProgressColor(hue: $0.hue, saturation: $0.sat, brightness: $0.bri) })
    }
}
```

If the compiler reports an actor-isolation error on reading `Plan` or `Tracker`
properties from the `nonisolated init`, remove `nonisolated` from this init
only and mark the call sites' functions `@MainActor` instead. Do not add
`@preconcurrency` or `nonisolated(unsafe)`.

### Step 2b: `PlanMatcher` (the bars)

Create `Hugo/Features/Planner/Domain/PlanMatcher.swift`:

```swift
import Foundation

/// One category's logged time on one day.
nonisolated struct LoggedCategoryTime: Equatable, Sendable {
    /// `EntryCategory.key`.
    let key: String
    let name: String
    let iconName: String
    /// Nil for untracked time, which counts as main.
    let type: TrackerType?
    let color: CategoryProgressColor?
    var seconds: TimeInterval
}

/// One bar in a calendar day: a plan and how much of it logged time covers, or
/// logged time that no plan covers.
nonisolated struct PlannerBar: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case plan
        case unplanned
    }

    /// The plan item's id, or `unplanned:` followed by the category key.
    let id: String
    let kind: Kind
    let categoryName: String
    let categoryIconName: String
    let color: CategoryProgressColor?
    /// The plan's duration, or the unplanned logged time.
    let seconds: TimeInterval
    /// Logged time counted toward this bar. Equals `seconds` for unplanned time.
    let filledSeconds: TimeInterval

    /// How full the bar is, from 0 to 1.
    var fraction: Double { seconds > 0 ? min(1, filledSeconds / seconds) : 0 }

    /// Planned time not covered yet. Always 0 for unplanned time.
    var remainingSeconds: TimeInterval { max(0, seconds - filledSeconds) }

    /// True when less than a minute of the plan is left.
    var isFull: Bool { remainingSeconds < 60 }
}

/// Matches one day's logged time to its plans: the same category first, then
/// the same kind (main or separate). Logged time left over becomes unplanned bars.
nonisolated enum PlanMatcher {
    static func bars(plans: [PlannedItem], logged: [LoggedCategoryTime]) -> [PlannerBar] {
        let ordered = plans.enumerated()
            .sorted { lhs, rhs in
                let left = lhs.element.startMinute ?? Int.max
                let right = rhs.element.startMinute ?? Int.max
                return left != right ? left < right : lhs.offset < rhs.offset
            }
            .map(\.element)
        let categories = logged.sorted { $0.key < $1.key }
        var unused = Dictionary(categories.map { ($0.key, $0.seconds) }, uniquingKeysWith: +)
        var filled: [String: TimeInterval] = [:]

        func fill(_ plan: PlannedItem, from key: String) {
            let need = plan.duration - (filled[plan.id] ?? 0)
            let take = min(max(0, need), unused[key] ?? 0)
            guard take > 0 else { return }
            filled[plan.id, default: 0] += take
            unused[key, default: 0] -= take
        }

        for plan in ordered {
            fill(plan, from: plan.categoryKey)
        }
        for plan in ordered {
            for category in categories where (category.type ?? .main) == plan.categoryType {
                fill(plan, from: category.key)
            }
        }

        let planBars = ordered.map { plan in
            PlannerBar(
                id: plan.id, kind: .plan, categoryName: plan.categoryName,
                categoryIconName: plan.categoryIconName, color: plan.color,
                seconds: plan.duration, filledSeconds: filled[plan.id] ?? 0)
        }
        let unplannedBars =
            categories
            .filter { (unused[$0.key] ?? 0) >= 60 }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map { category in
                let seconds = unused[category.key] ?? 0
                return PlannerBar(
                    id: "unplanned:\(category.key)", kind: .unplanned, categoryName: category.name,
                    categoryIconName: category.iconName, color: category.color,
                    seconds: seconds, filledSeconds: seconds)
            }
        return planBars + unplannedBars
    }
}
```

### Step 3: `PlannerMonth`

Create `Hugo/Features/Planner/Domain/PlannerMonth.swift` with three types:

```swift
import Foundation

/// Main and separate time kept apart, so the yearly goal's credit rule can apply.
nonisolated struct TimeSplit: Equatable, Sendable {
    var main: TimeInterval = 0
    var separate: TimeInterval = 0

    static let zero = TimeSplit()

    var total: TimeInterval { main + separate }

    /// Untracked time (`type == nil`) counts as main, as on the Field Service line.
    mutating func add(_ seconds: TimeInterval, type: TrackerType?) {
        if type == .separate { separate += seconds } else { main += seconds }
    }

    /// What is left of `self` once `covered` is taken off, per kind, never below zero.
    func remaining(after covered: TimeSplit) -> TimeSplit {
        TimeSplit(main: max(0, main - covered.main), separate: max(0, separate - covered.separate))
    }

    static func + (lhs: TimeSplit, rhs: TimeSplit) -> TimeSplit {
        TimeSplit(main: lhs.main + rhs.main, separate: lhs.separate + rhs.separate)
    }
}

/// One day of a Planner month.
nonisolated struct PlannerDay: Identifiable, Equatable, Sendable {
    let id: CalendarDay
    let logged: TimeSplit
    let planned: TimeSplit
    /// Plan bars in fill order, then unplanned bars.
    let bars: [PlannerBar]
    let isToday: Bool
    let isPast: Bool

    /// `items` and `entries` must already belong to `day`. `trackers` give the
    /// colors of logged categories.
    static func make(
        day: CalendarDay,
        items: [PlannedItem],
        entries: [Entry],
        trackers: [Tracker],
        today: CalendarDay
    ) -> PlannerDay {
        var planned = TimeSplit.zero
        for item in items {
            planned.add(item.duration, type: item.categoryType)
        }

        var logged = TimeSplit.zero
        var byCategory: [String: LoggedCategoryTime] = [:]
        for entry in entries {
            let seconds = max(entry.duration, 0)
            let category = entry.resolvedCategory()
            logged.add(seconds, type: category.type)
            if byCategory[category.key] == nil {
                let tracker = category.trackerID.flatMap { id in trackers.first { $0.id == id } }
                byCategory[category.key] = LoggedCategoryTime(
                    key: category.key, name: category.name, iconName: category.iconName, type: category.type,
                    color: tracker.flatMap { CategoryProgressColor(hue: $0.hue, saturation: $0.sat, brightness: $0.bri) },
                    seconds: 0)
            }
            byCategory[category.key]?.seconds += seconds
        }

        return PlannerDay(
            id: day, logged: logged, planned: planned,
            bars: PlanMatcher.bars(plans: items, logged: Array(byCategory.values)),
            isToday: day == today, isPast: day < today)
    }
}

/// A month in the Planner: logged and planned time for each day, and the
/// month's still-planned and projected time.
nonisolated struct PlannerMonth: Equatable, Sendable {
    let month: YearMonth
    let today: CalendarDay
    let days: [PlannerDay]

    var hasPlans: Bool { days.contains { $0.planned.total > 0 } }

    var logged: TimeSplit { days.reduce(.zero) { $0 + $1.logged } }

    var planned: TimeSplit { days.reduce(.zero) { $0 + $1.planned } }

    /// Planned time on today and later days that logged time has not yet covered.
    var stillPlanned: TimeSplit {
        days.filter { $0.id >= today }.reduce(.zero) { $0 + $1.planned.remaining(after: $1.logged) }
    }

    /// Logged time plus still-planned time.
    var projected: TimeSplit { logged + stillPlanned }

    /// Entries and items outside `month` are ignored.
    static func make(
        month: YearMonth,
        items: [PlannedItem],
        entries: [Entry],
        trackers: [Tracker] = [],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> PlannerMonth {
        let today = CalendarDay(now, calendar: calendar)
        let entriesByDay = Dictionary(grouping: entries) { CalendarDay($0.date, calendar: calendar) }
        let itemsByDay = Dictionary(grouping: items, by: \.day)
        let days = month.days(calendar: calendar).map { day in
            PlannerDay.make(
                day: day, items: itemsByDay[day] ?? [], entries: entriesByDay[day] ?? [],
                trackers: trackers, today: today)
        }
        return PlannerMonth(month: month, today: today, days: days)
    }

    /// The months the Planner pages through: the current month and the next 11.
    static func reachableMonths(from now: Date = .now, calendar: Calendar = .current) -> [YearMonth] {
        var month = now.yearMonth(using: calendar)
        var months: [YearMonth] = []
        for _ in 0..<12 {
            months.append(month)
            month = month.nextMonth(calendar: calendar)
        }
        return months
    }
}
```

### Step 4: `PlannerTarget`

Create `Hugo/Features/Planner/Domain/PlannerTarget.swift`:

```swift
import Foundation

/// What the monthly target starts from before extra hours are added.
nonisolated enum PlannerTargetBase: String, CaseIterable, Sendable {
    /// The publisher status's monthly goal.
    case monthlyGoal
    /// What is left of the yearly goal, shared evenly over the months left in
    /// the theocratic year. Only statuses with a yearly goal offer it.
    case yearlyGoalShare
}

nonisolated enum PlannerTarget {
    /// The monthly target for `month` in seconds, or nil when it would be zero.
    /// `creditedBeforeCurrentMonth` is the credited time of the current
    /// theocratic year's months before the current month; it is read only for
    /// `.yearlyGoalShare`.
    static func seconds(
        for month: YearMonth,
        base: PlannerTargetBase,
        extraHours: Int,
        status: PublisherStatus?,
        creditedBeforeCurrentMonth: TimeInterval,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TimeInterval? {
        var baseSeconds = TimeInterval(status?.monthlyGoal ?? 0) * 3_600

        if base == .yearlyGoalShare, let status, status.yearlyGoalRule != nil {
            let currentYear = TheocraticYear.containing(now, calendar: calendar)
            if currentYear.contains(month) {
                let current = now.yearMonth(using: calendar)
                let monthsLeft = currentYear.months.filter { $0 >= current }.count
                let left = max(0, TimeInterval(status.yearlyGoal) * 3_600 - creditedBeforeCurrentMonth)
                let hours = monthsLeft > 0 ? left / TimeInterval(monthsLeft) / 3_600 : 0
                // The epsilon keeps an exact 50.0 from rounding up to 51.
                baseSeconds = max(0, (hours - 1e-9).rounded(.up)) * 3_600
            }
        }

        let total = baseSeconds + TimeInterval(max(0, extraHours)) * 3_600
        return total > 0 ? total : nil
    }

    /// Credited time of the months in `report` before `month`, with the same
    /// formula as `YearlyGoalProgress`.
    static func creditedSeconds(
        before month: YearMonth, in report: TheocraticYearReport, rule: YearlyGoalRule
    ) -> TimeInterval {
        report.months.filter { $0.id < month }.reduce(0) { total, serviceMonth in
            let contribution = serviceMonth.contribution
            return total + rule.creditedSeconds(main: contribution.main, separate: contribution.separate)
        }
    }
}
```

### Step 5: `PlannerMonthStatus`

Create `Hugo/Features/Planner/Domain/PlannerMonthStatus.swift`:

```swift
import Foundation

/// The numbers in the Planner header for one month.
nonisolated struct PlannerMonthStatus: Equatable, Sendable {
    let targetSeconds: TimeInterval?
    /// Logged time; credited time when the status has a yearly goal.
    let loggedSeconds: TimeInterval
    /// Projected minus logged time, on the same basis as `loggedSeconds`.
    let stillPlannedSeconds: TimeInterval
    /// Projected time that does not count toward the yearly goal (separate
    /// time beyond the allowance). Always 0 without a yearly goal.
    let uncountedSeconds: TimeInterval
    /// Days from today (or the month's first day, for a future month) to the
    /// month's last day, including both. 0 for a past month.
    let daysLeft: Int

    /// Differences smaller than a minute are shown as equal.
    static let differenceThreshold: TimeInterval = 60

    var projectedSeconds: TimeInterval { loggedSeconds + stillPlannedSeconds }

    /// Target minus projected time. Positive when the plan falls short. Nil without a target.
    var shortfallSeconds: TimeInterval? { targetSeconds.map { $0 - projectedSeconds } }

    /// Target minus logged time, never below zero. Nil without a target.
    var leftSeconds: TimeInterval? { targetSeconds.map { max(0, $0 - loggedSeconds) } }

    /// `leftSeconds` spread evenly over `daysLeft`. Nil without a target, when
    /// nothing is left, or when no days are left.
    var perDaySeconds: TimeInterval? {
        guard let leftSeconds, leftSeconds >= Self.differenceThreshold, daysLeft > 0 else { return nil }
        return leftSeconds / TimeInterval(daysLeft)
    }

    /// With a yearly goal `rule`, logged and projected time count only their credited part.
    static func make(month: PlannerMonth, targetSeconds: TimeInterval?, rule: YearlyGoalRule?) -> PlannerMonthStatus {
        let logged: TimeInterval
        let projected: TimeInterval
        if let rule {
            logged = rule.creditedSeconds(main: month.logged.main, separate: month.logged.separate)
            projected = rule.creditedSeconds(main: month.projected.main, separate: month.projected.separate)
        } else {
            logged = month.logged.total
            projected = month.projected.total
        }
        return PlannerMonthStatus(
            targetSeconds: targetSeconds,
            loggedSeconds: logged,
            stillPlannedSeconds: max(0, projected - logged),
            uncountedSeconds: max(0, month.projected.total - projected),
            daysLeft: month.days.filter { $0.id >= month.today }.count)
    }
}
```

### Step 6: `PlanPace`

Create `Hugo/Features/Planner/Domain/PlanPace.swift`:

```swift
import Foundation

/// How the current month's logged time compares with the time planned up to now.
nonisolated struct PlanPace: Equatable, Sendable {
    /// Planned time on days before today, plus today's planned time as far as
    /// it has been logged. A planned day never counts against the user until it is over.
    let expectedSeconds: TimeInterval
    let loggedSeconds: TimeInterval

    /// Positive when ahead of the plan.
    var differenceSeconds: TimeInterval { loggedSeconds - expectedSeconds }

    /// Nil when the month has no plans.
    static func make(month: PlannerMonth) -> PlanPace? {
        guard month.hasPlans else { return nil }
        let expected = month.days.reduce(0) { total, day in
            if day.id < month.today { return total + day.planned.total }
            if day.id == month.today { return total + min(day.planned.total, day.logged.total) }
            return total
        }
        return PlanPace(expectedSeconds: expected, loggedSeconds: month.logged.total)
    }
}
```

### Step 7: Tests

All suites use the UTC calendar and `date(...)` helper shown in "Current state",
`main = Tracker(name: "Field Service", type: .main, iconName: "figure.walk")`,
`separate = Tracker(name: "LDC", type: .separate, iconName: "hammer")`, and
build `PlannedItem`s directly with the memberwise init (for example
`PlannedItem(id: "a", day: CalendarDay(year: 2026, month: 11, day: 5), duration: 7_200, startMinute: nil, categoryName: "Field Service", categoryIconName: "figure.walk", categoryType: .main, trackerID: main.id, color: nil)`).
Set `trackerID` to the tracker whose entries should match the plan in pass 1.
Mark a suite `@MainActor` only if creating `Tracker`/`Entry`/`Plan` requires it
(`AddEntryFormModelTests` is `@MainActor`; `YearlyGoalProgressTests` is not).
"Now" in every test is `date(2026, 11, 3, hour: 12)` unless stated.

`PlannerMonthTests`:
1. November 2026 has 30 days; `days[2].isToday`, `days[1].isPast`, `days[3].isPast == false`.
2. Entries on 1 Nov (1 h main) and 2 Nov (30 min separate) give `logged == TimeSplit(main: 3_600, separate: 1_800)`; an entry dated 1 Dec 2026 is ignored.
3. An untracked entry (`tracker: nil`) counts as main.
4. Still planned: plan 2 h on 1 Nov (past, nothing logged) contributes 0; plan 3 h today with 1 h logged today contributes 2 h; plan 2 h on 10 Nov contributes 2 h. `stillPlanned.total == 4 h`, `projected.total == logged.total + 4 h`.
5. Logged above plan today (plan 1 h, logged 3 h) contributes 0 still planned, not negative.
6. Separate and main are kept apart: plan 2 h separate today with 2 h main logged today gives still planned `TimeSplit(main: 0, separate: 7_200)`.
7. A future month (December 2026, now 3 Nov): every planned second is still planned.
8. `hasPlans` is false with no items and true with one.
9. `reachableMonths(from: date(2026, 11, 3))` has 12 items from November 2026 to October 2027.
10. `PlannedItem(plan, trackers:)` uses the live tracker's current name when the id matches (rename the tracker after creating the plan), and the plan's snapshot when `trackers` is empty. This test needs `Plan(date:duration:tracker:)`; mark it `@MainActor` if needed.
11. `PlannedItem.categoryKey` equals `Entry(date:duration:tracker:).resolvedCategory().key` for the same live tracker.
12. A day with entries and no plans (1 h Field Service on 1 Nov) has one `.unplanned` bar of 1 h with `fraction == 1`; a day with nothing has no bars.
13. Consistency: on a day with plans 2 h main (Field Service), 1 h main (a second main tracker) and 1 h separate, and logged 2.5 h Field Service and 2 h separate, the sum of `remainingSeconds` over plan bars of each kind equals `planned.remaining(after: logged)` for that kind (main 0.5 h, separate 0).

`PlanMatcherTests` (pure value types; build `LoggedCategoryTime` directly with
`key: main.id.uuidString` and so on):
1. Owner's example: plans 2 h Field Service and 1 h LDC; logged 1 h Field Service
   and 1 h LDC → two plan bars, Field Service `fraction == 0.5` and
   `remainingSeconds == 3_600`, LDC `fraction == 1` and `isFull`; no unplanned bars.
2. Pass 2: plan 2 h Field Service; logged 2 h of another main category ("Phone",
   different key) → the plan bar is full and there are no unplanned bars.
3. Pass 2 respects kind: plan 2 h Field Service; logged 2 h LDC (separate) → the
   plan bar is empty and there is one unplanned LDC bar of 2 h.
4. Overflow: plan 1 h Field Service; logged 3 h Field Service → plan bar full,
   plus one unplanned Field Service bar of 2 h with id `"unplanned:" + key`.
5. Order: two Field Service plans of 1 h with start minutes 840 and 600 (in that
   input order), logged 1.5 h → the 600 plan comes first and is full, the 840
   plan has `fraction == 0.5`. A plan without a start minute comes after both.
6. Leftovers under a minute (plan 1 h, logged 1 h 0 m 30 s) make no unplanned bar.
7. Untracked logged time (`type: nil`) fills a main plan in pass 2.

`PlannerTargetTests` (regular pioneer `PublisherStatus.status(for: "regular-pioneer")!`, now 3 Nov 2026, month November 2026 unless stated):
1. `.monthlyGoal`, extra 0 → 50 h.
2. `.monthlyGoal`, extra 5 → 55 h.
3. `.yearlyGoalShare`, credited before 100 h → 50 h (exact, no rounding up).
4. credited 95 h → 51 h. credited 90 h → 51 h. credited 110 h → 49 h.
5. credited 700 h → nil; with extra 3 → 3 h.
6. December 2026 with credited 95 h → 51 h (same share as November).
7. September 2027 (next theocratic year) → 50 h.
8. now 15 Aug 2027 (1 month left), month August 2027, credited 560 h → 40 h.
9. Auxiliary pioneer with `.yearlyGoalShare` → 30 h (falls back to the monthly goal).
10. Publisher (`"publisher"`) extra 0 → nil; extra 10 → 10 h. `status: nil`, extra 0 → nil.
11. `creditedSeconds(before:in:rule:)`: build a report with
    `TheocraticYearReportBuilder.report(for: TheocraticYear(startYear: 2026), entries: [...], now: date(2026, 11, 3, hour: 12), calendar: calendar)`
    from entries of 40 h main in September and 30 h main + 30 h separate in October
    and 10 h in November; with the regular pioneer's rule, credited before November is
    40 + (30 + min(30, 55 - 30)) = 95 h. The November entry is excluded.
    (Check `TheocraticYearReportBuilder.report`'s parameter list in
    `Hugo/Features/ServiceYear/Domain/TheocraticYearReportBuilder.swift` and pass `locale: Locale(identifier: "en_US_POSIX")` if needed.)

`PlannerMonthStatusTests`:
1. No rule: logged 10 h, still planned 30 h, target 50 h → `projectedSeconds == 40 h`, `shortfallSeconds == 10 h`, `leftSeconds == 40 h`.
2. `daysLeft` on 3 Nov 2026 is 28; for December 2026 viewed on 3 Nov it is 31; `perDaySeconds == 40 h / 28`.
3. Target nil → `shortfallSeconds`, `leftSeconds`, `perDaySeconds` all nil.
4. With the regular pioneer's rule: planned future 30 h main + 40 h separate, nothing logged → `projectedSeconds == 55 h`, `uncountedSeconds == 15 h`.
5. Logged above target: target 50 h, logged 52 h → `leftSeconds == 0`, `perDaySeconds == nil`, `shortfallSeconds == -2 h`.

`PlanPaceTests` (now 3 Nov 2026 noon):
1. No plans → nil.
2. Plans only after today, 4 h logged → expected 0, difference +4 h.
3. 3 h planned on 2 Nov, 1 h logged on 2 Nov → difference -2 h.
4. 2 h planned today, nothing logged today, nothing else → expected 0, difference 0.
5. 2 h planned today, 3 h logged today → expected 2 h, difference +1 h.
6. 2 h planned today, 1 h logged today → expected 1 h, difference 0.

**Verify**: Focused tests → `** TEST SUCCEEDED **`, all six new suites present.

### Step 8: Glossary

Append to the `## Planning` section of `CONTEXT.md` (added by plan 067):

```markdown
**Still planned**:
Planned time on today and later days that logged time has not yet covered. For each day and each kind of time, the planned time minus the logged time, never below zero.

**Projected time**:
A month's logged time plus its still-planned time. The Planner shows it as "With your plan".
_Avoid_: Expected time (that is yearly-goal pacing)

**Monthly target**:
The hours the Planner aims at for one month: the monthly goal, or an even share of what is left of the yearly goal, plus extra hours.
_Avoid_: Goal (the goal comes from the publisher status)

**Extra hours**:
Hours the user adds to the monthly target each month, as a buffer, or as a personal target when the publisher status has no goal.

**Plan pace**:
How the current month's logged time compares with the time planned up to now. Today's plan counts only as far as it has been logged.

**Covered time**:
The part of a plan that logged time on the same day accounts for: first time in the plan's category, then other time of the same kind (main or separate). The Planner draws it as the filled part of the plan's bar.

**Unplanned time**:
Logged time on a day that no plan covers, including time beyond a plan.
```

### Step 9: Full gate

**Verify**: `Scripts/verify.sh` → exit 0.

## Test plan

Listed in Step 7: six new suites, modeled on
`HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift`. They pin
every number in "Product rules", including the rounding example (95 h credited → 51 h),
the owner's bar example, and the agreement between bars and still-planned time.
`OverviewMetricsTests` must keep passing after the color type moves.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] The six new suites exist under `HugoTests/Features/Planner/Domain/` and pass
- [ ] `grep -rn "struct CategoryProgressColor" Hugo` → one match, in `Hugo/Domain/CategoryProgressColor.swift`
- [ ] `ls Hugo/Features/Planner` → only `Domain`
- [ ] `grep -rn "import SwiftUI" Hugo/Features/Planner/Domain` → no matches
- [ ] `grep -n "^\*\*Plan pace\*\*" CONTEXT.md` → one match
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- Plan 067 is not DONE (`grep -n "SchemaV12" Hugo/Persistence/AppSchema.swift` has no match).
- A test from Step 7 fails and the expected number in this plan looks wrong to
  you. Do not change the expectation to match the code. Report both numbers.
  The product rules are the owner's decisions.
- `TheocraticYearReportBuilder.report` or `ServiceMonth.contribution` has a
  different shape than described.
- You need to change any existing type to make the new code compile.

## Maintenance notes

- Plans 069-072 read only these types. If a rule changes, change it here and
  its test, not in a view.
- Repeating plans (future): add a second source of `PlannedItem`s (computed
  from a stored rule for the visible month) and pass both to `PlannerMonth.make`.
  Nothing else in the Planner needs to change. `PlannedItem.id` for an
  occurrence should combine the rule id and the day.
- `reachableMonths` is the single place that decides how far the Planner pages.
- The rounding epsilon in `PlannerTarget.seconds` exists because durations are
  doubles. Keep it if the formula changes.
- `PlanPace` deliberately ignores the credit rule: it answers "did I do what I
  planned", not "how am I doing on my yearly goal".
- `PlanMatcher`'s second pass (same kind) is what keeps the bars equal to the
  header's still-planned time. If the owner later wants strict per-category
  bars, drop the second loop, and decide whether still-planned time should
  become per category as well; test 13 in `PlannerMonthTests` will flag the gap.
- Future "suggestion pills" in Add Entry: the plan bars of a day with
  `kind == .plan && !isFull` are exactly the suggestions, each with
  `remainingSeconds` as the duration.
