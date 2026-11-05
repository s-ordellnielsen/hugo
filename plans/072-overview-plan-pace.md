# Plan 072: Show on the Overview whether the month is ahead of or behind the plan

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 2e8a451..HEAD -- Hugo/Features/Overview HugoTests/Features/Overview`
> Plan 068 moves `CategoryProgressColor` out of `OverviewMetrics.swift`; that
> change is expected. For any other change, compare the "Current state"
> excerpts against the live code; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW (display only; nothing changes for users without plans)
- **Depends on**: plans/067-plan-model-schema-v12.md, plans/068-planner-domain-math.md (070 should land first so users can create plans)
- **Category**: direction
- **Planned at**: commit `2e8a451`, 2026-11-04
- **Issue**: [SLN-275](https://linear.app/sebastianln/issue/SLN-275)

## Why this matters

The Overview's monthly circle once showed "Ahead of Schedule" or "Behind
Schedule". It was hidden because comparing against an even pace can discourage
users who planned a slow start to the month. With the Planner, Hugo knows the
user's own plan, so the comparison becomes fair: ahead of or behind what *you*
planned. This plan brings the label back, only for months the user has planned.

## Product rules (decided with the owner, do not change)

1. The status shows only when the current month has at least one plan
   (`PlanPace.make` returns non-nil). Without plans the Overview looks exactly as today.
2. The comparison is `PlanPace` from plan 068: planned time on days before
   today, plus today's planned time only as far as it is already logged,
   against all logged time this month. Plain totals, no yearly-goal credit rule.
3. The label and icon are the existing `MonthlyProgressStatus` levels and
   strings (thresholds: more than 5 h ahead, more than 2 h ahead, within 2 h,
   more than 2 h behind, more than 5 h behind). Do not change the strings or thresholds.
4. VoiceOver reads the status as part of the card's value.

## Current state

- `Hugo/Features/Overview/Views/MonthlyProgressCard.swift`:

  ```swift
  struct MonthlyProgressCard: View {
      let value: Double
      let monthlyGoal: Double
      let expectedProgress: Double
      let onAddEntry: () -> Void
      let onShowDetails: () -> Void
      ...
                      VStack {
                          Text(Date.now, format: .dateTime.month(.wide))
                              ...
                          Text(String("\(Int(value))"))
                              ...
                              .motion(Motion.value, value: value)
                          // Keep this status view for future planning features. It is hidden for now because
                          // schedule labels can discourage users who are behind their expected progress.
                          // MonthlyProgressStatusView(expected: expectedProgress, current: value)
                      }
      ...
              .accessibilityElement(children: .combine)
              .accessibilityLabel(Text("a11y.monthly_progress_card.label"))
              .accessibilityValue(
                  monthlyGoal > 0
                      ? Text("a11y.monthly_progress_card.value.\(Int(value)).\(Int(monthlyGoal))")
                      : Text("a11y.monthly_progress_card.value.\(Int(value))")
              )
  ```

  `expectedProgress` is used only by the commented-out line.
- `Hugo/Features/Overview/Views/MonthlyProgressStatusView.swift`:

  ```swift
  struct MonthlyProgressStatusView: View {
      let expected: Double
      let current: Double
      var body: some View {
          let status = MonthlyProgressStatus.make(expected: expected, current: current)
          return HStack {
              Image(systemName: status.icon)
              Text(status.label)
          }.fontWeight(.semibold)
      }
  }
  ```

  It has no other users.
- `Hugo/Features/Overview/Domain/MonthlyProgressStatus.swift`:
  `MonthlyProgressStatus.make(expected: Double, current: Double)` (both in hours;
  returns `.onTarget` when `expected` is zero), `label: String`, `icon: String`.
  English labels: "Way Ahead of Schedule", "Ahead of Schedule", "On Target",
  "Behind Schedule", "Way Behind Schedule"; Danish already says "plan"
  ("Foran plan", "Følger plan", ...).
- `Hugo/Features/Overview/Screens/OverviewView.swift`, `OverviewDayView`:

  ```swift
  @Query private var entries: [Entry]
  @Query private var submissions: [SubmittedReport]
  ...
  init(today: Date) {
      self.today = today
      let range = today.yearMonth(using: .current).dateRange(calendar: .current)
      let start = range.lowerBound
      let end = range.upperBound
      _entries = Query(
          filter: #Predicate<Entry> { $0.date >= start && $0.date < end }, sort: \Entry.date, order: .reverse)
  }
  ...
  MonthlyProgressCard(
      value: metrics.progress, monthlyGoal: metrics.monthlyGoal,
      expectedProgress: metrics.expectedProgress, onAddEntry: { showingAddEntry = true },
      onShowDetails: { showingDetails = true })
  ```

- `HugoTests/Features/Overview/Domain/MonthlyProgressStatusTests.swift`
  (`@MainActor struct`, parameterized `@Test(arguments:)`) is the test pattern.
- From plan 068: `PlannedItem(plan, trackers:)`,
  `PlannerMonth.make(month:items:entries:trackers:now:calendar:)`,
  `PlanPace.make(month:) -> PlanPace?` with `expectedSeconds` and `loggedSeconds`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Layout | `Scripts/check-layout.sh` | exit 0, no output |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/MonthlyProgressStatusTests -only-testing:HugoTests/PlanPaceTests -only-testing:HugoTests/OverviewMetricsTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:
- `Hugo/Features/Overview/Domain/MonthlyProgressStatus.swift` (one factory)
- `Hugo/Features/Overview/Views/MonthlyProgressStatusView.swift`
- `Hugo/Features/Overview/Views/MonthlyProgressCard.swift`
- `Hugo/Features/Overview/Screens/OverviewView.swift`
- `HugoTests/Features/Overview/Domain/MonthlyProgressStatusTests.swift`

**Out of scope**:
- `OverviewMetrics` (keep `expectedProgress` and its tests; see maintenance notes).
- `Localizable.xcstrings`: no new strings.
- Anything in the Planner feature.

## Git workflow

- Branch: `advisor/072-overview-plan-pace`
- Conventional Commits, for example `feat: show plan pace on the overview`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: A factory from plan pace, with a test

In `MonthlyProgressStatus.swift` add:

```swift
extension MonthlyProgressStatus {
    /// The current month compared with the user's plan.
    static func make(pace: PlanPace) -> Self {
        make(expected: pace.expectedSeconds / 3_600, current: pace.loggedSeconds / 3_600)
    }
}
```

Add to `MonthlyProgressStatusTests`:
- `PlanPace(expectedSeconds: 10 * 3_600, loggedSeconds: 13 * 3_600)` → `.aboveTarget`.
- `PlanPace(expectedSeconds: 10 * 3_600, loggedSeconds: 4 * 3_600)` → `.wayBelowTarget`.
- `PlanPace(expectedSeconds: 0, loggedSeconds: 4 * 3_600)` → `.onTarget`.

**Verify**: Focused tests → `** TEST SUCCEEDED **`.

### Step 2: Show the status on the card

1. `MonthlyProgressStatusView`: replace `expected`/`current` with
   `let status: MonthlyProgressStatus` and drop the `make` call in `body`.
2. `MonthlyProgressCard`: replace `let expectedProgress: Double` with
   `var planStatus: MonthlyProgressStatus? = nil` (same position, directly after
   `monthlyGoal`, so the memberwise initializer takes it after `monthlyGoal:`).
   Replace the three comment lines with:

   ```swift
   if let planStatus {
       MonthlyProgressStatusView(status: planStatus)
           .font(.caption)
           .foregroundStyle(.secondary)
           .transition(.opacity)
   }
   ```

3. Replace the `.accessibilityValue(...)` with a `Text(verbatim:)` built from a
   string, so the status can be appended without `Text` concatenation:

   ```swift
   .accessibilityValue(Text(verbatim: accessibilityValueText))
   ...
   private var accessibilityValueText: String {
       let amount =
           monthlyGoal > 0
           ? String(localized: "a11y.monthly_progress_card.value.\(Int(value)).\(Int(monthlyGoal))")
           : String(localized: "a11y.monthly_progress_card.value.\(Int(value))")
       guard let planStatus else { return amount }
       return "\(amount), \(planStatus.label)"
   }
   ```

   The two keys already exist in the catalog (`a11y.monthly_progress_card.value.%lld.%lld`
   and `a11y.monthly_progress_card.value.%lld`). After the change, run the app in
   the simulator with VoiceOver or the Accessibility Inspector and confirm the
   value reads "3 of 50 hours this month", not the raw key.

### Step 3: Feed the status from the Overview

In `OverviewDayView` (`OverviewView.swift`):

1. Add `@Query private var plans: [Plan]` and `@Query private var trackers: [Tracker]`.
   In `init`, bound plans to the same month range:
   `_plans = Query(filter: #Predicate<Plan> { $0.date >= start && $0.date < end })`.
2. Add:

   ```swift
   /// Nil unless the current month has plans.
   private var planStatus: MonthlyProgressStatus? {
       let month = PlannerMonth.make(
           month: today.yearMonth(using: .current),
           items: plans.map { PlannedItem($0, trackers: trackers) },
           entries: entries, trackers: trackers, now: .now, calendar: .current)
       return PlanPace.make(month: month).map(MonthlyProgressStatus.make(pace:))
   }
   ```

3. Update the card call: replace `expectedProgress: metrics.expectedProgress`
   with `planStatus: planStatus`.
4. Add `planStatus` to the existing `.motion(Motion.presence, value: reminderMonth)`
   only if the status pops in without animation in the simulator; otherwise leave it.

**Verify**: `Scripts/verify.sh` → exit 0.

## Test plan

- `MonthlyProgressStatusTests`: three new cases (Step 1).
- `PlanPaceTests` (plan 068) covers the pace math.
- Manual (owner): with no plans this month, the Overview is unchanged. Plan 3 h
  for yesterday and log 0 h: "Behind Schedule". Plan 2 h for today only: "On
  Target" in the morning; log 3 h today: "On Target" (+1 h is within 2 h); log
  5 h today: "Ahead of Schedule". VoiceOver reads the status after the hours.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -n "expectedProgress" Hugo/Features/Overview/Views/MonthlyProgressCard.swift` → no matches
- [ ] `grep -n "// MonthlyProgressStatusView" Hugo/Features/Overview/Views/MonthlyProgressCard.swift` → no matches
- [ ] `grep -n "@Query private var plans" Hugo/Features/Overview/Screens/OverviewView.swift` → one match
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- Plan 068 is not DONE (`PlanPace` does not exist).
- `MonthlyProgressStatusView` has callers other than the commented line.
- The status text does not fit inside the progress circle at the default
  Dynamic Type size (it overlaps the ring). Report with a screenshot; do not
  resize the circle.
- `String(localized:)` with the interpolated `Int`s resolves to a raw key at runtime.

## Maintenance notes

- `OverviewMetrics.expectedProgress` (even pace through the month) is no longer
  shown anywhere. It stays because its tests document the old rule; delete both
  in a later cleanup if nobody wants the even-pace status back.
- If the owner wants plan-specific wording ("Ahead of your plan"), change only
  the English values of the five `month.progress.status.*` keys.
- The Overview now depends on Planner types (`PlannedItem`, `PlannerMonth`,
  `PlanPace`). The Planner must never depend on Overview types; plan 068 moved
  `CategoryProgressColor` to `Hugo/Domain` for that reason.
