# Plan 086: Fill the Overview circle by area, and against the plan when there is no monthly goal

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 1432319..HEAD -- Hugo/Features/Overview Hugo/Resources/Localizable.xcstrings HugoTests/Features/Overview`
> Plan 085 must already be committed, so its changes to `OverviewView.swift`, `MonthlyProgressCard.swift`, `OverviewMetrics.swift`, `OverviewMetricsTests.swift` and the string catalog are expected. Compare the "Current state" excerpts below with the live code. They describe the code **after** plan 085. On any mismatch beyond 085's changes, treat it as a STOP condition.

## Status

- **Priority**: P1 (scheduled for the next external TestFlight build)
- **Effort**: M + owner
- **Risk**: LOW (drawing and one new rule; no schema change, no change to reports or totals)
- **Depends on**: plans/085-overview-plan-pace-sheet.md
- **Category**: bug
- **Planned at**: commit `1432319`, 2026-11-05
- **Issue**: [SLN-190](https://linear.app/sebastianln/issue/SLN-190), [SLN-191](https://linear.app/sebastianln/issue/SLN-191)

## Why this matters

The big circle on the Overview fills with color as the month's hours grow. Two things are wrong with it.

1. **It never fills for publishers without a monthly goal (SLN-190).** The circle divides logged hours by the publisher status's monthly goal. A plain publisher has a goal of 0, and so does a user who hasn't picked a status, so the circle stays empty all month. Plain publishers are probably the largest group of users. The owner decided: without a monthly goal, the circle fills against the time planned in the Planner for the whole month. If nothing is planned, it works like a switch. It is empty until the month has an entry of its own, then full.
2. **It fills by height, not by area (SLN-191).** The fill is a rectangle rising from the bottom of the circle to `progress × diameter`. A circle is narrow at the bottom, so at 25 % progress only about 20 % of the circle is colored, and at 75 % about 80 %. The picture disagrees with the number. The fix keeps the look (a fill rising from the bottom) but picks the height that colors exactly the right share of the area.

## Current state

Glossary terms (from `CONTEXT.md`):

- **Monthly goal**: "The hours the publisher status expects in one month."
- **Plan**: "Time the user intends to spend in service on one day: a duration, a category and optionally a start time. A plan never counts as logged time."
- **Logged time**: "The sum of entry durations, before any rounding."
- **Carried-in entry**: "An entry Hugo creates on the 1st of the next month to hold minutes that were transferred."

Files and their roles (state after plan 085):

- `Hugo/Features/Overview/Views/MonthlyProgressCircle.swift` draws the circle. At `1432319`, which plan 085 does not change:

  ```swift
  // MonthlyProgressCircle.swift:3-10
  struct MonthlyProgressCircle: View {
      let progress: Double
      let maxValue: Double

      @Environment(\.colorScheme) private var colorScheme
      @ScaledMetric(relativeTo: .largeTitle) private var preferredSize: CGFloat = HugoLayout.Size.monthlyProgressDiameter

      var normalizedProgress: Double { maxValue > 0 ? min(max(progress / maxValue, 0), 1) : 0 }
  ```

  ```swift
  // MonthlyProgressCircle.swift:29-40
                  Rectangle()
                      .fill(progressGradient)
                      .frame(width: side, height: side)
                      .mask(alignment: .bottom) {
                          Rectangle()
                              .frame(
                                  width: side,
                                  height: CGFloat(
                                      ceil(normalizedProgress * Double(side) + (normalizedProgress >= 1 ? 1 : 0)))
                              )
                      }
                      .motion(Motion.progress, value: normalizedProgress)
  ```

  The `+ 1` when full is the fix for SLN-71 (the fill stopped one point short of the top). Keep it.
- `Hugo/Features/Overview/Domain/OverviewMetrics.swift` (after 085, only this struct remains):

  ```swift
  struct OverviewMetrics {
      let totalHours: Double
      let monthlyGoal: Double
      let expectedProgress: Double

      var progress: Double { max(totalHours, 0) }

      static func make(entries: [Entry], status: PublisherStatus?, now: Date, calendar: Calendar) -> OverviewMetrics {
          let totalHours = entries.reduce(0) { $0 + max($1.duration, 0) } / 3600
          let goal = Double(status?.monthlyGoal ?? 0)
          let days = Double(calendar.range(of: .day, in: .month, for: now)?.count ?? 0)
          let day = Double(calendar.component(.day, from: now))
          let expected = days > 0 ? day / days * goal : 0
          return OverviewMetrics(totalHours: totalHours, monthlyGoal: goal, expectedProgress: expected)
      }
  }
  ```

- `Hugo/Features/Overview/Views/MonthlyProgressCard.swift` (after 085) has the properties `value: Double`, `monthlyGoal: Double`, `planStatus: MonthlyProgressStatus?`, `onAddEntry`, `onShowPlanPace`. It calls `MonthlyProgressCircle(progress: value, maxValue: monthlyGoal).accessibilityHidden(true)`, and has:

  ```swift
  private var accessibilityValueText: String {
      monthlyGoal > 0
          ? String(localized: "a11y.monthly_progress_card.value.\(Int(value)).\(Int(monthlyGoal))")
          : String(localized: "a11y.monthly_progress_card.value.\(Int(value))")
  }
  ```

- `Hugo/Features/Overview/Screens/OverviewView.swift`, `OverviewDayView` (after 085): it has `metrics: OverviewMetrics`, a `plannerMonth: PlannerMonth` computed property, and in `body` the line `let pace = PlanPace.make(month: plannerMonth)`. It calls `MonthlyProgressCard(value: metrics.progress, monthlyGoal: metrics.monthlyGoal, planStatus: ..., onAddEntry: ..., onShowPlanPace: ...)`.
- `Hugo/Features/Planner/Domain/PlannerMonth.swift:88`: `var planned: TimeSplit { days.reduce(.zero) { $0 + $1.planned } }`, the month's planned time. `.total` gives seconds. Do not edit Planner files.
- `Entry.isCarriedIn` (`Hugo/Persistence/SchemaVersions/V11/EntryV11.swift:55-57`) is `sourceReportYear != nil && sourceReportMonth != nil`.
- The two existing accessibility strings (`Hugo/Resources/Localizable.xcstrings:22-56`):

  ```json
      "a11y.monthly_progress_card.value.%lld.%lld" : {
        "comment" : "Accessibility value of the monthly progress card when a goal exists. First argument: hours so far. Second: the monthly goal in hours.",
        "localizations" : {
          "da" : {
            "stringUnit" : {
              "state" : "translated",
              "value" : "%1$lld af %2$lld timer denne måned"
            }
          },
          "en" : {
            "stringUnit" : {
              "state" : "translated",
              "value" : "%1$lld of %2$lld hours this month"
            }
          }
        }
      },
  ```

  The next key after it is `"a11y.overview.list-style.by-date"` (line 57).
- Project facts: Xcode uses synchronized folders, so new files join their targets on their own. Default actor isolation is `MainActor`, so pure value logic in `Domain` folders is marked `nonisolated` (see `Hugo/Features/Planner/Domain/PlanPace.swift`). Tests use Swift Testing and mirror the source path (`HugoTests/Features/Overview/Domain/`). `OverviewMetricsTests` builds a fixed UTC Gregorian calendar and a `date(_:_:_:)` helper. Copy that pattern.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/OverviewMetricsTests -only-testing:HugoTests/MonthlyCircleFillTests -only-testing:HugoTests/CircleFillGeometryTests` | `** TEST SUCCEEDED **` |
| JSON is valid | `python3 -c "import json; json.load(open('Hugo/Resources/Localizable.xcstrings', encoding='utf-8'))"` | exit 0, no output |
| Full gate | `Scripts/verify.sh` | exit 0 (several minutes) |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run the same command again.

## Scope

**In scope**:
- `Hugo/Features/Overview/Domain/CircleFillGeometry.swift` (create)
- `Hugo/Features/Overview/Domain/MonthlyCircleFill.swift` (create)
- `Hugo/Features/Overview/Domain/OverviewMetrics.swift`
- `Hugo/Features/Overview/Views/MonthlyProgressCircle.swift`
- `Hugo/Features/Overview/Views/MonthlyProgressCard.swift`
- `Hugo/Features/Overview/Screens/OverviewView.swift`
- `Hugo/Resources/Localizable.xcstrings` (one new key)
- `HugoTests/Features/Overview/Domain/CircleFillGeometryTests.swift` (create)
- `HugoTests/Features/Overview/Domain/MonthlyCircleFillTests.swift` (create)
- `HugoTests/Features/Overview/Domain/OverviewMetricsTests.swift`

**Out of scope**:
- The hero number. It keeps showing `Int(metrics.progress)` (whole logged hours, carried-in time included).
- The status line, `PlanPaceSheet`, `MonthlyProgressStatus` and `PlanPace`.
- Every Planner file, including `PlannerTarget` (extra hours). The owner chose the month's plans, not the Planner target, as the fallback.
- The circle's colors, gradient, size and animation token (`Motion.progress`).
- A ring or arc design. The owner kept the filled circle.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- Never stage, edit, stash or discard files in `plans/` or `.claude/`. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage in-scope files by explicit path.
- One commit. Use: `fix: fill the Overview circle by area and against the plan without a monthly goal`

## Steps

### Step 1: Add the area-to-height geometry

Create `Hugo/Features/Overview/Domain/CircleFillGeometry.swift`:

```swift
import Foundation

/// Converts between the share of a circle's area that is filled from the
/// bottom and the height the fill reaches. Both are fractions: 0 is empty,
/// 1 is full, and height is measured as a share of the diameter.
nonisolated enum CircleFillGeometry {
    /// Share of the area below `height`. A circular segment of height h in a
    /// circle of radius r has area r²·acos((r−h)/r) − (r−h)·√(2rh−h²). With
    /// r = 1/2 and x = 1 − 2h, dividing by the circle's area πr² gives
    /// (acos(x) − x·√(1−x²)) / π.
    static func areaFraction(forHeight height: Double) -> Double {
        let h = min(max(height, 0), 1)
        let x = 1 - 2 * h
        return (acos(x) - x * (1 - x * x).squareRoot()) / .pi
    }

    /// The height whose fill covers `area` of the circle. The inverse of
    /// `areaFraction(forHeight:)`, found by bisection because it has no
    /// closed form. Values outside 0...1 are clamped; NaN counts as 0.
    static func height(forAreaFraction area: Double) -> Double {
        guard area.isFinite else { return area == .infinity ? 1 : 0 }
        let target = min(max(area, 0), 1)
        if target == 0 || target == 1 { return target }
        var low = 0.0
        var high = 1.0
        for _ in 0..<60 {
            let middle = (low + high) / 2
            if areaFraction(forHeight: middle) < target {
                low = middle
            } else {
                high = middle
            }
        }
        return (low + high) / 2
    }
}
```

Create `HugoTests/Features/Overview/Domain/CircleFillGeometryTests.swift`:

```swift
import Testing

@testable import Hugo

struct CircleFillGeometryTests {
    @Test(arguments: [0.0, 0.5, 1.0])
    func endpointsAndMiddleMatch(fraction: Double) {
        #expect(abs(CircleFillGeometry.height(forAreaFraction: fraction) - fraction) < 1e-9)
    }

    @Test(arguments: [0.01, 0.05, 0.1, 0.25, 0.4, 0.6, 0.75, 0.9, 0.95, 0.99])
    func heightRoundTripsToArea(fraction: Double) {
        let height = CircleFillGeometry.height(forAreaFraction: fraction)
        #expect(abs(CircleFillGeometry.areaFraction(forHeight: height) - fraction) < 1e-6)
    }

    @Test
    func heightGrowsWithArea() {
        var previous = -1.0
        for step in 0...20 {
            let height = CircleFillGeometry.height(forAreaFraction: Double(step) / 20)
            #expect(height > previous)
            previous = height
        }
    }

    @Test
    func aQuarterOfTheAreaNeedsMoreThanAQuarterOfTheHeight() {
        let height = CircleFillGeometry.height(forAreaFraction: 0.25)
        #expect(height > 0.29 && height < 0.31)
    }

    @Test
    func outOfRangeValuesAreClamped() {
        #expect(CircleFillGeometry.height(forAreaFraction: -0.5) == 0)
        #expect(CircleFillGeometry.height(forAreaFraction: 1.5) == 1)
        #expect(CircleFillGeometry.height(forAreaFraction: .nan) == 0)
    }
}
```

**Verify**: the focused tests compile only after Step 2 creates `MonthlyCircleFillTests`. Run them after Step 2.

### Step 2: Add the fill rule and the "own entries" flag

1. In `OverviewMetrics.swift`, add a stored property `let hasOwnEntries: Bool` after `expectedProgress`. In `make`, compute it and pass it to the initializer:

   ```swift
   /// True when the month has logged time other than carried-in entries.
   let hasOwnEntries = entries.contains { !$0.isCarriedIn && $0.duration > 0 }
   return OverviewMetrics(
       totalHours: totalHours, monthlyGoal: goal, expectedProgress: expected, hasOwnEntries: hasOwnEntries)
   ```

   Put the doc comment on the stored property, not on the local constant.

2. Create `Hugo/Features/Overview/Domain/MonthlyCircleFill.swift`:

   ```swift
   import Foundation

   /// How full the Overview circle is, and what it is measured against.
   nonisolated struct MonthlyCircleFill: Equatable, Sendable {
       nonisolated enum Basis: Equatable, Sendable {
           /// Logged time against the publisher status's monthly goal.
           case monthlyGoal(hours: Double)
           /// No monthly goal: logged time against all time planned this month.
           case plan(plannedSeconds: TimeInterval)
           /// No monthly goal and no plans: full once the month has an entry of its own.
           case presence
       }

       let basis: Basis
       /// Share of the circle's area to fill, from 0 to 1.
       let fraction: Double

       /// A monthly goal wins over plans. Without a goal, the month's plans set
       /// the scale. Without either, the circle is empty or full depending on
       /// `hasOwnEntries` (carried-in entries alone do not fill it).
       static func make(
           monthlyGoalHours: Double, loggedSeconds: TimeInterval, plannedSeconds: TimeInterval, hasOwnEntries: Bool
       ) -> MonthlyCircleFill {
           let logged = max(loggedSeconds, 0)
           if monthlyGoalHours > 0 {
               return MonthlyCircleFill(
                   basis: .monthlyGoal(hours: monthlyGoalHours),
                   fraction: min(logged / (monthlyGoalHours * 3_600), 1))
           }
           if plannedSeconds > 0 {
               return MonthlyCircleFill(
                   basis: .plan(plannedSeconds: plannedSeconds), fraction: min(logged / plannedSeconds, 1))
           }
           return MonthlyCircleFill(basis: .presence, fraction: hasOwnEntries ? 1 : 0)
       }
   }
   ```

3. Create `HugoTests/Features/Overview/Domain/MonthlyCircleFillTests.swift` with these tests (all `@Test`, no `@MainActor` needed):
   - `goalSetsTheScale`: `make(monthlyGoalHours: 30, loggedSeconds: 15 * 3_600, plannedSeconds: 0, hasOwnEntries: true)` → `fraction == 0.5`, `basis == .monthlyGoal(hours: 30)`.
   - `goalWinsOverPlans`: goal 30, logged 15 h, planned 20 h → `fraction == 0.5`, basis `.monthlyGoal(hours: 30)`.
   - `goalCapsAtFull`: goal 30, logged 40 h → `fraction == 1`.
   - `withoutGoalPlansSetTheScale`: goal 0, logged 5 h, planned 20 h → `fraction == 0.25`, basis `.plan(plannedSeconds: 20 * 3_600)`.
   - `withoutGoalPlansCapAtFull`: goal 0, logged 25 h, planned 20 h → `fraction == 1`.
   - `withoutGoalOrPlansAnOwnEntryFillsTheCircle`: goal 0, logged 0.5 h, planned 0, `hasOwnEntries: true` → `fraction == 1`, basis `.presence`.
   - `withoutGoalOrPlansNoEntryLeavesItEmpty`: goal 0, logged 0, planned 0, `hasOwnEntries: false` → `fraction == 0`, basis `.presence`.
   - `negativeLoggedTimeCountsAsZero`: goal 30, logged −100 → `fraction == 0`.

4. In `OverviewMetricsTests.swift`, add:
   - `carriedInEntriesAloneAreNotOwnEntries`: one `Entry(date: date(2026, 1, 1), duration: 1_800, tracker: nil)` with `sourceReportYear = 2025` and `sourceReportMonth = 12` set after creation → `OverviewMetrics.make(...).hasOwnEntries == false`.
   - `aRegularEntryIsAnOwnEntry`: one regular entry of 600 seconds → `hasOwnEntries == true`.
   - `zeroLengthEntriesAreNotOwnEntries`: one regular entry with `duration: 0` → `hasOwnEntries == false`.

**Verify**: the focused tests → `** TEST SUCCEEDED **` (the app compiles, because nothing uses the new types yet).

### Step 3: Draw the circle by area

In `MonthlyProgressCircle.swift`:

- Replace `let progress: Double` and `let maxValue: Double` with `let fraction: Double` and a doc comment: `/// Share of the circle's area to fill, from 0 to 1.`
- Replace `normalizedProgress` (line 10) with:

  ```swift
  private var clampedFraction: Double { min(max(fraction, 0), 1) }

  /// The fill's height as a share of the diameter, chosen so the colored
  /// area matches `fraction` (a circle is narrow at the bottom, so a
  /// quarter of the area needs about 30 % of the height).
  private var fillHeight: Double { CircleFillGeometry.height(forAreaFraction: clampedFraction) }
  ```

- In the mask (lines 33–38) use `ceil(fillHeight * Double(side) + (clampedFraction >= 1 ? 1 : 0))`, and change `.motion(Motion.progress, value: normalizedProgress)` to `.motion(Motion.progress, value: fillHeight)`.

The app does not compile until Step 4 updates the caller.

### Step 4: Feed the card the fill

**`MonthlyProgressCard.swift`**:

- Replace `let monthlyGoal: Double` with `let fill: MonthlyCircleFill`. Keep `let value: Double` (the hero hours).
- Call `MonthlyProgressCircle(fraction: fill.fraction)` (keep `.accessibilityHidden(true)`).
- Replace `accessibilityValueText` with:

  ```swift
  private var accessibilityValueText: String {
      switch fill.basis {
      case .monthlyGoal(let hours):
          String(localized: "a11y.monthly_progress_card.value.\(Int(value)).\(Int(hours))")
      case .plan(let plannedSeconds):
          String(
              localized:
                  "a11y.monthly_progress_card.value.planned.\(Int(value)).\(Int((plannedSeconds / 3_600).rounded(.up)))"
          )
      case .presence:
          String(localized: "a11y.monthly_progress_card.value.\(Int(value))")
      }
  }
  ```

  Planned hours round up so VoiceOver never says "20 of 20" while the circle is not yet full.

**`OverviewView.swift`** (`OverviewDayView.body`): next to `let pace = PlanPace.make(month: plannerMonth)`, build the month once and reuse it:

```swift
let month = plannerMonth
let pace = PlanPace.make(month: month)
let metrics = self.metrics
let fill = MonthlyCircleFill.make(
    monthlyGoalHours: metrics.monthlyGoal, loggedSeconds: metrics.progress * 3_600,
    plannedSeconds: month.planned.total, hasOwnEntries: metrics.hasOwnEntries)
```

Pass `value: metrics.progress, fill: fill` to `MonthlyProgressCard` instead of `value:` and `monthlyGoal:`.

**Verify**: `grep -rn "maxValue\|normalizedProgress\|monthlyGoal: metrics" Hugo/Features/Overview` → no output. The focused tests → `** TEST SUCCEEDED **`.

### Step 5: Add the VoiceOver string

Insert this entry into `Hugo/Resources/Localizable.xcstrings` directly after the `"a11y.monthly_progress_card.value.%lld.%lld"` entry and before `"a11y.overview.list-style.by-date"`. Use the same JSON shape as the excerpt above:

- Key: `a11y.monthly_progress_card.value.planned.%lld.%lld`
- Comment: `Accessibility value of the monthly progress card when there is no monthly goal and the month has plans. First argument: hours so far. Second: hours planned this month.`
- en: `%1$lld of %2$lld planned hours this month`
- da (owner reviews): `%1$lld af %2$lld planlagte timer denne måned`

**Verify**: the JSON check exits 0. `grep -c '"a11y.monthly_progress_card.value.planned.%lld.%lld"' Hugo/Resources/Localizable.xcstrings` → `1`.

### Step 6: Run the gate and commit

Run `Scripts/verify.sh`. Stage the in-scope files by path and commit with the message from "Git workflow".

**Verify**: `Scripts/verify.sh` exits 0. `git show --stat HEAD` lists only in-scope files.

## Test plan

- `CircleFillGeometryTests` (new): endpoints, round trip within 1e-6 for ten fractions, monotonic growth, the 25 % case (height between 0.29 and 0.31), clamping and NaN.
- `MonthlyCircleFillTests` (new, 8 tests): goal basis, goal over plans, caps, plan basis, presence basis both ways, negative time.
- `OverviewMetricsTests` (3 new tests): `hasOwnEntries` ignores carried-in and zero-length entries.
- Pattern: `HugoTests/Features/Overview/Domain/MonthlyProgressStatusTests.swift` (argument-based `@Test`) and `OverviewMetricsTests.swift` (calendar and date helper).

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, including the three test suites above.
- [ ] `grep -rn "maxValue\|normalizedProgress" Hugo/Features/Overview` → no output.
- [ ] `grep -c '"a11y.monthly_progress_card.value.planned.%lld.%lld"' Hugo/Resources/Localizable.xcstrings` → `1`.
- [ ] `git show --stat HEAD` lists only in-scope files.
- [ ] Owner check on device:
  - As an auxiliary or regular pioneer, the circle fills against the monthly goal as before, but a quarter of the goal now colors about a quarter of the circle.
  - As a publisher (no goal) with plans this month, the circle fills against the month's planned time.
  - As a publisher with no plans, the circle is empty with no entries this month and full after the first entry. A month that holds only carried-in minutes stays empty.
  - At 100 %, the fill still reaches the very top (SLN-71).
  - VoiceOver reads "N of M planned hours this month" in the plan case.

## STOP conditions

Stop and report back (do not improvise) if:

- Plan 085 is not committed (`grep -rn "onShowPlanPace" Hugo/Features/Overview` returns nothing).
- The "Current state" excerpts don't match the live code beyond 085's changes.
- `MonthlyProgressCircle` has another caller besides `MonthlyProgressCard` (`grep -rn "MonthlyProgressCircle(" Hugo`).
- `CircleFillGeometryTests.heightRoundTripsToArea` fails for any fraction after you re-check the formula against this plan. Do not loosen the tolerance.
- A step's verification fails twice after a reasonable fix attempt.

## Maintenance notes

- Closes SLN-190 and SLN-191. The status half of SLN-190 was already gone: the status line now compares with the plan (plan 072) and only shows when there are plans.
- **Decision to confirm with the owner:** in the "no goal, no plans" case, carried-in entries alone do not fill the circle, because they hold last month's transferred minutes, not service done this month. The hero number still counts them. If the owner wants any entry to count, change `hasOwnEntries` in `OverviewMetrics.make` and its test.
- In the plan case, the scale is the whole month's planned time, not the plan up to today. A publisher who plans 20 hours and has logged 5 sees a quarter-full circle on day 1 and on day 25 alike. The status line and the plan pace sheet (plan 085) cover the "on track today" question.
- Extra hours from the Planner target (Settings) do not affect the circle. If a later build lets publishers set a personal monthly target, add it as a basis between `monthlyGoal` and `plan` in `MonthlyCircleFill.make`.
- `OverviewMetrics.expectedProgress` has no reader in the app any more (only tests). Leave it; removing it is unrelated cleanup.
