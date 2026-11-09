# Plan 099: Let users mix their own category color with a hue and a tone slider

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in "STOP conditions" happens, stop and report. Do not
> improvise. When done, update this plan's row in `plans/README.md`, unless a
> reviewer dispatched you and said they maintain the index.
>
> **Prerequisite**: plan 098 (SLN-287) must be DONE. Check:
> `test -f Hugo/Domain/CategoryColor.swift && test -f Hugo/Features/Categories/Views/CategoryColorPicker.swift && test -f Hugo/DesignSystem/Theme/CategoryColorStyle.swift`
> exits 0. If not, STOP.
>
> **Drift check (run first)**: this plan was written at `af030fb`, before
> plan 098 existed. Run
> `git log --oneline af030fb..HEAD -- Hugo/Features/Categories Hugo/Domain/CategoryColor.swift Hugo/DesignSystem`.
> Expected: only plan 098's commits. Then compare the "Current state" excerpts
> (taken from plan 098's specification) with the live files. A mismatch in
> the signatures named there is a STOP condition.

## Status

- **Priority**: P3
- **Effort**: M + owner (device check of the sliders' feel and VoiceOver)
- **Risk**: LOW. No persistence change. A new generic slider control and changes to the category color row.
- **Depends on**: plans/098-category-color-presets.md (SLN-287)
- **Category**: direction
- **Planned at**: commit `af030fb`, 2026-11-09
- **Issue**: [SLN-308](https://linear.app/sebastianln/issue/SLN-308)

## Why this matters

Plan 098 offers Automatic and six preset colors for a category. Some users will want a color the presets don't have, for example to match a category to a color they already use elsewhere. This plan adds a color wheel button at the start of the row. Tapping it reveals two sliders under the swatches:

- **Hue** runs through every color.
- **Tone** goes from pale to strong in dark mode and from bright to deep in light mode.

The owner liked the same idea in another app (2026-11-09). It needs only two sliders, and every position gives a color that is easy to see, because `CategoryColor` already maps the tone per appearance and enforces a contrast floor.

Presets stay the first choice. The sliders are one tap away and hidden otherwise, which keeps the row simple for older users (`AGENTS.md` section 6, "Simplicity" and "Modularity").

## Current state

These files come from plan 098. Confirm each signature before you start.

- `Hugo/Domain/CategoryColor.swift`: `nonisolated struct CategoryColor: Hashable, Sendable` with `let hue: Double`, `let tone: Double` (both 0...1), `init(hue:tone:)` (clamps), `init?(storedHue:storedTone:)`, `enum Appearance { case light, dark }` and `func components(for: Appearance) -> Components`.
- `Hugo/DesignSystem/Theme/CategoryColorStyle.swift`:
  - `nonisolated struct CategoryColorStyle: ShapeStyle`, with `init(_ color: CategoryColor?)`; nil draws `.hugoAccent`.
  - `extension CategoryColor.Appearance { init(_ colorScheme: ColorScheme) }`.
  - `extension CategoryColor { func color(for appearance: Appearance) -> Color }`. Use this for gradient stops.
- `Hugo/Features/Categories/Domain/CategoryColorPreset.swift`: `CategoryColorPreset.all` (blue, indigo, purple, pink, orange, green) and `static func matching(_ color: CategoryColor?) -> CategoryColorPreset?` (within 0.001).
- `Hugo/Features/Categories/Views/CategoryColorPicker.swift`:
  - `struct CategoryColorPicker: View { @Binding var selection: CategoryColor? ... }`.
  - The body is a horizontal `ScrollView` holding an `HStack(spacing: HugoLayout.Spacing.compact)`: the Automatic swatch (`swatch(color: nil, name: "tracker.color.automatic")`), then one swatch per preset.
  - `isSelected(_:)` is true for nil when `selection == nil`, and otherwise when `CategoryColorPreset.matching(selection)?.color == color`. A custom color therefore selects no swatch today.
  - Each swatch is a `Button` that sets `selection`, with `.accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)`.
- The picker sits in a `Form` section in both `AddCategoryView` (bound to `@State private var color: CategoryColor?`) and `CategoryDetailView` (bound through `Binding(get: { tracker.categoryColor }, set: { tracker.setCategoryColor($0) })`). The section has the header `tracker.color.label` and the footer `tracker.color.footer`.
- **Exemplars in the repo** (present at `af030fb`):
  - Pure geometry in `DesignSystem` with its own tests: `Hugo/DesignSystem/Components/MarkedProgressBarGeometry.swift` and `HugoTests/DesignSystem/Components/MarkedProgressBarGeometryTests.swift`. Follow that split, so the math lives in a value type and the view only draws.
  - An adjustable VoiceOver control: `Hugo/Features/ServiceYear/Views/TheocraticYearPicker.swift:118-130`:

```swift
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("year.picker.a11y.label")
        .accessibilityValue(shownYear.spokenName)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                move(to: layout.year(shownYear, movedBy: 1), layout: layout)
            case .decrement:
                move(to: layout.year(shownYear, movedBy: -1), layout: layout)
            @unknown default:
                break
            }
        }
```

  - Motion that respects Reduce Motion: `.motion(Motion.presence, value:)` from `Hugo/DesignSystem/Motion/Motion.swift`.
- Theme tokens (`Hugo/DesignSystem/Theme/Theme.swift`): `HugoLayout.Size.minimumHitTarget = 44`, `HugoLayout.Size.colorSwatch = 32` (added by 098), and `HugoLayout.Spacing.compact = 8` / `.regular = 12`.
- `DesignSystem` admission rule (`AGENTS.md` section 7): a file there must name no feature type and import nothing from a feature. `GradientSlider` takes plain `ShapeStyle`s, `Text`s and a `Binding<Double>`, so it qualifies. Hue names are category-specific presentation, so they live in `Features/Categories/Domain`.

## Design (load-bearing)

- **Row layout.** The custom swatch comes first, then a thin vertical divider, then Automatic and the presets, as in the owner's reference screenshots. The custom swatch is a circle filled with an `AngularGradient` of 12 hues (tone 0.5, current appearance) and the same selection ring as the other swatches.
- **When the sliders show.**
  - They show when the custom swatch is selected, meaning the current selection is non-nil and matches no preset, or when the user just tapped the custom swatch.
  - Tapping Automatic or a preset hides them (`Motion.presence`).
  - Tapping the custom swatch keeps the current color if one is set, so the sliders start from the preset the user had. With Automatic selected, it starts from `CategoryColor(hue: 0.5, tone: 0.5)`.
- **Hue slider.** The track is a horizontal `LinearGradient` of 13 stops at hue `i / 12` (i in 0...12), using the current tone and the current appearance. The thumb is filled with the current color.
- **Tone slider.** The track is a `LinearGradient` of 5 stops at tone 0, 0.25, 0.5, 0.75 and 1, using the current hue and appearance.
- **Writes.** During a drag the picker keeps a local draft and writes `selection` once, when the drag ends. That avoids one SwiftData change per frame in `CategoryDetailView`, which binds straight to the synced model. A VoiceOver adjustment writes at once.
- **VoiceOver.**
  - Each slider is one adjustable element.
  - Hue: label "Hue", value a color name (Red, Orange, Yellow, Green, Teal, Blue, Purple, Pink), one step = 1/24.
  - Tone: label "Tone", value a whole percentage, one step = 0.1.
- **Footer.** While the sliders show, the section footer changes from `tracker.color.footer` to `tracker.color.custom.footer`, which explains the tone slider.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Layout rules | `Scripts/check-layout.sh` | exit 0 |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/GradientSliderGeometryTests -only-testing:HugoTests/CategoryHueNameTests -only-testing:HugoTests/CategoryColorPresetTests -only-testing:HugoTests/CategoryColorTests` | `** TEST SUCCEEDED **` |
| Catalog JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0 |
| Full gate (before the commit) | `Scripts/verify.sh` | exit 0 |
| Whitespace | `git diff --check` | exit 0 |

New files are picked up automatically (synchronized folders). Do not edit `project.pbxproj`.

## Scope

**In scope**:

- `Hugo/DesignSystem/Components/GradientSlider.swift` (create)
- `Hugo/DesignSystem/Components/GradientSliderGeometry.swift` (create)
- `Hugo/DesignSystem/Theme/Theme.swift` (two size tokens only)
- `Hugo/Features/Categories/Domain/CategoryHueName.swift` (create)
- `Hugo/Features/Categories/Views/CategoryColorPicker.swift`
- `Hugo/Features/Categories/Screens/AddCategoryView.swift` and `CategoryDetailView.swift` (footer only, see Step 5)
- `Hugo/Resources/Localizable.xcstrings` (the new keys in Step 6 only)
- `HugoTests/DesignSystem/Components/GradientSliderGeometryTests.swift` (create, next to `MarkedProgressBarGeometryTests.swift`)
- `HugoTests/Features/Categories/Domain/CategoryHueNameTests.swift` (create)

**Out of scope**:

- `CategoryColor`, its formulas or its contrast floor, `CategoryColorStyle`, `CategoryColorPreset` values, and anything in `Hugo/Persistence`. If the sliders produce a color that looks wrong, report it. Do not retune the model here.
- A hex field, a system `ColorPicker`, an opacity control or a "tinted background" option. The owner does not want them.
- Planner, list and picker drawing. They already use `CategoryColorStyle`.
- `Hugo.xcodeproj/project.pbxproj`, `.claude/` and `plans/` (the reviewer commits `plans/`).

## Git workflow

- Work on `main` directly. No branch, no worktree, no push.
- Stage explicit paths only.
- One commit after `Scripts/verify.sh` exits 0: `feat: let users mix a custom category color with hue and tone sliders`.

## Steps

### Step 1: Add the slider geometry (pure) and its tests

Create `Hugo/DesignSystem/Components/GradientSliderGeometry.swift`:

```swift
import CoreGraphics

/// Maps between a 0...1 value and a thumb position on a horizontal track.
/// The thumb's center stays a radius away from each end, so the whole thumb
/// stays on the track.
nonisolated struct GradientSliderGeometry: Equatable, Sendable {
    let trackWidth: CGFloat
    let thumbDiameter: CGFloat

    /// The thumb center's x for `value` (clamped to 0...1).
    func thumbCenterX(for value: Double) -> CGFloat

    /// The value for a touch at `x`, clamped to 0...1. On a track no wider
    /// than the thumb, returns 0.
    func value(forX x: CGFloat) -> Double

    /// `value` moved by `step` and clamped to 0...1. If `wraps` is true it
    /// wraps around instead (for hue: 1 + 1/24 becomes 1/24).
    static func stepped(_ value: Double, by step: Double, wraps: Bool) -> Double
}
```

The usable span is `trackWidth - thumbDiameter`. `thumbCenterX = thumbDiameter / 2 + span * value`, and `value(forX:) = (x - thumbDiameter / 2) / span`, clamped. When wrapping, use `value.truncatingRemainder(dividingBy: 1)` and add 1 to a negative result. A result of exactly 1.0 stays 1.0 after an increment from below, but a decrement from 0 gives `1 - step`.

**Verify**: `GradientSliderGeometryTests` pass (see Test plan).

### Step 2: Add the generic `GradientSlider` view

Add to `HugoLayout.Size` in `Theme.swift`:

```swift
        static let gradientSliderHeight: CGFloat = 36
        static let gradientSliderThumbRing: CGFloat = 4
```

Create `Hugo/DesignSystem/Components/GradientSlider.swift`:

```swift
import SwiftUI

/// A horizontal slider whose track is any style, such as a gradient. Drag or
/// tap anywhere on the track. VoiceOver adjusts it by `step`.
struct GradientSlider<Track: ShapeStyle, Thumb: ShapeStyle>: View {
    @Binding var value: Double
    let track: Track
    let thumb: Thumb
    let label: Text
    let valueText: Text
    var step: Double = 0.05
    var wraps = false
    /// True when a drag starts, false when it ends. Not called for VoiceOver
    /// adjustments, which change `value` directly.
    var onEditingChanged: (Bool) -> Void = { _ in }

    @ScaledMetric(relativeTo: .body) private var height = HugoLayout.Size.gradientSliderHeight
    @State private var isDragging = false

    var body: some View { ... }
}
```

Body requirements:

- A `GeometryReader` holding a `ZStack(alignment: .leading)`. The first layer is `Capsule().fill(track)`, with a 1 pt `Capsule().strokeBorder(.separator)` overlay so a pale track still has an edge in light mode.
- The second layer is the thumb: `Circle().fill(thumb)`, `frame(width: height - 2 * ring, height: height - 2 * ring)`, an overlay `Circle().strokeBorder(.white, lineWidth: ring)` padded so the ring sits outside the fill, and `.shadow(radius: 2)`. Position it with `.position(x: geometry.thumbCenterX(for: value), y: height / 2)`.
- Frame: `.frame(height: height)`, then `.frame(minHeight: HugoLayout.Size.minimumHitTarget)` and `.contentShape(Rectangle())`.
- Gesture: `DragGesture(minimumDistance: 0)`. On the first `onChanged`, set `isDragging = true` and call `onEditingChanged(true)`. On every change, set `value = geometry.value(forX: location.x)`. `onEnded` calls `onEditingChanged(false)` and sets `isDragging = false`.
- Accessibility: copy `TheocraticYearPicker`'s pattern, with `.accessibilityElement(children: .ignore)`, `.accessibilityLabel(label)` and `.accessibilityValue(valueText)`. Its `.accessibilityAdjustableAction` sets `value = GradientSliderGeometry.stepped(value, by: ±step, wraps: wraps)`.
- Add a `#Preview` with a red-to-blue `LinearGradient` track and a `@Previewable @State` value.

**Verify**: the focused test command builds and prints `** TEST SUCCEEDED **`, and `grep -rnE "Category|Tracker|Entry" Hugo/DesignSystem/Components/GradientSlider*.swift` prints nothing (the admission rule).

### Step 3: Add hue names for VoiceOver

Create `Hugo/Features/Categories/Domain/CategoryHueName.swift`:

```swift
import Foundation

/// A rough color name for a hue, spoken by VoiceOver on the hue slider.
nonisolated enum CategoryHueName: CaseIterable, Sendable {
    case red, orange, yellow, green, teal, blue, purple, pink

    /// Hue ranges (0...1): red below 0.04 or from 0.96, orange below 0.11,
    /// yellow below 0.19, green below 0.44, teal below 0.53, blue below 0.69,
    /// purple below 0.81, pink below 0.96.
    init(hue: Double)

    var name: LocalizedStringResource  // "tracker.color.hue.red" and so on
}
```

**Verify**: `CategoryHueNameTests` pass.

### Step 4: Add the custom swatch and the sliders to `CategoryColorPicker`

Change `CategoryColorPicker` as follows. Keep its public signature, `@Binding var selection: CategoryColor?`, unchanged.

1. Add state and environment:

```swift
    @Environment(\.colorScheme) private var colorScheme
    /// Set when the user taps the custom swatch, so the sliders stay open
    /// even while the color happens to match a preset.
    @State private var customIsOpen = false
    /// The color while a slider is dragged. Written to `selection` when the drag ends.
    @State private var draft: CategoryColor?
```

2. Add helpers:
   - `private var shown: CategoryColor? { draft ?? selection }`
   - `private var showsSliders: Bool { customIsOpen || (selection != nil && CategoryColorPreset.matching(selection) == nil) }`
3. Change `isSelected(_:)` so that Automatic and the presets are never selected while `showsSliders` is true.
4. Make the body a `VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular)`:
   - First the existing horizontal `ScrollView`. Its `HStack` starts with the custom swatch, then `Capsule().fill(.separator).frame(width: 2, height: swatchSize * 0.75).accessibilityHidden(true)`, then the existing Automatic and preset swatches.
   - Then, `if showsSliders`, two `GradientSlider`s with `.transition(.opacity)` and `.motion(Motion.presence, value: showsSliders)` on the `VStack`. The hue slider uses `wraps: true` and `step: 1.0 / 24`. The tone slider uses `step: 0.1`.
5. The custom swatch is a `Button` drawn like the others, filled with `AngularGradient(colors: (0...12).map { CategoryColor(hue: Double($0) / 12, tone: 0.5).color(for: .init(colorScheme)) }, center: .center)`. It is selected when `showsSliders` is true, and its accessibility label is `tracker.color.custom`. Its action:

```swift
        customIsOpen = true
        if selection == nil { selection = CategoryColor(hue: 0.5, tone: 0.5) }
```

6. Tapping Automatic or a preset sets `customIsOpen = false` and `draft = nil` before it sets `selection`.
7. Slider bindings. Hue example; tone is the same with `tone`:

```swift
    private var hueBinding: Binding<Double> {
        Binding(
            get: { shown?.hue ?? 0.5 },
            set: { newHue in
                let updated = CategoryColor(hue: newHue, tone: shown?.tone ?? 0.5)
                if draft != nil { draft = updated } else { selection = updated }
            })
    }
```

   `onEditingChanged` starts a drag with `draft = selection ?? CategoryColor(hue: 0.5, tone: 0.5)`. When the drag ends it does `selection = draft; draft = nil`. A VoiceOver adjustment happens while `draft` is nil, so it writes `selection` at once, which is intended.
8. Tracks and thumbs:
   - Hue track: `LinearGradient(colors: (0...12).map { CategoryColor(hue: Double($0) / 12, tone: shown?.tone ?? 0.5).color(for: appearance) }, startPoint: .leading, endPoint: .trailing)`.
   - Tone track: `LinearGradient(colors: [0, 0.25, 0.5, 0.75, 1].map { CategoryColor(hue: shown?.hue ?? 0.5, tone: $0).color(for: appearance) }, startPoint: .leading, endPoint: .trailing)`.
   - Both thumbs: `CategoryColorStyle(shown)`.
   - `appearance` is `CategoryColor.Appearance(colorScheme)`.
9. VoiceOver values:
   - Hue: `Text(CategoryHueName(hue: shown?.hue ?? 0.5).name)`.
   - Tone: `Text((shown?.tone ?? 0.5).formatted(.percent.precision(.fractionLength(0))))`.
   - Labels: `Text("tracker.color.hue")` and `Text("tracker.color.tone")`.
10. Expose `showsSliders` to the screens for the footer by adding `var onCustomChange: (Bool) -> Void = { _ in }`. Call it from `.onChange(of: showsSliders, initial: true) { _, new in onCustomChange(new) }`.
11. Update the `#Preview`s: add one with a custom color selected, `CategoryColor(hue: 0.5, tone: 0.3)`.

**Verify**: build succeeds (focused command). In the Xcode preview or the simulator, check by hand: tapping the wheel shows the sliders, and tapping Blue hides them. Report what you saw, because the executor cannot be sure of a visual result without looking.

### Step 5: Switch the footer while the sliders show

In `AddCategoryView` and `CategoryDetailView`:

- Add `@State private var colorIsCustom = false`.
- Pass `onCustomChange: { colorIsCustom = $0 }` to `CategoryColorPicker`.
- Change the section footer to `Text(colorIsCustom ? "tracker.color.custom.footer" : "tracker.color.footer")`.

Change nothing else in those files.

**Verify**: `git diff --stat -- Hugo/Features/Categories/Screens` shows only these two files with small changes (under 10 lines each).

### Step 6: Add the strings (English and Danish)

Add these keys with the same JSON shape as `tracker.color.label` (English and Danish `stringUnit`s with `"state": "translated"`, plus a comment):

| Key | English | Danish | Comment |
|---|---|---|---|
| `tracker.color.custom` | Custom Color | Egen farve | VoiceOver name of the color wheel swatch that opens the sliders. |
| `tracker.color.custom.footer` | Hue picks the color. Tone picks how light or deep it is, and Hugo adjusts it so it stays easy to see in light and dark mode. | Farvetone vælger farven. Nuance vælger, hvor lys eller dyb den er, og Hugo justerer den, så den er nem at se i både lys og mørk tilstand. | Footer under the category color sliders. |
| `tracker.color.hue` | Hue | Farvetone | VoiceOver label of the hue slider. |
| `tracker.color.tone` | Tone | Nuance | VoiceOver label of the tone slider. |
| `tracker.color.hue.red` | Red | Rød | Spoken hue name. |
| `tracker.color.hue.orange` | Orange | Orange | Spoken hue name. |
| `tracker.color.hue.yellow` | Yellow | Gul | Spoken hue name. |
| `tracker.color.hue.green` | Green | Grøn | Spoken hue name. |
| `tracker.color.hue.teal` | Teal | Blågrøn | Spoken hue name. |
| `tracker.color.hue.blue` | Blue | Blå | Spoken hue name. |
| `tracker.color.hue.purple` | Purple | Lilla | Spoken hue name. |
| `tracker.color.hue.pink` | Pink | Pink | Spoken hue name. |

**Verify**: catalog JSON check exits 0, and `python3 -I -c "import json;s=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'];print(sum(k.startswith('tracker.color.') for k in s))"` prints `21` (9 from plan 098 plus 12). Then `Scripts/verify.sh` exits 0 and `git diff --check` exits 0, and you can commit.

### Step 7 (owner, not the executor): device check

Report these to the owner as open items:

- Drag both sliders in light and dark mode on a device. The thumb follows the finger, and the tracks recolor as the other slider moves.
- Scroll the category screen by starting a swipe on a slider. If the slider jumps instead of the form scrolling, see Maintenance notes.
- Set a custom color, leave the screen, and come back. The wheel is still selected and the sliders are open.
- Pick a preset after a custom color. The sliders close.
- With VoiceOver, both sliders adjust by swiping up and down and speak a color name or a percentage.
- No CloudKit change is needed (no new fields).

## Test plan

Swift Testing throughout.

`GradientSliderGeometryTests` (model the file on the existing `MarkedProgressBarGeometry` tests):

- `thumbStaysOnTrack`: width 200, thumb 36. Value 0 gives center 18, value 1 gives 182, value 0.5 gives 100.
- `touchMapsToValueAndClamps`: x 18 gives 0, x 182 gives 1, x 100 gives 0.5, x -50 gives 0 and x 500 gives 1.
- `narrowTrackReturnsZero`: width 30 with thumb 36 gives 0 for any x.
- `steppingClamps`: `stepped(0.95, by: 0.1, wraps: false) == 1` and `stepped(0.05, by: -0.1, wraps: false) == 0`.
- `steppingWrapsForHue`: `stepped(1.0, by: 1.0 / 24, wraps: true)` is within 1e-9 of `1.0 / 24`, and `stepped(0, by: -1.0 / 24, wraps: true)` is within 1e-9 of `23.0 / 24`.

`CategoryHueNameTests`:

- One `@Test(arguments:)` over pairs: (0.0, red), (0.03, red), (0.04, orange), (0.15, yellow), (0.37, green), (0.5, teal), (0.6, blue), (0.68, blue), (0.78, purple), (0.9, pink), (0.96, red) and (1.0, red).
- `everyPresetHasTheExpectedName`: blue maps to blue, indigo to blue (0.68 < 0.69), purple to purple, pink to pink, orange to orange, and green to green.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] The focused test command prints `** TEST SUCCEEDED **`, including `GradientSliderGeometryTests` and `CategoryHueNameTests`
- [ ] `grep -rnE "Category|Tracker|Entry" Hugo/DesignSystem/Components/GradientSlider*.swift` prints nothing
- [ ] The catalog has 21 `tracker.color.*` keys, each with English and Danish
- [ ] `git diff --stat HEAD~1 -- Hugo/Domain Hugo/Persistence Hugo/DesignSystem/Theme/CategoryColorStyle.swift Hugo/Features/Categories/Domain/CategoryColorPreset.swift` prints nothing (the color model is untouched)
- [ ] `git status --short` shows nothing outside the Scope list (the owner's unstaged `project.pbxproj` excepted)
- [ ] `plans/README.md` row for 099 updated, and the owner told about Step 7

## STOP conditions

Stop and report if:

- The prerequisite check fails, or a signature in "Current state" differs from the live code.
- `GradientSlider` cannot be written without naming a category type. That would break the `DesignSystem` admission rule, so ask before moving it.
- A slider position produces a color that is hard to see. That is a model problem for `CategoryColor`, which this plan must not change.
- The drag gesture blocks the form from scrolling in the simulator, and `minimumDistance: 0` cannot be kept. Report it rather than picking another gesture design.
- Steps 4-5 seem to need a change to how `CategoryDetailView` stores the color (for example a new save call).

## Maintenance notes

- **Scroll conflict.** `DragGesture(minimumDistance: 0)` lets a tap set the value at once, like the owner's reference app. If testers find that a vertical swipe over a slider moves it, switch to `DragGesture(minimumDistance: 6)` plus `onTapGesture(coordinateSpace: .local)` for taps. That is a change to `GradientSlider` only.
- **Draft writes.** The picker writes the synced model once per drag, not once per frame. Keep that if the picker is reused elsewhere.
- **Hue names** are rough on purpose. The hue ranges in `CategoryHueName` are the only place to adjust them, and the tests list the boundaries.
- `GradientSlider` is generic. A future "Increase Contrast" variant of `CategoryColor` needs no change here, because the tracks are built from `CategoryColor.color(for:)`.
