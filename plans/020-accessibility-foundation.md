# Plan 020: Make the app usable with VoiceOver, Switch Control, and Full Keyboard Access

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for plan 020
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat d65afec..HEAD -- Hugo/Features/Overview Hugo/Features/Reports/MonthlyReportRow.swift Hugo/Features/ServiceYear/MonthlyReportEmptyRow.swift Hugo/Features/SymbolPicker Hugo/Features/Entries Hugo/Features/Reports/Domain/ServiceDurationFormatter.swift Hugo/Resources/Localizable.xcstrings`
> If any in-scope file changed, compare the "Current state" excerpts against
> the live code; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: LOW
- **Depends on**: plans/016-green-verification-gate.md, plans/017-user-visible-correctness.md
- **Category**: a11y
- **Planned at**: commit `d65afec`, 2026-08-06

## Why this matters

`grep -rn "accessibility" Hugo` returns **one** match in ~6,000 lines. There
are no labels, values, hints, or traits anywhere. `AGENTS.md` §6 states the
product principle directly:

> **Ease of use.** The app should be accessible to all, the user base ranges
> from around 13 to 70 years. As there will be a lot of older users, the app
> should always explain itself and make good use of accessibility features.

Concretely, today: the three primary cards are `.onTapGesture` on a
`ZStack`/`VStack`, so VoiceOver, Switch Control and Full Keyboard Access
**cannot activate them at all**; durations are spoken as "oh two colon three
zero"; and 52 symbol-picker buttons are unlabeled. Converting the cards to
`Button` also gives them a pressed state, which is the highest-leverage motion
improvement in the app — so it lands here rather than in the animation plan.

## Current state

### A. Cards that are not buttons

`Hugo/Features/Overview/MonthlyProgressCard.swift:10-34` — a `ZStack` with an
inner `Button`, tapped via a gesture on the container:

```swift
var body: some View {
    ZStack {
        MonthlyProgressCircle(progress: value, maxValue: monthlyGoal, marker: expectedProgress)
        VStack {
            Text(Date.now, format: .dateTime.month(.wide))
            …
            Text("\(Int(value))")
            MonthlyProgressStatusView(expected: expectedProgress, current: value)
        }
        Button(action: onAddEntry) { Label("entry.add.label", systemImage: "plus").padding(12) }
        …
    }
    .contentShape(Rectangle()).onTapGesture(perform: onShowDetails)
}
```

`Hugo/Features/Reports/MonthlyReportRow.swift:96-102` — same pattern, and it
also contains a `Menu`:

```swift
    .padding(24)
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(32)
    .tint(.primary)
    .onTapGesture {
        isExpanded.toggle()
    }
```

`Hugo/Features/ServiceYear/MonthlyReportEmptyRow.swift:55-66` — same, plus an
`.accessibilityElement(children: .contain)` that currently makes things worse:
it groups the card but the tap action still is not exposed.

### B. Durations spoken as digit pairs

`Hugo/Features/Reports/Domain/ServiceDurationFormatter.swift:3-9`:

```swift
nonisolated enum ServiceDurationFormatter {
    static func string(from duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int(duration.truncatingRemainder(dividingBy: 3600) / 60)
        return String(format: "%02d:%02d", hours, minutes)
    }
}
```

Used in `EntryRow:35`, `MonthlyReportRow:51,67`, `MonthlyReportTotalsView:8,10,12`,
`TheocraticYearTotalsView:11,17,24`, `MonthlyReportEntryListView:27`,
`CategoryProgressBreakdownView:28`, `SubmitReportView:41,69,78,87`.

### C. Unlabeled symbol grid

`Hugo/Features/SymbolPicker/SymbolPicker.swift:36-43,83-94` — 52 buttons whose
only content is an `Image(systemName:)`. `SymbolDefinition.name` holds exactly
the label they need.

### D. Selection conveyed by colour alone

`SymbolPicker.swift:88-93` (background colour), `CategoryPicker.swift:44-46`
(a checkmark image with no trait), `PublisherStatusSelectionView.swift:23`
and `OnboardingView.swift:37-42` (filled vs. empty circle).

### Conventions

- All user-facing strings are keys in `Hugo/Resources/Localizable.xcstrings`.
  Add new `a11y.*` keys with English values only; plan 024 fills Danish.
- Pure value logic lives in an `enum` namespace under the owning feature — see
  `Hugo/Features/Overview/MonthlyProgressStatus.swift` for the pattern.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan020 CODE_SIGNING_ALLOWED=NO` | `TEST SUCCEEDED` |
| Full gate | `Scripts/verify.sh` | exit 0 |
| Gesture audit | `grep -rn "onTapGesture" Hugo` | only on non-primary affordances (see Done criteria) |

## Scope

**In scope**:
- `Hugo/App/CardButtonStyle.swift` (create)
- `Hugo/Features/Overview/MonthlyProgressCard.swift`
- `Hugo/Features/Overview/MonthlyProgressCircle.swift`
- `Hugo/Features/Overview/CategoryProgressBreakdownView.swift`
- `Hugo/Features/Reports/MonthlyReportRow.swift`
- `Hugo/Features/ServiceYear/MonthlyReportEmptyRow.swift`
- `Hugo/Features/Reports/Domain/ServiceDurationFormatter.swift`
- `Hugo/Features/Entries/EntryRow.swift`
- `Hugo/Features/SymbolPicker/SymbolPicker.swift`
- `Hugo/Features/Categories/CategoryPicker.swift`
- `Hugo/Features/Settings/PublisherStatusSelectionView.swift`
- `Hugo/Features/Onboarding/OnboardingView.swift`
- `Hugo/Resources/Localizable.xcstrings`
- `HugoTests/Domain/ServiceDurationFormatterTests.swift`

**Out of scope** (do NOT touch):
- Font sizes, frame sizes, `@ScaledMetric` — plan 021 owns Dynamic Type. Adding
  labels here and scaling there keeps two large diffs separable.
- The five remaining animation suggestions — plan 022. Only the
  `CardButtonStyle` press feedback belongs here, because it is inseparable from
  the Button conversion.
- `Hugo/Features/SymbolPicker/Enums/SymbolSet.swift` and `Structs/SymbolDefinition.swift`
  — plan 019 owns those files.
- Danish translations.

## Git workflow

- Branch: `advisor/020-accessibility-foundation`
- One commit per step, message style: `` `020` Step N — <summary> ``
- Do NOT push or open a PR.

## Steps

### Step 1: Add a shared card button style

Create `Hugo/App/CardButtonStyle.swift`:

```swift
import SwiftUI

/// Press feedback for the app's tappable cards. Subtle by design: these are
/// occasional-frequency surfaces, so the scale is small and the curve short.
struct CardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(scale(for: configuration))
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
            .contentShape(Rectangle())
    }

    private func scale(for configuration: Configuration) -> CGFloat {
        guard !reduceMotion else { return 1 }
        return configuration.isPressed ? 0.97 : 1
    }
}

extension ButtonStyle where Self == CardButtonStyle {
    static var card: CardButtonStyle { CardButtonStyle() }
}
```

Under Reduce Motion the scale is suppressed but the button still works — the
guidance is *gentler*, not *nothing*, and here scale is the only motion so
suppressing it entirely is correct.

**Verify**: `Scripts/verify.sh` → exit 0.

### Step 2: Convert the three cards to buttons

For each of `MonthlyProgressCard`, `MonthlyReportRow`, `MonthlyReportEmptyRow`:

1. Wrap the card content in `Button(action: <the existing tap closure>) { … }`.
2. Apply `.buttonStyle(.card)`.
3. Remove the `.onTapGesture { … }`.
4. Keep the nested `Button`/`Menu` **outside** the card button's label. SwiftUI
   does not support a button inside a button's label; hoist the inner control
   into an overlay sibling instead:

```swift
ZStack(alignment: .topTrailing) {
    Button(action: onShowDetails) { cardContent }
        .buttonStyle(.card)
    menuOrAddButton          // sibling, not a descendant
}
```

5. Add accessibility to the card button:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel(Text("a11y.card.month-progress.\(monthName)"))
.accessibilityValue(Text("a11y.card.month-progress.value.\(Int(value))"))
.accessibilityHint(Text("a11y.card.month-progress.hint"))
```

with equivalents for the two month rows
(`a11y.card.month-report.*`, `a11y.card.month-empty.*`). Suggested English:

| Key | English |
|---|---|
| `a11y.card.month-progress.%@` | `%@ progress` |
| `a11y.card.month-progress.value.%lld` | `%lld hours this month` |
| `a11y.card.month-progress.hint` | `Opens the detailed report` |
| `a11y.card.month-report.%@` | `%@ report` |
| `a11y.card.month-report.hint` | `Opens the month's entries` |
| `a11y.card.month-empty.%@` | `%@, no entries` |
| `a11y.card.month-empty.hint` | `Adds an entry to this month` |

6. In `MonthlyReportEmptyRow`, replace the existing
   `.accessibilityElement(children: .contain)` with `.combine` on the button —
   `.contain` was grouping without exposing the action.

**Verify**: `grep -rn "onTapGesture" Hugo` → no matches in
`MonthlyProgressCard.swift`, `MonthlyReportRow.swift`, `MonthlyReportEmptyRow.swift`.
Manual with VoiceOver on: swipe to each card — it announces label + value +
hint and double-tap activates it. Manual with Full Keyboard Access: Tab reaches
each card and Space activates it.

### Step 3: Make durations speak like durations

Add a spoken form next to the display form, keeping the `HH:MM` visual output
byte-identical:

```swift
nonisolated enum ServiceDurationFormatter {
    /// Compact display form, e.g. "02:30". Unchanged.
    static func string(from duration: TimeInterval) -> String {
        let clamped = max(duration, 0)
        let hours = Int(clamped / 3600)
        let minutes = Int(clamped.truncatingRemainder(dividingBy: 3600) / 60)
        return String(format: "%02d:%02d", hours, minutes)
    }

    /// Spoken form for VoiceOver, e.g. "2 hours, 30 minutes", localized.
    static func accessibilityString(from duration: TimeInterval, locale: Locale = .current) -> String {
        let clamped = max(duration, 0)
        let hours = Int(clamped / 3600)
        let minutes = Int(clamped.truncatingRemainder(dividingBy: 3600) / 60)
        var style = Duration.UnitsFormatStyle(
            allowedUnits: [.hours, .minutes],
            width: .wide
        )
        style.locale = locale
        return Duration.seconds(hours * 3600 + minutes * 60).formatted(style)
    }
}
```

Note the added `max(duration, 0)` — negative durations currently render as
`-1:-30`. Then, at each of the display sites listed in "Current state B", add:

```swift
Text(ServiceDurationFormatter.string(from: entry.duration))
    .accessibilityLabel(ServiceDurationFormatter.accessibilityString(from: entry.duration))
```

**Verify**: `grep -c "accessibilityString(from:" Hugo` → at least 10.
`HugoTests/Domain/ServiceDurationFormatterTests.swift` (5 existing tests) → all
pass unchanged, proving the display form did not move.

### Step 4: Label the symbol grid and expose selection state

In `SymbolPicker.symbolButton(_:)`, add:

```swift
.accessibilityLabel(Text(symbol.name))
.accessibilityAddTraits(selectedSymbol == symbol.id ? [.isButton, .isSelected] : .isButton)
```

Do the same `.isSelected` treatment in:
- `CategoryPicker.swift:30-49` — the row `Button`, selected when `selection?.id == tracker.id`
- `PublisherStatusSelectionView.swift:19-37` — selected when `currentStatus == status.id`
- `OnboardingView.swift:33-69` — selected when `currentStatus == status.id`

For all four, also confirm the visual checkmark/fill is not the *only* signal
once `.isSelected` is set — it no longer is.

**Verify**: `grep -rn "isSelected" Hugo` → 4 matches.
Manual with VoiceOver: in the symbol picker, each cell announces its name and
the chosen one announces "selected".

### Step 5: Group compound rows so they read as one thing

Several rows currently read as three separate elements. Combine them:

- `EntryRow.swift` — the whole row button:
  `.accessibilityElement(children: .combine)`, then
  `.accessibilityLabel` composing category name + duration + date, and
  `.accessibilityValue` for the Bible-studies count when non-zero (currently a
  bare `book` glyph plus a number, which reads as "book 2").
  Suggested key `a11y.entry.bible-studies.%lld` → `%lld Bible studies`.
- `CategoryProgressBreakdownView.swift:14-32` — the proportional bar is a
  `GeometryReader` of unlabeled `Rectangle`s. Add
  `.accessibilityElement(children: .ignore)` plus a single
  `.accessibilityLabel("a11y.breakdown.bar")` and an `.accessibilityValue`
  summarising the top categories; the per-category rows below already carry the
  same information in text form.
- `MonthlyProgressCircle.swift` — `.accessibilityHidden(true)`. It is decorative;
  the value is announced by the card in Step 2.

**Verify**: `Scripts/verify.sh` → exit 0. Manual with VoiceOver: one swipe
moves past an entry row, not three.

### Step 6: Audit what is left

Run `grep -rn "onTapGesture" Hugo` and confirm every remaining match is a
non-primary affordance with a keyboard/VoiceOver-reachable equivalent. Run
`grep -rn "Image(systemName:" Hugo | wc -l` and spot-check that every
*interactive* icon has either a `Label` with text or an `accessibilityLabel`.

**Verify**: both greps reviewed; findings recorded in the plan's status row.

## Test plan

`HugoTests/Domain/ServiceDurationFormatterTests.swift` (5 existing tests; model
after them):

- `accessibilityStringSpellsOutHoursAndMinutes` — 9000 s → contains "2" and
  "30" and is longer than 8 characters (i.e. not the `HH:MM` form).
- `accessibilityStringForWholeHours` — 7200 s → non-empty, does not crash.
- `displayStringClampsNegativeToZero` — `-60` → `"00:00"`.
- `accessibilityStringClampsNegativeToZero` — `-60` → same as `0`.
- `displayStringIsUnchangedForKnownValues` — regression pin: 0 → `"00:00"`,
  3600 → `"01:00"`, 5400 → `"01:30"`, 359_999 → `"99:59"`.

Verification: test command → `TEST SUCCEEDED`, 5 more tests than before.

## Done criteria

ALL must hold:

- [ ] `grep -rn "onTapGesture" Hugo/Features/Overview/MonthlyProgressCard.swift Hugo/Features/Reports/MonthlyReportRow.swift Hugo/Features/ServiceYear/MonthlyReportEmptyRow.swift` → no matches
- [ ] `grep -rn "buttonStyle(.card)" Hugo` → 3 matches
- [ ] `grep -rn "accessibilityLabel\|accessibilityValue\|accessibilityHint\|accessibilityAddTraits" Hugo | wc -l` → ≥ 25
- [ ] `grep -n "accessibilityString" Hugo/Features/Reports/Domain/ServiceDurationFormatter.swift` → present
- [ ] All new `a11y.*` keys exist in `Localizable.xcstrings` with English values
- [ ] `Scripts/verify.sh` exits 0
- [ ] Test count increased by 5; all pass
- [ ] `git status` shows no files outside the in-scope list
- [ ] `plans/README.md` row for 020 updated

## STOP conditions

Stop and report if:

- Wrapping a card in `Button` produces a nested-button warning or the inner
  `Menu` stops opening. The overlay-sibling shape in Step 2 is the intended
  fix; if it does not work for `MonthlyReportRow` specifically (it has a `Menu`
  in its header row), stop rather than removing the menu.
- `Duration.UnitsFormatStyle` is unavailable or produces English output in a
  Danish locale — the fallback is a manual localized-key approach and that is a
  design decision.
- Converting `MonthlyProgressCard` to a Button breaks the `.offset(x: 128, y: 128)`
  add-entry button's hit area. Plan 021 replaces that offset; if it blocks you
  here, stop and re-sequence rather than fixing the layout in this plan.
- Any existing test fails.

## Maintenance notes

- **New rule for this codebase**: a tappable surface is a `Button`, never an
  `.onTapGesture` on a container. `.onTapGesture` is acceptable only on a
  decorative element that also has a real control.
- `ServiceDurationFormatter` now has two outputs. Anywhere a duration is shown,
  both must be used — display for the eye, `accessibilityString` for the label.
- The `a11y.*` key namespace is new. Keep it; it makes the catalog auditable.
- Deliberately deferred to plan 021: Dynamic Type, `@ScaledMetric`, and the
  fixed 360 pt circle that overflows an iPhone SE.
- Deliberately deferred to plan 022: the five remaining animation suggestions.
- Reviewer should scrutinize: Step 2's nested-control hoisting on
  `MonthlyReportRow`, which is the trickiest conversion of the three.
