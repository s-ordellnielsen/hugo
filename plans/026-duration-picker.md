# Plan 026: Purpose-built scroll-wheel duration picker

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in "STOP conditions" occurs, stop and report — do not
> improvise. When done, update the status row for plan 026 in
> `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat d65afec..HEAD -- Hugo/Features/Entries Hugo/Features/Settings Hugo/Domain/UserDefaultsKeys.swift HugoTests/Features/Entries`
> If any in-scope file changed, compare the "Current state" excerpts against the
> live code; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED (touches the entry-creation data path; existing tests must keep passing)
- **Depends on**: plans/016-green-verification-gate.md, plans/017-user-visible-correctness.md
- **Category**: feature + code-quality (removes the repurposed-`DatePicker` hack)
- **Planned at**: commit `d65afec`, 2026-08-06

## Why this matters

Duration entry is currently a **repurposed `DatePicker`**. Both call sites
abuse a time-of-day picker to mean "a length of time":

- `AddEntryView.swift:21-23` — `DatePicker("entry.duration.label", selection: $form.durationDate, displayedComponents: .hourAndMinute).datePickerStyle(.wheel)`.
- `EntryDetailView.swift:46-49` — `EntryDurationPicker`, which wraps another
  `.hourAndMinute` `DatePicker`.

This is wrong in three ways the operator wants fixed:

1. **A `Date` is not a duration.** The code converts a time-of-day into seconds
   (`EntryDurationConversion.seconds(from:)`) and back (`EntryDetailView`'s
   hand-rolled `durationAsDate`). That round-trip is pure ceremony and has
   already been flagged as duplicated conversion logic.
2. **No configurable minute granularity.** The system wheel is fixed at
   1-minute steps. The operator wants a user setting of 1 / 5 / 15 minutes.
3. **No configurable maximum.** A time-of-day wheel caps at 23:59. The operator
   wants the max as a *property*: 24 h for a normal same-day entry, but a much
   larger ceiling for a future backfill-earlier-reports feature.

The operator's product direction: **keep the scroll-wheel vibe** (a real wheel,
not a stepper/slider), but build it purpose-built. This plan implements exactly
that, no App Intent / widget work (explicitly deferred).

## Current state

### The repurposed-DatePicker hack

`Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift`:
- `var durationDate: Date` (line 16) — the source of truth is a `Date`, set to
  `calendar.startOfDay(for: now)` (line 30).
- `var durationInSeconds: TimeInterval { EntryDurationConversion.seconds(from: durationDate, calendar: ![](Screenshot%202026-08-06%20at%2012.20.28.png)calendar) }` (line 33-34).
- Validation `durationInSeconds == 0` (line 38); `draft()` uses `durationInSeconds` (line 71-76).

`EntryDurationConversion` (lines 80-93) — two functions converting
`Date`↔seconds via a `Calendar`. This is the shared conversion the picker
should replace at the view layer (the helper may stay for the form model).

`Hugo/Features/Entries/EntryDetailView.swift:19-39` — a **second, hand-rolled**
`durationAsDate` computed property duplicating the seconds→components math that
`EntryDurationConversion.date(from:calendar:reference:)` already provides.
`EntryDurationPicker.swift` then does the inverse in `updateDuration()`.

`Hugo/Features/Entries/EntryDurationPicker.swift` — the entire file is the
hack: `@State var durationAsDate: Date`, a `.hourAndMinute` `DatePicker`, and
`updateDuration()` converting back. Header comment even names a stale file
(`EntryListDurationPicker.swift`).

### Settings pattern to reuse

`Hugo/Features/Settings/SettingsView.swift` already uses
`@AppStorage(UserDefaultsKeys.X)` + `Picker` (see `defaultRoundingRule`,
line 4, and its `Picker(selection:)` at line 32). `UserDefaultsKeys`
(`Hugo/Domain/UserDefaultsKeys.swift`) is the constants enum — **do not
hardcode key strings** (plan 023 removes the existing hardcoded ones).

### Existing tests (must keep passing / extend)

`HugoTests/Features/Entries/AddEntryFormModelTests.swift` — 7 tests, including
`convertsDurationToSeconds` (sets `durationDate`, expects `durationInSeconds`)
and a parameterized `durationRoundTrips` over `EntryDurationConversion`. Uses
`import Testing`, `@Test`, `#expect`, and a private `date(_:_:_:hour:minute:)`
helper.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan026 CODE_SIGNING_ALLOWED=NO` | `TEST SUCCEEDED` |
| Entry tests only | same, plus `-only-testing:HugoTests/AddEntryFormModelTests -only-testing:HugoTests/DurationPickerModelTests` | pass |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:
- New `Hugo/Features/Entries/DurationPickerView.swift` — the purpose-built wheel.
- New `Hugo/Features/Entries/DurationPickerModel.swift` — testable value logic (hours/minutes/interval/max/clamping).
- `Hugo/Features/Entries/AddEntry/AddEntryView.swift` — swap the duration `DatePicker` for the new picker.
- `Hugo/Features/Entries/EntryDetailView.swift` — swap `EntryDurationPicker` for the new picker; delete the hand-rolled `durationAsDate`.
- `Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift` — expose duration as a value the new picker binds to (see Step 4); keep `durationInSeconds` semantics.
- `Hugo/Domain/UserDefaultsKeys.swift` — add the interval key.
- `Hugo/Features/Settings/SettingsView.swift` — add the interval setting row.
- **Delete** `Hugo/Features/Entries/EntryDurationPicker.swift` once both call sites are migrated.
- Tests: extend `AddEntryFormModelTests`, add `DurationPickerModelTests`.

**Out of scope** (do NOT touch):
- Any App Intent or Widget work — explicitly deferred by the operator.
- The backfill-earlier-reports *feature* itself. This plan only makes the
  picker's max **configurable by property** so backfill can later pass a larger
  ceiling; it does not build backfill.
- `EntryDurationConversion` — leave the helper in place; the form model still
  uses it. Do not delete it while `durationDate` remains (see Step 4 note).
- The `DatePicker` used for the entry's **date** and **time-of-day** selection
  (`$form.date`, the time picker) — those are genuine dates, not durations.
  Only the *duration* pickers change.
- Localization of new strings beyond adding English keys; Danish via plan 024.
- `Hugo/Persistence/**` — the `Entry.duration` `TimeInterval` model is unchanged.

## Git workflow

- Branch: `advisor/026-duration-picker`
- One commit per step, message style: `` `026` Step N — <summary> ``
- Do NOT push or open a PR.

## Steps

### Step 1: Add the interval setting (UserDefaultsKeys + Settings UI)

1. `UserDefaultsKeys.swift` — add:
   ```swift
   static let durationPickerMinuteInterval = "durationPickerMinuteInterval"
   ```
2. `SettingsView.swift` — add an `@AppStorage` for it (Int, default `1`) and a
   `Picker` in the appropriate section offering **1, 5, 15** minutes. Mirror the
   existing `defaultRoundingRule` `Picker` structure exactly. New label strings
   go through the catalog (`settings.duration-interval.*`), English only.

**Verify**: build succeeds; Settings shows the picker with three choices;
selection persists across relaunch (it is `@AppStorage`).

### Step 2: Build the testable value model

Create `DurationPickerModel.swift` — a small `struct`/`final class` (value
semantics preferred for testability) holding the **duration as total minutes
(Int)** and exposing:

- `minuteInterval: Int` (1, 5, or 15 — clamp/validate to these; default 1)
- `maxDuration: TimeInterval` (a property, **required at init**, no hardcoded cap)
- `hours: Int` / `minutes: Int` derived from total minutes for the two wheels
- A `timeInterval: TimeInterval` projection (`totalMinutes * 60`)
- Clamping:
  - minutes snap down to the nearest `minuteInterval` multiple
  - total clamps to `maxDuration` (i.e. `totalMinutes <= Int(maxDuration / 60)`)
  - the minute wheel's valid range depends on whether the selected hour is the
    final (max) hour — beyond the max hour, minutes are limited to the remainder
- Mutation API the view calls when either wheel changes, re-applying clamps.

This type owns **all** the math so the view is dumb. No `Calendar`, no `Date` —
durations are minutes/seconds, not wall-clock times.

**Verify**: it compiles in isolation; the Step 5 tests (written first if you
prefer TDD) pass against it.

### Step 3: Build the wheel view

Create `DurationPickerView.swift`. Keep the **scroll-wheel vibe**: a
multi-component wheel. Recommended implementation: an `HStack` of two
`Picker`s each with `.pickerStyle(.wheel)` (hours, minutes) plus small
"hours"/"min" unit labels, bound to the model from Step 2. Requirements:

- Hours wheel range: `0 ... maxHours` where `maxHours = Int(maxDuration / 3600)`.
- Minutes wheel range: the valid, interval-snapped set for the currently
  selected hour (so the user cannot scroll minutes past `maxDuration`).
- Changing either wheel updates the model; the model clamps; the view reflects
  the clamped value (e.g. selecting hour = max forces minutes to the remainder).
- Read `minuteInterval` from the `@AppStorage` key (default 1) unless a value is
  injected for tests/previews.
- Take `maxDuration` as an initializer parameter — **the caller decides**.
- Accessibility: each wheel gets `.accessibilityLabel`/`value` (e.g. hours and
  minutes spoken); reuse plan 020's `a11y.*` pattern. Reduce Motion: the wheel
  is a system control; no custom animation to gate.
- A `#Preview` at a 24-hour max and at a large (e.g. 100-hour) max.

Match the visual density of the existing `.wheel` `DatePicker` it replaces so
the form layout does not jump.

### Step 4: Migrate the two call sites to value-typed duration

The cleanest contract is for the picker to bind a `TimeInterval` (seconds),
matching `Entry.duration` directly — no `Date` round-trip.

- **AddEntry** (`AddEntryFormModel` + `AddEntryView`): the model currently
  stores `durationDate`. Add a stored `durationInSeconds`-backed property the
  picker binds to, and make `durationInSeconds` read from it (not from
  `durationDate`). Keep `draft()` and the `durationInSeconds == 0` validation
  behavior identical. The existing `convertsDurationToSeconds` test sets
  `durationDate` — **migrate that test** to set the new seconds-backed property
  (see Step 5 note). Keep `durationDate`/`EntryDurationConversion` only if still
  referenced; otherwise remove the now-dead `durationDate` and the unused
  `seconds(from:)` direction. Default the picker's `maxDuration` to **24 hours**
  here.
- **EntryDetail** (`EntryDetailView`): replace `EntryDurationPicker` with
  `DurationPickerView(duration: $entry.duration, maxDuration: …)`. Default
  `maxDuration` to **24 hours** for same-day edits. Delete the hand-rolled
  `durationAsDate` computed property (lines 19-39) — it is fully subsumed.

> Note: if you keep `Entry.duration` editable for *past* entries that may
> legitimately exceed 24 h, a hard 24 h cap on the detail screen would corrupt
> them on edit. If that case exists, pass a larger `maxDuration` on the detail
> screen or clamp only on user change. Flag the choice in the commit message;
  > do not silently truncate stored data.

**Verify**: `grep -rn "EntryDurationPicker\|durationAsDate" Hugo` → no matches.
`AddEntryView` shows the new wheel; `EntryDetailView` shows it and edits save.

### Step 5: Delete the old picker and extend tests

1. `git rm Hugo/Features/Entries/EntryDurationPicker.swift`.
2. `AddEntryFormModelTests` — update `convertsDurationToSeconds` and
   `durationRoundTrips` to the new seconds-backed API. Keep the round-trip
   parameter set `[0.0, 60.0, 5_400.0, 86_340.0]`.
3. New `HugoTests/Features/Entries/DurationPickerModelTests.swift`:
   - `minutesSnapDownToInterval` — e.g. interval 15, set 23 min → 15.
   - `totalClampsToMaxDuration` — set beyond max → exactly max.
   - `minutesWheelLimitedAtMaxHour` — at max hour, minutes limited to remainder.
   - `intervalValidationRestrictsToAllowedValues` — 7 → falls back/clamps to 1/5/15.
   - `timeIntervalProjectionIsCorrect` — `totalMinutes * 60`.
   - `defaultIntervalIsOne` (reading no stored value → 1).
   - Mirror the existing `import Testing` / `@Test` / `#expect` style.

**Verify**: entry-tests-only command → all pass; count is (7 migrated) +
(≥6 new).

## Test plan

Covered in Step 5. The critical invariant: **every pre-existing
`AddEntryFormModelTests` behavior still passes** (validation, draft creation,
bible-studies floor, default-category preference), with only the
duration-source tests migrated to the new API. No behavior of `draft()` may
change.

Verification: full test command → `TEST SUCCEEDED`.

## Done criteria

ALL must hold:

- [ ] `grep -rn "EntryDurationPicker" Hugo` → no matches (file deleted)
- [ ] `grep -rn "durationAsDate" Hugo` → no matches
- [ ] No `.hourAndMinute` `DatePicker` remains as a *duration* input (`grep -rn "hourAndMinute" Hugo` → only legitimate time-of-day uses, if any)
- [ ] `DurationPickerView` takes `maxDuration` as a property; AddEntry passes 24 h
- [ ] Settings offers 1 / 5 / 15 minute intervals; choice persists and is honored
- [ ] Minutes snap to the interval; total clamps to `maxDuration`
- [ ] All 7 migrated `AddEntryFormModelTests` pass; ≥6 new `DurationPickerModelTests` pass
- [ ] `draft()` behavior unchanged (same validation, same output for equivalent input)
- [ ] `Scripts/verify.sh` exits 0
- [ ] `plans/README.md` row for 026 updated

## STOP conditions

Stop and report if:

- Migrating a call site would **truncate an existing stored `Entry.duration`**
  that exceeds the chosen `maxDuration`. Do not corrupt data; re-decide the cap.
- The two-wheel `Picker` approach cannot prevent scrolling minutes past
  `maxDuration` cleanly (e.g. the wheels desync). Fall back to a single wheel of
  total-minutes or a validated range, and report the tradeoff.
- A pre-existing `AddEntryFormModelTests` test fails after migration in a way
  that indicates a real behavior change (not just an API rename). That is a
  regression — revert and report.
- Reading `minuteInterval` from `@AppStorage` inside the view proves untestable;
  hoist it to an injected parameter with the storage read at the call site.
- The new picker cannot be made accessible (labeled wheels) to the standard set
  by plan 020.

## Maintenance notes

- **Backfill hook**: the entire point of `maxDuration` as a property is the
  future backfill-earlier-reports feature. When that lands, pass a large
  ceiling (e.g. a full report period's hours) instead of 24 h — no picker
  changes needed. Do not hardcode 24 h anywhere inside `DurationPickerView`.
- `EntryDurationConversion` may become dead after this migration. If Step 4
  removes its last caller, delete it; otherwise leave it and note why.
- The minute-interval setting is a deliberate user-choice feature (granular vs.
  coarse). Keep the allowed set to exactly {1, 5, 15} unless the operator adds
  more; the model validates against drift.
- Two-wheel wheel pickers can be finicky about programmatic clamping while the
  user is mid-scroll on iOS 26. The Step 3 STOP condition exists for this —
  prefer correctness (can't exceed max) over keeping both wheels independently
  scrollable.
- If a future design wants the duration shown as a formatted string ("1 h 30 m")
  in the form row, reuse `ServiceDurationFormatter` rather than adding a new
  formatter.
- Reviewer should scrutinize: the clamping-at-max behavior and that no stored
  `Entry.duration` can be truncated.
