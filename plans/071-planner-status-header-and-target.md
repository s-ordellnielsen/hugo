# Plan 071: Show the month's status above the Planner calendar, with a target setting

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 2e8a451..HEAD -- Hugo/Domain/UserDefaultsKeys.swift Hugo/Features/Settings/Screens/SettingsView.swift Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift Hugo/Features/ServiceYear/Domain`
> Plans 067-070 must be DONE first. For any change to the files above, compare
> the "Current state" excerpts against the live code; on a mismatch, treat it
> as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (users will compare these numbers with their own tally; string catalog edits)
- **Depends on**: plans/067 to plans/070, plans/073-planner-calendar-polish.md
- **Category**: direction
- **Planned at**: commit `2e8a451`, 2026-11-04

## Why this matters

A calendar of plans answers "what did I plan?" but not "is it enough?". This
plan adds a header above each month's calendar that answers that question:
the hours the month reaches with the plan, how much is logged and still
planned, the target, and one plain sentence such as "Plan 4 hours more to reach
your target". It also adds the setting that decides the target, so a regular
pioneer can aim at an even share of what is left of the yearly goal, and a
publisher without a goal can set a personal target. Users of the app this
feature is modeled on (My Service) praised its per-day figure and complained
that its numbers were unlabeled, so every number here carries a label.

## Product rules (decided with the owner, do not change)

1. All math comes from plan 068: `PlannerTarget.seconds(...)`,
   `PlannerTarget.creditedSeconds(before:in:rule:)`, `PlannerMonthStatus.make(...)`.
   Do not re-implement any of it in a view.
2. Settings, stored in `UserDefaults` (not synced, like the publisher status):
   - **Start from** (`PlannerTargetBase`): "Monthly goal" (default) or "Share of
     what's left of the yearly goal". The picker is shown only when the
     publisher status has a yearly goal (`status?.yearlyGoalRule != nil`).
   - **Extra hours**: whole hours, 0 to 30, default 0.
3. The header shows, top to bottom:
   - an eyebrow "With your plan" and a chevron (like the Year header),
   - the projected time as the hero number (`ServiceDurationFormatter.hoursString`), and
     "Target 50 hours" on the same line when there is a target,
   - a bar (only with a target): logged time filled with `.hugoAccent`, still
     planned time in `.hugoAccent` at 35% opacity, on a `.quaternary` track
     scaled to `max(target, projected)`; a thin `.primary` tick marks the target
     when the plan goes past it,
   - "Logged X" and "Still planned Y", each with the matching legend shape from
     plan 069 (a full and an empty `PlannerBarShape`),
   - one sentence: "Plan X more to reach your target", "Your plan reaches your
     target", "Your plan is X over your target", or, without a target,
     "Set a target to compare your plan with",
   - when available: "X left · about Y a day" (`leftSeconds`, `perDaySeconds`),
   - for yearly-goal statuses, when `uncountedSeconds` is at least a minute:
     "X in other categories won't count toward your goal".
4. Tapping the header opens the target settings in a sheet. The same screen is
   reachable from Settings under "Planner".
5. Threshold: differences under one minute count as equal
   (`PlannerMonthStatus.differenceThreshold`).

## Current state

- `Hugo/Domain/UserDefaultsKeys.swift` is an `enum` of `static let` string keys,
  for example `static let yearlyGoalPacing = "yearlyGoalPacing"`.
- `Hugo/Features/Settings/Screens/GeneralSettingsView.swift` shows how a raw-value
  enum setting is bound and listed:

  ```swift
  @AppStorage(UserDefaultsKeys.yearlyGoalPacing) private var pacing: YearlyGoalPacing = .proRated
  ...
  Picker(selection: $pacing) {
      ForEach(YearlyGoalPacing.allCases, id: \.self) { option in
          Text(option.label).tag(option)
      }
  } label: {
      Label("settings.yearlyGoal.pacing", systemImage: "chart.line.uptrend.xyaxis")
  }
  ```

  and `YearlyGoalPacing.label` is a `LocalizedStringResource` switch in an
  extension next to the enum (`Hugo/Features/ServiceYear/Domain/YearlyGoalPacing.swift`).
- `Hugo/Features/Settings/Screens/SettingsView.swift`, middle section:

  ```swift
  Section {
      NavigationLink(destination: ReportSettingsView()) {
          Label("settings.group.settings.report", systemImage: "doc.text")
      }
      NavigationLink(destination: CategorySettingsView()) {
          Label("settings.group.settings.category", systemImage: "square.grid.2x2")
      }
      NavigationLink(destination: GeneralSettingsView()) {
          Label("settings.group.settings.general", systemImage: "gearshape")
      }
  }
  ```

  `SettingsView` has `var showDismiss: Bool = false` and adds a cancellation
  toolbar button when true; copy that idea for the target screen's Done button.
- `Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift` is the header
  to match visually: a `VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact)`
  with an eyebrow (`.caption`, `.textCase(.uppercase)`,
  `.tracking(HugoLayout.Typography.eyebrowTracking)`, `.semibold`, `.secondary`)
  and a trailing `chevron.right` (`.footnote`, `.semibold`, `.secondary`,
  `accessibilityHidden`), the hero
  `Text(ServiceDurationFormatter.hoursString(from: seconds)).font(.system(.largeTitle, design: .serif, weight: .bold)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1).contentTransition(.numericText()).motion(Motion.value, value: seconds)`,
  sentences in `.subheadline`/`.semibold` or `.caption`/`.secondary`, and
  `.padding(.horizontal, HugoLayout.Spacing.card)`, `.padding(.vertical, HugoLayout.Spacing.regular)`,
  no background. `ServiceYearPageView` wraps it in a `NavigationLink` with
  `.buttonStyle(.card)` (`CardButtonStyle`, a press scale, in `Hugo/DesignSystem/Styles`).
  Its sentences use this pattern (from `YearlyGoalProgress.paceSentence`):

  ```swift
  let amount = ServiceDurationFormatter.hoursString(from: abs(differenceSeconds))
  return String(
      localized: "year.header.ahead", defaultValue: "\(amount) ahead",
      comment: "Counted time is ahead of the expected time. The argument is a duration such as 3 hours.")
  ```

- `Hugo/Features/ServiceYear/Domain/TheocraticYearReportBuilder.swift`:
  `TheocraticYearReportBuilder.report(for: TheocraticYear, entries: [Entry], submissions: [SubmittedReport] = [], trackers: [Tracker] = [], now: Date = .now, calendar: Calendar = .current, locale: Locale = .current)`.
  `ServiceYearPageView` queries `_submissions = Query(sort: \SubmittedReport.year)`
  and a year-bounded entries query; copy those.
- From plans 069 and 073: `Hugo/Features/Planner/Screens/PlannerView.swift` contains
  `PlannerView` and a `private struct PlannerPager` (with `let today: Date`,
  `let resetToken: UUID`, scroll state, `@State private var scrolledPages: [YearMonth: Bool]`,
  and a `ForEach(months, id: \.self)` that builds
  `PlannerMonthPage(month: month, today: today, onScrolledFromTopChange: { scrolledPages[month] = $0 })`).
  `Hugo/Features/Planner/Views/PlannerMonthPage.swift` has
  `init(month:today:onScrolledFromTopChange:)`, builds a `PlannerMonth`, and shows
  `PlannerCalendarGrid(month:onSelect:)` and `PlannerIntroCard()` inside a
  `VStack(spacing: HugoLayout.Spacing.card)` in a `ScrollView` that reports
  scrolling through `.onScrollGeometryChange`. Keep that callback working.
  `PlannerBarShape(fraction:color:)` is in `PlannerBarView.swift`; the legend
  draws `fraction: 0` for planned and `fraction: 1` for logged, both in `.hugoAccent`.
- From plan 068: `PlannerMonthStatus` has `targetSeconds`, `loggedSeconds`,
  `stillPlannedSeconds`, `uncountedSeconds`, `daysLeft`, `projectedSeconds`,
  `shortfallSeconds`, `leftSeconds`, `perDaySeconds`, `differenceThreshold`, and
  `make(month:targetSeconds:rule:)`. `PlannerTargetBase` has `monthlyGoal` and `yearlyGoalShare`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Layout | `Scripts/check-layout.sh` | exit 0, no output |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/PlannerMonthStatusTests -only-testing:HugoTests/PlannerTargetTests` | `** TEST SUCCEEDED **` |
| Strings valid JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | no output |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:
- `Hugo/Domain/UserDefaultsKeys.swift` (two keys)
- `Hugo/Features/Planner/Domain/PlannerTarget.swift` (add `label`)
- `Hugo/Features/Planner/Domain/PlannerMonthStatus.swift` (add sentence properties)
- `HugoTests/Features/Planner/Domain/PlannerMonthStatusTests.swift` (sentence tests)
- `Hugo/Features/Planner/Screens/PlannerView.swift` (`PlannerPager` queries and targets)
- `Hugo/Features/Planner/Views/PlannerMonthPage.swift`
- `Hugo/Features/Settings/Screens/SettingsView.swift` (one link)
- `Hugo/Resources/Localizable.xcstrings` (new keys only)
- Create: `Hugo/Features/Planner/Views/PlannerStatusHeader.swift`,
  `Hugo/Features/Planner/Views/PlannerProgressBar.swift`,
  `Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift`

**Out of scope**:
- `TheocraticYearTotalsView`, `CenteredProgressBar`, `GeneralSettingsView`: patterns only.
- The Overview (plan 072).
- Any change to the numbers from plan 068. If a number looks wrong, STOP.

## Git workflow

- Branch: `advisor/071-planner-status-header-and-target`
- Conventional Commits, for example `feat: show the month status and target in the planner`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Settings keys and the base label

`UserDefaultsKeys`: add after `yearlyGoalPacing`:

```swift
    static let plannerTargetBase = "plannerTargetBase"
    static let plannerExtraHours = "plannerExtraHours"
```

In `PlannerTarget.swift`, add:

```swift
extension PlannerTargetBase {
    var label: LocalizedStringResource {
        switch self {
        case .monthlyGoal: "planner.target.base.monthlyGoal"
        case .yearlyGoalShare: "planner.target.base.yearlyGoalShare"
        }
    }
}
```

### Step 2: Sentences, with tests

Add to `PlannerMonthStatus.swift`:

```swift
extension PlannerMonthStatus {
    var summarySentence: String {
        guard let shortfall = shortfallSeconds else {
            return String(
                localized: "planner.header.noTarget", defaultValue: "Set a target to compare your plan with",
                comment: "Planner header when there is no monthly target.")
        }
        let amount = ServiceDurationFormatter.hoursString(from: abs(shortfall))
        if shortfall >= Self.differenceThreshold {
            return String(
                localized: "planner.header.short", defaultValue: "Plan \(amount) more to reach your target",
                comment: "The plan falls short of the monthly target. The argument is a duration such as 4 hours.")
        }
        if shortfall <= -Self.differenceThreshold {
            return String(
                localized: "planner.header.over", defaultValue: "Your plan is \(amount) over your target",
                comment: "The plan goes past the monthly target. The argument is a duration such as 3 hours.")
        }
        return String(
            localized: "planner.header.reached", defaultValue: "Your plan reaches your target",
            comment: "The plan meets the monthly target.")
    }

    /// "16 hours left · about 1 hour, 10 minutes a day", or nil.
    var perDaySentence: String? {
        guard let leftSeconds, let perDaySeconds else { return nil }
        let left = ServiceDurationFormatter.hoursString(from: leftSeconds)
        let perDay = ServiceDurationFormatter.hoursString(from: perDaySeconds)
        return String(
            localized: "planner.header.perDay", defaultValue: "\(left) left · about \(perDay) a day",
            comment: "Time still needed this month and that time spread over the days left. Both arguments are durations.")
    }

    /// Nil unless some planned or logged time will not count toward the yearly goal.
    var uncountedSentence: String? {
        guard uncountedSeconds >= Self.differenceThreshold else { return nil }
        let amount = ServiceDurationFormatter.hoursString(from: uncountedSeconds)
        return String(
            localized: "planner.header.uncounted",
            defaultValue: "\(amount) in other categories won't count toward your goal",
            comment: "Separate-category time beyond the allowance. The argument is a duration.")
    }
}
```

Add tests to `PlannerMonthStatusTests`. Build statuses with the memberwise
initializer. The sentences come from the string catalog, so compare sentences
with each other instead of with English text:
- target 50 h, logged 0, still planned 46 h (shortfall 4 h): `summarySentence`
  contains `"4"` and differs from the sentence for still planned 50 h (shortfall 0);
- still planned 50 h minus 30 s (shortfall 30 s) gives the same sentence as shortfall 0;
- still planned 53 h (3 h over) differs from both;
- `targetSeconds: nil` gives a fourth, different sentence;
- `perDaySentence` is nil when `targetSeconds` is nil;
- `uncountedSentence` is nil for `uncountedSeconds: 59` and non-nil for 15 h.

**Verify**: Focused tests → `** TEST SUCCEEDED **`.

### Step 3: The bar

`Hugo/Features/Planner/Views/PlannerProgressBar.swift`:

```swift
import SwiftUI

/// Logged and still-planned time on a track that ends at the target, or at the
/// projected time when the plan goes past the target.
struct PlannerProgressBar: View {
    let loggedSeconds: TimeInterval
    let stillPlannedSeconds: TimeInterval
    let targetSeconds: TimeInterval

    private var projectedSeconds: TimeInterval { loggedSeconds + stillPlannedSeconds }

    var body: some View {
        GeometryReader { proxy in
            let scale = max(targetSeconds, projectedSeconds, 1)
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(Color.hugoAccent.opacity(0.35))
                    .frame(width: width * min(1, projectedSeconds / scale))
                Capsule()
                    .fill(Color.hugoAccent)
                    .frame(width: width * min(1, loggedSeconds / scale))
                if projectedSeconds > targetSeconds {
                    Rectangle()
                        .fill(.primary)
                        .frame(width: 2)
                        .offset(x: width * targetSeconds / scale - 1)
                }
            }
        }
        .frame(height: HugoLayout.Size.goalTrackHeight)
        .motion(Motion.progress, value: projectedSeconds)
        .accessibilityHidden(true)
    }
}
```

### Step 4: The header

`Hugo/Features/Planner/Views/PlannerStatusHeader.swift`: a view with
`let status: PlannerMonthStatus`. Build it like `TheocraticYearTotalsView`
(see "Current state"), in this order:

1. `HStack { eyebrow Text("planner.header.eyebrow"); Spacer(minLength: HugoLayout.Spacing.regular); chevron }`.
2. `HStack(alignment: .firstTextBaseline)`: the hero (projected seconds, same
   modifiers as the Year header), `Spacer()`, and when `status.targetSeconds` is
   set, `Text(String(localized: "planner.header.target", defaultValue: "Target \(amount)", comment: ...))`
   in `.subheadline`/`.secondary`.
3. When there is a target: `PlannerProgressBar(...)` with `.padding(.vertical, HugoLayout.Spacing.tight)`.
4. `HStack(spacing: HugoLayout.Spacing.spacious)` of two items, each
   `HStack(spacing: HugoLayout.Spacing.small) { PlannerBarShape(fraction: <f>, color: .hugoAccent).frame(width: 16, height: HugoLayout.Size.calendarBarHeight).accessibilityHidden(true); Text(...) }`:
   logged (`f` = 1, key `"planner.header.logged"`, "Logged \(amount)") and still
   planned (`f` = 0, key `"planner.header.stillPlanned"`, "Still planned \(amount)");
   `.font(.footnote)`, `.foregroundStyle(.secondary)`.
5. `Text(status.summarySentence)` in `.subheadline`/`.semibold`, `.padding(.top, HugoLayout.Spacing.compact)`.
6. `if let perDaySentence = status.perDaySentence { Text(perDaySentence) }` in `.footnote`/`.secondary`.
7. `if let uncountedSentence = status.uncountedSentence { Text(uncountedSentence) }` in `.footnote`/`.secondary`.

Container modifiers: `.frame(maxWidth: .infinity, alignment: .leading)`,
`.padding(.horizontal, HugoLayout.Spacing.card)`, `.padding(.vertical, HugoLayout.Spacing.regular)`,
`.accessibilityElement(children: .combine)`, `.accessibilityHint(Text("planner.header.a11y.hint"))`.
Use `.fixedSize(horizontal: false, vertical: true)` on the sentences so they wrap.

Add two previews: one with a target and a shortfall, one with `targetSeconds: nil`.

### Step 5: The target settings screen

`Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift`:

```swift
import SwiftUI

struct PlannerTargetSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UserDefaultsKeys.plannerTargetBase) private var base: PlannerTargetBase = .monthlyGoal
    @AppStorage(UserDefaultsKeys.plannerExtraHours) private var extraHours = 0
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""

    var showsDone = false

    private var status: PublisherStatus? { PublisherStatus.status(for: statusID) }
    private var hasGoal: Bool { (status?.monthlyGoal ?? 0) > 0 }

    var body: some View {
        List {
            if status?.yearlyGoalRule != nil {
                Section {
                    Picker(selection: $base) {
                        ForEach(PlannerTargetBase.allCases, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    } label: {
                        Text("planner.target.base")
                    }
                    .pickerStyle(.inline)
                } footer: {
                    Text("planner.target.base.footer")
                }
            }
            Section {
                Stepper(value: $extraHours, in: 0...30) {
                    LabeledContent(
                        "planner.target.extra",
                        value: ServiceDurationFormatter.hoursString(from: TimeInterval(extraHours) * 3_600))
                }
            } footer: {
                Text(hasGoal ? "planner.target.extra.footer" : "planner.target.extra.footer.noGoal")
            }
        }
        .navigationTitle("planner.target.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("navigation.done") { dismiss() }
                }
            }
        }
    }
}
```

The ternary inside `Text(...)` must resolve to localized keys. `TheocraticYearTotalsView`
already uses `Text(progress == nil ? "year.header.total.eyebrow" : "year.header.counted.eyebrow")`;
check in the simulator that the footer shows English text, not the key. If it
shows the raw key, write `Text(hasGoal ? LocalizedStringKey("planner.target.extra.footer") : LocalizedStringKey("planner.target.extra.footer.noGoal"))`.

Add `#Preview { NavigationStack { PlannerTargetSettingsView() } }`.

Settings link: in `SettingsView`'s middle section, after the General link, add
`NavigationLink(destination: PlannerTargetSettingsView()) { Label("tab.planner", systemImage: "calendar") }`.

### Step 6: Feed targets into each month

In `PlannerPager` (`PlannerView.swift`):

1. Add properties and queries:

   ```swift
   @Query private var yearEntries: [Entry]
   @Query private var submissions: [SubmittedReport]
   @Query private var trackers: [Tracker]
   @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""
   @AppStorage(UserDefaultsKeys.plannerTargetBase) private var targetBase: PlannerTargetBase = .monthlyGoal
   @AppStorage(UserDefaultsKeys.plannerExtraHours) private var extraHours = 0
   ```

   Add an explicit `init(today: Date, resetToken: UUID)` that sets both lets and
   bounds `_yearEntries` to `TheocraticYear.containing(today).dateRange()` with a
   `#Predicate<Entry> { $0.date >= start && $0.date < end }`, and sets
   `_submissions = Query(sort: \SubmittedReport.year)`.

2. Add:

   ```swift
   private var status: PublisherStatus? { PublisherStatus.status(for: statusID) }

   /// Credited time of this theocratic year's months before the current month.
   /// Built only when the target needs it.
   private var creditedBeforeCurrentMonth: TimeInterval {
       guard targetBase == .yearlyGoalShare, let rule = status?.yearlyGoalRule else { return 0 }
       let report = TheocraticYearReportBuilder.report(
           for: TheocraticYear.containing(today), entries: yearEntries, submissions: submissions,
           trackers: trackers, now: today)
       return PlannerTarget.creditedSeconds(before: today.yearMonth(), in: report, rule: rule)
   }
   ```

3. In `body`, compute `let credited = creditedBeforeCurrentMonth` once, and build
   each page as:

   ```swift
   PlannerMonthPage(
       month: month, today: today,
       targetSeconds: PlannerTarget.seconds(
           for: month, base: targetBase, extraHours: extraHours, status: status,
           creditedBeforeCurrentMonth: credited, now: today),
       rule: status?.yearlyGoalRule,
       onScrolledFromTopChange: { scrolledPages[month] = $0 })
   ```

In `PlannerMonthPage`:

1. Add `let targetSeconds: TimeInterval?` and `let rule: YearlyGoalRule?` and
   take them in `init`, between `today` and `onScrolledFromTopChange`
   (`init(month:today:targetSeconds:rule:onScrolledFromTopChange:)`).
2. Add `@State private var isShowingTarget = false`.
3. At the top of the `VStack`, before the grid:

   ```swift
   Button { isShowingTarget = true } label: {
       PlannerStatusHeader(
           status: PlannerMonthStatus.make(month: plannerMonth, targetSeconds: targetSeconds, rule: rule))
   }
   .buttonStyle(.card)
   ```

4. `.sheet(isPresented: $isShowingTarget) { NavigationStack { PlannerTargetSettingsView(showsDone: true) }.presentationDetents([.medium, .large]) }`.

### Step 7: Strings

Add to `Hugo/Resources/Localizable.xcstrings` (format as in plan 069 Step 9).
Keys with two arguments use positional specifiers.

| Key | English | Danish |
|---|---|---|
| `planner.header.eyebrow` | With your plan | Med din plan |
| `planner.header.target` | Target %@ | Måltal %@ |
| `planner.header.logged` | Logged %@ | Udført %@ |
| `planner.header.stillPlanned` | Still planned %@ | Stadig planlagt %@ |
| `planner.header.short` | Plan %@ more to reach your target | Planlæg %@ mere for at nå dit måltal |
| `planner.header.reached` | Your plan reaches your target | Din plan når dit måltal |
| `planner.header.over` | Your plan is %@ over your target | Din plan er %@ over dit måltal |
| `planner.header.noTarget` | Set a target to compare your plan with | Vælg et måltal at sammenligne din plan med |
| `planner.header.perDay` | %1$@ left · about %2$@ a day | %1$@ tilbage · cirka %2$@ om dagen |
| `planner.header.uncounted` | %@ in other categories won't count toward your goal | %@ i andre kategorier tæller ikke med mod dit mål |
| `planner.header.a11y.hint` | Opens the target settings | Åbner indstillingerne for måltal |
| `planner.target.title` | Monthly Target | Måltal for måneden |
| `planner.target.base` | Start From | Udgangspunkt |
| `planner.target.base.monthlyGoal` | Monthly goal | Månedligt mål |
| `planner.target.base.yearlyGoalShare` | Share of what's left of the yearly goal | Andel af det, der mangler til årsmålet |
| `planner.target.base.footer` | "Share of what's left" spreads the hours you still need for your yearly goal evenly over the months left in the service year, rounded up to whole hours. | "Andel af det, der mangler" fordeler de timer, du stadig mangler til årsmålet, ligeligt over de resterende måneder i tjenesteåret, rundet op til hele timer. |
| `planner.target.extra` | Extra Hours | Ekstra timer |
| `planner.target.extra.footer` | Added to your target every month, for example to keep a buffer. | Lægges til dit måltal hver måned, for eksempel for at have lidt luft. |
| `planner.target.extra.footer.noGoal` | Your publisher status has no goal, so extra hours become your monthly target. | Din forkynderstatus har intet mål, så de ekstra timer bliver dit måltal for måneden. |

Mind JSON escaping of the straight double quotes in the two footer strings (`\"`).

**Verify**: JSON check prints nothing; every key above has `en` and `da`.

### Step 8: Full gate

**Verify**: `Scripts/verify.sh` → exit 0.

## Test plan

- `PlannerMonthStatusTests`: sentence tests (Step 2).
- Plan 068's `PlannerTargetTests` and `PlannerMonthStatusTests` cover the numbers.
- Manual (owner):
  - Regular pioneer, "Monthly goal", no extra: the header shows "Target 50 hours".
  - Switch to "Share of what's left": the target matches the yearly-goal
    arithmetic (check against the Year tab's counted total).
  - Set 5 extra hours: the target grows by 5 h on every month.
  - Switch the publisher status to Publisher: the picker disappears, the footer
    changes, and with 0 extra hours the header says "Set a target ...".
  - Plan 30 h of a separate category as a regular pioneer: the "won't count" line appears.
  - VoiceOver reads the header as one element with a hint.
  - Largest Dynamic Type size: sentences wrap and the hero shrinks.
  - Danish: review every new string (owner step).

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -n "plannerTargetBase\|plannerExtraHours" Hugo/Domain/UserDefaultsKeys.swift` → two matches
- [ ] `grep -rn "creditedSeconds(main:" Hugo/Features/Planner/Views Hugo/Features/Planner/Screens` → no matches (math stays in Domain)
- [ ] All 19 string keys exist with `en` and `da`
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- Plans 067-070 are not DONE, or `PlannerPager` / `PlannerMonthPage` do not
  look like the description in "Current state".
- A header number disagrees with a hand calculation from plan 068's rules.
  Report the inputs and both numbers; do not adjust the math in a view.
- Adding the year `@Query` to `PlannerPager` makes swiping visibly stutter in the
  simulator with the preview data. Report it rather than caching by hand.

## Maintenance notes

- The target depends on `UserDefaults`, the publisher status and the year's
  entries and reports. Each is observed (`@AppStorage`, `@Query`), so changing
  any of them redraws the pager.
- `creditedBeforeCurrentMonth` builds a year report on every pager render when
  "Share of what's left" is selected. The Year page does the same work; measure
  before optimizing.
- The settings are per device, like the publisher status. If Hugo later syncs
  settings through iCloud key-value storage (an open direction idea in
  `plans/README.md`), include these two keys.
- Possible follow-up from My Service: a "required per day" figure is already in
  `perDaySentence`; an annual roll-up of planned vs logged per month was left
  out of v1 on purpose (see the README's Planner notes).
