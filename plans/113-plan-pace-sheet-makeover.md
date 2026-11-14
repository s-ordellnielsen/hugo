# Plan 113: Show the plan pace as a bar with a "today" marker, in the carried-in sheet's layout

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 7dd6b4c..HEAD -- Hugo/Features/Overview/Screens/PlanPaceSheet.swift Hugo/Features/Overview/Screens/OverviewView.swift Hugo/Features/Planner/Domain/PlanPace.swift HugoTests/Features/Planner/Domain/PlanPaceTests.swift Hugo/DesignSystem/Components/MarkedProgressBar.swift`
> Expected: no output. If a file is listed, compare the excerpts below with the
> live code. A mismatch is a STOP condition. Changes to
> `Localizable.xcstrings` from other plans are fine as long as the
> `overview.pace.*` keys named below are unchanged.

## Status

- **Priority**: P3
- **Effort**: S + owner (look at it on a device, in English and Danish)
- **Risk**: LOW. One sheet's layout, one new stored value on `PlanPace`, strings. No change to how pace is computed, no schema.
- **Depends on**: plan 111 Revision 2 (the carried-in sheet layout this plan copies; done as `1bb4e58`)
- **Category**: direction (UI)
- **Planned at**: commit `7dd6b4c`, 2026-11-14 (rewritten the same day after the owner chose the bar; nothing from the first version had run)
- **Issue**: [SLN-311](https://linear.app/sebastianln/issue/SLN-311)

## Why this matters

Tapping the status line under the Overview circle ("You're 3 hours behind your plan") opens the plan pace sheet. Today it has a navigation bar with the title "Your plan" and a Done button, a list with "Planned until today" and "Logged", and a footer about how today's plans count. The owner decided on 2026-11-14:

1. Same makeover as the carried-in breakdown sheet (plan 111, Revisions 1 and 2): no title, no Done button, the heading at the very top, a drag indicator.
2. Keep the heading exactly as it is: the status icon, its label in `.title2` serif bold, and the difference sentence under it.
3. Remove the footer. It explains a technicality, and most users get more confused by it.
4. Replace the list with a bar: the track is **the whole month's plan**, the fill is the logged time, and a marker shows the time planned until today. Below the bar, two numbers: logged, and planned this month. If the fill hasn't reached the marker, the user is behind, and they can see by how much without comparing two numbers.

Sketch:

```
 ⌄ Behind plan
   You're 3 hours behind your plan

   ████████████░░░░░│░░░░░░░░░░░░░░░
                    15 hours planned until today

   11 hours, 30 min           32 hours
   Logged                     Planned this month
```

## Current state

### The sheet

`Hugo/Features/Overview/Screens/PlanPaceSheet.swift` (whole file at `7dd6b4c`):

```swift
import SwiftUI

/// The plan pace of the current month in numbers. Opened from the status line
/// under the Overview circle.
struct PlanPaceSheet: View {
    let pace: PlanPace

    @Environment(\.dismiss) private var dismiss

    private var status: MonthlyProgressStatus { .make(pace: pace) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                        Label(status.label, systemImage: status.icon)
                            .font(.system(.title2, design: .serif, weight: .bold))
                        Text(pace.differenceSentence)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .listRowBackground(Color.clear)
                }
                Section {
                    LabeledContent(
                        "overview.pace.planned",
                        value: ServiceDurationFormatter.hoursString(from: pace.expectedSeconds))
                    LabeledContent(
                        "overview.pace.logged",
                        value: ServiceDurationFormatter.hoursString(from: pace.loggedSeconds))
                } footer: {
                    Text("overview.pace.footer")
                }
            }
            .navigationTitle("overview.pace.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("navigation.done") { dismiss() }
                }
            }
        }
    }
}

#Preview("Behind") {
    PlanPaceSheet(pace: PlanPace(expectedSeconds: 15 * 3_600, loggedSeconds: 11 * 3_600 + 30 * 60))
}

#Preview("Ahead") {
    PlanPaceSheet(pace: PlanPace(expectedSeconds: 8 * 3_600, loggedSeconds: 12 * 3_600))
}
```

It is opened from `Hugo/Features/Overview/Screens/OverviewView.swift` (inside `OverviewDayView`, around line 110):

```swift
            .sheet(isPresented: $showingPlanPace) {
                if let pace {
                    PlanPaceSheet(pace: pace)
                        .presentationDetents([.medium])
                }
            }
```

### `PlanPace`

`Hugo/Features/Planner/Domain/PlanPace.swift` (whole file):

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

`PlannerMonth` (`Hugo/Features/Planner/Domain/PlannerMonth.swift:89`) already has `var planned: TimeSplit`, the month's whole plan; `.total` is its seconds.

`PlanPace(expectedSeconds:loggedSeconds:)` is called in `PlanPaceSheet`'s previews, `HugoTests/Features/Overview/Domain/PlanPaceSentenceTests.swift` and `HugoTests/Features/Overview/Domain/MonthlyProgressStatusTests.swift`. Giving the new property a default value keeps those calls compiling unchanged.

### The bar to reuse

`MarkedProgressBar` (`Hugo/DesignSystem/Components/MarkedProgressBar.swift`). Its initializer:

```swift
    init(
        filled: Double,
        extended: Double? = nil,
        marker: Double? = nil,
        @ViewBuilder markerLabel: () -> MarkerLabel
    )
```

Values are fractions 0...1 (it clamps them). It draws the accent fill, a marker line and the marker label under the marker, animates changes, respects Reduce Motion, and **hides itself from VoiceOver**: its doc comment says callers must expose the same information. An existing caller with a marker label, `Hugo/Features/Settings/Views/CurrentMonthCalculationPreview.swift:42-46`:

```swift
                MarkedProgressBar(filled: option.fraction, marker: calculation.todayFraction) {
                    Text(calculation.todayLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
```

### The layout to copy

`Hugo/Features/Overview/Screens/CarriedInBreakdownSheet.swift` (plan 111 Revision 2): no `NavigationStack`, the heading first with `.accessibilityAddTraits(.isHeader)`, shown with `.presentationDetents([.medium])` and `.presentationDragIndicator(.visible)`. That sheet keeps a `List` because it lists categories. This sheet has no list any more, so it uses a plain `VStack` with padding.

### Strings

In `Hugo/Resources/Localizable.xcstrings`:

| Key | English | Danish | After this plan |
|---|---|---|---|
| `overview.pace.title` | Your plan | Din plan | removed |
| `overview.pace.planned` | Planned until today | Planlagt indtil i dag | removed |
| `overview.pace.footer` | Today's plans count only as far as … | Dagens planer tæller kun med … | removed |
| `overview.pace.logged` | Logged | Udført | unchanged, reused |
| `overview.pace.marker.%@` | %@ planned until today | %@ planlagt indtil i dag | new |
| `overview.pace.plannedMonth` | Planned this month | Planlagt denne måned | new |
| `overview.pace.a11y.numbers.%@.%@.%@` | %1$@ logged. %2$@ planned until today. %3$@ planned this month. | %1$@ udført. %2$@ planlagt indtil i dag. %3$@ planlagt denne måned. | new |

`navigation.done` stays: other screens use it. Only `PlanPaceSheet` uses the three removed keys (`grep -rn "overview.pace.title\|overview.pace.planned\"\|overview.pace.footer" Hugo --include='*.swift'` finds only that file).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Debug -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/PlanPaceTests` | `** TEST SUCCEEDED **` |
| Catalog is valid JSON | `python3 -I -c "import json; json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0, no output |
| Full gate (before each commit) | `Scripts/verify.sh` | exit 0 |
| Whitespace | `git diff --check` | exit 0 |

Use 4-space indentation. Tabs fail the lint.

## Scope

**In scope** (the only files you may change):

- `Hugo/Features/Planner/Domain/PlanPace.swift`
- `HugoTests/Features/Planner/Domain/PlanPaceTests.swift`
- `Hugo/Features/Overview/Screens/PlanPaceSheet.swift`
- `Hugo/Features/Overview/Screens/OverviewView.swift` (the `PlanPaceSheet` `.sheet` modifier only)
- `Hugo/Resources/Localizable.xcstrings` (remove three keys, add three keys)

**Out of scope**:

- `MarkedProgressBar.swift` and its geometry. Use the component as it is.
- How `expectedSeconds` is computed, `PlanPaceSentence`, `MonthlyProgressStatus`, and the status line in `MonthlyProgressCard`.
- `PlanPaceSentenceTests.swift`, `MonthlyProgressStatusTests.swift`. They must keep compiling unchanged.
- `CarriedInBreakdownSheet.swift`, `OverviewListView.swift`.
- `Hugo.xcodeproj/project.pbxproj`, `.claude/`, `Changelog/` and `plans/` (except this plan's README row). Never stage them.

## Git workflow

- Work on `main`. No branch, no worktree, no push. Stage files by path.
- Two commits, each after `Scripts/verify.sh` exits 0:
  1. `feat: give the plan pace the month's whole plan and bar fractions` (Step 1)
  2. `feat: show the plan pace as a bar with a today marker` (Steps 2-4)

## Steps

### Step 1: Give `PlanPace` the month's plan and the bar's fractions

In `PlanPace.swift`:

1. Below `let loggedSeconds: TimeInterval`, add:

```swift
    /// All time planned in the month, past and future days. Zero when unknown.
    var plannedSeconds: TimeInterval = 0
```

   It must be a `var` with a default, so the memberwise initializer still accepts `PlanPace(expectedSeconds:loggedSeconds:)`.

2. Below `differenceSeconds`, add:

```swift
    /// The bar's full length: the month's plan, or the time expected so far
    /// if that is larger (which only happens when `plannedSeconds` is unknown).
    private var barScale: TimeInterval { max(plannedSeconds, expectedSeconds, 1) }

    /// Logged time as a fraction of the month's plan, capped at 1.
    var loggedFraction: Double { min(loggedSeconds / barScale, 1) }

    /// Time planned until today as a fraction of the month's plan.
    var expectedFraction: Double { min(expectedSeconds / barScale, 1) }
```

3. In `make(month:)`, change the return to:

```swift
        return PlanPace(
            expectedSeconds: expected, loggedSeconds: month.logged.total, plannedSeconds: month.planned.total)
```

4. In `PlanPaceTests.swift`, add these tests (reuse `makeNovember`, `item` and `entry`; "today" in those helpers is November 3):

   - `plannedSecondsIsTheWholeMonthsPlan`: items of 3 h on Nov 2 and 5 h on Nov 10, an entry of 1 h on Nov 2 → `plannedSeconds == 8 * 3_600`, `expectedSeconds == 3 * 3_600`.
   - `fractionsAreMeasuredAgainstTheMonthsPlan`: same items, entry of 2 h on Nov 2 → `loggedFraction == 0.25`, `expectedFraction == 0.375`.
   - `loggedFractionIsCappedAtTheMonthsPlan`: item of 2 h on Nov 2, entry of 5 h on Nov 2 → `loggedFraction == 1`, `expectedFraction == 1`.
   - `fractionsFallBackWithoutAMonthPlan`: `PlanPace(expectedSeconds: 4 * 3_600, loggedSeconds: 2 * 3_600)` (no `plannedSeconds`) → `expectedFraction == 1`, `loggedFraction == 0.5`.

**Verify**: lint exits 0. The focused test command → `** TEST SUCCEEDED **` with the 4 new tests passing. `Scripts/verify.sh` exits 0 (this also proves `PlanPaceSentenceTests` and `MonthlyProgressStatusTests` still compile). Commit 1.

### Step 2: Rebuild the sheet

Replace the whole of `PlanPaceSheet.swift` with:

```swift
import SwiftUI

/// The plan pace of the current month: a status heading, then a bar whose
/// track is the month's plan, filled with the logged time and marked where
/// the plan expects the user to be today. Opened from the status line under
/// the Overview circle.
struct PlanPaceSheet: View {
    let pace: PlanPace

    private var status: MonthlyProgressStatus { .make(pace: pace) }

    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.card) {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                Label(status.label, systemImage: status.icon)
                    .font(.system(.title2, design: .serif, weight: .bold))
                Text(pace.differenceSentence)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
                MarkedProgressBar(filled: pace.loggedFraction, marker: pace.expectedFraction) {
                    Text("overview.pace.marker.\(hours(pace.expectedSeconds))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline) {
                    amount(hours(pace.loggedSeconds), label: "overview.pace.logged", alignment: .leading)
                    Spacer(minLength: HugoLayout.Spacing.regular)
                    amount(hours(pace.plannedSeconds), label: "overview.pace.plannedMonth", alignment: .trailing)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                Text(
                    "overview.pace.a11y.numbers.\(spoken(pace.loggedSeconds)).\(spoken(pace.expectedSeconds)).\(spoken(pace.plannedSeconds))"
                ))
        }
        .padding(HugoLayout.Spacing.card)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func amount(_ value: String, label: LocalizedStringKey, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: HugoLayout.Spacing.tight) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .bold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func hours(_ seconds: TimeInterval) -> String {
        ServiceDurationFormatter.hoursString(from: seconds)
    }

    private func spoken(_ seconds: TimeInterval) -> String {
        ServiceDurationFormatter.accessibilityString(from: seconds)
    }
}

#Preview("Behind") {
    PlanPaceSheet(
        pace: PlanPace(expectedSeconds: 15 * 3_600, loggedSeconds: 11 * 3_600 + 30 * 60, plannedSeconds: 32 * 3_600))
}

#Preview("Ahead") {
    PlanPaceSheet(pace: PlanPace(expectedSeconds: 8 * 3_600, loggedSeconds: 12 * 3_600, plannedSeconds: 30 * 3_600))
}
```

Notes:
- The heading block is unchanged except for `.accessibilityAddTraits(.isHeader)`. Do not change its fonts, icon or spacing.
- The bar hides itself from VoiceOver, so the group below it reads one sentence with all three numbers.
- Let `swift-format` decide line breaks; the lint must pass.

**Verify**: lint exits 0. `grep -n "NavigationStack\|List {\|navigationTitle\|navigation.done\|footer\|dismiss" Hugo/Features/Overview/Screens/PlanPaceSheet.swift` prints nothing. `grep -n "MarkedProgressBar" Hugo/Features/Overview/Screens/PlanPaceSheet.swift` prints one line.

### Step 3: Show the drag indicator

In `OverviewView.swift`, in the `.sheet(isPresented: $showingPlanPace)` modifier, add `.presentationDragIndicator(.visible)` after `.presentationDetents([.medium])`. Change nothing else in that file.

**Verify**: `grep -n "presentationDragIndicator" Hugo/Features/Overview/Screens/OverviewView.swift` prints one line.

### Step 4: Strings

In `Hugo/Resources/Localizable.xcstrings` (keep the file's formatting: two-space JSON indentation, `" : "` spacing, keys in sorted order, `"state" : "translated"` for `da` and `en`; copy the shape of `overview.pace.logged`, and of an existing `%@` key such as `report.line.transferred.%@` for the format strings):

1. Remove `overview.pace.title`, `overview.pace.planned` and `overview.pace.footer`.
2. Add, in sorted position:
   - `overview.pace.a11y.numbers.%@.%@.%@`: English "%1$@ logged. %2$@ planned until today. %3$@ planned this month.", Danish "%1$@ udført. %2$@ planlagt indtil i dag. %3$@ planlagt denne måned." Comment: "VoiceOver text for the bar and numbers in the plan pace sheet. Arguments: logged time, time planned until today, time planned this month, each spoken such as 11 hours, 30 minutes."
   - `overview.pace.marker.%@`: English "%@ planned until today", Danish "%@ planlagt indtil i dag". Comment: "Label under the marker on the plan pace bar. The argument is a duration such as 15 hours."
   - `overview.pace.plannedMonth`: English "Planned this month", Danish "Planlagt denne måned". Comment: "Label under the month's total planned time in the plan pace sheet."

**Verify**:
- The JSON check exits 0.
- `python3 -I -c "import json; d=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings']; print([k in d for k in ['overview.pace.a11y.numbers.%@.%@.%@','overview.pace.marker.%@','overview.pace.plannedMonth','overview.pace.title','overview.pace.planned','overview.pace.footer']])"` prints `[True, True, True, False, False, False]`.
- `Scripts/verify.sh` exits 0. After it, `git diff -- Hugo/Resources/Localizable.xcstrings` shows only the three removed and three added keys (a build must not add or mark stale anything else).
- `git status --short` lists only the in-scope files (plus files the owner changed, which you must not stage). `git diff --check` exits 0.

Commit 2.

## Test plan

- 4 new `PlanPaceTests` cover the month's plan, both fractions, the cap at 1 and the fallback when `plannedSeconds` is unknown.
- `PlanPaceSentenceTests` and `MonthlyProgressStatusTests` keep compiling and passing without edits.
- The sheet only displays these values. The owner checks it on a device.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -n "var plannedSeconds\|var loggedFraction\|var expectedFraction" Hugo/Features/Planner/Domain/PlanPace.swift` prints three lines
- [ ] `grep -n "NavigationStack\|footer" Hugo/Features/Overview/Screens/PlanPaceSheet.swift` prints nothing
- [ ] `grep -n "presentationDragIndicator" Hugo/Features/Overview/Screens/OverviewView.swift` prints one line
- [ ] `git diff HEAD~2 --stat` lists only the in-scope files
- [ ] `plans/README.md` row for 113 updated

## STOP conditions

- The drift check shows changes and the excerpts no longer match.
- Adding `plannedSeconds` breaks a `PlanPace(expectedSeconds:loggedSeconds:)` call that you may not edit.
- `MarkedProgressBar` would need a change to show the marker label.
- A build adds, removes or marks stale any catalog key other than the six this plan changes.
- The change seems to need a file outside the in-scope list.

## Maintenance notes

- **Owner device check**, in English and Danish: plan some time on earlier days of this month and on later days, and log less than planned so far. Tap the status line under the Overview circle.
  - The sheet opens at half height with a drag indicator. The status heading sits at the top, unchanged in look. No title bar, no Done button, no footer.
  - The bar's fill stops before the marker. The marker label reads "15 hours planned until today" with the real amount. Below the bar: the logged time on the left, the month's planned time on the right.
  - Log more than planned so far: the fill passes the marker. Log more than the whole month's plan: the bar is full.
  - With VoiceOver: the heading is announced as a heading, then one sentence with the three amounts.
- New small sheets on the Overview should follow this layout: heading at the top, medium detent, visible drag indicator, no navigation bar.
- If the Planner header ever needs the same "where you should be today" marker, `PlanPace.expectedFraction` is ready for it.
