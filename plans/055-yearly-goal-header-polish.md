# Plan 055: Polish the yearly goal header (bar, hours wording, fewer labels)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 672aa54..HEAD -- Hugo/DesignSystem/Components/CenteredProgressBar.swift Hugo/Features/ServiceYear Hugo/Features/Reports Hugo/Resources/Localizable.xcstrings`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding. On a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/054-yearly-goal-header.md (DONE)
- **Category**: direction
- **Planned at**: commit `672aa54`, 2026-11-03

## Why this matters

The owner reviewed the plan 054 header and wants four changes. (1) The bar has a
vertical tick in the center that they dislike, and the trail should start *on*
the center point, not touch it. (2) Durations read as `152:00`; reports hold whole
hours, so show `152 hours` and add minutes only when there are some. (3) The
caption row under the bar is unnecessary. (4) The footer under "By month" on the
year detail screen is unnecessary because users know the rule.

## Decisions (made with the owner, do not change)

- Duration style "xx hours": whole hours show as `152 hours` (singular `1 hour`,
  and `0 hours`). When minutes exist show both, for example `152 hours, 30 minutes`.
  Seconds are dropped (truncated to the minute), as the current `HH:mm` formatter does.
- Scope of the new style: the Year page (header, year detail, the category rows
  inside each month card) and the totals block on the monthly report detail screen
  (`MonthlyReportTotalsView`). Everything else keeps `HH:mm`: entry rows
  (`EntryRow`), `MonthlyReportEntryListView`, and the Overview breakdown
  (`CategoryProgressBreakdownView`). Do not touch those.

## Current state

- `Hugo/Features/Reports/Domain/ServiceDurationFormatter.swift`: `nonisolated enum`
  with `string(from:)` (`HH:mm`, truncates seconds, clamps negatives to 0) and
  `accessibilityString(from:locale:)`, which uses
  `Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes], width: .wide)` and
  switches `style.locale` when a non-current locale is passed:

```swift
private static let defaultAccessibilityStyle = Duration.UnitsFormatStyle(
    allowedUnits: [.hours, .minutes],
    width: .wide
)
```

- `Hugo/DesignSystem/Components/CenteredProgressBar.swift`: generic bar. Today it
  draws, in a `ZStack(alignment: .leading)`: the track capsule, the trail capsule
  (`.frame(width: trailWidth)` with `.offset(x: min(knobX, centerX))`, so one end
  touches the center), a 2 pt wide center `Rectangle` tick (to remove), and the knob.
- `Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift`: the header.
  Properties `report`, `progress`, `status`. `status` and
  `@Environment(\.dynamicTypeSize)` are used only for the end labels (`monthlyGoalHours`,
  `endLabels`). Primary number uses `ServiceDurationFormatter.string(from: primarySeconds)`;
  the actual-total line interpolates `ServiceDurationFormatter.string(from: progress.actualSeconds)`;
  the accessibility label uses `accessibilityString`.
- `Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift`: the `paceSentence`
  extension builds "%@ ahead" / "%@ behind" with
  `ServiceDurationFormatter.string(from: abs(differenceSeconds))`.
- `Hugo/Features/ServiceYear/Screens/ServiceYearDetailView.swift`: properties
  `report`, `progress`, `status`. `status` is used only for the footer's
  `status.separateAllowanceHours` and to unwrap in `if let progress, let status`.
  All durations go through `ServiceDurationFormatter.string`.
- `Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift:213` (`categoryRow`)
  and `Hugo/Features/Reports/Views/MonthlyReportTotalsView.swift:22-30` use
  `ServiceDurationFormatter.string`.
- `ServiceYearPageView.swift` creates the header and detail screen:
  `ServiceYearDetailView(report: report, progress: progress, status: status)` and
  `TheocraticYearTotalsView(report: report, progress: progress, status: status)`.
- Strings in `Hugo/Resources/Localizable.xcstrings` (source `en`, plus `da`). Keys
  to delete as unused after this plan: `year.header.pace`, `year.header.end.behind`,
  `year.header.end.ahead`, `year.detail.credit.footer`.
- Test exemplar: `HugoTests/Features/Reports/Domain/ServiceDurationFormatterTests.swift`.
- Conventions: read `AGENTS.md` fully. Notably `nonisolated` domain types, no
  catch-all folders, 4-space indent, strings need `en` and `da`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Layout check | `Scripts/check-layout.sh` | exit 0 |
| Strings valid JSON | `python3 -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/<Suite>` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope** (the only files you may modify):
- `Hugo/DesignSystem/Components/CenteredProgressBar.swift`
- `Hugo/Features/Reports/Domain/ServiceDurationFormatter.swift`
- `Hugo/Features/Reports/Views/MonthlyReportTotalsView.swift`
- `Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift`
- `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift`
- `Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift`
- `Hugo/Features/ServiceYear/Screens/ServiceYearDetailView.swift`
- `Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift`
- `Hugo/Resources/Localizable.xcstrings`
- `HugoTests/Features/Reports/Domain/ServiceDurationFormatterTests.swift`
- `plans/README.md` (status row)

**Out of scope** (do NOT touch):
- `EntryRow`, `MonthlyReportEntryListView`, `CategoryProgressBreakdownView`,
  `ReportingLineCard` and `ServiceDurationFormatter.string(from:)` itself (other
  screens still use it).
- The month card's big hour number and unit label in `ServiceYearMonthRow` (it
  already reads "xx hours").
- Calculation code (`YearlyGoalRule`, `YearlyGoalPacing`, progress math).

## Git workflow

- Branch/worktree is provided by the reviewer. Conventional Commits, for example
  `feat: show durations as hours on the year page`. End each commit message with
  `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Run `Scripts/install-hooks.sh` once; run `Scripts/verify.sh` before the last commit.
- Do NOT push.

## Steps

### Step 1: Add an hours formatter

In `ServiceDurationFormatter.swift` add, matching the style of
`accessibilityString`:

```swift
/// "152 hours" or "152 hours, 30 minutes". Seconds are dropped and zero minutes are omitted.
static func hoursString(from duration: TimeInterval, locale: Locale = .current) -> String
```

Implementation: clamp negatives to 0, truncate to whole minutes, build a
`Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes], width: .wide, zeroValueUnits: .hide)`
(set `locale` like `accessibilityString` does), and format
`Duration.seconds(wholeMinutes * 60)`. If a zero total renders as an empty string
or anything other than "0 hours", special-case it so the result is `"0 hours"`
(for example by formatting with `allowedUnits: [.hours]` only when `wholeMinutes == 0`).
A single hour must read "1 hour".

Add tests to `ServiceDurationFormatterTests.swift` (`en_US` locale): 0 -> "0 hours";
3_600 -> "1 hour"; 7_200 -> "2 hours"; 90_000 -> "25 hours"; 5_400 -> contains "1 hour"
and "30 minutes"; 3_659 -> "1 hour" (seconds dropped); -5 -> "0 hours". Also call
it once with `Locale(identifier: "da")` and report in NOTES what it returns
(expected a Danish "timer"/"time"); do not assert Danish text.

**Verify**: `-only-testing:HugoTests/DurationFormattingTests` -> `** TEST SUCCEEDED **`
(the suite struct in that file is named `DurationFormattingTests`).

### Step 2: Bar: remove the tick and center the trail on the center point

In `CenteredProgressBar.swift`:
- Delete the center `Rectangle` tick.
- Make the trail's rounded end sit *on* the center point. Let `h = HugoLayout.Size.goalTrackHeight`.
  The trail is a `Capsule` of height `h` that spans from `centerX - h / 2` to `knobX`
  when `knobX >= centerX`, and from `knobX` to `centerX + h / 2` when `knobX < centerX`.
  So its width is `abs(knobX - centerX) + h / 2`, and its leading edge is
  `centerX - h / 2` for the right side and `knobX` for the left side.
- Keep hiding the trail when `clampedFraction == 0` (no trail, knob alone in the center).
- Keep everything else (knob, track, motion, accessibility, preview) unchanged.

**Verify**: build succeeds:
`xcodebuild build -project Hugo.xcodeproj -scheme Hugo -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` -> `** BUILD SUCCEEDED **`.

### Step 3: Header: remove the labels under the bar, use hours wording

In `TheocraticYearTotalsView.swift`:
- Delete `endLabels`, `monthlyGoalHours`, the `@Environment(\.dynamicTypeSize)` property
  and the `status` property. Update both `#Preview`s and the call in `ServiceYearPageView.swift`
  to `TheocraticYearTotalsView(report: report, progress: progress)`.
- Primary number, the "Actual total" line and the accessibility label use
  `ServiceDurationFormatter.hoursString(from:)` instead of `string(from:)` /
  `accessibilityString`. Keep the `.system(.largeTitle, design: .serif, weight: .bold)`
  font for the primary number and add `.minimumScaleFactor(0.6)` and `.lineLimit(1)`
  so "152 hours, 30 minutes" cannot wrap badly. Drop `.monospacedDigit()` only if it
  causes visible problems; otherwise keep it.

In `YearlyGoalProgress.swift`, `paceSentence` uses
`ServiceDurationFormatter.hoursString(from: abs(differenceSeconds))`. Update the
`comment:` arguments so they say the argument is a duration such as "3 hours".

### Step 4: Detail screen: hours wording, no footer, no `status`

In `ServiceYearDetailView.swift`:
- Replace both `ServiceDurationFormatter.string` uses with `hoursString`.
- Remove the `footer:` from the By month section (keep the header).
- Remove the `status` property; the months section no longer needs it
  (`if let progress { monthsSection(progress) }`). Update the preview and the call in
  `ServiceYearPageView.swift` to `ServiceYearDetailView(report: report, progress: progress)`.
  `ServiceYearPageView` keeps its own `status` because it still derives `progress` from it.

### Step 5: Hours wording elsewhere in scope

- `ServiceYearMonthRow.swift` `categoryRow`: use `hoursString`.
- `MonthlyReportTotalsView.swift`: the three totals use `hoursString`. These sit in a
  three-column `HStack`; add `.lineLimit(1)` and `.minimumScaleFactor(0.6)` to the
  value `Text` so "152 hours" fits at default size, and keep the existing
  accessibility-size vertical layout.

### Step 6: Strings

Delete from `Localizable.xcstrings` the keys `year.header.pace`,
`year.header.end.behind`, `year.header.end.ahead` and `year.detail.credit.footer`.
Edit the catalog the same careful way as plan 054 (script or precise edits, no
reformatting of the rest of the file). Confirm no source file still references them:
`grep -rn "year.header.pace\|year.header.end\|year.detail.credit.footer" Hugo --include='*.swift'` returns nothing.

**Verify**: JSON check prints nothing; `Scripts/verify.sh` -> exit 0.

## Test plan

- New formatter tests from step 1. Existing suites still pass (the `HH:mm`
  `string(from:)` tests must be unchanged).
- Existing `YearlyGoalProgressTests` and `YearlyGoalRuleTests` must still pass untouched.
- Visual checks are for the reviewer; list in NOTES what you could not run.

## Done criteria

All must hold:

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -n "Rectangle()" Hugo/DesignSystem/Components/CenteredProgressBar.swift` returns no matches
- [ ] `grep -n "endLabels\|monthlyGoalHours\|credit.footer" -r Hugo --include='*.swift'` returns no matches
- [ ] `grep -n "ServiceDurationFormatter.string" Hugo/Features/ServiceYear` returns no matches
- [ ] `hoursString` tests exist and pass
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row updated (unless the reviewer maintains the index)

## STOP conditions

Stop and report back if:

- The code at "Current state" does not match (drift).
- `Duration.UnitsFormatStyle` cannot produce "0 hours" / "1 hour" in a way the tests in
  step 1 describe even with the special case. Report what it produces.
- A change requires touching an out-of-scope file.
- `Scripts/verify.sh` fails twice on the same issue after a reasonable fix.

## Maintenance notes

- `hoursString` is the style for the year page and monthly totals; entry-level
  screens deliberately keep `HH:mm`. If the owner later wants it elsewhere, only call
  sites change.
- Reviewer: check the header at the largest Dynamic Type size and with minutes
  present ("152 hours, 30 minutes"), and the knob/trail look at fractions around 0,
  plus and minus 1.
