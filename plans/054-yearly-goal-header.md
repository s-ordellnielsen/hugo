# Plan 054: Replace the Year page header with a yearly-goal progress header

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat a29e7f9..HEAD -- Hugo/Features/ServiceYear Hugo/Features/PublisherStatus Hugo/Features/Settings Hugo/Domain/UserDefaultsKeys.swift Hugo/DesignSystem Hugo/PreviewSupport Hugo/Resources/Localizable.xcstrings`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding. On a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: MED (new calculation that users will compare against their own tally; string catalog edits)
- **Depends on**: none (plans 001-053 are DONE)
- **Category**: direction
- **Planned at**: commit `a29e7f9`, 2026-11-03
- **Issue**: [SLN-257](https://linear.app/sebastianln/issue/SLN-257)

## Why this matters

The header of each Year page (`TheocraticYearTotalsView`) shows main, total and
separate hours. A regular pioneer cares about one thing: am I on pace for 600
hours? Only part of the separate-category time counts toward that goal, so the
raw total misleads. This plan makes the header show the hours that count toward
the yearly goal, how far ahead or behind pace the user is (a Gentler Streaks
style bar with an oversized knob and a trail from the center), and the actual
total only when it differs. Tapping the header opens a year detail screen that
holds everything the old header showed.

## Product rules (decided with the owner, do not change)

1. **Credit rule, per month, only for statuses with a yearly goal** (today only
   Regular Pioneer: 600 h per year, 50 h per month):
   `credited = main + min(separate, max(0, monthlyGoal + allowance - main))`
   where `allowance` is 5 h for Regular Pioneer. All main field service always
   counts, even above the monthly goal (so users can bank hours or catch up).
   Months are independent. Examples with goal 50 h, allowance 5 h:
   - main 65, separate 0 -> credited 65
   - main 40, separate 20 -> credited 55
   - main 65, separate 10 -> credited 65
   - main 50, separate 10 -> credited 55
   - main 0, separate 100 -> credited 55
2. **Primary number** in the header is the credited total. The **actual total**
   (main + separate) appears in a smaller size, only when it differs from the
   credited total.
3. **Statuses without a yearly goal** (auxiliary pioneer, publisher, or no
   status chosen): no goal bar and no credit calculation. The header shows the
   actual total as the primary number, still tappable.
4. **Bar**: the center means "exactly on pace". Each end is plus or minus one
   monthly goal (50 h). The knob is oversized. A trail is drawn from the center
   to the knob. The knob clamps at the ends; the text beside the bar always
   shows the real difference.
5. **Expected hours so far** depends on a new user setting, "Pace for the
   current month", with three values. Default is `proRated`.
   - `proRated`: completed months in full, plus `monthlyGoal * day / daysInMonth`
     for the current month (day is the 1-based day of `now`). On Oct 31 for a
     regular pioneer this is exactly 100 h; on Nov 3 it is 105 h.
   - `completedMonths`: completed months only; the current month expects 0.
   - `includeCurrentMonth`: completed months plus the full current month.
   For a year that ended before the current month, expected is the full yearly
   goal. For a year that starts after the current month, there is no bar.
6. The publisher status is a single global setting with no history. The current
   status applies to every year page. Do not try to store status per year.
7. Submission flow is untouched. This is display-only math.

## Current state

- `Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift` is the header
  being replaced. It takes `report: TheocraticYearReport` and shows
  main / total (serif, prominent) / separate in an `HStack`, in a
  `secondarySystemGroupedBackground` card with `HugoLayout.CornerRadius.card`.
- `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift` builds the report and
  renders the header:

```swift
// ServiceYearPageView.swift:41-54
let report = self.report
return ScrollView {
    VStack(spacing: HugoLayout.Spacing.card) {
        if report.hasEntries {
            TheocraticYearTotalsView(report: report)
        } else {
            emptyYearCard
        }
        ForEach(report.months) { month in ServiceYearMonthRow(month: month).id(month.id) }
    }
    .padding()
}
```

- `ServiceYearView` (`Screens/ServiceYearView.swift`) wraps the pages in a
  `NavigationStack`, so a `NavigationLink` inside a page can push a screen.
- `Hugo/Features/ServiceYear/Domain/TheocraticYearReportBuilder.swift` computes
  per-month contributions. Submitted months use submitted whole hours from
  `reportingLines`; unsubmitted months use raw entry seconds. This is the
  correct source for credit math. The function is currently private:

```swift
// TheocraticYearReportBuilder.swift:~47
private static func contribution(
    for month: TheocraticYearMonth
) -> (total: TimeInterval, main: TimeInterval, separate: TimeInterval, bibleStudies: Int) {
```

- `TheocraticYearReport` (`Domain/TheocraticYearReport.swift`) has `year`,
  `months: [TheocraticYearMonth]`, `totalSeconds`, `totalBibleStudies`,
  `mainDuration`, `separateDuration`, `hasEntries`. `TheocraticYearMonth.id` is a
  `YearMonth` (Comparable, has `lastDay(calendar:)`, `date(day:calendar:)`).
- `Hugo/Features/PublisherStatus/Domain/PublisherStatus.swift`:
  `PublisherStatus` is a `nonisolated struct` with `id`, `nameKey`, `shortName`,
  `goalPeriod` (`.yearly`/`.monthly`), `goal: Int`, `monthlyGoal`, `yearlyGoal`,
  and `static let all` with `PublisherStatus(id: "regular-pioneer", ..., goalPeriod: .yearly, goal: 600)`.
  Look-up: `PublisherStatus.status(for: id)`. The chosen id is stored with
  `@AppStorage(UserDefaultsKeys.publisherStatus) var statusID = ""`.
- Settings use `@AppStorage` with keys in `Hugo/Domain/UserDefaultsKeys.swift`.
  Enum-valued exemplar: `Hugo/Features/Overview/Domain/OverviewListStyle.swift`
  (`enum OverviewListStyle: String, CaseIterable`) used via
  `@AppStorage(UserDefaultsKeys.overviewListStyle) private var listStyle: OverviewListStyle = .byDate`.
  Picker exemplar: `Hugo/Features/Settings/Screens/GeneralSettingsView.swift`
  (`Picker ... .pickerStyle(.navigationLink)`).
- Design system: `HugoLayout` tokens and `Color.hugoAccent` in
  `Hugo/DesignSystem/Theme/Theme.swift`; `Motion.progress` / `Motion.value` and
  `.motion(_:value:)` in `Hugo/DesignSystem/Motion/Motion.swift` (respects Reduce
  Motion; use it, never raw `withAnimation` for the knob); `.card` button style in
  `Hugo/DesignSystem/Styles/CardButtonStyle.swift`.
- Duration display: `ServiceDurationFormatter.string(from:)` gives `HH:mm`;
  `accessibilityString(from:)` gives spoken hours and minutes.
- Test exemplar: `HugoTests/Features/ServiceYear/Domain/TheocraticYearReportBuilderTests.swift`
  (Swift Testing, fixed UTC Gregorian `calendar`, `en_US_POSIX` locale, a
  `makeReport(entries:)` helper, explicit `now`).
- Strings live in `Hugo/Resources/Localizable.xcstrings` (source `en`, also `da`;
  every key has both, `"state": "translated"`, and a `comment`).
- Conventions from `AGENTS.md` that apply (read it fully before starting):
  Swift 6, MainActor default isolation, so value types in `Domain` are
  declared `nonisolated`. Feature role folders only: `Screens`, `Views`,
  `State`, `Domain`, `Services`; never nest folders. Generic UI with no feature
  types goes in `Hugo/DesignSystem/<role>`. No `ObservableObject`. No
  `DispatchQueue`. 4-space indent. Pure value logic needs no view model.
  Types with time/locale logic take `now` and `calendar` parameters.
  Accessibility matters: users range from 13 to 70.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Layout check | `Scripts/check-layout.sh` | exit 0 |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Full gate | `Scripts/verify.sh` | exit 0 |
| Strings valid JSON | `python3 -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/<SuiteName>` | `** TEST SUCCEEDED **` |

## Scope

**In scope** (the only files you may modify or create):
- `Hugo/Features/PublisherStatus/Domain/PublisherStatus.swift` (modify)
- `Hugo/Features/ServiceYear/Domain/YearlyGoalRule.swift` (create)
- `Hugo/Features/ServiceYear/Domain/YearlyGoalPacing.swift` (create)
- `Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift` (create)
- `Hugo/Features/ServiceYear/Domain/TheocraticYearReportBuilder.swift` (only: make `contribution(for:)` non-private)
- `Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift` (rewrite)
- `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift` (modify)
- `Hugo/Features/ServiceYear/Screens/ServiceYearDetailView.swift` (create)
- `Hugo/DesignSystem/Components/CenteredProgressBar.swift` (create)
- `Hugo/DesignSystem/Theme/Theme.swift` (add two size tokens)
- `Hugo/Domain/UserDefaultsKeys.swift` (add one key)
- `Hugo/Features/Settings/Screens/GeneralSettingsView.swift` (add the pacing picker)
- `Hugo/PreviewSupport/ReportPreviewFixtures.swift` (add a preview fixture if needed)
- `Hugo/Resources/Localizable.xcstrings` (add keys)
- `HugoTests/Features/ServiceYear/Domain/YearlyGoalRuleTests.swift` (create)
- `HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift` (create)
- `plans/README.md` (status row)

**Out of scope** (do NOT touch):
- Submission flow, `ReportingLineCalculator`, `SubmitReportFormModel`, schemas,
  migrations, `SyncDeduplicator`. No SwiftData model changes: nothing here is persisted
  except one `UserDefaults` key.
- `MonthlyReportBuilder`, `MonthlyReportDetailView`, `ServiceYearMonthRow`.
- The Overview feature and its `OverviewMetrics` goal logic.
- Do not add per-year publisher status history, notifications, widgets or
  extra settings beyond the single pacing picker.

## Git workflow

- Branch: `advisor/054-yearly-goal-header`.
- Conventional Commits, one commit per step group, for example
  `feat: add the yearly goal credit rule and progress calculation`.
- Run `Scripts/install-hooks.sh` once. Run `Scripts/verify.sh` before every commit.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Teach `PublisherStatus` its credit allowance

In `PublisherStatus.swift` add a stored property after `goal`:
`var separateAllowanceHours: Int = 0` (memberwise init keeps working, the
parameter is optional). Set `separateAllowanceHours: 5` on the
`regular-pioneer` entry in `all`. Then add:

```swift
/// The credit rule for statuses that count hours toward a yearly goal; nil otherwise.
var yearlyGoalRule: YearlyGoalRule? {
    guard goalPeriod == .yearly, goal > 0 else { return nil }
    return YearlyGoalRule(
        monthlyGoalSeconds: TimeInterval(monthlyGoal) * 3_600,
        separateAllowanceSeconds: TimeInterval(separateAllowanceHours) * 3_600)
}
```

This will not compile until step 2. Do step 2 before building.

### Step 2: Add the credit rule

Create `Hugo/Features/ServiceYear/Domain/YearlyGoalRule.swift`:

```swift
import Foundation

/// How much of one month's time counts toward a yearly goal.
nonisolated struct YearlyGoalRule: Equatable, Sendable {
    let monthlyGoalSeconds: TimeInterval
    /// Separate-category time that may count on top of the monthly goal.
    let separateAllowanceSeconds: TimeInterval

    /// All main time counts. Separate time counts only up to
    /// `monthlyGoalSeconds + separateAllowanceSeconds` in total.
    func creditedSeconds(main: TimeInterval, separate: TimeInterval) -> TimeInterval {
        let room = max(0, monthlyGoalSeconds + separateAllowanceSeconds - main)
        return main + min(separate, room)
    }
}
```

**Verify**: step 3 and 4 build together; verify after step 4.

### Step 3: Add the pacing setting type and key

1. `Hugo/Domain/UserDefaultsKeys.swift`: add
   `static let yearlyGoalPacing = "yearlyGoalPacing"` (after `publisherStatus`).
2. Create `Hugo/Features/ServiceYear/Domain/YearlyGoalPacing.swift`:

```swift
import Foundation

/// How much of the current month counts as "expected so far" on the yearly goal bar.
nonisolated enum YearlyGoalPacing: String, CaseIterable, Sendable {
    case proRated
    case completedMonths
    case includeCurrentMonth
}
```

Match the file header style of the neighbours (the `//  File.swift` banner is
optional; newer files omit it).

### Step 4: Add the progress calculation

1. In `TheocraticYearReportBuilder.swift` remove `private` from
   `static func contribution(for:)`. Change nothing else in the file.
2. Create `Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift`:

```swift
nonisolated struct YearlyGoalProgress: Equatable, Sendable {
    let creditedSeconds: TimeInterval
    let actualSeconds: TimeInterval
    /// Seconds the user should have by now. Nil when the year has not started.
    let expectedSeconds: TimeInterval?
    let yearlyGoalSeconds: TimeInterval
    let monthlyGoalSeconds: TimeInterval
    let creditedByMonth: [YearMonth: TimeInterval]

    var showsActualTotal: Bool { abs(actualSeconds - creditedSeconds) >= 60 }
    /// Credited minus expected. Nil when there is no expectation.
    var differenceSeconds: TimeInterval? { expectedSeconds.map { creditedSeconds - $0 } }
    /// The knob position from -1 (a monthly goal behind) to 1 (a monthly goal ahead).
    var barFraction: Double? { ... clamp(difference / monthlyGoalSeconds, -1...1) }
    var isOnTrack: Bool { abs(differenceSeconds ?? 0) < 60 }

    static func make(
        report: TheocraticYearReport, rule: YearlyGoalRule, yearlyGoalSeconds: TimeInterval,
        pacing: YearlyGoalPacing, now: Date = .now, calendar: Calendar = .current
    ) -> YearlyGoalProgress
}
```

`make` rules (write exactly this logic):
- For each month in `report.months`, `let c = TheocraticYearReportBuilder.contribution(for: month)`;
  credited = `rule.creditedSeconds(main: c.main, separate: c.separate)`. Sum into
  `creditedSeconds` and fill `creditedByMonth`. `actualSeconds = report.totalSeconds`.
- `current = now.yearMonth(using: calendar)`. If `report.months[0].id > current`
  then `expectedSeconds = nil`.
- Otherwise expected is the sum over `report.months`: month `< current` adds
  `monthlyGoalSeconds`; month `== current` adds, by pacing: `proRated` ->
  `monthlyGoalSeconds * day / lastDay` where `day = calendar.component(.day, from: now)`
  and `lastDay = current.lastDay(calendar: calendar)`; `completedMonths` -> 0;
  `includeCurrentMonth` -> `monthlyGoalSeconds`; month `> current` adds 0.
  A past year therefore expects 12 x monthly goal.
- `yearlyGoalSeconds` is passed in as `TimeInterval(status.yearlyGoal) * 3_600` by the caller.
- `barFraction` clamps to `-1...1` and returns nil when `expectedSeconds` is nil.
  Guard division by zero (`monthlyGoalSeconds > 0`).

Add `import Foundation` and follow the exact style of
`TheocraticYearReportBuilder.swift` (`nonisolated`, `now`/`calendar` parameters).

**Verify**: `xcodebuild build -project Hugo.xcodeproj -scheme Hugo -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` -> `** BUILD SUCCEEDED **`

### Step 5: Write the calculation tests (before any UI)

Create the two test files (see Test plan). Run
`-only-testing:HugoTests/YearlyGoalRuleTests` and
`-only-testing:HugoTests/YearlyGoalProgressTests`.

**Verify**: both print `** TEST SUCCEEDED **`.

### Step 6: Add the centered progress bar component

Add to `HugoLayout.Size` in `Theme.swift`: `static let goalTrackHeight: CGFloat = 12`
and `static let goalKnobDiameter: CGFloat = 36`.

Create `Hugo/DesignSystem/Components/CenteredProgressBar.swift`. It is generic: it
must name no feature type.

```swift
struct CenteredProgressBar: View {
    /// -1 (left end) ... 0 (center) ... 1 (right end).
    let fraction: Double
    let accessibilityLabel: LocalizedStringKey
    let accessibilityValue: String
    ...
}
```

Behavior:
- Height is `HugoLayout.Size.goalKnobDiameter`. Use `GeometryReader` for width.
- Track: full-width `Capsule`, height `goalTrackHeight`, fill `Color(.tertiarySystemFill)`.
- A small center tick (2 pt wide, a bit taller than the track) in `.secondary`.
- Knob x position: `width / 2 + fraction * (width / 2 - knobDiameter / 2)`.
- Trail: a `Capsule` filled `.hugoAccent`, height `goalTrackHeight`, spanning from the
  center x to the knob x (its width is `abs(knobX - centerX)`, positioned on the
  correct side). It is absent (zero width) at `fraction == 0`.
- Knob: `Circle`, diameter `goalKnobDiameter`, fill `Color(.systemBackground)`,
  a `.hugoAccent` stroke of 4 pt, and a subtle shadow (`.shadow(color: .black.opacity(0.15), radius: 4, y: 2)`).
- Animate the knob and trail with `.motion(Motion.progress, value: fraction)`.
- Accessibility: `.accessibilityElement(children: .ignore)`, then the label and value.
- Include a `#Preview` showing fractions -1, -0.3, 0, 0.6, 1 stacked.

Meaning is never conveyed by color alone: position and the text next to the bar
carry it.

**Verify**: `Scripts/check-layout.sh` -> exit 0; build succeeds.

### Step 7: Add the pacing picker to settings

In `GeneralSettingsView.swift` add
`@AppStorage(UserDefaultsKeys.yearlyGoalPacing) private var pacing: YearlyGoalPacing = .proRated`
and `@AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""`.
Add a second `Section`, shown only when
`PublisherStatus.status(for: statusID)?.yearlyGoalRule != nil`, containing a
`Picker` in the same `.pickerStyle(.navigationLink)` form as the existing one, with a
`Label("settings.yearlyGoal.pacing", systemImage: "chart.line.uptrend.xyaxis")`,
three options tagged by `YearlyGoalPacing` case, and a footer
`Text("settings.yearlyGoal.pacing.footer")`. Use `ForEach(YearlyGoalPacing.allCases, id: \.self)`.

### Step 8: Rewrite the header

Rewrite `TheocraticYearTotalsView`:

```swift
struct TheocraticYearTotalsView: View {
    let report: TheocraticYearReport
    /// Nil when the publisher status has no yearly goal.
    let progress: YearlyGoalProgress?
    let status: PublisherStatus?
}
```

Layout inside the existing card chrome (keep the padding, background and corner
radius from the current file), one `VStack(alignment: .leading)`:
1. Top row: eyebrow text (same style as `ServiceYearMonthRow.monthTitle`: `.caption`,
   uppercase, `HugoLayout.Typography.eyebrowTracking`, semibold, secondary), leading;
   a `chevron.right` image, secondary, trailing, `.accessibilityHidden(true)`.
   Eyebrow key: `year.header.counted.eyebrow` when `progress != nil`,
   `year.header.total.eyebrow` otherwise.
2. Primary number: `ServiceDurationFormatter.string(from:)` of credited seconds
   (or `report.totalSeconds` when `progress == nil`), using
   `.system(.largeTitle, design: .serif, weight: .bold)` and `.monospacedDigit()`.
   Add `.contentTransition(.numericText())` with `.motion(Motion.value, value: ...)`.
3. When `progress.showsActualTotal`: one `.caption` secondary line
   `year.header.actual` ("Actual total %@") with the actual total.
4. When `progress?.barFraction` is non-nil: a status sentence in `.subheadline`
   semibold: `year.header.onTrack`, `year.header.ahead` ("%@ ahead") or
   `year.header.behind` ("%@ behind"), with the absolute difference as `HH:mm`.
   Then `CenteredProgressBar(fraction:...)`, then a caption row with the end
   labels "-N h" and "+N h" (N = the monthly goal in hours, from
   `status.monthlyGoal`) and a centered "On pace" caption (`year.header.pace`).
5. Dynamic Type: at `isAccessibilitySize` the end-label row stacks vertically (reuse
   the `@Environment(\.dynamicTypeSize)` approach of the current file). Nothing
   may truncate.
6. Accessibility: the header is one element with
   `.accessibilityElement(children: .ignore)`, a label built from
   `year.header.a11y.label` (the credited total spoken with
   `ServiceDurationFormatter.accessibilityString`, plus the ahead/behind/on-track
   phrase) and `.accessibilityHint("year.header.a11y.hint")` ("Opens the year details").
   The bar's own accessibility is therefore hidden inside the combined element.

Remove the old three-column layout entirely.

### Step 9: Wire the header and the detail screen into the page

In `ServiceYearPageView.swift`:
- Add `@AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""` and
  `@AppStorage(UserDefaultsKeys.yearlyGoalPacing) private var pacing: YearlyGoalPacing = .proRated`.
- Add computed `status: PublisherStatus?` (`PublisherStatus.status(for: statusID)`) and
  `progress(for report:) -> YearlyGoalProgress?` that returns nil unless
  `status?.yearlyGoalRule` exists, else calls `YearlyGoalProgress.make(report:rule:yearlyGoalSeconds: TimeInterval(status.yearlyGoal) * 3_600, pacing:)`.
- Replace the header call with a `NavigationLink { ServiceYearDetailView(report: report, progress: progress, status: status) } label: { TheocraticYearTotalsView(report: report, progress: progress, status: status) }` with `.buttonStyle(.card)`.
  Keep the `report.hasEntries` check and `emptyYearCard` as they are.

Create `Hugo/Features/ServiceYear/Screens/ServiceYearDetailView.swift`: a `List`
(the style used by `MonthlyReportDetailView`) titled with
`.navigationTitle(report.year.displayName)`, `.navigationSubtitle("year.detail.subtitle")`
and `.navigationBarTitleDisplayMode(.inline)`, with an `EditorialNavigationTitle`
principal toolbar item exactly as `MonthlyReportDetailView` does. Sections:
1. **Yearly goal** (only when `progress != nil`): rows for credited total, goal
   (`status.yearlyGoal` hours), expected so far, and ahead/behind.
2. **Totals**: main, separate, actual total, Bible studies
   (`report.mainDuration`, `report.separateDuration`, `report.totalSeconds`,
   `report.totalBibleStudies`). This is where the old header content now lives.
3. **By month** (only when `progress != nil`): for each month that is not
   `isFuture`, a row with the month name, the credited time, and, when it differs
   from the month's actual time, the actual time in secondary caption. A footer
   explains the rule in plain words (`year.detail.credit.footer`).
Keep it plain. Use `LabeledContent` for rows. No charts.

Update `ReportPreviewFixtures` only if a preview needs it. Both previews should
render: `#Preview` for the header with a regular-pioneer `progress` and one with
`progress: nil`.

**Verify**: `Scripts/verify.sh` -> exit 0 (strings are added in step 10; run it again after).

### Step 10: Add the strings

Add every key below to `Hugo/Resources/Localizable.xcstrings` in the existing format
(copy an existing entry, keep keys alphabetical like the file, include a
`comment`, both `da` and `en` with `"state": "translated"`). Do not reformat the
rest of the file; use a small script or careful edits, then run the JSON check.

| Key | English | Danish |
|---|---|---|
| `year.header.counted.eyebrow` | Counted toward goal | Tæller med mod målet |
| `year.header.total.eyebrow` | Total | Total |
| `year.header.actual` | Actual total %@ | Faktisk total %@ |
| `year.header.onTrack` | On pace | På skinner |
| `year.header.ahead` | %@ ahead | %@ foran |
| `year.header.behind` | %@ behind | %@ bagud |
| `year.header.pace` | On pace | På skinner |
| `year.header.a11y.label` | Counted toward yearly goal: %1$@. %2$@ | Tæller med mod årsmålet: %1$@. %2$@ |
| `year.header.a11y.hint` | Opens the year details | Åbner årsoversigten |
| `year.detail.subtitle` | Year details | Årsoversigt |
| `year.detail.credit.footer` | Main field service always counts toward your yearly goal. Time in other categories counts only until you reach your monthly goal plus %lld hours. | Almindelig forkyndelse tæller altid med mod årsmålet. Tid i andre kategorier tæller kun, indtil du når dit månedlige mål plus %lld timer. |
| `settings.yearlyGoal.pacing` | Pace for the current month | Tempo for denne måned |
| `settings.yearlyGoal.pacing.footer` | Choose how much of this month you should have done by today when comparing with your yearly goal. | Vælg, hvor meget af denne måned du skal have nået i dag, når du sammenligner med dit årsmål. |
| `settings.yearlyGoal.pacing.proRated` | Spread across the month | Fordelt over måneden |
| `settings.yearlyGoal.pacing.completedMonths` | Completed months only | Kun afsluttede måneder |
| `settings.yearlyGoal.pacing.includeCurrentMonth` | Include the whole month | Hele måneden fra start |

Also add keys for the detail screen row labels (`year.detail.credited`,
`year.detail.goal`, `year.detail.expected`, `year.detail.difference`, section
headers) with sensible en/da text. Reuse existing keys where they already exist
(`monthlyReport.detail.largeTotal.main.label`, `...separate.label`,
`...total.label`). Search the catalog before adding: `grep -n '"year\.' Hugo/Resources/Localizable.xcstrings`.
Every `Text("...")` and `Label("...")` you wrote must resolve to a key.

**Verify**: JSON check prints nothing; `Scripts/verify.sh` -> exit 0.

### Step 11: Look at it

Run the app in the simulator (use the `run` skill if available) and check, with
a Regular Pioneer status: an empty-ish year, a year with only main time, a month
with separate time that exceeds the allowance (header shows both numbers), and the
largest Dynamic Type size. Also check dark mode and VoiceOver reading order of the
header. Report anything you could not check.

## Test plan

New suites, Swift Testing, `@testable import Hugo`, patterned on
`TheocraticYearReportBuilderTests` (fixed UTC Gregorian calendar, `en_US_POSIX`).

`YearlyGoalRuleTests` (rule: goal 50 h, allowance 5 h; values in seconds):
- main 65, sep 0 -> 65; main 40, sep 20 -> 55; main 65, sep 10 -> 65 (the three
  owner examples); main 50, sep 10 -> 55; main 0, sep 100 -> 55; main 0, sep 0 -> 0;
  fractional minutes survive (main 49:30, sep 10:00 -> 55:00).
- `PublisherStatus.status(for: "regular-pioneer")?.yearlyGoalRule` equals 50 h / 5 h;
  `auxiliary-pioneer` and `publisher` return nil.

`YearlyGoalProgressTests` (build reports with `TheocraticYearReportBuilder.report(for:entries:now:calendar:locale:)`,
entries for the 2026/2027 year, fixed `now`):
- Regular pioneer with 50 h main in September and 50 h main in October, `now` =
  Oct 31 2026 midday, `proRated` -> expected 100 h, difference 0, `isOnTrack`, `barFraction == 0`.
- Same entries, `now` = Nov 3 2026, `proRated` -> expected 105 h, `barFraction` is
  `(100 - 105) / 50 = -0.1` (within 1e-9).
- Same, `completedMonths` -> expected 100 h at Nov 3; `includeCurrentMonth` -> 150 h.
- 200 h ahead clamps `barFraction` to 1; far behind clamps to -1.
- Credit differs from actual: one month with 40 h main and 20 h separate -> credited
  55 h, actual 60 h, `showsActualTotal == true`; main-only month -> `showsActualTotal == false`.
- A past year (`now` in 2028) -> expected 600 h. A future year (`now` in 2026-08
  against the 2026/2027 year) -> `expectedSeconds == nil`, `barFraction == nil`.
- A submitted month uses submitted whole hours, not raw seconds (build a
  `SubmittedReport` with a main `reportingLines` entry; follow how
  `TheocraticYearReportBuilderTests` constructs submissions; persistence tests use
  `InMemoryModelContainer.make()`).
- `creditedByMonth` holds one entry per year month.

Verification: `Scripts/verify.sh` -> exit 0 with the new tests included.

## Done criteria

All must hold:

- [ ] `Scripts/verify.sh` exits 0
- [ ] `YearlyGoalRuleTests` and `YearlyGoalProgressTests` exist and pass
- [ ] `grep -n "monthlyReport.detail.largeTotal" Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift` returns no matches (old layout is gone)
- [ ] `python3 -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` exits 0 and every new key has `da` and `en`
- [ ] `grep -rn "ObservableObject\|DispatchQueue" Hugo/Features/ServiceYear Hugo/DesignSystem/Components/CenteredProgressBar.swift` returns no matches
- [ ] `CenteredProgressBar.swift` mentions no feature type (`grep -n "YearlyGoal\|Theocratic\|PublisherStatus" Hugo/DesignSystem/Components/CenteredProgressBar.swift` returns nothing)
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The "Current state" excerpts do not match the code (drift).
- `TheocraticYearReportBuilder.contribution(for:)` has changed shape or already
  returns something other than `(total, main, separate, bibleStudies)`.
- A `NavigationLink` inside `ServiceYearPageView` does not push (the horizontal
  paging scroll view may swallow it). Report what you saw; do not restructure
  `ServiceYearView`.
- `Scripts/verify.sh` fails twice on the same issue after a reasonable fix.
- Adding the strings requires reformatting large parts of the catalog.
- The credit rule needs a number the owner has not given (for example, an
  allowance for another status). Only Regular Pioneer has one.

## Maintenance notes

- Adding a yearly-goal status later means setting `goalPeriod: .yearly`, `goal` and
  `separateAllowanceHours` in `PublisherStatus.all`. The header, settings picker
  and detail screen follow automatically.
- A status change applies to all years at once (no history). If users start
  complaining that old years change, that needs a stored status per year.
- `now` is read when the page body renders. The header is not refreshed at
  midnight; plan 046 shows how the Overview handles that if it becomes a problem.
- Reviewers should check: the three owner examples in `YearlyGoalRuleTests`, that
  submitted months use submitted hours, Dynamic Type at the largest size, and that
  the Danish strings read naturally (owner step: Danish review).
- Deferred on purpose: a chart of monthly progress in the detail screen, and a
  "hours still needed per remaining month" line. Both are good follow-ups once the
  header has been used for a while.
