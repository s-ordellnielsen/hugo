# Plan 100: Make category colors in light mode as bright as the system colors

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in "STOP conditions" happens, stop and report. Do not
> improvise. When done, update this plan's row in `plans/README.md`, unless a
> reviewer dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat ae993a7..HEAD -- Hugo/Domain/CategoryColor.swift HugoTests/Domain/CategoryColorTests.swift`
> Expected: no output. Otherwise compare the excerpts below with the live
> files; a mismatch is a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S + owner (look at the colors on a device)
- **Risk**: LOW. One pure function and its tests. No stored data, no schema, no UI layout.
- **Depends on**: plans 098 and 099 (DONE)
- **Category**: direction
- **Planned at**: commit `ae993a7`, 2026-11-10
- **Issue**: [SLN-309](https://linear.app/sebastianln/issue/SLN-309)

## Why this matters

The owner tested plans 098 and 099 on a device. The dark-mode category colors look right, but light mode is much darker than Apple's system colors. The preset blue, for example, is `#265DB0` (a navy) where the system blue is `#007AFF`. The cause is the light-mode formula in `CategoryColor.components(for:)`: its brightness falls to 0.69 at the presets' tones, and the 2:1 contrast floor darkens it further.

This plan brightens the light-mode formula and lowers the light-mode contrast floor to 1.8:1. Apple's own orange (`#FF9500`), green (`#34C759`) and Hugo's accent mint (`#00C7BE`) measure 1.97, 1.99 and 1.90 against `#F2F2F7`, so 1.8 permits system-like colors and still stops near-white yellows. **Dark mode must not change at all**, because the owner likes it as it is. The stored hue and tone do not change, so presets and custom colors keep their values and only look brighter.

The advisor compared candidate formulas by perceived lightness (CIE L\*) against the system colors (higher is lighter):

| Preset (hue, tone) | System color, L\* | Now, L\* | After this plan, L\* |
|---|---|---|---|
| Blue (0.60, 0.55) | `#007AFF`, 53 | `#265DB0`, 40 | `#3A7EE3`, 53 |
| Indigo (0.68, 0.50) | `#5856D6`, 44 | `#3429B5`, 28 | `#4C3FE6`, 39 |
| Purple (0.78, 0.50) | `#AF52DE`, 52 | `#8829B5`, 38 | `#B03FE6`, 50 |
| Pink (0.90, 0.45) | `#FF2D55`, 56 | `#BA2B81`, 44 | `#E844A6`, 56 |
| Orange (0.07, 0.45) | `#FF9500`, 71 | `#BA672B`, 52 | `#E88944`, 66 |
| Green (0.37, 0.55) | `#34C759`, 71 | `#26B044`, 63 | `#35CF57`, 73 |

## Current state

`Hugo/Domain/CategoryColor.swift` (from plan 098):

- Line 22: `static let minimumContrast = 2.0`, used by both appearances.
- Lines 42-56, the light branch:

```swift
    /// The HSB components for one appearance, nudged away from the reference
    /// backgrounds when the contrast would be below `minimumContrast`.
    func components(for appearance: Appearance) -> Components {
        switch appearance {
        case .light:
            var saturation = 0.70 + 0.15 * tone
            var brightness = 0.92 - 0.42 * tone
            while brightness > 0.2,
                !Self.meetsFloor(
                    hue: hue, saturation: saturation, brightness: brightness, backgrounds: Self.lightBackgrounds)
            {
                brightness -= 0.02
            }
            return Components(hue: hue, saturation: saturation, brightness: brightness)
        case .dark:
            var saturation = 0.12 + 0.68 * tone
            var brightness = 1.00 - 0.10 * tone
            while !Self.meetsFloor(
                hue: hue, saturation: saturation, brightness: brightness, backgrounds: Self.darkBackgrounds)
```

- Lines 123-130, the floor check:

```swift
    private static func meetsFloor(
        hue: Double, saturation: Double, brightness: Double, backgrounds: [Double]
    ) -> Bool {
        let rgbValue = rgb(Components(hue: hue, saturation: saturation, brightness: brightness))
        let luminance = relativeLuminance(red: rgbValue.red, green: rgbValue.green, blue: rgbValue.blue)
        return backgrounds.allSatisfy { contrastRatio(luminance, $0) >= minimumContrast }
    }
```

`HugoTests/Domain/CategoryColorTests.swift`:

- `blueMatchesTheFormulaInBothAppearances` expects light saturation `0.7825` and brightness `0.689`, and dark `0.494` / `0.945`.
- `faintYellowIsDarkenedInLightMode` expects `yellow.brightness < 0.92`.
- `everyColorMeetsTheContrastFloor` compares both appearances with `CategoryColor.minimumContrast` (lines 76 and 85).

Nothing else in the app references `minimumContrast` (`grep -rn minimumContrast Hugo HugoTests` lists only these lines).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/CategoryColorTests -only-testing:HugoTests/CategoryColorPresetTests -only-testing:HugoTests/CategoryHueNameTests` | `** TEST SUCCEEDED **` |
| Full gate (before the commit) | `Scripts/verify.sh` | exit 0 |
| Whitespace | `git diff --check` | exit 0 |

## Scope

**In scope** (only these two files):

- `Hugo/Domain/CategoryColor.swift`
- `HugoTests/Domain/CategoryColorTests.swift`

**Out of scope**:

- The dark branch of `components(for:)`, `darkBackgrounds`, and every dark-mode number. They must stay byte-identical.
- `CategoryColorPreset` hue and tone values. Changing them would also change dark mode.
- `lightBackgrounds`, `rgb`, `relativeLuminance`, `contrastRatio`.
- Any view, persistence or catalog file.
- `Hugo.xcodeproj/project.pbxproj`, `.claude/`, `plans/` and the owner's `Changelog/` changes. Never stage them.

## Git workflow

- Work on `main`. No branch, no worktree, no push. Stage the two in-scope files by path.
- One commit after `Scripts/verify.sh` exits 0: `fix: make light-mode category colors as bright as the system colors`.

## Steps

### Step 1: Split the contrast floor per appearance

In `CategoryColor.swift`, replace `static let minimumContrast = 2.0` and its doc comment with:

```swift
    /// The lowest contrast ratio against any light-mode reference background.
    /// Apple's orange, green and mint measure about 1.9-2.0 against
    /// systemGroupedBackground, so 1.8 allows system-like colors and still
    /// darkens near-white ones.
    static let lightMinimumContrast = 1.8

    /// The lowest contrast ratio against any dark-mode reference background.
    static let darkMinimumContrast = 2.0
```

Give `meetsFloor` a `minimumContrast: Double` parameter and use it in place of the old static (`contrastRatio(luminance, $0) >= minimumContrast`). Pass `minimumContrast: Self.lightMinimumContrast` from the light branch and `minimumContrast: Self.darkMinimumContrast` from the dark branch. Update the `components(for:)` doc comment to say "below that appearance's minimum contrast".

### Step 2: Brighten the light formula

In the light branch only, change the two starting lines to:

```swift
            let saturation = 0.55 + 0.35 * tone
            var brightness = 1.00 - 0.20 * tone
```

`saturation` becomes `let`, because the light loop never changes it. Leave the loop (`while brightness > 0.2, ... brightness -= 0.02`) and the whole dark branch unchanged.

**Verify**: `git diff -U0 Hugo/Domain/CategoryColor.swift | grep -E '^[-+].*(0\.12|0\.68|1\.00 - 0\.10|darkBackgrounds)'` prints only the dark branch's `meetsFloor(...darkBackgrounds...)` call, removed and re-added with the extra `minimumContrast: Self.darkMinimumContrast` argument, or nothing. No dark-mode number may change.

### Step 3: Update the tests

In `CategoryColorTests.swift`:

1. `blueMatchesTheFormulaInBothAppearances`: change the light expectations to saturation `0.7425` and brightness `0.89`. Keep the hue and all dark expectations (`0.494`, `0.945`). Blue is not darkened by the floor (it measures 3.57:1).
2. `faintYellowIsDarkenedInLightMode`: change `#expect(yellow.brightness < 0.92)` to `#expect(yellow.brightness < 1.0)`. The formula starts at 1.0 for tone 0; the advisor's script shows the floor takes it to about 0.76.
3. `everyColorMeetsTheContrastFloor`: compare the light loop with `CategoryColor.lightMinimumContrast - 1e-9` and the dark loop with `CategoryColor.darkMinimumContrast - 1e-9`.
4. Add one test:

```swift
    @Test
    func lightPresetsAreBrighterThanBefore() {
        // Light-mode brightness at each preset's tone must start at 0.89 or more
        // (blue, green) and stay at least 0.80 after the floor.
        for preset in CategoryColorPreset.all {
            let light = preset.color.components(for: .light)
            #expect(light.brightness >= 0.80)
        }
    }
```

   The advisor's script gives these preset brightnesses: blue 0.89, indigo 0.90, purple 0.90, pink 0.91, orange 0.91, green 0.81 (green is darkened from 0.89 by the floor). If a value falls below 0.80, STOP and report it. Do not change the threshold.

**Verify**: the focused test command prints `** TEST SUCCEEDED **`, then `Scripts/verify.sh` exits 0, `git diff --check` exits 0, and you commit.

## Test plan

Covered in Step 3: the updated formula values, the per-appearance floor across 48 hues × 11 tones, and a new check that every preset is bright in light mode. The dark expectations stay as they are, which shows dark mode is unchanged.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -rn "CategoryColor.minimumContrast\|static let minimumContrast" Hugo HugoTests` prints nothing
- [ ] `git diff HEAD~1 --stat` lists only `Hugo/Domain/CategoryColor.swift` and `HugoTests/Domain/CategoryColorTests.swift`
- [ ] The dark expectations in `blueMatchesTheFormulaInBothAppearances` are still `0.494` and `0.945`
- [ ] `plans/README.md` row for 100 updated

## STOP conditions

- The drift check shows changes and the excerpts no longer match.
- Any test fails other than the expectations Step 3 changes, especially a dark-mode one.
- A preset's light brightness is below 0.80.
- The change seems to need any file outside the two in scope.

## Maintenance notes

- If light mode now looks too bright or too faint for some hue, tune only the light formula (`0.55 + 0.35 * tone`, `1.00 - 0.20 * tone`) or `lightMinimumContrast`. Dark mode stays independent.
- The light formula still deepens with tone, so plan 099's tone slider keeps working: in light mode it now goes from a light `#73ABFF`-like blue to a deep `#145ECC`-like blue at hue 0.6.
- Indigo stays a little darker than the system indigo (L\* 39 vs 44), because blue-violet hues look darker at the same HSB values. Tune the preset's tone only if the owner asks, and remember that it also changes dark mode.
