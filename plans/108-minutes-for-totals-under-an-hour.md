# Plan 108: Show minutes, not "0", when a month's total is under an hour

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 3055ae6..HEAD -- Hugo/Features/Overview/Views/MonthlyProgressCard.swift Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift Hugo/Domain Hugo/Resources/Localizable.xcstrings HugoTests/Domain`
> `Localizable.xcstrings` changes often; a change there is fine as long as the
> keys listed in Step 2 don't exist yet. For the two Swift views, any change
> means: compare the excerpts below with the live file. A mismatch is a STOP
> condition.

## Status

- **Priority**: P2
- **Effort**: S + owner (look at it on a device, in English and Danish, with VoiceOver)
- **Risk**: LOW. Two display spots and one small value type. No data, no schema.
- **Depends on**: none. Run it **before plan 109** (SLN-188), which edits the same lines of `MonthlyProgressCard.swift`.
- **Category**: direction
- **Planned at**: commit `3055ae6`, 2026-11-13
- **Issue**: [SLN-161](https://linear.app/sebastianln/issue/SLN-161)

## Why this matters

When a month has some time but less than an hour, two places show **0**: the big number in the Overview circle and the number on each month card on the Year page. A user who just logged 45 minutes sees "0" and may think the entry was lost. Many of Hugo's users are older and take the screen literally.

After this plan, those two places show **45 min** for a total between one minute and one hour. From one hour up they show whole hours as today. Everywhere else Hugo already writes durations with `ServiceDurationFormatter.hoursString`, which shows "45 min" (plan 080), so after this plan every screen agrees.

## Current state

### The rule Hugo already uses for text

`Hugo/Domain/ServiceDurationFormatter.swift:39-67`, `hoursString(from:locale:)`: "23 hours", "23 hours, 15 min" or "45 min" (Danish "23 timer 15 min"). Seconds are dropped, zero minutes are left out, zero is "0 hours", negative values count as zero. It uses the catalog key `duration.minutesShort` (`"%lld min"` in English and Danish).

`accessibilityString(from:locale:)` (same file, lines 25-37) formats hours and minutes with `Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes], width: .wide)`, for example "45 minutes".

Screens that already use `hoursString` and need no change: the Year page header (`TheocraticYearTotalsView`), the Year detail screen, the Planner header and cards, the plan pace sheet and the month totals (`MonthlyReportTotalsView`). Do not touch them.

### Display 1: the Overview circle

`Hugo/Features/Overview/Views/MonthlyProgressCard.swift`. `value` is the month's logged time **in hours** as a `Double` (`OverviewView` passes `metrics.progress`, which is `entries' seconds / 3600`). Lines 23-28:

```swift
                        Text(String("\(Int(value))"))
                            .font(.system(size: heroSize, weight: .bold, design: .serif))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                            .motion(Motion.value, value: value)
```

Lines 70-82, the VoiceOver value:

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

`fill.basis` is `MonthlyCircleFill.Basis` (`Hugo/Features/Overview/Domain/MonthlyCircleFill.swift:5-11`): `.monthlyGoal(hours: Double)`, `.plan(plannedSeconds: TimeInterval)`, `.presence`. The current English values are "%1$lld of %2$lld hours this month", "%1$lld of %2$lld planned hours this month" and "%1$(value)lld hours this month". Danish: "%1$lld af %2$lld timer denne måned", "%1$lld af %2$lld planlagte timer denne måned", "%(value)lld timer denne måned".

### Display 2: the month card on the Year page

`Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift:81-101`:

```swift
    private var duration: some View {
        HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.compact) {
            Text(displayedHours, format: .number)
                .font(.system(.title, design: .serif, weight: .bold))
                .foregroundStyle(summary == nil ? .tertiary : .primary)
            Text(hourLabel)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(summary == nil ? .tertiary : .secondary)
        }
    }

    private var displayedHours: Int {
        ServiceDurationFormatter.wholeHours(from: month.contribution.total)
    }

    private var hourLabel: LocalizedStringKey {
        displayedHours == 1
            ? "service_year.month.hour"
            : "service_year.month.hours"
    }
```

`month.contribution.total` is reported hours for a submitted month (always whole hours) and logged time otherwise, so only months that aren't submitted can show minutes. The keys `service_year.month.hour` / `.hours` are "hour"/"hours" and "time"/"timer". There is no accessibility modifier on this row today, so VoiceOver reads the number and the label as they are.

### Things that look related but are not in scope

- `ReportingLineCard.swift:171` uses `wholeHours` on purpose: the submit screen shows whole hours plus a separate remainder.
- At one hour or more, both displays still drop the minutes ("1" for 1 hour 30 minutes). SLN-161 asks only about totals under one hour, and a big "1 h 30" would need a design decision. Leave it.

### Conventions

- `Hugo/Domain` holds value types shared by several features (AGENTS.md section 7). The new type is used by Overview and ServiceYear, so it belongs there. Mark it `nonisolated` like `ServiceDurationFormatter`.
- Strings live in `Hugo/Resources/Localizable.xcstrings` with English and Danish values. Keys are written as they appear in code with `%lld` for `Int` and `%@` for `String` interpolations. Look at the entry for `a11y.monthly_progress_card.value.%lld.%lld` (around line 44) for the exact JSON shape:

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

  Keys are sorted alphabetically in the file. Insert new entries in sorted position, keeping the file valid JSON.
- Tests: Swift Testing. The pattern is `HugoTests/Domain/ServiceDurationFormatterTests.swift` (struct `DurationFormattingTests`, `@MainActor`, one-line `@Test` functions, `Locale(identifier: "en_US")`).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Catalog is valid JSON | `python3 -c "import json; json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | no output, exit 0 |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Full gate (layout check, lint, all tests serially, analyze) | `Scripts/verify.sh` | exit 0 |
| Whitespace | `git diff --check` | exit 0 |

## Scope

**In scope** (the only files you may change):

- `Hugo/Domain/HeadlineDuration.swift` (create)
- `HugoTests/Domain/HeadlineDurationTests.swift` (create)
- `Hugo/Features/Overview/Views/MonthlyProgressCard.swift`
- `Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift`
- `Hugo/Resources/Localizable.xcstrings` (add four keys, change nothing else)

**Out of scope**:

- `ServiceDurationFormatter.swift`. Reuse it; don't change it.
- `OverviewMetrics`, `OverviewView`, `MonthlyCircleFill`. Keep `value` in hours.
- The `.minimumScaleFactor(0.5)` on the hero number and any font-size or Dynamic Type change. Plan 109 (SLN-188) owns those. Move the modifier with the `Text` as it is.
- Every screen listed above as "already uses `hoursString`".
- `Hugo.xcodeproj/project.pbxproj`. New files in `Hugo/` and `HugoTests/` are picked up by the project's synchronized folders. If the build doesn't see them, see STOP conditions.
- `plans/README.md` beyond this plan's row, `.claude/` and the owner's `Changelog/` changes. Never stage them.

## Git workflow

- Work on `main`. No branch, no worktree, no push. Stage files by path.
- One commit after `Scripts/verify.sh` exits 0, Conventional Commits style as in `git log` (for example `b7124c2 feat: show the selected category in its color in Add Entry`). Use: `feat: show minutes when a month's total is under an hour`.

## Steps

### Step 1: Add `HeadlineDuration` and its tests

Create `Hugo/Domain/HeadlineDuration.swift`:

```swift
import Foundation

/// A total shown as one large number with a unit: whole hours, or whole
/// minutes when the total is more than zero but under one hour, so 45 minutes
/// shows as "45 min" and not "0". Seconds are dropped and negative values
/// count as zero, as in `ServiceDurationFormatter.hoursString(from:locale:)`.
nonisolated enum HeadlineDuration: Equatable, Sendable {
    case hours(Int)
    case minutes(Int)

    init(seconds: TimeInterval) {
        let wholeMinutes = Int(max(seconds, 0) / 60)
        self = (1..<60).contains(wholeMinutes) ? .minutes(wholeMinutes) : .hours(wholeMinutes / 60)
    }

    /// The number to show.
    var value: Int {
        switch self {
        case .hours(let hours): hours
        case .minutes(let minutes): minutes
        }
    }

    /// The total as VoiceOver should read it, such as "45 minutes" or
    /// "12 hours" (Danish "45 minutter", "12 timer").
    func spokenText(locale: Locale = .current) -> String {
        switch self {
        case .hours(let hours):
            ServiceDurationFormatter.hoursString(from: TimeInterval(hours) * 3_600, locale: locale)
        case .minutes(let minutes):
            ServiceDurationFormatter.accessibilityString(from: TimeInterval(minutes) * 60, locale: locale)
        }
    }
}
```

Create `HugoTests/Domain/HeadlineDurationTests.swift`:

```swift
import Foundation
import Testing

@testable import Hugo

@MainActor
struct HeadlineDurationTests {
    @Test func zeroIsZeroHours() { #expect(HeadlineDuration(seconds: 0) == .hours(0)) }
    @Test func underAMinuteIsZeroHours() { #expect(HeadlineDuration(seconds: 59) == .hours(0)) }
    @Test func oneMinuteIsMinutes() { #expect(HeadlineDuration(seconds: 60) == .minutes(1)) }
    @Test func fortyFiveMinutesIsMinutes() { #expect(HeadlineDuration(seconds: 45 * 60) == .minutes(45)) }
    @Test func justUnderAnHourIsMinutes() { #expect(HeadlineDuration(seconds: 3_599) == .minutes(59)) }
    @Test func oneHourIsHours() { #expect(HeadlineDuration(seconds: 3_600) == .hours(1)) }
    @Test func minutesAboveAnHourAreDropped() { #expect(HeadlineDuration(seconds: 5_400) == .hours(1)) }
    @Test func negativeIsZeroHours() { #expect(HeadlineDuration(seconds: -600) == .hours(0)) }

    @Test func valueIsTheShownNumber() {
        #expect(HeadlineDuration.minutes(45).value == 45)
        #expect(HeadlineDuration.hours(12).value == 12)
    }

    @Test func spokenTextNamesTheUnit() {
        let us = Locale(identifier: "en_US")
        #expect(HeadlineDuration.minutes(45).spokenText(locale: us) == "45 minutes")
        #expect(HeadlineDuration.hours(1).spokenText(locale: us) == "1 hour")
        #expect(HeadlineDuration.hours(12).spokenText(locale: us) == "12 hours")
    }
}
```

**Verify**: `Scripts/verify.sh` exits 0, and its test output includes `HeadlineDurationTests` with all tests passing. If only `spokenTextNamesTheUnit` fails on the minutes line because the system formats "45 minutes" slightly differently (for example "45 min"), change that one expectation to `#expect(HeadlineDuration.minutes(45).spokenText(locale: us).contains("45"))` and note it in your report. Any other failure is a STOP condition.

### Step 2: Add the strings

Add four entries to `Hugo/Resources/Localizable.xcstrings`, in sorted key order, each with `"state" : "translated"` for `da` and `en`:

| Key | Comment | English | Danish |
|---|---|---|---|
| `duration.minutesUnit` | `Unit shown after a large number of minutes, such as the min in 45 min on the Overview circle and the Year page. No period.` | `min` | `min` |
| `a11y.monthly_progress_card.value.minutes.%@` | `Accessibility value of the monthly progress card when the month has less than an hour and no goal or plan. The argument is the spoken minutes, such as 45 minutes.` | `%@ this month` | `%@ denne måned` |
| `a11y.monthly_progress_card.value.minutes.%@.%lld` | `Accessibility value of the monthly progress card when the month has less than an hour and a goal exists. First argument: the spoken minutes, such as 45 minutes. Second: the monthly goal in hours.` | `%1$@ of %2$lld hours this month` | `%1$@ af %2$lld timer denne måned` |
| `a11y.monthly_progress_card.value.minutes.planned.%@.%lld` | `Accessibility value of the monthly progress card when the month has less than an hour, no monthly goal and some plans. First argument: the spoken minutes, such as 45 minutes. Second: hours planned this month.` | `%1$@ of %2$lld planned hours this month` | `%1$@ af %2$lld planlagte timer denne måned` |

**Verify**: the JSON check from "Commands you will need" exits 0, and `grep -c '"duration.minutesUnit"\|"a11y.monthly_progress_card.value.minutes' Hugo/Resources/Localizable.xcstrings` prints `4`.

### Step 3: Use it in the Overview circle

In `Hugo/Features/Overview/Views/MonthlyProgressCard.swift`:

1. Add a private property. `value` is in hours. Multiply back to seconds and round, so floating-point error can't turn 25 minutes into 24:

```swift
    /// The month's total as the hero shows it: minutes under an hour, whole hours above.
    private var headline: HeadlineDuration {
        HeadlineDuration(seconds: (value * 3_600).rounded())
    }
```

2. Replace the hero `Text(String("\(Int(value))"))` and its five modifiers (lines 23-28) with `heroAmount`, and add this property:

```swift
    private var heroAmount: some View {
        HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.tight) {
            Text(String("\(headline.value)"))
                .font(.system(size: heroSize, weight: .bold, design: .serif))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
                .motion(Motion.value, value: value)
            if case .minutes = headline {
                Text("duration.minutesUnit")
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
```

   Keep it inside the same `VStack` so the existing `.accessibilityElement(children: .combine)`, `.accessibilityLabel` and `.accessibilityValue` still apply.

3. In `accessibilityValueText`, handle the minutes case first and leave the existing `switch` unchanged for hours:

```swift
    private var accessibilityValueText: String {
        if case .minutes = headline {
            let minutes = headline.spokenText()
            return switch fill.basis {
            case .monthlyGoal(let hours):
                String(localized: "a11y.monthly_progress_card.value.minutes.\(minutes).\(Int(hours))")
            case .plan(let plannedSeconds):
                String(
                    localized:
                        "a11y.monthly_progress_card.value.minutes.planned.\(minutes).\(Int((plannedSeconds / 3_600).rounded(.up)))"
                )
            case .presence:
                String(localized: "a11y.monthly_progress_card.value.minutes.\(minutes)")
            }
        }
        return switch fill.basis {
        // ... the existing three cases, unchanged ...
        }
    }
```

   For whole hours `Int(value)` and `headline.value` are the same number, so the existing cases stay as they are.

**Verify**: `xcrun swift-format lint --strict --recursive Hugo` exits 0. `grep -n "Int(value))\"))" Hugo/Features/Overview/Views/MonthlyProgressCard.swift` prints nothing.

### Step 4: Use it on the Year page month card

In `Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift`, replace `displayedHours` and `hourLabel` (lines 92-101) with:

```swift
    private var headline: HeadlineDuration {
        HeadlineDuration(seconds: month.contribution.total)
    }

    private var unitLabel: LocalizedStringKey {
        switch headline {
        case .minutes: "duration.minutesUnit"
        case .hours(1): "service_year.month.hour"
        case .hours: "service_year.month.hours"
        }
    }
```

In `duration`, use `Text(headline.value, format: .number)` and `Text(unitLabel)`, keep the fonts and colors, and add two modifiers to the `HStack` so VoiceOver reads "45 minutes" instead of "45, min":

```swift
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: headline.spokenText()))
```

**Verify**: `xcrun swift-format lint --strict --recursive Hugo` exits 0. `grep -n "displayedHours\|hourLabel" Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift` prints nothing.

### Step 5: Run the gate and commit

**Verify**: `Scripts/verify.sh` exits 0, `git diff --check` exits 0, and `git status --short` lists only the in-scope files (plus the owner's untouched `Changelog/` changes, which you must not stage). Commit with the message from "Git workflow".

## Test plan

- `HugoTests/Domain/HeadlineDurationTests.swift` (new, 10 tests): 0, 59 s, 60 s, 45 min, 3 599 s, 1 h, 1 h 30 min, a negative value, `value`, and `spokenText` in English.
- The two views have no logic beyond `HeadlineDuration`, so they get no unit test. The owner checks them on a device (see Maintenance notes).
- The whole existing suite must stay green.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, including the 10 `HeadlineDurationTests`
- [ ] `grep -rn "HeadlineDuration(seconds:" Hugo --include='*.swift'` shows `MonthlyProgressCard.swift` and `ServiceYearMonthRow.swift`
- [ ] `grep -c '"duration.minutesUnit"\|"a11y.monthly_progress_card.value.minutes' Hugo/Resources/Localizable.xcstrings` prints `4`
- [ ] `git show --stat HEAD` lists only in-scope files
- [ ] `plans/README.md` row for 108 updated

## STOP conditions

- The drift check shows changes to `MonthlyProgressCard.swift` or `ServiceYearMonthRow.swift` and an excerpt no longer matches (for example, plan 109 already ran and changed the hero).
- One of the four keys already exists in `Localizable.xcstrings` with a different value.
- The build doesn't find `HeadlineDuration` (the new file isn't part of the target). Report it. Don't edit `project.pbxproj`.
- A `HeadlineDurationTests` test other than the "45 minutes" spelling fails.
- The change seems to need a file outside the in-scope list.

## Maintenance notes

- Owner device check, in English and Danish:
  1. On the Overview, with 0 minutes, 45 minutes and 2 hours logged this month, the circle shows "0", "45 min" and "2". The "min" sits on the number's baseline and is smaller and gray.
  2. On the Year page, an unsubmitted month with 45 minutes shows "45 min". A month with 1 hour shows "1 hour" ("1 time").
  3. With VoiceOver: the circle reads "45 minutes of 50 hours this month" (with a goal) or "45 minutes this month" (no goal, no plan). The month card reads "45 minutes".
- **Plan 109 (SLN-188)** runs next and changes Dynamic Type on the hero, including the `.minimumScaleFactor(0.5)` that this plan moves into `heroAmount`. Its executor should look for the modifier there, not at the old line numbers.
- At one hour or more the hero and the month card still drop minutes. If the owner wants "1 h 30" later, extend `HeadlineDuration` with a case for hours and minutes; both views already switch on it.
- If a third place needs a large total with a unit, use `HeadlineDuration` and `duration.minutesUnit` instead of `wholeHours`.
