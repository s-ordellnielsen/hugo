# Plan 022: Establish a small motion vocabulary and apply it to five moments

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for plan 022
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat d65afec..HEAD -- Hugo/Features/Overview Hugo/Features/Entries/EntryListView.swift Hugo/Features/Reports/SubmitReportView.swift Hugo/App`
> If any in-scope file changed, compare the "Current state" excerpts against
> the live code; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/020-accessibility-foundation.md
- **Category**: polish
- **Planned at**: commit `d65afec`, 2026-08-06

## Why this matters

This app needs **less** motion than most, and it is already close to right —
the restraint is deliberate and should be preserved. The actual gap is that one
transition was written and never fires, and four state changes teleport. Five
small additions close them, all under 400 ms, all on `opacity`/`transform` only.

There is also currently **no** `accessibilityReduceMotion` handling anywhere in
the app. This plan introduces the shared tokens that make honouring it
automatic, so future motion inherits it for free.

## Current state

### A. A transition that never fires

`Hugo/Features/Overview/MonthlyProgressCard.swift:18-22`:

```swift
Text("\(Int(value))")
    .font(.system(size: 80))
    .fontWeight(.heavy)
    .fontDesign(.rounded)
    .contentTransition(.numericText())
```

`.contentTransition` only animates inside an animation transaction. `value`
changes via `@Query` → `OverviewMetrics`, outside any transaction, so the hero
number swaps instantly. The intent is in the code; the trigger is missing.

The same pattern appears at `DefaultCategoryButton.swift:20`
(`.contentTransition(.symbolEffect(.replace))`) and
`PublisherStatusSelectionView.swift:24,64`.

### B. The reminder card teleports

`Hugo/Features/Overview/OverviewView.swift:38-50`:

```swift
ScrollView {
    VStack {
        if let reminderMonth {
            ReportReminderCard(month: reminderMonth)
            Spacer(minLength: 32)
        }
        MonthlyProgressCard(…)
```

Appears on the last day of the month and disappears on submit, with no bridge —
the whole page jumps.

### C. Rounding rule changes swap instantly

`Hugo/Features/Reports/SubmitReportView.swift:56-92` — changing the picker
swaps between three mutually exclusive rows (carried-out / rounded-up /
rounded-down) and rewrites every category's hour value with no transition.

### D. New entries appear with no bridge

`Hugo/Features/Entries/EntryListView.swift` — after plan 017 this is a
`LazyVStack` of `EntryRow`s. A row added from the Add Entry sheet pops in.

### E. Legacy spring form

`Hugo/Features/Overview/MonthlyProgressCircle.swift:19`:

```swift
.animation(.spring(response: 0.6, dampingFraction: 0.9), value: normalizedProgress)
```

This one is correct in *behavior* — it is the only working animation in the app
— but uses the pre-iOS-17 parameterization.

### Conventions

- Plan 020 created `Hugo/App/CardButtonStyle.swift` with the press feedback and
  the first `@Environment(\.accessibilityReduceMotion)` usage. Follow its shape.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan022 CODE_SIGNING_ALLOWED=NO` | `TEST SUCCEEDED` |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:
- `Hugo/App/Motion.swift` (create)
- `Hugo/Features/Overview/MonthlyProgressCard.swift`
- `Hugo/Features/Overview/MonthlyProgressCircle.swift`
- `Hugo/Features/Overview/OverviewView.swift`
- `Hugo/Features/Reports/SubmitReportView.swift`
- `Hugo/Features/Entries/EntryListView.swift`
- `Hugo/Features/Categories/DefaultCategoryButton.swift`

**Out of scope** (do NOT touch — these were considered and deliberately rejected):
- `Hugo/App/AppRootView.swift` tab switching. Core navigation, 100+ times/day;
  the system default is correct and anything added makes it feel slow.
- `Hugo/Features/SymbolPicker/SymbolPicker.swift` grid filtering. Retriggers on
  every keystroke — motion there reads as input lag.
- `Hugo/Features/ServiceYear/ServiceYearView.swift` paging `TabView`. Native
  paging physics already handle velocity and rubber-banding; a custom layer
  fights it.
- `Hugo/Features/Overview/CategoryProgressBreakdownView.swift` bar segments.
  Functional data the user opened the sheet to read; decoration hinders.
- `Hugo/Features/Entries/EntryDetailView.swift` Bible-studies stepper. Tens of
  taps per session; a transition there feels unresponsive.
- `Hugo/Features/Onboarding/OnboardingView.swift`. Its `.blurReplace` and
  `.animation(.smooth)` are dead because `isLoading` is never set — that is
  dead code, owned by plan 023, not a motion problem.
- Any new animation not listed in Steps 2–6. The cap for this plan is five.

## Git workflow

- Branch: `advisor/022-motion-vocabulary`
- One commit per step, message style: `` `022` Step N — <summary> ``
- Do NOT push or open a PR.

## Steps

### Step 1: Define the vocabulary

Create `Hugo/App/Motion.swift`:

```swift
import SwiftUI

/// The app's complete motion vocabulary. Four tokens, all under 400 ms.
/// If a new moment does not fit one of these, that is a signal the moment
/// probably should not animate — not a reason to add a fifth token.
enum Motion {
    /// Press feedback and other sub-200 ms acknowledgements.
    static let feedback: Animation = .easeOut(duration: 0.16)
    /// Value changes: numbers, swapped rows, recalculated totals.
    static let value: Animation = .smooth(duration: 0.25)
    /// Elements entering or leaving the layout.
    static let presence: Animation = .smooth(duration: 0.3)
    /// The progress fill — the one place a little physics is warranted.
    static let progress: Animation = .spring(duration: 0.6, bounce: 0.15)
}

extension View {
    /// Applies `animation` unless the user has asked for reduced motion, in
    /// which case a plain cross-fade is used. Gentler, never nothing.
    func motion<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }
}

private struct MotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? .easeInOut(duration: 0.2) : animation, value: value)
    }
}
```

**Verify**: `Scripts/verify.sh` → exit 0.

### Step 2: Activate the hero number transition

In `MonthlyProgressCard`, add `.motion(Motion.value, value: value)` to the
`Text("\(Int(value))")`. Nothing else changes — `.contentTransition(.numericText())`
is already there and starts working the moment it has a transaction.

Do the same for `DefaultCategoryButton.swift:18-20`: add
`.motion(Motion.feedback, value: tracker.isDefault)` so its
`.symbolEffect(.replace)` actually plays.

**Verify**: manual — add an entry and watch the Overview number roll rather
than snap. Toggle a category's default star and watch the symbol morph.

### Step 3: Give the reminder card an entrance and exit

In `OverviewView`:

```swift
if let reminderMonth {
    ReportReminderCard(month: reminderMonth)
        .transition(.opacity.combined(with: .move(edge: .top)))
    Spacer(minLength: 32)
}
```

and `.motion(Motion.presence, value: reminderMonth)` on the enclosing `VStack`.

`reminderMonth` is `YearMonth?`, which is `Hashable` and therefore `Equatable` —
it works as an animation value directly.

**Verify**: manual — submit the month's report from the reminder card; the card
slides up and fades rather than vanishing.

### Step 4: Transition the rounding-rule rows

In `SubmitReportView`, add `.motion(Motion.value, value: model.selectedRule)` to
the rounding `Section`, `.transition(.opacity)` to each of the three
mutually-exclusive rows, and `.contentTransition(.numericText())` to the hour
`Text` inside `computedRow(_:)`.

**Verify**: manual — switch between Up / Down / Transfer; the status row
cross-fades and category hours roll.

### Step 5: Bridge new entries into the list

In `EntryListView`:

```swift
ForEach(entries) { entry in
    EntryRow(entry: entry, selectedEntry: $selectedEntry)
        .transition(.move(edge: .top).combined(with: .opacity))
}
```

with `.motion(Motion.presence, value: entries.count)` on the `LazyVStack`.

Key on `entries.count`, not `entries` — the array identity changes on every
SwiftData refresh and would animate on unrelated edits.

**Verify**: manual — add an entry; the new row slides in from the top of the
list rather than appearing.

### Step 6: Modernize the progress spring

In `MonthlyProgressCircle`, replace

```swift
.animation(.spring(response: 0.6, dampingFraction: 0.9), value: normalizedProgress)
```

with

```swift
.motion(Motion.progress, value: normalizedProgress)
```

Same feel, current API, and it now honours Reduce Motion.

**Verify**: manual — the fill still animates smoothly; with Reduce Motion on it
cross-fades instead of springing.

## Test plan

Motion is not unit-testable and this plan adds no logic. Verification is the
build gate plus a recorded manual pass, twice: once with Reduce Motion **off**
and once **on** (Settings → Accessibility → Motion → Reduce Motion).

Fill this in the status row:

| Moment | Reduce Motion off | Reduce Motion on |
|---|---|---|
| Hero number changes | rolls | cross-fades |
| Default-category star | morphs | cross-fades |
| Reminder card appears/leaves | slides + fades | fades |
| Rounding rule switch | cross-fades, hours roll | cross-fades |
| New entry added | slides in | fades in |
| Progress fill | springs | eases |

Existing tests must pass unchanged.

## Done criteria

ALL must hold:

- [ ] `Hugo/App/Motion.swift` exists and defines exactly 4 tokens
- [ ] `grep -rn "\.animation(" Hugo | grep -v "Motion.swift" | grep -v CardButtonStyle` → no matches (all motion goes through `.motion(_:value:)`)
- [ ] `grep -rn "spring(response:" Hugo` → no matches
- [ ] `grep -rn "accessibilityReduceMotion" Hugo` → ≥ 2 matches (Motion.swift + CardButtonStyle.swift)
- [ ] `Scripts/verify.sh` exits 0
- [ ] The Reduce Motion matrix above is filled in, both columns pass
- [ ] Test count unchanged; all pass
- [ ] `git status` shows no files outside the in-scope list
- [ ] `plans/README.md` row for 022 updated

## STOP conditions

Stop and report if:

- `.motion(Motion.presence, value: entries.count)` animates on every SwiftData
  refresh rather than only on insert/delete. If keying on `count` is not stable,
  stop — the fix involves entry identity and is a design decision.
- Any animation exceeds 400 ms in practice, or a moment only "works" when made
  slower. That is the signal it should not animate at all.
- You find yourself wanting a fifth token.
- The `.transition` on `EntryRow` fights the `LazyVStack`'s lazy instantiation
  and produces flicker on scroll.
- Plan 020 has not landed (`CardButtonStyle.swift` missing) — the press
  feedback and this vocabulary are meant to share the Reduce Motion approach.

## Maintenance notes

- **New rule**: no raw `.animation(...)` in feature code. Use `.motion(_:value:)`
  so Reduce Motion is handled once, centrally.
- The four tokens are a budget, not a starting point. Adding a fifth should
  require a real argument.
- The out-of-scope list in this plan is a record of six places motion was
  considered and rejected. Re-read it before adding animation anywhere — it
  will usually already contain the answer.
- Reviewer should scrutinize: Step 5's animation key, which is the only one
  with a plausible over-trigger failure mode.
