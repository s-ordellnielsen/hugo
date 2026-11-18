# Plan 131: Replace the Year tab's centered gauge with a goal bar that marks today's target

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**: this plan is written against the code **after
> plan 127**, which removed the `pacing:` parameter from
> `YearlyGoalProgress.make`. Confirm 127 landed:
> - `grep -n "pacing" Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift` → no output
> - `grep -n "static func currentMonthFraction" Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift` → one match
> - `grep -rn "YearlyGoalPacing" Hugo HugoTests` → no output
>
> If any check fails, STOP: plan 127 must run first.
> Then run `git diff --stat c918888..HEAD -- Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift Hugo/DesignSystem HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift`.
> Expected: only plan 127's changes (the preview call in `TheocraticYearTotalsView.swift`
> and the test edits). Anything else: compare with "Current state" and STOP on a mismatch.
> Also run `git status --short -- Hugo/Resources/Localizable.xcstrings CONTEXT.md` → no output, or STOP.

## Status

- **Priority**: P2
- **Effort**: M + owner (device check of the bar in English and Danish, VoiceOver, largest text size)
- **Risk**: LOW. Changes one card on the Year tab and adds read-only values to `YearlyGoalProgress`. No data changes.
- **Depends on**: 127 (one expected-time rule; `make` has no `pacing` parameter). Can run any time after 127; it does not need 128, 129 or 130.
- **Category**: direction
- **Planned at**: commit `c918888`, 2026-11-18
- **Issue**: pending (to be created in Linear)

## Why this matters

The Year tab's totals card shows the hours counted toward the yearly goal, then a pace sentence ("3 hours behind") and a gauge whose knob moves left or right of the middle, up to one monthly goal either way. The gauge has no scale and no labels. A tester didn't understand it.

The owner decided (2026-11-18) to replace it with the app's existing progress bar (`MarkedProgressBar`, used by the Planner and the plan pace sheet):

- The bar runs from 0 to the goal at the **end of the current month**: the monthly goal times the months of the theocratic year so far, the current month included. For a regular pioneer (50 hours a month) in November that is 3 x 50 = 150 hours.
- The fill is the counted time (`creditedSeconds`).
- A marker with the label "Target today" ("Mål i dag") sits at the expected time.
- Under the bar: the pace sentence, then one caption, "Goal by the end of November: 150 hours" ("Mål ved udgangen af november: 150 timer").

One caption instead of "0" and "150" labels at the ends: a bare "0" says nothing to a 70-year-old user, and one sentence names both the number and what it means. It is one `Text`, wraps at any text size and reads well in VoiceOver.

A past year's bar ends at the whole yearly goal, with no marker (there is no "today" in it). A year that has not started has no expected time and shows no bar, as today.

## Current state

### `YearlyGoalProgress` (`Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift`, after plan 127)

```swift
nonisolated struct YearlyGoalProgress: Equatable, Sendable {
    let creditedSeconds: TimeInterval
    /// The year total: reported hours of submitted months plus logged time of the rest.
    let yearTotalSeconds: TimeInterval
    /// Seconds the user should have by now: ... Nil when the year has not started.
    let expectedSeconds: TimeInterval?
    let yearlyGoalSeconds: TimeInterval
    let monthlyGoalSeconds: TimeInterval
    let months: [Month]
    ...
    /// Credited minus expected. Nil when there is no expectation.
    var differenceSeconds: TimeInterval? { expectedSeconds.map { creditedSeconds - $0 } }

    /// The knob position from -1 (a monthly goal behind) to 1 (a monthly goal ahead).
    var barFraction: Double? {
        guard let differenceSeconds, monthlyGoalSeconds > 0 else { return nil }
        return min(1, max(-1, differenceSeconds / monthlyGoalSeconds))
    }

    var isOnTrack: Bool { abs(differenceSeconds ?? 0) < Self.differenceThreshold }

    /// Nil when the status has no yearly goal.
    static func make(
        report: TheocraticYearReport,
        status: PublisherStatus,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> YearlyGoalProgress? {
        guard let rule = status.yearlyGoalRule else { return nil }
        let months = report.months.map { month in ... }

        let current = now.yearMonth(using: calendar)
        let expectedSeconds: TimeInterval?
        if let first = report.months.first, first.id > current {
            expectedSeconds = nil
        } else {
            expectedSeconds = report.months.reduce(0) { total, month in
                if month.id < current {
                    return total + rule.monthlyGoalSeconds
                }
                guard month.id == current else { return total }
                return total + rule.monthlyGoalSeconds * currentMonthFraction(now: now, calendar: calendar)
            }
        }

        return YearlyGoalProgress(
            creditedSeconds: months.reduce(0) { $0 + $1.creditedSeconds },
            yearTotalSeconds: report.totalSeconds,
            expectedSeconds: expectedSeconds,
            yearlyGoalSeconds: TimeInterval(status.yearlyGoal) * 3_600,
            monthlyGoalSeconds: rule.monthlyGoalSeconds,
            months: months)
    }
```

`report.months` holds the 12 `ServiceMonth`s of the theocratic year, September first (`TheocraticYear.months`: September to December of `startYear`, then January to August). The memberwise initializer is called only in `make` (`grep -rn "YearlyGoalProgress(" Hugo HugoTests` → one match).

`barFraction` is used only by `TheocraticYearTotalsView` and `YearlyGoalProgressTests` (`grep -rn barFraction Hugo HugoTests`).

### The card (`Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift:47-66`)

```swift
            if let fraction = progress?.barFraction, let paceSentence = progress?.paceSentence {
                Text(paceSentence)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.top, HugoLayout.Spacing.compact)

                CenteredProgressBar(
                    fraction: fraction,
                    accessibilityLabel: "year.header.counted.label",
                    accessibilityValue: paceSentence
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, HugoLayout.Spacing.card)
        .padding(.vertical, HugoLayout.Spacing.roomy)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint("year.header.a11y.hint")
```

The whole card is one accessibility element (`children: .ignore`) with a custom label, inside a `NavigationLink` to the year details. Its label today (lines 89-98):

```swift
    private var accessibilityLabelText: String {
        let spoken = ServiceDurationFormatter.hoursString(from: primarySeconds)
        guard let progress else { return spoken }
        return String(
            localized: "year.header.a11y.label",
            defaultValue: "Counted toward yearly goal: \(spoken). \(progress.paceSentence ?? "")",
            comment:
                "Spoken summary of the year header. The first argument is the counted time, the second is whether the user is ahead, behind or on pace."
        )
    }
```

The card's previews: `#Preview("Yearly goal")` (calls `YearlyGoalProgress.make(report: report, status: $0)` after plan 127) and `#Preview("No yearly goal")`.

### `CenteredProgressBar` (`Hugo/DesignSystem/Components/CenteredProgressBar.swift`)

Used only by `TheocraticYearTotalsView` (`grep -rn CenteredProgressBar Hugo HugoTests` → the component file and the card). Its knob size `HugoLayout.Size.goalKnobDiameter` (`Hugo/DesignSystem/Theme/Theme.swift:39`) is used only by `CenteredProgressBar`. `goalTrackHeight` (line 38) is also used by `MarkedProgressBar` and stays.

### `MarkedProgressBar` (`Hugo/DesignSystem/Components/MarkedProgressBar.swift`)

```swift
/// A normalized progress track with an optional faded extension and marker.
/// Callers must expose equivalent semantic information because this view hides
/// its drawing and marker label from VoiceOver.
struct MarkedProgressBar<MarkerLabel: View>: View {
    init(
        filled: Double,
        extended: Double? = nil,
        marker: Double? = nil,
        @ViewBuilder markerLabel: () -> MarkerLabel
    )
```

It clamps every value to 0...1 (so counted time above the scale fills the bar), draws the marker label above the bar and keeps it inside the bar's width, hides itself from VoiceOver, and turns off its animation under Reduce Motion. With `marker: nil` it shows no marker and no label. It supports right-to-left and dark mode (see its previews).

Exemplar: `Hugo/Features/Overview/Screens/PlanPaceSheet.swift:31-47` uses it the same way:

```swift
                MarkedProgressBar(filled: pace.loggedFraction, marker: pace.expectedFraction) {
                    Text("overview.pace.marker")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
```

and `Hugo/Features/Planner/Domain/PlanPace.swift` computes its fractions in the domain type:

```swift
    /// Logged time as a fraction of the month's plan, capped at 1.
    var loggedFraction: Double { min(loggedSeconds / barScale, 1) }
```

### Tests (`HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift`, after plan 127)

Uses a fixed GMT Gregorian `calendar`, `status = PublisherStatus.status(for: "regular-pioneer")!` (600 hours, 50 a month), `septemberAndOctober()` (50 hours of main time in each), `makeProgress(entries:submissions:now:)` and `date(_:_:_:hour:)`. Tests that mention `barFraction`:

- `onPaceAtTheEndOfOctoberWhenProRated`: `#expect(progress.barFraction == 0)`
- `proRatedExpectationGrowsWithTheDayOfTheMonth`: `let fraction = try #require(progress.barFraction)` and `#expect(abs(fraction - -0.1) < 1e-9)`
- `barFractionClampsAtBothEnds` (whole test)
- `aFutureYearHasNoExpectationAndNoBar`: `#expect(progress.barFraction == nil)`

### Vocabulary

`CONTEXT.md` defines **Expected time** (plan 127 rewrote it). After plan 129 the time that counts toward the goal is called **Counted time** (code: `creditedSeconds`); before 129 it is **Credited time**. The UI calls it "Counted toward goal". No new term is needed for the scale: it is the monthly goal times the months so far, a display detail, not a concept users or code talk about elsewhere.

### Help

Plan 130 lists "Your target this month" in the Year tab's Help menu, which explains the expected time with a worked example. This plan needs no help changes.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full gate | `Scripts/verify.sh` | exit 0 |
| Build | `xcodebuild build -project Hugo.xcodeproj -scheme Debug -destination 'generic/platform=iOS Simulator' -quiet 2>&1 \| grep -c "error:"` | `0` |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Debug -configuration Debug -destination 'platform=iOS Simulator,name=Hugo Verify iOS 26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/YearlyGoalProgressTests` | `** TEST SUCCEEDED **` |
| Catalog JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0 |

Do not run the focused tests while `Scripts/verify.sh` runs; both use the same simulator.

## Scope

**In scope:**
- `Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift`
- `Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift`
- `Hugo/DesignSystem/Components/CenteredProgressBar.swift` (delete)
- `Hugo/DesignSystem/Theme/Theme.swift` (delete `goalKnobDiameter` only)
- `HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift`
- `Hugo/Resources/Localizable.xcstrings` (add 3 keys)
- `CONTEXT.md` (one sentence)

**Out of scope:**
- `MarkedProgressBar` and `MarkedProgressBarGeometry`. Use them as they are.
- `ServiceYearDetailView` (its "Expected so far" row stays).
- The pace sentence wording (`paceSentence`) and the big number above the bar.
- Help menus and articles (plan 130).

## Git workflow

- Work on `main` directly. No branch, no worktree.
- One commit after `Scripts/verify.sh` exits 0: `feat: show the yearly goal as a bar with a target-today marker on the Year tab`.
- Never stage `.claude/`, `plans/` or `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`. Do not push.

## Steps

### Step 1: Add the scale and the fractions to `YearlyGoalProgress`

1. Add three stored properties after `months` (they join the memberwise initializer):

```swift
    /// The end of the goal bar: the monthly goal times the months of the
    /// theocratic year up to and including the current month. The whole
    /// yearly goal once the year is over. Nil before the year starts.
    let scaleEndSeconds: TimeInterval?
    /// The last month the scale covers: the current month, or August once
    /// the year is over. Nil before the year starts.
    let scaleEndMonth: YearMonth?
    /// True once the year's last month is over.
    let isYearOver: Bool
```

2. Keep `barFraction` for now (Step 4 deletes it, once nothing uses it). Add after it:

```swift
    /// Counted time as a share of the scale, from 0 to 1. Time above the
    /// scale fills the bar. Nil before the year starts.
    var fillFraction: Double? {
        guard let scaleEndSeconds, scaleEndSeconds > 0 else { return nil }
        return min(max(creditedSeconds / scaleEndSeconds, 0), 1)
    }

    /// Where "Target today" sits on the scale, from 0 to 1. Nil before the
    /// year starts and once it is over, because a finished year has no today.
    var markerFraction: Double? {
        guard !isYearOver, let expectedSeconds, let scaleEndSeconds, scaleEndSeconds > 0 else { return nil }
        return min(max(expectedSeconds / scaleEndSeconds, 0), 1)
    }
```

3. In `make`, after the `expectedSeconds` block, compute:

```swift
        let monthsSoFar = report.months.filter { $0.id <= current }
        let scaleEndMonth = monthsSoFar.last?.id
        let scaleEndSeconds = scaleEndMonth.map { _ in rule.monthlyGoalSeconds * Double(monthsSoFar.count) }
        let isYearOver = report.months.last.map { $0.id < current } ?? false
```

   and pass `scaleEndSeconds: scaleEndSeconds, scaleEndMonth: scaleEndMonth, isYearOver: isYearOver` as the last three arguments of the `YearlyGoalProgress(...)` call.

`YearMonth` is `Hashable` and used in the `Sendable` `Month` already, so `YearlyGoalProgress` stays `Equatable` and `Sendable` with synthesized conformances.

**Verify**: build → `0`.

### Step 2: Tests

In `HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift`:

1. `onPaceAtTheEndOfOctoberWhenProRated`: delete `#expect(progress.barFraction == 0)`.
2. `proRatedExpectationGrowsWithTheDayOfTheMonth`: delete the two `barFraction` lines and change `func ... () throws {` to `func ... () {` if nothing else in it throws.
3. Delete `barFractionClampsAtBothEnds`.
4. `aFutureYearHasNoExpectationAndNoBar`: replace `#expect(progress.barFraction == nil)` with:

```swift
        #expect(progress.scaleEndSeconds == nil)
        #expect(progress.scaleEndMonth == nil)
        #expect(progress.fillFraction == nil)
        #expect(progress.markerFraction == nil)
```

5. Add these tests:

```swift
    @Test
    func firstMonthScaleIsOneMonthlyGoal() throws {
        let progress = makeProgress(entries: [], now: date(2026, 9, 10, hour: 12))
        #expect(progress.scaleEndSeconds == TimeInterval(50 * 3_600))
        #expect(progress.scaleEndMonth == YearMonth(year: 2026, month: 9))
        let marker = try #require(progress.markerFraction)
        #expect(abs(marker - 10.0 / 30.0) < 1e-9)
    }

    @Test
    func midNovemberScaleEndsAtThreeMonthlyGoals() throws {
        let progress = makeProgress(entries: septemberAndOctober(), now: date(2026, 11, 15, hour: 12))
        #expect(progress.scaleEndSeconds == TimeInterval(150 * 3_600))
        #expect(progress.scaleEndMonth == YearMonth(year: 2026, month: 11))
        let fill = try #require(progress.fillFraction)
        #expect(abs(fill - 100.0 / 150.0) < 1e-9)
        let marker = try #require(progress.markerFraction)
        #expect(abs(marker - 125.0 / 150.0) < 1e-9)
    }

    @Test
    func onTheLastDayTheMarkerReachesTheEnd() {
        let progress = makeProgress(entries: septemberAndOctober(), now: date(2026, 11, 30, hour: 12))
        #expect(progress.markerFraction == 1)
    }

    @Test
    func aMonthWithoutCountedTimeLeavesTheBarEmpty() {
        let progress = makeProgress(entries: [], now: date(2026, 11, 15, hour: 12))
        #expect(progress.fillFraction == 0)
        #expect(progress.markerFraction != nil)
    }

    @Test
    func countedTimeAboveTheScaleFillsTheBar() {
        let progress = makeProgress(
            entries: [Entry(date: date(2026, 9, 1), duration: 300 * 3_600, tracker: main)],
            now: date(2026, 10, 31, hour: 12))
        #expect(progress.scaleEndSeconds == TimeInterval(100 * 3_600))
        #expect(progress.fillFraction == 1)
    }

    @Test
    func aPastYearScaleIsTheYearlyGoalWithoutAMarker() throws {
        let progress = makeProgress(entries: septemberAndOctober(), now: date(2028, 1, 15))
        #expect(progress.isYearOver)
        #expect(progress.scaleEndSeconds == TimeInterval(600 * 3_600))
        #expect(progress.scaleEndMonth == YearMonth(year: 2027, month: 8))
        #expect(progress.markerFraction == nil)
        let fill = try #require(progress.fillFraction)
        #expect(abs(fill - 100.0 / 600.0) < 1e-9)
    }
```

   `statusWithoutAYearlyGoalHasNoProgress` (an auxiliary pioneer has no yearly goal, so `make` returns nil and the card shows no bar) stays as it is and covers the "no yearly goal" case.

**Verify**: focused tests command → `** TEST SUCCEEDED **`, with the six new tests passing.

### Step 3: The card

In `TheocraticYearTotalsView.swift`:

1. Replace the block `if let fraction = progress?.barFraction, let paceSentence = progress?.paceSentence { ... CenteredProgressBar(...) }` with:

```swift
            if let progress, let fillFraction = progress.fillFraction,
                let scaleEndSeconds = progress.scaleEndSeconds, let scaleEndMonth = progress.scaleEndMonth
            {
                VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                    MarkedProgressBar(filled: fillFraction, marker: progress.markerFraction) {
                        Text("year.goalBar.marker")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let paceSentence = progress.paceSentence {
                        Text(paceSentence)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text(
                        "year.goalBar.scaleEnd.\(ServiceDurationFormatter.hoursString(from: scaleEndSeconds)).\(scaleEndMonth.monthName())"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, HugoLayout.Spacing.compact)
            }
```

   The card stays one accessibility element, so the bar's hidden drawing is covered by the label in item 2.

2. Replace `accessibilityLabelText` with:

```swift
    private var accessibilityLabelText: String {
        let spoken = ServiceDurationFormatter.hoursString(from: primarySeconds)
        guard let progress else { return spoken }
        if let scaleEndSeconds = progress.scaleEndSeconds, let scaleEndMonth = progress.scaleEndMonth {
            let goal = ServiceDurationFormatter.hoursString(from: scaleEndSeconds)
            let month = scaleEndMonth.monthName()
            return String(
                localized: "year.header.a11y.goalBar",
                defaultValue: "Counted toward yearly goal: \(spoken) of \(goal) by the end of \(month). \(progress.paceSentence ?? "")",
                comment:
                    "Spoken summary of the year header with its goal bar. Arguments: the counted time, the goal by the end of the month, the month's name, and whether the user is ahead, behind or on pace."
            )
        }
        return String(
            localized: "year.header.a11y.label",
            defaultValue: "Counted toward yearly goal: \(spoken). \(progress.paceSentence ?? "")",
            comment:
                "Spoken summary of the year header. The first argument is the counted time, the second is whether the user is ahead, behind or on pace."
        )
    }
```

   VoiceOver then reads, for example, "Counted toward yearly goal: 118 hours of 150 hours by the end of November. 7 hours behind", then the existing hint "Opens the year details".

3. Add two previews after the existing ones (use only existing keys or `verbatim` text, so the build adds no catalog keys):

```swift
#Preview("Yearly goal, dark, largest text") {
    let report = ReportPreviewFixtures.yearReport
    let progress = PublisherStatus.status(for: "regular-pioneer").flatMap {
        YearlyGoalProgress.make(report: report, status: $0)
    }
    TheocraticYearTotalsView(report: report, progress: progress)
        .padding()
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
        .modelContainer(.preview)
}

#Preview("Yearly goal, Danish") {
    let report = ReportPreviewFixtures.yearReport
    let progress = PublisherStatus.status(for: "regular-pioneer").flatMap {
        YearlyGoalProgress.make(report: report, status: $0)
    }
    TheocraticYearTotalsView(report: report, progress: progress)
        .padding()
        .environment(\.locale, Locale(identifier: "da_DK"))
        .modelContainer(.preview)
}
```

**Verify**: build → `0`.

### Step 4: Remove the old gauge

1. In `YearlyGoalProgress.swift`, delete `barFraction` and its doc comment.
2. Delete `Hugo/DesignSystem/Components/CenteredProgressBar.swift`.
3. In `Hugo/DesignSystem/Theme/Theme.swift`, delete the line `static let goalKnobDiameter: CGFloat = 36`.

**Verify**: `grep -rn "CenteredProgressBar\|goalKnobDiameter\|barFraction" Hugo HugoTests` → no output. Build → `0`.

No catalog key becomes unused: `year.header.counted.label` (the old gauge's accessibility label) is still the card's label text, and `year.header.a11y.label` is still used for a year without a scale.

### Step 5: Strings

Use the catalog helper from plan 129 Step 4 (`/tmp/xcstrings_edit.py` with `load`, `save`, `entry`, `insert_sorted`; save it again from plan 129 if it is missing, and confirm `x.save(x.load())` leaves `git diff` empty). Add these keys with `insert_sorted`, `en` and `da` both `"state" : "translated"`:

| Key | English | Danish | Comment |
|---|---|---|---|
| `year.goalBar.marker` | Target today | Mål i dag | Label of the marker on the Year tab's goal bar: the time expected by today. |
| `year.goalBar.scaleEnd.%@.%@` | Goal by the end of %2$@: %1$@ | Mål ved udgangen af %2$@: %1$@ | Caption under the Year tab's goal bar. The first argument is the goal at the end of the month, such as 150 hours; the second is the month's name, such as November. |
| `year.header.a11y.goalBar` | Counted toward yearly goal: %1$@ of %2$@ by the end of %3$@. %4$@ | Tæller med mod årsmålet: %1$@ af %2$@ ved udgangen af %3$@. %4$@ | Spoken summary of the year header with its goal bar. Arguments: the counted time, the goal by the end of the month, the month's name, and whether the user is ahead, behind or on pace. |

The comment of `year.header.a11y.goalBar` must match the Swift `comment:` in Step 3 exactly.

**Verify**:
- `python3 -I -c "import json;s=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'];print([s[k]['localizations']['da']['stringUnit']['value'] for k in ['year.goalBar.marker','year.goalBar.scaleEnd.%@.%@','year.header.a11y.goalBar']])"` → the three Danish values above.
- `git diff --numstat -- Hugo/Resources/Localizable.xcstrings` → about 54 added and 0 removed lines.

### Step 6: `CONTEXT.md`

At the end of the **Expected time** entry, add the sentence: `The Year tab's goal bar marks it as "Target today" / "Mål i dag", on a scale that ends at the monthly goal times the months so far.`

### Step 7: Full gate and commit

Run `Scripts/verify.sh`. After it, `git diff -- Hugo/Resources/Localizable.xcstrings` must show only the 3 added keys. Commit the in-scope files with the message from "Git workflow".

## Test plan

- New in `YearlyGoalProgressTests`: first month (scale 50 hours, marker at 10/30), mid-November (scale 150, fill 100/150, marker 125/150), last day (marker 1), no counted time (fill 0), counted time above the scale (fill 1), past year (scale 600, ends in August, no marker).
- Changed: the future-year test checks that scale, month, fill and marker are all nil.
- Kept: `statusWithoutAYearlyGoalHasNoProgress` (no progress, so no bar).
- Removed: `barFractionClampsAtBothEnds` and the `barFraction` assertions.
- `Scripts/verify.sh` → exit 0.

Owner checks on a device (record results in the plan's status row):
1. Regular pioneer, current year: the bar fills with the counted hours; "Target today" sits above the marker; under the bar the pace sentence and "Goal by the end of November: 150 hours" (in the current month). Danish: "Mål i dag" and "Mål ved udgangen af november: 150 timer".
2. Swipe to last year: the bar ends at the yearly goal, with no marker, and the caption names August.
3. Publisher status Publisher or Auxiliary Pioneer: no bar, as before.
4. VoiceOver on the card: "Counted toward yearly goal: … of … by the end of …", then the pace sentence and the hint.
5. Largest accessibility text size: the marker label, pace sentence and caption wrap; nothing is cut off.
6. Dark mode and Reduce Motion: the bar shows correctly; with Reduce Motion it does not animate.
7. Ask the tester who didn't understand the old gauge whether the new bar is clear.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -rn "CenteredProgressBar\|goalKnobDiameter\|barFraction" Hugo HugoTests` → no output
- [ ] `grep -n "MarkedProgressBar(filled: fillFraction" Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift` → 1 match
- [ ] `grep -c "func firstMonthScaleIsOneMonthlyGoal\|func midNovemberScaleEndsAtThreeMonthlyGoals\|func onTheLastDayTheMarkerReachesTheEnd\|func aMonthWithoutCountedTimeLeavesTheBarEmpty\|func countedTimeAboveTheScaleFillsTheBar\|func aPastYearScaleIsTheYearlyGoalWithoutAMarker" HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift` → `6`
- [ ] `git status --short` shows no modified files outside the in-scope list, except the owner's `Debug.xcscheme`

## STOP conditions

- Plan 127 has not landed (drift check), or `make` still has a `pacing` parameter.
- `CenteredProgressBar`, `barFraction` or `goalKnobDiameter` is used anywhere besides the places listed in "Current state". Keep it, and report where.
- `MarkedProgressBar`'s initializer differs from the excerpt.
- The build after Step 5 adds or changes catalog keys other than the three new ones (the Swift `defaultValue`/`comment` and the catalog disagree). Fix the mismatch once; if the diff still shows extra changes, STOP.

## Maintenance notes

- The scale uses `monthlyGoalSeconds` times the months so far. For a yearly goal that does not divide by 12, `monthlyGoal` is rounded down (`PublisherStatus.monthlyGoal` uses integer division), so a past year's scale can be a few hours below `yearlyGoalSeconds`. Today the only yearly goal is 600, which divides evenly. Expected time uses the same monthly goal, so the bar and the pace sentence always agree.
- If the owner wants the marker on a past year (at the end of the bar), drop the `!isYearOver` guard in `markerFraction`, but then change the marker label for past years: "Target today" is wrong there.
- `ServiceYearDetailView` still says "Expected so far" for the same number. Changing it to "Target today" would be wrong for past years; leave it unless the owner asks.
- A reviewer should check the card at the largest text size in Danish, and that VoiceOver reads the whole card as one element.
