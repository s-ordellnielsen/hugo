# Plan 134: Stop the duration wheel crashing when it lands on 24:xx

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 0af2e24..HEAD -- Hugo/Features/Entries/Views/DurationWheelPicker.swift Hugo/Features/Entries/Domain`
> Expected: no output. If the file changed, compare it with "Current state" and STOP on a mismatch.
> Also `git status --short` must show only
> `M Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` (the owner's own
> edit, if present; never touch or commit it) and untracked plan files.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: MEDIUM. UIKit picker behavior cannot be unit tested, so the new logic is extracted into a pure type and the coordinator is verified by reading plus a manual check.
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `0af2e24`, 2026-11-23
- **Issue**: [SLN-317](https://linear.app/sebastianln/issue/SLN-317)

## Why this matters

In Add Entry, the "Duration" wheel (hours and minutes) goes up to 24 hours. If
the user scrolls the hours to 24 and then touches the minutes wheel, the app
crashes (index out of range). A crash while logging time can lose the entry
being added. The same wheel is used in Entry Detail and in the Plan form, so
all three screens are affected.

The issue calls it the "time picker". It is not `EntryTimePickerView` (that is
a system `DatePicker` with `.hourAndMinute`, which cannot reach 24). It is
`DurationWheelPicker` (SLN-199 already made it the single duration
implementation).

### Root cause

`DurationWheelPicker.swift` builds the minutes wheel from `minuteOptions`, a
computed property on the coordinator that derives the hour from the binding
(`duration.wrappedValue`), not from the wheel. At 24 hours with
`maxDuration` of 24 hours the only valid minute is `00`, so `minuteOptions`
has one element.

In `didSelectRow` for the hours wheel, the code calls
`pickerView.reloadComponent(1)` and only afterwards writes
`duration.wrappedValue`. So the reload asks the data source while the binding
still holds the old hour (say 23), and the minutes wheel is rebuilt with 60
rows. `updateUIView` does not rebuild it later (it reloads only when the
interval or `maxHours` change). The wheel now shows hour 24 with minutes 00 to
59. When the user scrolls the minutes to, for example, `15`, `didSelectRow`
runs `minuteOptions[row]` with row 15, but `minuteOptions` now has one
element: crash. `viewForRow` has the same unguarded `minuteOptions[row]`.
Scrolling back from 24 to 23 has the mirror problem (the minutes wheel is
rebuilt with one row), so minutes become stuck at `00`.

### Decision: keep 24:00 valid, do not stop at 23:59

- The 24-hour ceiling is deliberate and shared: `AddEntryView` and
  `PlanFormView` pass `24 * 60 * 60`, `EntryDetailView` passes
  `max(24 * 60 * 60, entry.duration)` so an existing longer entry still opens.
- The wheel already has logic for "last hour allows only the minutes left up
  to `maxDuration`", so 24:00 exactly is a designed, valid value. The bug is
  that this logic is fed a stale hour. Lowering the ceiling to 23:59 would not
  fix that bug: `EntryDetailView` can legitimately pass a larger maximum, so
  the same stale-hour crash would remain at the top hour there.
- So the fix is to make the minutes wheel read the hour from the wheel itself
  and to bounds-check every index. 24:00 stays selectable, 24:15 can never be
  shown or selected.

## Current state

`Hugo/Features/Entries/Views/DurationWheelPicker.swift` (verify before editing).

Lines 67 to 83, the coordinator state and the `hours` / `minuteOptions` /
`minutes` / `select` members (the file's own line numbers):

```swift
        private var hours: Int {
            min(maxHours, Int(max(0, duration.wrappedValue) / 3600))
        }

        private var minuteOptions: [Int] {
            let remainingSeconds = maxDuration - TimeInterval(hours * 3600)
            let ceiling = hours >= maxHours ? max(0, Int(remainingSeconds / 60)) : 59
            return Array(stride(from: 0, through: ceiling, by: interval))
        }

        private var minutes: Int {
            let rawMinutes = Int(max(0, duration.wrappedValue).truncatingRemainder(dividingBy: 3600) / 60)
            let snapped = (rawMinutes / interval) * interval
            return min(minuteOptions.last ?? 0, snapped)
        }

        func select(in picker: UIPickerView, animated: Bool) {
            picker.selectRow(hours, inComponent: 0, animated: animated)
            let minuteRow = minuteOptions.firstIndex(of: minutes) ?? 0
            picker.selectRow(minuteRow, inComponent: 1, animated: animated)
            lastAppliedDuration = duration.wrappedValue
        }
```

Then the data source and delegate (`numberOfRowsInComponent`, `viewForRow`,
`didSelectRow`):

```swift
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            component == 0 ? maxHours + 1 : minuteOptions.count
        }
        ...
            let value = component == 0 ? row : minuteOptions[row]
        ...
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            let newHours = component == 0 ? row : hours
            var newMinutes = component == 1 ? minuteOptions[row] : minutes

            if component == 0 {
                let remainingSeconds = maxDuration - TimeInterval(newHours * 3600)
                let ceiling = newHours >= maxHours ? max(0, Int(remainingSeconds / 60)) : 59
                let options = Array(stride(from: 0, through: ceiling, by: interval))
                newMinutes = min(options.last ?? 0, newMinutes)
                pickerView.reloadComponent(1)
                let minuteRow = options.firstIndex(of: newMinutes) ?? 0
                pickerView.selectRow(minuteRow, inComponent: 1, animated: false)
            }

            let candidate = TimeInterval(newHours * 3600 + newMinutes * 60)
            let clamped = min(maxDuration, max(0, candidate))
            duration.wrappedValue = clamped
            lastAppliedDuration = clamped
        }
```

The crash is `minuteOptions[row]` in `didSelectRow` (and the same index in
`viewForRow`). `pickerView.reloadComponent(1)` runs before
`duration.wrappedValue = clamped`, which is why the data source sees the old
hour.

No existing test touches the wheel's range logic: `HugoTests/Features/Entries/Domain/`
holds only `DurationWheelAccessibilityTests.swift` for the wheel. The project
uses file-system synchronized groups, so new `.swift` files under `Hugo/` and
`HugoTests/` are picked up without editing `Hugo.xcodeproj`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint files | `xcrun swift-format lint --strict <files>` | exit 0, no output |
| Whole gate | `Scripts/verify.sh` | exit 0 (lint, all tests, analyze). Takes several minutes. |

## Scope

**In scope** (the only files you may modify or create):

- `Hugo/Features/Entries/Domain/DurationWheelRange.swift` (new)
- `HugoTests/Features/Entries/Domain/DurationWheelRangeTests.swift` (new)
- `Hugo/Features/Entries/Views/DurationWheelPicker.swift`
- `plans/README.md` (status row)

**Out of scope** (do NOT touch):

- `EntryTimePickerView.swift`: a different control (start time of day) that cannot reach 24.
- `AddEntryView.swift`, `EntryDetailView.swift`, `PlanFormView.swift`: their `maxDuration` values stay as they are.
- `DurationWheelAccessibility.swift` and its tests.
- `Hugo.xcodeproj` and `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`: never stage it.

## Git workflow

- Commit straight to `main`. Do not create a branch or a worktree.
- One commit after `Scripts/verify.sh` exits 0, Conventional Commits: `fix: stop the duration wheel crashing at 24 hours`.
- Stage by explicit path only (the four paths above that changed). Never `git add -A` or `git add .`. Do not push.

## Steps

### Step 1: Add the pure range type

Create `Hugo/Features/Entries/Domain/DurationWheelRange.swift` with exactly:

```swift
import Foundation

/// Which minutes the duration wheel offers for each hour. The last hour allows
/// only the minutes left up to `maxDuration`, so with a 24 hour maximum the
/// hour 24 offers only `00`.
nonisolated struct DurationWheelRange: Equatable {
    let maxDuration: TimeInterval
    let interval: Int

    init(maxDuration: TimeInterval, interval: Int) {
        self.maxDuration = maxDuration
        self.interval = max(1, interval)
    }

    var maxHours: Int { max(0, Int(maxDuration / 3600)) }

    /// The minutes the wheel shows for `hours`. An hour outside the range is
    /// treated as the nearest valid hour.
    func minuteOptions(forHours hours: Int) -> [Int] {
        let hours = min(maxHours, max(0, hours))
        let remainingSeconds = maxDuration - TimeInterval(hours * 3600)
        let ceiling = hours >= maxHours ? max(0, Int(remainingSeconds / 60)) : 59
        return Array(stride(from: 0, through: ceiling, by: interval))
    }

    /// `minutes` snapped down to the interval and limited to what `hours` offers.
    func snappedMinutes(_ minutes: Int, forHours hours: Int) -> Int {
        let snapped = (max(0, minutes) / interval) * interval
        return min(minuteOptions(forHours: hours).last ?? 0, snapped)
    }
}
```

**Verify**: `xcrun swift-format lint --strict Hugo/Features/Entries/Domain/DurationWheelRange.swift` exits 0.

### Step 2: Add the regression tests

Create `HugoTests/Features/Entries/Domain/DurationWheelRangeTests.swift`:

```swift
import Foundation
import Testing

@testable import Hugo

struct DurationWheelRangeTests {
    private let day = DurationWheelRange(maxDuration: 24 * 3600, interval: 5)

    @Test
    func hour24OffersOnlyZeroMinutes() {
        #expect(day.minuteOptions(forHours: 24) == [0])
    }

    @Test
    func hour23OffersAllMinutesAtTheInterval() {
        #expect(day.minuteOptions(forHours: 23) == Array(stride(from: 0, through: 55, by: 5)))
    }

    @Test
    func anHourBeyondTheRangeIsTreatedAsTheLastHour() {
        #expect(day.minuteOptions(forHours: 25) == [0])
        #expect(day.minuteOptions(forHours: -1) == day.minuteOptions(forHours: 0))
    }

    @Test
    func snappingAtHour24NeverLeavesZero() {
        #expect(day.snappedMinutes(15, forHours: 24) == 0)
        #expect(day.snappedMinutes(59, forHours: 24) == 0)
    }

    @Test
    func snappingRoundsDownToTheInterval() {
        #expect(day.snappedMinutes(17, forHours: 3) == 15)
    }

    @Test
    func aPartialLastHourOffersTheMinutesLeft() {
        let range = DurationWheelRange(maxDuration: 25 * 3600 + 30 * 60, interval: 15)
        #expect(range.minuteOptions(forHours: 25) == [0, 15, 30])
        #expect(range.minuteOptions(forHours: 24) == [0, 15, 30, 45])
    }

    @Test
    func aZeroIntervalDoesNotTrap() {
        let range = DurationWheelRange(maxDuration: 3600, interval: 0)
        #expect(range.minuteOptions(forHours: 0).count == 60)
    }
}
```

**Verify**: `xcrun swift-format lint --strict HugoTests/Features/Entries/Domain/DurationWheelRangeTests.swift` exits 0. (The tests run in Step 4.)

### Step 3: Make the coordinator read the hour from the wheel and bounds-check

All edits are in `Hugo/Features/Entries/Views/DurationWheelPicker.swift`, inside `final class Coordinator`.

1. Replace the `minuteOptions` property (the whole `private var minuteOptions: [Int] { ... }` block) with:

```swift
        private var range: DurationWheelRange {
            DurationWheelRange(maxDuration: maxDuration, interval: interval)
        }

        /// The hour the wheel is showing. The minutes wheel must follow this
        /// and not the binding, because the binding is written after the wheel
        /// has already moved.
        private func selectedHours(in picker: UIPickerView) -> Int {
            min(maxHours, max(0, picker.selectedRow(inComponent: 0)))
        }
```

2. Replace the `minutes` property with:

```swift
        private var minutes: Int {
            let rawMinutes = Int(max(0, duration.wrappedValue).truncatingRemainder(dividingBy: 3600) / 60)
            return range.snappedMinutes(rawMinutes, forHours: hours)
        }
```

3. Replace `select(in:animated:)` with (reload the minutes wheel after the hour is set, so it holds the right rows before its row is chosen):

```swift
        func select(in picker: UIPickerView, animated: Bool) {
            picker.selectRow(hours, inComponent: 0, animated: animated)
            picker.reloadComponent(1)
            let options = range.minuteOptions(forHours: hours)
            picker.selectRow(options.firstIndex(of: minutes) ?? 0, inComponent: 1, animated: animated)
            lastAppliedDuration = duration.wrappedValue
        }
```

4. In `numberOfRowsInComponent`, replace `minuteOptions.count` with
   `range.minuteOptions(forHours: selectedHours(in: pickerView)).count`, so the line reads:

```swift
            component == 0 ? maxHours + 1 : range.minuteOptions(forHours: selectedHours(in: pickerView)).count
```

5. In `viewForRow`, replace the line `let value = component == 0 ? row : minuteOptions[row]` with:

```swift
            let options = range.minuteOptions(forHours: selectedHours(in: pickerView))
            let value = component == 0 ? row : (options.indices.contains(row) ? options[row] : 0)
```

6. Replace the whole body of `didSelectRow` (everything between its braces) with:

```swift
            let newHours = selectedHours(in: pickerView)
            let options = range.minuteOptions(forHours: newHours)
            let newMinutes: Int
            if component == 1 {
                newMinutes = options.indices.contains(row) ? options[row] : (options.last ?? 0)
            } else {
                newMinutes = range.snappedMinutes(minutes, forHours: newHours)
                pickerView.reloadComponent(1)
                pickerView.selectRow(options.firstIndex(of: newMinutes) ?? 0, inComponent: 1, animated: false)
            }

            let candidate = TimeInterval(newHours * 3600 + newMinutes * 60)
            let clamped = min(maxDuration, max(0, candidate))
            duration.wrappedValue = clamped
            lastAppliedDuration = clamped
```

Do not change `DurationWheelPicker`, `DurationPickerRepresentable`, the `#Preview`s or any other member.

**Verify**:
- `grep -n "minuteOptions\[" Hugo/Features/Entries/Views/DurationWheelPicker.swift` → only `options[row]` forms inside an `indices.contains` check (no bare `minuteOptions[`).
- `grep -n "minuteOptions" Hugo/Features/Entries/Views/DurationWheelPicker.swift` → only calls `range.minuteOptions(forHours:`.
- `xcrun swift-format lint --strict Hugo/Features/Entries/Views/DurationWheelPicker.swift` → exit 0.

### Step 4: Run the gate and commit

Run `Scripts/verify.sh`, with the full output redirected to a file under
`/private/tmp/claude-501/-Users-sebastiannielsen-Documents-Areas-Personal-Apps-Hugo/e838d7fa-4b4b-47a9-b236-f61a2004ed12/scratchpad/`
(for example `verify-134.log`), and take the exit code from the script itself.
Then stage the three changed source files by explicit path and commit with the
message from "Git workflow".

**Verify**: exit code 0, and the log contains `** TEST SUCCEEDED **` and `** ANALYZE SUCCEEDED **`. `grep -c "DurationWheelRangeTests" <log>` is at least 1.

## Test plan

- New `DurationWheelRangeTests` (Step 2) pin the cause: hour 24 offers only `00`, hour 23 offers the full set, out-of-range hours clamp, and snapping at hour 24 never leaves `0`. These fail against the old logic only through the coordinator, so the point of the tests is to lock the range rules the coordinator now depends on.
- The coordinator itself is a UIKit delegate and has no test seam here. Say this in NOTES.
- Manual check for the owner (put in NOTES for the reviewer): on a simulator, open Add Entry, scroll hours to 24, confirm the minutes wheel shows only `00` and the app does not crash; try to scroll the minutes; scroll hours back to 23 and confirm minutes 00 to 59 return. Repeat in a Plan form and in Entry Detail on an entry shorter than 24 hours.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0.
- [ ] `grep -n "minuteOptions\[" Hugo/Features/Entries/Views/DurationWheelPicker.swift` prints nothing.
- [ ] `DurationWheelRangeTests` ran and passed.
- [ ] Only the three source files above changed in the commit (the new type, its test, the picker).
- [ ] `plans/README.md` status row updated (unless the reviewer maintains it).

## STOP conditions

Stop and report back (do not improvise) if:

- The code at "Current state" does not match, for example `minuteOptions` is already index-safe or `didSelectRow` already reads the hour from the picker.
- `selectedHours(in:)` causes a compile error under Swift 6 isolation (then say so; do not add `nonisolated` or `@MainActor` annotations by guessing).
- A step's verification fails twice.
- The change appears to need any file outside the scope list, including `Hugo.xcodeproj`.

## Maintenance notes

- Any new use of `DurationWheelPicker` can pass a `maxDuration` that is not a whole number of hours. `DurationWheelRange` handles that (see the partial last hour test).
- Rule for this wheel: never derive the minutes rows from the binding inside a data source or delegate callback. The binding lags the wheel by one callback.
- `Entry.duration` has no model-level upper bound, so a hand-edited or synced entry longer than 24 hours is shown through `EntryDetailView`'s `max(24 * 60 * 60, entry.duration)`. That path now also cannot crash at its top hour.
- Reviewer: confirm the manual check above on a device, since the UIKit callbacks are not covered by unit tests.
