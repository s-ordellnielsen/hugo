# Plan 089: Announce hours and minutes on the duration wheel

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 1432319..HEAD -- Hugo/Features/Entries/Views/DurationWheelPicker.swift`
> Expected: no output. If the file is listed, compare the "Current state" excerpts against the live code; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S (+ owner check with VoiceOver)
- **Risk**: LOW (accessibility text only; what sighted users see does not change)
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `1432319`, 2026-11-05
- **Issue**: [SLN-283](https://linear.app/sebastianln/issue/SLN-283)
- **Status**: IMPLEMENTED; owner VoiceOver check in English and Danish pending

## Why this matters

When a VoiceOver user scrolls the duration wheel in Add Entry, Entry Detail or the plan form, they hear bare numbers such as "zero one" and "thirty". Nothing says which wheel is hours and which is minutes, so it is easy to set 30 hours instead of 30 minutes. Many of Hugo's users are older, and some rely on VoiceOver. After this plan, each wheel row is read with its unit ("1 hour", "30 minutes"; "1 time", "30 minutter" in Danish).

## Current state

- `Hugo/Features/Entries/Views/DurationWheelPicker.swift` is the duration wheel. `DurationWheelPicker` (lines 12–29) is the SwiftUI wrapper; it hosts a `UIPickerView` through `DurationPickerRepresentable` with two components, hours (0) and minutes (1). The wrapper's accessibility today (lines 26–27):

  ```swift
          .accessibilityElement(children: .contain)
          .accessibilityLabel(Text("entry.duration.label"))
  ```

- Each row is a `UILabel` built in the coordinator (lines 125–134). This is where the bare numbers come from:

  ```swift
          func pickerView(
              _ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?
          ) -> UIView {
              let label = view as? UILabel ?? UILabel()
              let value = component == 0 ? row : minuteOptions[row]
              label.text = String(format: "%02d", value)
              label.font = .preferredFont(forTextStyle: .title2)
              label.textAlignment = .center
              return label
          }
  ```

  When a row view has an `accessibilityLabel`, VoiceOver reads that label for the selected row instead of the view's text.

- The wheel is used in three places, all with the same initializer `DurationWheelPicker(duration:minuteInterval:maxDuration:)`. The initializer does not change in this plan:
  - `Hugo/Features/Entries/Screens/AddEntryView.swift:30`
  - `Hugo/Features/Entries/Screens/EntryDetailView.swift:21`
  - `Hugo/Features/Planner/Screens/PlanFormView.swift:28`

- `Hugo/Domain/ServiceDurationFormatter.swift` already formats durations for VoiceOver with `Duration.UnitsFormatStyle` and wide units:

  ```swift
      static func accessibilityString(from duration: TimeInterval, locale: Locale = .current) -> String {
  ```

  and its `hoursString` uses `zeroValueUnits: .show(length: 1)` so zero reads "0 hours" (lines 45–49). The existing test `hoursStringFormatsWholeHours` in `HugoTests/Domain/ServiceDurationFormatterTests.swift` shows the exact English output: "0 hours", "1 hour", "2 hours". Another plan in this batch changes `hoursString` in that file, so do **not** edit `ServiceDurationFormatter.swift`. Use `Duration.UnitsFormatStyle` directly in a new helper, and call `accessibilityString` only as it is.

- Use the formatter for units and plurals. Do not add hand-built strings such as `"%lld hours"` to the catalog; `Duration.UnitsFormatStyle` already handles plurals in English and Danish.

- Conventions: pure value logic lives in a feature's `Domain` folder and is `nonisolated` where possible (see `Hugo/Features/Entries/Domain/EntryCategory.swift:6`). Tests mirror the source layout, use Swift Testing, and pass a fixed `Locale` (see `HugoTests/Domain/ServiceDurationFormatterTests.swift`).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Build | `xcodebuild build -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData CODE_SIGNING_ALLOWED=NO` | ends with `** BUILD SUCCEEDED **` |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/DurationWheelAccessibilityTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 (takes several minutes) |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run the same command again; that is not a failure.

## Scope

**In scope** (the only files you modify or create):
- `Hugo/Features/Entries/Domain/DurationWheelAccessibility.swift` (create)
- `HugoTests/Features/Entries/Domain/DurationWheelAccessibilityTests.swift` (create)
- `Hugo/Features/Entries/Views/DurationWheelPicker.swift`

**Out of scope**:
- `Hugo/Domain/ServiceDurationFormatter.swift` and its tests (another plan changes them).
- The visible row text: rows keep showing "01", "30" and so on.
- `AddEntryView.swift`, `EntryDetailView.swift`, `PlanFormView.swift`: they must compile unchanged.
- `Localizable.xcstrings`: no new strings.
- Making the wheel one adjustable element, or replacing the `UIPickerView`.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- The working tree may hold uncommitted owner files in `plans/` and `.claude/`. Never stage, edit, stash or discard them. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage only the in-scope files, by explicit path.
- One commit, Conventional Commits style: `fix: announce hours and minutes on the duration wheel`

## Steps

### Step 1: Add the spoken row labels and their tests

Create `Hugo/Features/Entries/Domain/DurationWheelAccessibility.swift`:

```swift
import Foundation

/// What VoiceOver says for one row of the duration wheel: the number with its
/// unit, such as "1 hour" or "30 minutes" ("1 time", "30 minutter" in Danish).
nonisolated enum DurationWheelAccessibility {
    static func hoursLabel(_ hours: Int, locale: Locale = .current) -> String {
        label(seconds: hours * 3_600, unit: .hours, locale: locale)
    }

    static func minutesLabel(_ minutes: Int, locale: Locale = .current) -> String {
        label(seconds: minutes * 60, unit: .minutes, locale: locale)
    }

    private static func label(seconds: Int, unit: Duration.UnitsFormatStyle.Unit, locale: Locale) -> String {
        var style = Duration.UnitsFormatStyle(
            allowedUnits: [unit],
            width: .wide,
            zeroValueUnits: .show(length: 1)
        )
        style.locale = locale
        return Duration.seconds(seconds).formatted(style)
    }
}
```

Create `HugoTests/Features/Entries/Domain/DurationWheelAccessibilityTests.swift`:

```swift
import Foundation
import Testing

@testable import Hugo

struct DurationWheelAccessibilityTests {
    private let english = Locale(identifier: "en_US")
    private let danish = Locale(identifier: "da_DK")

    @Test
    func hoursCarryTheirUnitInEnglish() {
        #expect(DurationWheelAccessibility.hoursLabel(0, locale: english) == "0 hours")
        #expect(DurationWheelAccessibility.hoursLabel(1, locale: english) == "1 hour")
        #expect(DurationWheelAccessibility.hoursLabel(2, locale: english) == "2 hours")
    }

    @Test
    func minutesCarryTheirUnitInEnglish() {
        #expect(DurationWheelAccessibility.minutesLabel(0, locale: english) == "0 minutes")
        #expect(DurationWheelAccessibility.minutesLabel(1, locale: english) == "1 minute")
        #expect(DurationWheelAccessibility.minutesLabel(30, locale: english) == "30 minutes")
    }

    @Test
    func unitsAreDanishInDanish() {
        let oneHour = DurationWheelAccessibility.hoursLabel(1, locale: danish)
        let twoHours = DurationWheelAccessibility.hoursLabel(2, locale: danish)
        let thirtyMinutes = DurationWheelAccessibility.minutesLabel(30, locale: danish)
        #expect(oneHour.hasPrefix("1") && oneHour.hasSuffix("time"))
        #expect(twoHours.hasPrefix("2") && twoHours.hasSuffix("timer"))
        #expect(thirtyMinutes.hasPrefix("30") && thirtyMinutes.hasSuffix("minutter"))
    }
}
```

**Verify**: the focused test command → `** TEST SUCCEEDED **`, and the output lists the 3 tests above as passed.

### Step 2: Give each wheel row its spoken label

In `DurationWheelPicker.swift`, inside `pickerView(_:viewForRow:forComponent:reusing:)`, add one line after `label.text = String(format: "%02d", value)`:

```swift
            label.accessibilityLabel =
                component == 0
                ? DurationWheelAccessibility.hoursLabel(value)
                : DurationWheelAccessibility.minutesLabel(value)
```

Set it on every call, including reused labels, so a recycled row never keeps another row's label.

**Verify**: the build command → `** BUILD SUCCEEDED **`. `grep -n "accessibilityLabel =" Hugo/Features/Entries/Views/DurationWheelPicker.swift` → 1 line.

### Step 3: Give the wheel as a whole the full duration

In `DurationWheelPicker.body`, add a value after the existing label (lines 26–27), so the group carries "Duration" plus the full duration:

```swift
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("entry.duration.label"))
        .accessibilityValue(Text(verbatim: ServiceDurationFormatter.accessibilityString(from: duration)))
```

Keep `children: .contain`, so each wheel stays reachable on its own. Whether VoiceOver speaks a container's value depends on how the user navigates. The per-row labels from Step 2 are the main fix.

**Verify**: the build command → `** BUILD SUCCEEDED **`. `git diff --stat` lists only `DurationWheelPicker.swift` among existing files, plus the two new files as untracked (`git status --short`).

### Step 4: Run the gate and commit

Run `Scripts/verify.sh`. Then stage the three in-scope files by path and commit with the message from "Git workflow".

**Verify**: `Scripts/verify.sh` exits 0. `git show --stat HEAD` lists exactly the three in-scope files.

## Test plan

- New: `DurationWheelAccessibilityTests` (Step 1), covering singular and plural forms, zero, English exact text, and Danish units.
- Pattern: `HugoTests/Domain/ServiceDurationFormatterTests.swift` (fixed `Locale`, exact strings in English).
- The VoiceOver behavior itself has no automated test. The owner checks it on a device, in English and in Danish:
  1. Turn on VoiceOver. Open Add Entry, swipe to the duration wheel.
  2. Focus the hours wheel and flick up and down. VoiceOver says "1 hour", "2 hours" ("1 time", "2 timer").
  3. Focus the minutes wheel and flick. VoiceOver says "5 minutes", "30 minutes" ("5 minutter", "30 minutter").
  4. Repeat in Entry Detail (tap an entry) and in the Planner's plan form.
  5. Sighted check: the wheel still shows "01", "30" with no visual change.

## Done criteria

- [x] `Scripts/verify.sh` exits 0, including the 3 new tests.
- [x] The visible row text remains `String(format: "%02d", value)`.
- [x] The picker contains row labels and a complete-duration accessibility value.
- [ ] Owner confirms VoiceOver output in English and Danish on device.

## STOP conditions

Stop and report back (do not improvise) if:

- The rows are no longer `UILabel`s built in `pickerView(_:viewForRow:forComponent:reusing:)` (for example, the wheel was rewritten in SwiftUI).
- An English test in Step 1 fails with a different text than expected. Report the actual output; do not change the expected strings to match.
- The Danish test fails because the output contains English words ("hour", "minute"). That means the `locale` is not applied; report it.
- The fix appears to need changes to `ServiceDurationFormatter.swift` or any of the three call sites.

## Maintenance notes

- If the owner's device check shows VoiceOver still reading "zero one", the row label is not being picked up by `UIPickerView`'s accessibility. The next step is to adopt `UIPickerViewAccessibilityDelegate` on the coordinator and return the same strings from `pickerView(_:accessibilityLabelForComponent:)` for the selected row. That is a follow-up, not part of this plan.
- If minute steps or the maximum hours change (`interval`, `maxHours`), the labels follow automatically because they are built from the row's value.
- Plan 080 in this batch changes `ServiceDurationFormatter.hoursString` to a short style ("23 hours, 15 min"). This plan deliberately does not use `hoursString`, so VoiceOver keeps full words.
