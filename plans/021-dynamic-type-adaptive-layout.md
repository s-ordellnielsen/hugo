# Plan 021: Make the layout survive Dynamic Type, small screens, and iPad multitasking

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for plan 021
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat d65afec..HEAD -- Hugo/Features/Overview Hugo/Features/SymbolPicker/SymbolPicker.swift Hugo/Features/Categories Hugo/Features/Entries/EntryRow.swift Hugo/Features/ServiceYear`
> If any in-scope file changed, compare the "Current state" excerpts against
> the live code; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: plans/020-accessibility-foundation.md
- **Category**: a11y
- **Planned at**: commit `d65afec`, 2026-08-06

## Why this matters

`grep -rn "dynamicTypeSize\|ScaledMetric\|sizeCategory\|horizontalSizeClass" Hugo`
returns **zero** matches. Seven hardcoded `.font(.system(size:))` values run
from 11 pt to 80 pt and never scale. The Overview hero is a fixed **360 pt**
circle with its add-entry button placed at a magic `.offset(x: 128, y: 128)` —
that overflows a 320 pt-wide iPhone SE before Dynamic Type is even considered.
The symbol grid picks its column count from `UIDevice.current.userInterfaceIdiom`,
which is wrong in Slide Over and Stage Manager.

For an app whose stated audience skews older (`AGENTS.md` §6), Dynamic Type is
not a nicety — larger text is the single most-used accessibility setting on iOS.

## Current state

### A. The fixed hero circle

`Hugo/Features/Overview/MonthlyProgressCircle.swift:3-21`:

```swift
struct MonthlyProgressCircle: View {
    let progress: Double
    let maxValue: Double
    let marker: Double?
    @Environment(\.colorScheme) private var colorScheme
    private let size: CGFloat = 360
    …
        }.frame(width: size, height: size).clipShape(Circle())
```

`Hugo/Features/Overview/MonthlyProgressCard.swift:18-31`:

```swift
                Text("\(Int(value))")
                    .font(.system(size: 80))
                    .fontWeight(.heavy)
                    .fontDesign(.rounded)
                    .contentTransition(.numericText())
                MonthlyProgressStatusView(expected: expectedProgress, current: value)
            }
            Button(action: onAddEntry) { Label("entry.add.label", systemImage: "plus").padding(12) }.buttonBorderShape(
                .circle
            )
            .font(.largeTitle)
				.labelStyle(.iconOnly)
				.buttonStyle(.glass)
				.offset(x: 128, y: 128)
```

`marker` is declared but never rendered — note it, do not remove it here
(plan 023 owns dead code).

### B. Fixed font sizes

- `Hugo/Features/Entries/EntryRow.swift:42` — `.font(.system(size: 17))`
- `Hugo/Features/SymbolPicker/SymbolPicker.swift:85` — `.font(.system(size: 24))`
- `Hugo/Features/ServiceYear/TheocraticYearTotalsView.swift:31` — `.font(.system(size: 11))`
- `Hugo/Features/ServiceYear/ServiceYearPageView.swift:40` — `.font(.system(size: 40))`
- `Hugo/Features/Overview/MonthlyProgressCard.swift:19` — `.font(.system(size: 80))`
- `Hugo/Features/Categories/CategoryDetailView.swift:30` — `.font(.system(size: 48))`
- `Hugo/Features/Categories/AddCategoryView.swift:27` — `.font(.system(size: 48))`

### C. Fixed tile sizes

`AddCategoryView.swift:29` and `CategoryDetailView.swift:33,37` — `.frame(width: 128, height: 128)`.

### D. Idiom-based grid

`Hugo/Features/SymbolPicker/SymbolPicker.swift:27-30`:

```swift
private var columns: [GridItem] {
    let count = UIDevice.current.userInterfaceIdiom == .pad ? 8 : 4
    return Array(repeating: GridItem(.flexible(minimum: 70)), count: count)
}
```

### Conventions

- Prefer semantic text styles (`.title`, `.callout`, `.caption`) over
  `.font(.system(size:))`. Where a specific size is genuinely required, use
  `@ScaledMetric` so it tracks the user's setting.
- Layout constants that must scale get `@ScaledMetric`; layout constants that
  must *not* (hairlines, corner radii) stay literal.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan021 CODE_SIGNING_ALLOWED=NO` | `TEST SUCCEEDED` |
| Small-screen build | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' -derivedDataPath /tmp/HugoPlan021SE CODE_SIGNING_ALLOWED=NO` | `BUILD SUCCEEDED` |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:
- `Hugo/Features/Overview/MonthlyProgressCircle.swift`
- `Hugo/Features/Overview/MonthlyProgressCard.swift`
- `Hugo/Features/Overview/OverviewView.swift`
- `Hugo/Features/Entries/EntryRow.swift`
- `Hugo/Features/SymbolPicker/SymbolPicker.swift`
- `Hugo/Features/ServiceYear/TheocraticYearTotalsView.swift`
- `Hugo/Features/ServiceYear/ServiceYearPageView.swift`
- `Hugo/Features/Categories/CategoryDetailView.swift`
- `Hugo/Features/Categories/AddCategoryView.swift`

**Out of scope** (do NOT touch):
- Accessibility labels/traits — plan 020 added them; do not restate or move them.
- Animations — plan 022.
- Dead code including `MonthlyProgressCircle.marker` — plan 023.
- Colour and contrast. Worth a separate pass; not this one.

## Git workflow

- Branch: `advisor/021-dynamic-type-adaptive-layout`
- One commit per step, message style: `` `021` Step N — <summary> ``
- Do NOT push or open a PR.

## Steps

### Step 1: Make the hero circle fit its container

Replace the hardcoded `size` with a value derived from the available width, and
scale it with Dynamic Type up to a ceiling:

```swift
struct MonthlyProgressCircle: View {
    let progress: Double
    let maxValue: Double
    let marker: Double?

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .largeTitle) private var preferredSize: CGFloat = 360

    var body: some View {
        GeometryReader { proxy in
            let side = min(preferredSize, proxy.size.width)
            …
                .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 360)
    }
}
```

The exact shape is up to you, but these three properties must hold:
1. On a 320 pt-wide screen the circle never exceeds the readable width minus
   the card's horizontal padding.
2. At `.accessibility3` and above it does not push the layout off-screen.
3. The existing gradient-fill behavior and its `normalizedProgress` maths are
   unchanged.

**Verify**: SE build command → `BUILD SUCCEEDED`. Manual on iPhone SE
simulator: Overview renders with no horizontal clipping at default text size
and at `.accessibility3` (Settings → Accessibility → Display & Text Size →
Larger Text).

### Step 2: Anchor the add-entry button instead of offsetting it

Replace `.offset(x: 128, y: 128)` with alignment inside the `ZStack`:

```swift
ZStack(alignment: .bottomTrailing) {
    // circle + centred VStack as today, wrapped so they still centre
    …
    Button(action: onAddEntry) { … }
        .padding(.trailing, 8)
        .padding(.bottom, 8)
}
```

The button must remain inside the circle's visual bounds at every text size,
and must stay a sibling of (not nested inside) the card button that plan 020
introduced.

**Verify**: manual at default and `.accessibility3` on both iPhone SE and
iPhone 17 Pro — the plus button stays on the circle and remains tappable.

### Step 3: Replace fixed font sizes

| File:line | Today | Change to |
|---|---|---|
| `MonthlyProgressCard.swift:19` | `.font(.system(size: 80))` | `.font(.system(size: heroSize, weight: .heavy, design: .rounded))` with `@ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 80`, plus `.minimumScaleFactor(0.5)` and `.lineLimit(1)` |
| `EntryRow.swift:42` | `.font(.system(size: 17))` | `.font(.body)` |
| `TheocraticYearTotalsView.swift:31` | `.font(.system(size: 11))` | `.font(.caption2)` |
| `ServiceYearPageView.swift:40` | `.font(.system(size: 40))` | `.font(.largeTitle)` |
| `SymbolPicker.swift:85` | `.font(.system(size: 24))` | `.font(.title2)` |
| `CategoryDetailView.swift:30` | `.font(.system(size: 48))` | `@ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 48` |
| `AddCategoryView.swift:27` | `.font(.system(size: 48))` | same as above |

**Verify**: `grep -rn "\.font(\.system(size:" Hugo` → matches only where a
`@ScaledMetric` variable is passed, never a literal.

### Step 4: Scale the icon tiles

In `AddCategoryView` and `CategoryDetailView`, replace `.frame(width: 128, height: 128)`
with `@ScaledMetric(relativeTo: .largeTitle) private var tileSize: CGFloat = 128`
and `.frame(width: tileSize, height: tileSize)`.

**Verify**: manual at `.accessibility3` — the icon and its tile grow together
and the tile does not clip the glyph.

### Step 5: Drive the symbol grid from the size class

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass
@ScaledMetric(relativeTo: .title2) private var minimumCellWidth: CGFloat = 70

private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: minimumCellWidth), spacing: 12)]
}
```

`.adaptive` removes the need for a count entirely and is correct in Slide Over,
Stage Manager, and at every text size. Keep `horizontalSizeClass` only if you
find a case `.adaptive` handles badly; otherwise delete the `UIDevice` import
path.

**Verify**: `grep -rn "UIDevice" Hugo` → no matches. Manual on iPad: the picker
in Slide Over shows fewer columns than full-screen.

### Step 6: Clamp where clamping is honest

Some surfaces genuinely cannot render at `.accessibility5` — a three-column
totals row, for instance. For those, prefer reflowing over clamping, and clamp
only as a last resort:

- `MonthlyReportTotalsView` and `TheocraticYearTotalsView` use a three-column
  `HStack`. At `.accessibility3`+, switch to a `VStack` using
  `@Environment(\.dynamicTypeSize)` and `dynamicTypeSize.isAccessibilitySize`.
- Do **not** apply a blanket `.dynamicTypeSize(...(.accessibility3))` cap to the
  app. Capping is a last resort; if you reach for it, note exactly where and why
  in the status row.

**Verify**: manual at `.accessibility5` — the totals row stacks vertically and
all three numbers are readable.

## Test plan

Layout is not unit-testable here and there is no snapshot-test infrastructure —
do not add one in this plan. The verification is the build gate plus a recorded
manual matrix. Fill this table in the plan's status row:

| Device | Text size | Overview | Year | Add Category | Symbol picker |
|---|---|---|---|---|---|
| iPhone SE (3rd gen) | Default | | | | |
| iPhone SE (3rd gen) | accessibility3 | | | | |
| iPhone 17 Pro | Default | | | | |
| iPhone 17 Pro | accessibility5 | | | | |
| iPad (Slide Over) | Default | | | | |

Pass = no clipping, no overlap, every control reachable.

Existing tests must continue to pass unchanged — this plan touches no logic.

## Done criteria

ALL must hold:

- [ ] `grep -rn "UIDevice" Hugo` → no matches
- [ ] `grep -rn "\.font(\.system(size: [0-9]" Hugo` → no matches (literals gone)
- [ ] `grep -rn "offset(x: 128, y: 128)" Hugo` → no matches
- [ ] `grep -rn "ScaledMetric" Hugo | wc -l` → ≥ 5
- [ ] `grep -n "private let size: CGFloat = 360" Hugo/Features/Overview/MonthlyProgressCircle.swift` → no match
- [ ] SE build command → `BUILD SUCCEEDED`
- [ ] `Scripts/verify.sh` exits 0
- [ ] The manual matrix above is filled in and all cells pass
- [ ] Test count unchanged; all pass
- [ ] `plans/README.md` row for 021 updated

## STOP conditions

Stop and report if:

- `@ScaledMetric` inside `MonthlyProgressCircle` combined with the `GeometryReader`
  produces a layout loop (symptom: the view flickers or the console logs
  repeated layout passes). The fix is to move the metric to the parent card;
  if that also loops, stop.
- Making the circle flexible breaks the gradient fill's
  `normalizedProgress * size` maths so the fill no longer reaches the top at
  100%.
- Plan 020's card `Button` conversion has not landed — Step 2 assumes the
  add-entry button is already a sibling rather than nested.
- A surface cannot be made to work at `.accessibility5` without capping. Report
  which one; do not silently cap.

## Maintenance notes

- **New rule**: no literal `.font(.system(size:))` in this codebase. Semantic
  style, or `@ScaledMetric`.
- The manual matrix should be re-run whenever the Overview or Year layout
  changes; it is the only regression net for layout here.
- Snapshot tests would replace that matrix. Deliberately deferred — adding a
  snapshot dependency is a project-level decision and `plans/README.md` has a
  standing preference against new dependencies.
- Reviewer should scrutinize: Step 1 and Step 2 together on an iPhone SE. That
  screen is where the current layout actually breaks.
