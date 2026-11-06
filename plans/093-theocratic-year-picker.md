# Plan 093: Jump to a theocratic year from the Year tab's title

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat b5f2177..HEAD -- Hugo/Features/ServiceYear/Screens/ServiceYearView.swift Hugo/Features/ServiceYear/Domain/TheocraticYear.swift Hugo/DesignSystem/Theme/Theme.swift Hugo/Resources/Localizable.xcstrings`
> Expected: no output, or only `Localizable.xcstrings` (other plans add strings to it). If any Swift file is listed, compare the "Current state" excerpts against the live code. On a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M (+ owner check on device, which decides whether the strip stays)
- **Risk**: MED (custom scroll snapping and a toolbar popover; no data or schema change)
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `b5f2177`, 2026-11-06
- **Issue**: [SLN-303](https://linear.app/sebastianln/issue/SLN-303)
- **Replaces**: plan 088 (cancelled; it jumped to a month, the owner wants to jump to a year)

## Why this matters

The Year tab pages sideways between theocratic years, one swipe per year. A publisher who wants to look at a year several years back has to swipe through every year in between. Today that is at most a year or two, but the owner plans a data import, which will add many past years at once.

This plan makes the year title in the navigation bar ("2026/2027") a button. Tapping it opens a small popover with a strip of calendar years, for example `2025 [2026 / 2027] 2028`. A rounded band in the middle holds the two calendar years of one theocratic year. A flick glides through several years with momentum and settles with a whole theocratic year in the band. When the strip comes to rest, the Year tab behind it shows that year.

The owner chose this custom strip over a plain `Menu` on 2026-11-06, on the condition that it is tried on device first. If it does not work well, the fallback is a native `Menu` that lists the same years (see "Maintenance notes"). Keep the title button and the `jump(to:)` wiring in this plan independent of the strip, so the fallback only has to replace the popover's content.

## Current state

### The Year tab

`Hugo/Features/ServiceYear/Screens/ServiceYearView.swift` is the Year tab. It pages horizontally between theocratic years, one `ServiceYearPageView` per year. The years come from `TheocraticYear.availableYears` (lines 24–29):

```swift
    private var years: [TheocraticYear] {
        TheocraticYear.availableYears(
            entryDates: (earliestEntry + latestEntry).map(\.date),
            now: .now
        )
    }
```

The pager's position is `@State private var scrollPosition: TheocraticYear.ID?` (line 8), bound with `.scrollPosition(id: $scrollPosition)` (line 60). `activeYear` (lines 35–37) is `displayedYear ?? currentYear`. When `scrollPosition` changes, this handler updates `displayedYear`, which animates the title digits (lines 94–102):

```swift
        .onChange(
            of: scrollPosition,
            { _, newValue in
                guard let newValue, let year = years.first(where: { $0.id == newValue }) else { return }
                withAnimation(.snappy) {
                    displayedYear = year
                }
            }
        )
```

So setting `scrollPosition = year.id` is all it takes to show another year. The existing `resetToken` handler (lines 103–108) already does this to return to the current year.

The toolbar is at lines 67–85:

```swift
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 0) {
                        Text(String(activeYear.startYear))
                            .contentTransition(.numericText(value: Double(activeYear.startYear)))
                        Text(String("/"))
                        Text(String(activeYear.startYear + 1))
                            .contentTransition(.numericText(value: Double(activeYear.startYear + 1)))
                            .animation(.snappy.delay(0.05), value: activeYear.startYear + 1)
                    }
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .monospacedDigit()
                }
                ToolbarItem {
                    SettingsButton(sizeClass: .compact)
                }
            }
```

### The years have no gaps

`TheocraticYear.availableYears` (`Hugo/Features/ServiceYear/Domain/TheocraticYear.swift:42-56`) returns every year from the earliest entry's year through the later of the latest entry's year and the current year, with no gaps, oldest first:

```swift
        let firstYear = min(containing(earliest, calendar: calendar), currentYear)
        let lastYear = max(containing(latest, calendar: calendar), currentYear)

        return (firstYear.startYear...lastYear.startYear).map(TheocraticYear.init(startYear:))
```

Without entries it returns only the current year. The picker can therefore describe the years as a first year and a last year. A year with no entries still has a page, so it also appears in the strip.

`TheocraticYear` (same file, lines 3–8) is a `nonisolated struct` with `startYear`, `id` (= `startYear`) and `displayName` (`"2026/2027"`). It is `Hashable`, `Comparable`, `Identifiable` and `Sendable`.

### iPad

In the regular-width layout (`Hugo/App/AppRootView.swift:84-96`) the Year tab is the detail column of a `NavigationSplitView`. The principal toolbar item shows in both widths, so the new button gets no size-class condition.

### Conventions to match

- **Isolation**: the target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Value types in a feature's `Domain` folder are declared `nonisolated struct` (see `TheocraticYear.swift:3`). Views are MainActor by default.
- **Folders** (`AGENTS.md` section 7): pure value logic goes in `Hugo/Features/ServiceYear/Domain/`, embedded views in `Hugo/Features/ServiceYear/Views/`. Tests mirror the source path under `HugoTests/Features/ServiceYear/Domain/`. The Xcode project uses file-system synchronized groups, so new files need no `project.pbxproj` edits. `Scripts/check-layout.sh` fails on any other folder.
- **Layout tokens** live in `Hugo/DesignSystem/Theme/Theme.swift`, enum `HugoLayout`. Feature-specific sizes sit in `HugoLayout.Size` next to general ones (for example `symbolPickerMinimumCellWidth`). Lines 39–43 today:

  ```swift
          static let calendarDayMinHeight: CGFloat = 64
          static let calendarBarHeight: CGFloat = 6

          static let minimumHitTarget: CGFloat = 44
      }
  ```

  Spacing tokens used below: `HugoLayout.Spacing.tight` (4), `.compact` (8), `.regular` (12), `.spacious` (16).
- **Scaled sizes** use `@ScaledMetric(relativeTo:)` with a token as the default, as in `Hugo/Features/SymbolPicker/Screens/SymbolPicker.swift:22`.
- **Motion**: `Hugo/DesignSystem/Motion/Motion.swift` defines `Motion.value` (`.smooth(duration: 0.25)`). Views read `@Environment(\.accessibilityReduceMotion)` and skip animation when it is true (see `Hugo/DesignSystem/Components/MarkedProgressBar.swift:12`).
- **Localized strings with arguments** use `String(localized:defaultValue:comment:)` with interpolation, and the catalog stores the translation with positional `%1$@` specifiers. Exemplar `Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift:89-97`:

  ```swift
          return String(
              localized: "year.header.a11y.label",
              defaultValue: "Counted toward yearly goal: \(spoken). \(progress.paceSentence ?? "")",
              comment:
                  "Spoken summary of the year header. The first argument is the counted time, the second is whether the user is ahead, behind or on pace."
          )
  ```

  Plain keys are used directly as `Text("key")`, `.accessibilityHint("key")` and so on (same file, line 65).
- **String catalog**: `Hugo/Resources/Localizable.xcstrings`, source language `en`, with `da` translations. Each entry has a `comment` and `localizations.en` / `localizations.da`, each `{"stringUnit": {"state": "translated", "value": ...}}`. Existing Year keys start with `year.` (for example `year.subtitle`: "Service Year" / "Tjenesteår").
- **Formatting**: `swift-format` with 4-space indentation and a 120-character line limit. Tests use Swift Testing; see `HugoTests/Features/ServiceYear/Domain/TheocraticYearTests.swift` (a `@MainActor struct` with `@Test` functions and `#expect`).
- **Vocabulary** (`CONTEXT.md`): "Theocratic year: The year from September 1 to August 31, written as both calendar years, for example 2026/2027." Use "theocratic year" in type names and comments. The user-facing English text says "service year", as the existing `year.subtitle` does.

## Design (what you are building)

Read this before the steps. The numbers are fixed; do not tune them.

```
 popover
 ┌──────────────────────────────────────┐
 │   2025  ( 2026  /  2027 )  2028      │   ← strip, 4 cells wide; band = 2 cells
 │        Swipe or tap a year           │   ← hint, footnote, secondary
 └──────────────────────────────────────┘
```

- **Cells.** One cell per calendar year, from the first theocratic year's start year to the last theocratic year's end year. Three theocratic years 2024/2025 to 2026/2027 give the cells 2024, 2025, 2026, 2027. The cell width is `W` (64 pt, scaled with Dynamic Type relative to `.title3`).
- **Strip.** The visible strip is `4W` wide: the band (`2W`) in the middle and one cell on each side. The scroll content has `W` of padding before the first cell and after the last cell.
- **Offsets.** With that padding, content offset `i * W` puts theocratic year number `i` (counting from 0, oldest first) in the band. The scroll range is exactly `0...(count - 1) * W`, so the first and last years can reach the band and nothing else can.
- **Snapping.** A custom `ScrollTargetBehavior` rounds the offset where a flick would come to rest to the nearest multiple of `W`. The strip keeps its momentum and settles on a whole year. Do not use `.viewAligned`: by default it limits a swipe to one item in compact width, which removes the momentum.
- **Band and slash.** A capsule filled with `Color(.tertiarySystemFill)`, `2W` wide, sits behind the middle of the strip. A "/" in the secondary style sits in the exact center, above the strip, and ignores taps.
- **Emphasis.** Years in the band are fully opaque. Opacity falls off linearly to 0.4 at the neighbouring cells' centers and stays there. A short gradient mask fades the strip's outer edges.
- **Selection.** While the strip scrolls, the year in the band updates live, and each change plays a selection haptic. The Year tab changes only when the strip comes to rest, so the pager does not churn during a flick.
- **Taps.** Tapping a year left of the band makes it the start year. Tapping a year right of the band makes it the end year. Tapping a year inside the band closes the popover. Closing also works by tapping outside the popover.
- **Title button.** Only when there are two or more years does the title become a button, with a small `chevron.down` after it. With one year the title stays plain text, exactly as today.
- **VoiceOver.** The strip is one adjustable element: label "Service year", value "2026 to 2027". Swiping up or down moves one year and selects it right away, without animation. The hint text is hidden from VoiceOver because "swipe" means something else there.
- **Text size.** The popover content is capped at Dynamic Type `.xxLarge` so the strip fits on a 375-point-wide iPhone. VoiceOver users and users at larger sizes can still use the adjustable element and the pager.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Folder layout | `Scripts/check-layout.sh` | exit 0, no output |
| JSON is valid | `python3 -c "import json; json.load(open('Hugo/Resources/Localizable.xcstrings', encoding='utf-8'))"` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/TheocraticYearStripLayoutTests -only-testing:HugoTests/TheocraticYearTests` | `** TEST SUCCEEDED **` |
| Build only | `xcodebuild build -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData CODE_SIGNING_ALLOWED=NO` | `** BUILD SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 (takes several minutes) |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run the same command again. That is not a failure.

## Suggested executor toolkit

- Use the `write-swift` skill if available when a Swift 6 isolation error appears (see Step 3's notes).

## Scope

**In scope** (the only files you modify or create):
- `Hugo/Features/ServiceYear/Domain/TheocraticYearStripLayout.swift` (create)
- `HugoTests/Features/ServiceYear/Domain/TheocraticYearStripLayoutTests.swift` (create)
- `Hugo/Features/ServiceYear/Views/TheocraticYearPicker.swift` (create)
- `Hugo/Features/ServiceYear/Domain/TheocraticYear.swift` (add `spokenName`)
- `HugoTests/Features/ServiceYear/Domain/TheocraticYearTests.swift` (one new test)
- `Hugo/Features/ServiceYear/Screens/ServiceYearView.swift` (title button and popover)
- `Hugo/DesignSystem/Theme/Theme.swift` (one size token)
- `Hugo/Resources/Localizable.xcstrings` (four new keys)

**Out of scope** (do not touch):
- `ServiceYearPageView.swift`, `ServiceYearMonthRow.swift`, `TheocraticYearTotalsView.swift` and the year header. Other plans change them.
- `TheocraticYear.availableYears`. The picker shows exactly the years the pager has; do not add, filter or reorder years.
- `SettingsButton`, `AppRootView` and the nested `NavigationStack` (tracked separately as SLN-200).
- A "current year" button, a marker on the current year, or entry counts per year. Keep the strip plain. Tapping the Year tab again already returns to the current year.
- Animating the pager's jump. The pager jumps without animation. The title digits already animate through the existing `onChange(of: scrollPosition)` handler.
- Do not open the string catalog in Xcode and save it; edit the text file directly.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- The working tree may hold uncommitted owner files in `plans/` and `.claude/`. Never stage, edit, stash or discard them. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage only the in-scope files, by explicit path.
- One commit, Conventional Commits style: `feat: jump to a theocratic year from the Year title`

## Steps

### Step 1: Add the strip layout and its tests

Create `Hugo/Features/ServiceYear/Domain/TheocraticYearStripLayout.swift` with exactly this content:

```swift
import CoreGraphics

/// What a tap on a year in the theocratic year picker strip does.
nonisolated enum TheocraticYearStripTapAction: Equatable, Sendable {
    /// Put this theocratic year in the band.
    case select(TheocraticYear)
    /// The tapped year is already in the band: close the picker.
    case close
}

/// The geometry of the theocratic year picker strip.
///
/// The strip shows one cell per calendar year. The two calendar years of the
/// selected theocratic year sit side by side in a band in the middle, for
/// example `2025 [2026 / 2027] 2028`. The content offset `index * cellWidth`
/// puts the theocratic year at `index` (counting from the first year) in the band.
nonisolated struct TheocraticYearStripLayout: Equatable, Sendable {
    /// The opacity of years outside the band.
    static let dimmedEmphasis = 0.4

    /// The oldest theocratic year in the strip.
    let firstYear: TheocraticYear
    /// The newest theocratic year in the strip.
    let lastYear: TheocraticYear
    let cellWidth: CGFloat

    /// `years` is the pager's list of years, which has no gaps. An empty list
    /// gives a strip with a single year; callers show the picker only with two
    /// or more years.
    init(years: [TheocraticYear], cellWidth: CGFloat) {
        let fallback = TheocraticYear(startYear: 0)
        self.firstYear = years.min() ?? fallback
        self.lastYear = years.max() ?? fallback
        self.cellWidth = cellWidth
    }

    /// The number of theocratic years the strip can put in the band.
    var yearCount: Int {
        lastYear.startYear - firstYear.startYear + 1
    }

    /// Every start year, plus the end year of the last theocratic year.
    var calendarYears: [Int] {
        Array(firstYear.startYear...(lastYear.startYear + 1))
    }

    /// Space before the first cell and after the last. With it, the scroll
    /// range is exactly the offsets that put a theocratic year in the band.
    var edgePadding: CGFloat {
        cellWidth
    }

    /// The visible width: the band (two cells) and one cell on each side.
    var stripWidth: CGFloat {
        cellWidth * 4
    }

    /// The content offset that puts `year` in the band. Years outside the strip are clamped.
    func offset(for year: TheocraticYear) -> CGFloat {
        CGFloat(index(of: year)) * cellWidth
    }

    /// The theocratic year in the band at a content offset, rounded to the nearest year.
    func year(forOffset offset: CGFloat) -> TheocraticYear {
        guard cellWidth > 0 else { return firstYear }
        let index = Int((offset / cellWidth).rounded())
        return year(atIndex: index)
    }

    /// The nearest offset that puts a whole theocratic year in the band.
    func snappedOffset(forProposedOffset offset: CGFloat) -> CGFloat {
        self.offset(for: year(forOffset: offset))
    }

    /// The theocratic year `step` years after `year` (before it when negative),
    /// stopping at the first and last year.
    func year(_ year: TheocraticYear, movedBy step: Int) -> TheocraticYear {
        self.year(atIndex: index(of: year) + step)
    }

    /// The opacity for a cell whose center is at `midX` in the strip's visible
    /// coordinates: 1 inside the band, falling to `dimmedEmphasis` at the
    /// neighbouring cells' centers.
    func emphasis(forCellMidX midX: CGFloat) -> Double {
        guard cellWidth > 0 else { return 1 }
        let distance = abs(midX - stripWidth / 2)
        // 0 at the centers of the band's two cells, 1 at the centers of their neighbours.
        let fade = Double((distance - cellWidth / 2) / cellWidth)
        guard fade > 0 else { return 1 }
        guard fade < 1 else { return Self.dimmedEmphasis }
        return 1 - (1 - Self.dimmedEmphasis) * fade
    }

    /// What tapping `calendarYear` does while `yearInBand` is in the band.
    func tapAction(forCalendarYear calendarYear: Int, yearInBand: TheocraticYear) -> TheocraticYearStripTapAction {
        if calendarYear < yearInBand.startYear {
            return .select(year(atIndex: calendarYear - firstYear.startYear))
        }
        if calendarYear > yearInBand.startYear + 1 {
            return .select(year(atIndex: calendarYear - 1 - firstYear.startYear))
        }
        return .close
    }

    private func index(of year: TheocraticYear) -> Int {
        min(max(year.startYear - firstYear.startYear, 0), yearCount - 1)
    }

    private func year(atIndex index: Int) -> TheocraticYear {
        let clamped = min(max(index, 0), yearCount - 1)
        return TheocraticYear(startYear: firstYear.startYear + clamped)
    }
}
```

Then create `HugoTests/Features/ServiceYear/Domain/TheocraticYearStripLayoutTests.swift` with exactly this content:

```swift
import CoreGraphics
import Testing

@testable import Hugo

@MainActor
struct TheocraticYearStripLayoutTests {
    private let cellWidth: CGFloat = 64

    private func layout(_ startYears: ClosedRange<Int>) -> TheocraticYearStripLayout {
        TheocraticYearStripLayout(years: startYears.map(TheocraticYear.init(startYear:)), cellWidth: cellWidth)
    }

    private func year(_ startYear: Int) -> TheocraticYear {
        TheocraticYear(startYear: startYear)
    }

    @Test
    func listsEveryStartYearAndTheLastEndYear() {
        #expect(layout(2024...2026).calendarYears == [2024, 2025, 2026, 2027])
    }

    @Test
    func showsBothCalendarYearsOfASingleYear() {
        let single = layout(2026...2026)
        #expect(single.calendarYears == [2026, 2027])
        #expect(single.yearCount == 1)
    }

    @Test
    func acceptsYearsInAnyOrder() {
        let shuffled = TheocraticYearStripLayout(years: [year(2026), year(2024), year(2025)], cellWidth: cellWidth)
        #expect(shuffled.calendarYears == [2024, 2025, 2026, 2027])
    }

    @Test
    func showsTheBandAndOneYearOnEachSide() {
        let strip = layout(2024...2026)
        #expect(strip.stripWidth == 256)
        #expect(strip.edgePadding == 64)
    }

    @Test
    func placesEachYearOneCellFurther() {
        let strip = layout(2024...2026)
        #expect(strip.offset(for: year(2024)) == 0)
        #expect(strip.offset(for: year(2025)) == 64)
        #expect(strip.offset(for: year(2026)) == 128)
    }

    @Test
    func clampsOffsetsOfYearsOutsideTheStrip() {
        let strip = layout(2024...2026)
        #expect(strip.offset(for: year(2020)) == 0)
        #expect(strip.offset(for: year(2030)) == 128)
    }

    @Test
    func roundsAnOffsetToTheNearestYear() {
        let strip = layout(2024...2026)
        #expect(strip.year(forOffset: 31) == year(2024))
        #expect(strip.year(forOffset: 33) == year(2025))
        #expect(strip.year(forOffset: 100) == year(2026))
    }

    @Test
    func clampsOffsetsPastTheEnds() {
        let strip = layout(2024...2026)
        #expect(strip.year(forOffset: -40) == year(2024))
        #expect(strip.year(forOffset: 900) == year(2026))
    }

    @Test
    func snapsWhereAFlickWouldStopToAWholeYear() {
        let strip = layout(2024...2026)
        #expect(strip.snappedOffset(forProposedOffset: 90) == 64)
        #expect(strip.snappedOffset(forProposedOffset: 100) == 128)
        #expect(strip.snappedOffset(forProposedOffset: -20) == 0)
        #expect(strip.snappedOffset(forProposedOffset: 900) == 128)
    }

    @Test
    func endsTheScrollRangeWithTheLastYearInTheBand() {
        let strip = layout(2019...2026)
        let contentWidth = strip.edgePadding * 2 + strip.cellWidth * CGFloat(strip.calendarYears.count)
        #expect(contentWidth - strip.stripWidth == strip.offset(for: year(2026)))
    }

    @Test
    func emphasizesTheTwoYearsInTheBand() {
        let strip = layout(2024...2026)
        let dimmed = TheocraticYearStripLayout.dimmedEmphasis
        // The strip is 256 wide, so the band's cells are centered at 96 and 160.
        #expect(strip.emphasis(forCellMidX: 96) == 1)
        #expect(strip.emphasis(forCellMidX: 160) == 1)
        #expect(strip.emphasis(forCellMidX: 128) == 1)
        // The neighbouring cells are centered at 32 and 224.
        #expect(strip.emphasis(forCellMidX: 32) == dimmed)
        #expect(strip.emphasis(forCellMidX: 224) == dimmed)
        #expect(strip.emphasis(forCellMidX: -100) == dimmed)
        let halfway = strip.emphasis(forCellMidX: 64)
        #expect(abs(halfway - (1 + dimmed) / 2) < 0.0001)
    }

    @Test
    func closesWhenTappingAYearInTheBand() {
        let strip = layout(2022...2027)
        #expect(strip.tapAction(forCalendarYear: 2025, yearInBand: year(2025)) == .close)
        #expect(strip.tapAction(forCalendarYear: 2026, yearInBand: year(2025)) == .close)
    }

    @Test
    func makesAnEarlierTappedYearTheStartYear() {
        let strip = layout(2022...2027)
        #expect(strip.tapAction(forCalendarYear: 2024, yearInBand: year(2025)) == .select(year(2024)))
        #expect(strip.tapAction(forCalendarYear: 2022, yearInBand: year(2025)) == .select(year(2022)))
    }

    @Test
    func makesALaterTappedYearTheEndYear() {
        let strip = layout(2022...2027)
        #expect(strip.tapAction(forCalendarYear: 2027, yearInBand: year(2025)) == .select(year(2026)))
        #expect(strip.tapAction(forCalendarYear: 2028, yearInBand: year(2025)) == .select(year(2027)))
    }

    @Test
    func movesByAStepAndStopsAtTheEnds() {
        let strip = layout(2024...2026)
        #expect(strip.year(year(2025), movedBy: 1) == year(2026))
        #expect(strip.year(year(2025), movedBy: -1) == year(2024))
        #expect(strip.year(year(2026), movedBy: 1) == year(2026))
        #expect(strip.year(year(2024), movedBy: -1) == year(2024))
    }
}
```

**Verify**: run the "Focused tests" command with only `-only-testing:HugoTests/TheocraticYearStripLayoutTests` → `** TEST SUCCEEDED **`, 15 tests in `TheocraticYearStripLayoutTests` passed.

### Step 2: Add the spoken name, the size token and the strings

**2a.** In `Hugo/Features/ServiceYear/Domain/TheocraticYear.swift`, add this property inside the struct, directly after `var displayName: String { "\(startYear)/\(startYear + 1)" }`:

```swift

    /// The year as VoiceOver says it, for example "2026 to 2027".
    var spokenName: String {
        String(
            localized: "year.picker.a11y.value",
            defaultValue: "\(String(startYear)) to \(String(startYear + 1))",
            comment:
                "Spoken name of a theocratic year. The arguments are its two calendar years, such as 2026 and 2027."
        )
    }
```

`String(startYear)` keeps the number free of a thousands separator ("2026", not "2,026").

**2b.** Add this test to `HugoTests/Features/ServiceYear/Domain/TheocraticYearTests.swift`, directly after `displaysTheocraticYearDesignation()`:

```swift

    @Test
    func spellsOutBothCalendarYearsForVoiceOver() {
        let spoken = TheocraticYear(startYear: 2026).spokenName
        #expect(spoken.contains("2026"))
        #expect(spoken.contains("2027"))
        #expect(!spoken.contains("/"))
    }
```

**2c.** In `Hugo/DesignSystem/Theme/Theme.swift`, add one line in `HugoLayout.Size` directly after `static let calendarBarHeight: CGFloat = 6`:

```swift
        static let yearPickerCellWidth: CGFloat = 64
```

**2d.** Add four keys to `Hugo/Resources/Localizable.xcstrings`, inside `"strings"`, in alphabetical position among the other `year.` keys (after `year.header.total.label`, before `year.subtitle`). Match the indentation of the surrounding entries (two spaces per level; check one existing entry first).

| Key | Comment | en | da |
|---|---|---|---|
| `year.picker.a11y.hint` | `Accessibility hint for the Year tab's title, which opens the year picker.` | `Choose another service year` | `Vælg et andet tjenesteår` |
| `year.picker.a11y.label` | `Accessibility label for the Year tab's title button and for the year picker strip.` | `Service year` | `Tjenesteår` |
| `year.picker.a11y.value` | `Spoken name of a theocratic year. The arguments are its two calendar years, such as 2026 and 2027.` | `%1$@ to %2$@` | `%1$@ til %2$@` |
| `year.picker.hint` | `Short instruction below the year picker strip.` | `Swipe or tap a year` | `Stryg eller tryk på et år` |

Each entry has this shape (shown for the first key):

```json
    "year.picker.a11y.hint" : {
      "comment" : "Accessibility hint for the Year tab's title, which opens the year picker.",
      "localizations" : {
        "da" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Vælg et andet tjenesteår"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Choose another service year"
          }
        }
      }
    },
```

**Verify**:
- "JSON is valid" command → exit 0.
- `grep -c '"year.picker.' Hugo/Resources/Localizable.xcstrings` → `4`.
- "Focused tests" command (both test suites) → `** TEST SUCCEEDED **`.

### Step 3: Build the picker view

Create `Hugo/Features/ServiceYear/Views/TheocraticYearPicker.swift` with exactly this content:

```swift
import SwiftUI

/// A strip of calendar years with a band in the middle that holds one
/// theocratic year, for example `2025 [2026 / 2027] 2028`. A flick glides
/// through the years and settles with a whole theocratic year in the band.
/// The Year tab shows that year once the strip comes to rest.
struct TheocraticYearPicker: View {
    /// The pager's years, oldest first, with no gaps.
    let years: [TheocraticYear]
    /// The year the Year tab shows.
    let selection: TheocraticYear
    let onSelect: (TheocraticYear) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @ScaledMetric(relativeTo: .title3) private var cellWidth: CGFloat = HugoLayout.Size.yearPickerCellWidth

    @State private var position = ScrollPosition(edge: .leading)
    @State private var yearInBand: TheocraticYear?
    @State private var scrollPhase: ScrollPhase = .idle

    private var layout: TheocraticYearStripLayout {
        TheocraticYearStripLayout(years: years, cellWidth: cellWidth)
    }

    private var shownYear: TheocraticYear {
        yearInBand ?? selection
    }

    var body: some View {
        let layout = self.layout
        VStack(spacing: HugoLayout.Spacing.compact) {
            strip(layout)
            Text("year.picker.hint")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(HugoLayout.Spacing.spacious)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .onAppear {
            yearInBand = selection
            position.scrollTo(x: layout.offset(for: selection))
        }
    }

    private func strip(_ layout: TheocraticYearStripLayout) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(layout.calendarYears, id: \.self) { calendarYear in
                    Button {
                        handleTap(on: calendarYear, layout: layout)
                    } label: {
                        Text(String(calendarYear))
                            .font(.system(.title3, design: .serif, weight: .bold))
                            .monospacedDigit()
                            .frame(width: layout.cellWidth)
                            .frame(minHeight: HugoLayout.Size.minimumHitTarget)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .visualEffect { content, proxy in
                        content.opacity(
                            layout.emphasis(forCellMidX: proxy.frame(in: .scrollView(axis: .horizontal)).midX)
                        )
                    }
                }
            }
            .padding(.horizontal, layout.edgePadding)
        }
        .frame(width: layout.stripWidth)
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(TheocraticYearStripSnapping(layout: layout))
        .scrollPosition($position)
        .onScrollGeometryChange(for: TheocraticYear.self) { geometry in
            layout.year(forOffset: geometry.contentOffset.x + geometry.contentInsets.leading)
        } action: { _, year in
            yearInBand = year
        }
        .onScrollPhaseChange { _, phase in
            scrollPhase = phase
            if phase == .idle {
                select(yearInBand)
            }
        }
        .sensoryFeedback(.selection, trigger: yearInBand) { _, _ in
            scrollPhase != .idle
        }
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.1),
                    .init(color: .black, location: 0.9),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .background {
            Capsule()
                .fill(Color(.tertiarySystemFill))
                .frame(width: layout.cellWidth * 2)
        }
        .overlay {
            Text(String("/"))
                .font(.system(.title3, design: .serif, weight: .bold))
                .foregroundStyle(.secondary)
                .allowsHitTesting(false)
        }
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
    }

    private func handleTap(on calendarYear: Int, layout: TheocraticYearStripLayout) {
        switch layout.tapAction(forCalendarYear: calendarYear, yearInBand: shownYear) {
        case .close:
            dismiss()
        case .select(let year):
            move(to: year, layout: layout)
        }
    }

    /// Scrolls the strip so `year` is in the band and shows it on the Year tab right away.
    private func move(to year: TheocraticYear, layout: TheocraticYearStripLayout) {
        yearInBand = year
        let animation: Animation? = reduceMotion || voiceOverEnabled ? nil : Motion.value
        withAnimation(animation) {
            position.scrollTo(x: layout.offset(for: year))
        }
        select(year)
    }

    private func select(_ year: TheocraticYear?) {
        guard let year, year != selection else { return }
        onSelect(year)
    }
}

/// Lets the strip glide with momentum, then settles where a whole theocratic
/// year sits in the band.
private nonisolated struct TheocraticYearStripSnapping: ScrollTargetBehavior {
    let layout: TheocraticYearStripLayout

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        target.rect.origin.x = layout.snappedOffset(forProposedOffset: target.rect.origin.x)
    }
}

#Preview {
    TheocraticYearPicker(
        years: (2019...2026).map(TheocraticYear.init(startYear:)),
        selection: TheocraticYear(startYear: 2024),
        onSelect: { _ in }
    )
}
```

Notes for this step:
- Checked against the iOS SDK in `/Applications/Xcode.app` on 2026-11-06: `ScrollTargetBehavior` has no actor annotation, and `ScrollPosition(edge:)`, `ScrollPosition.scrollTo(x:)`, `CoordinateSpaceProtocol.scrollView(axis:)` and `sensoryFeedback(_:trigger:condition:)` all exist. The fallbacks below are only for a different Xcode.
- `TheocraticYearStripSnapping` is `nonisolated` on purpose. The target uses MainActor default isolation, and a MainActor struct cannot satisfy a nonisolated protocol requirement. If the compiler instead reports that `updateTarget` must be MainActor-isolated, remove the word `nonisolated` from that one declaration and build again. Do not change anything else to silence an isolation error.
- If `ScrollPosition(edge: .leading)` does not compile, use `ScrollPosition(point: .zero)`. If `position.scrollTo(x:)` does not compile, use `position.scrollTo(point: CGPoint(x: layout.offset(for: ...), y: 0))` in both places. These are the only allowed API substitutions.
- If `sensoryFeedback(_:trigger:condition:)` reports a closure isolation error, remove the condition closure (leaving `.sensoryFeedback(.selection, trigger: yearInBand)`) and note in your report that the picker may tick once when it opens.

**Verify**:
- "Build only" command → `** BUILD SUCCEEDED **`, with no new warnings in `TheocraticYearPicker.swift` (`grep -n "TheocraticYearPicker.swift.*warning"` on the build output prints nothing).
- "Lint" command → exit 0.

### Step 4: Make the title open the picker

Edit `Hugo/Features/ServiceYear/Screens/ServiceYearView.swift`.

**4a.** Add this property directly after `@State private var scrolledPages: [TheocraticYear.ID: Bool] = [:]`:

```swift
    @State private var isYearPickerPresented = false
```

**4b.** Replace the whole `ToolbarItem(placement: .principal) { ... }` block (the first item in `.toolbar`, shown in "Current state") with:

```swift
                ToolbarItem(placement: .principal) {
                    if years.count > 1 {
                        Button {
                            isYearPickerPresented = true
                        } label: {
                            HStack(spacing: HugoLayout.Spacing.tight) {
                                yearTitle
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("year.picker.a11y.label")
                        .accessibilityValue(activeYear.spokenName)
                        .accessibilityHint("year.picker.a11y.hint")
                        .popover(isPresented: $isYearPickerPresented) {
                            TheocraticYearPicker(years: years, selection: activeYear, onSelect: jump(to:))
                                .presentationCompactAdaptation(.popover)
                        }
                    } else {
                        yearTitle
                    }
                }
```

Leave the second `ToolbarItem` (`SettingsButton`) unchanged.

**4c.** Add these two members directly after the `isScrolledFromTop` computed property (before `var body`). `yearTitle` is the old principal content moved unchanged:

```swift
    private var yearTitle: some View {
        HStack(spacing: 0) {
            Text(String(activeYear.startYear))
                .contentTransition(.numericText(value: Double(activeYear.startYear)))
            Text(String("/"))
            Text(String(activeYear.startYear + 1))
                .contentTransition(.numericText(value: Double(activeYear.startYear + 1)))
                .animation(.snappy.delay(0.05), value: activeYear.startYear + 1)
        }
        .font(.system(.headline, design: .serif, weight: .bold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .monospacedDigit()
    }

    /// Shows `year` on the pager. The existing `onChange(of: scrollPosition)`
    /// handler updates `displayedYear` and animates the title.
    private func jump(to year: TheocraticYear) {
        scrollPosition = year.id
    }
```

Do not change `onAppear`, the `onChange(of: scrollPosition)` handler or the `onChange(of: resetToken)` handler.

**Verify**:
- "Build only" command → `** BUILD SUCCEEDED **`.
- `grep -n "TheocraticYearPicker(" Hugo/Features/ServiceYear/Screens/ServiceYearView.swift` → exactly one match.
- `grep -n "SettingsButton(sizeClass: .compact)" Hugo/Features/ServiceYear/Screens/ServiceYearView.swift` → exactly one match.
- "Lint" command → exit 0.

### Step 5: Run the full gate and commit

If the lint step in any earlier step reported formatting differences, run `xcrun swift-format format --in-place` on the in-scope Swift files only (never on the whole tree), then lint again.

**Verify**: `Scripts/verify.sh` → exit 0.

Then stage only the eight in-scope files by explicit path and commit with `feat: jump to a theocratic year from the Year title`. `git status --short` afterwards must show no in-scope file as modified.

## Test plan

- `TheocraticYearStripLayoutTests` (new, 15 tests): calendar years for several years and for one year, unsorted input, strip width and padding, offset per year and clamping, rounding an offset to a year and clamping past the ends, snapping proposed offsets, that the scroll range ends with the last year in the band, emphasis inside and outside the band, the three tap rules, and stepping with clamping. Modelled on `TheocraticYearTests.swift`.
- `TheocraticYearTests.spellsOutBothCalendarYearsForVoiceOver` (new): the spoken name has both calendar years and no slash.
- The scrolling, popover and haptics cannot be unit tested. The owner checks them on device (below).

## Owner check on device (decides whether the strip stays)

The executor cannot do these. The reviewer hands them to the owner. To get several years, add one entry dated three or four years back (for example March 2023) and delete it afterwards.

1. iPhone, light and dark: the title shows "2026/2027 ⌄". Tapping it opens a popover under the title, not a sheet. The band is visible in both modes.
2. A firm flick glides several years and settles with two calendar years in the band. Selection ticks play while it moves. The Year tab behind it changes only once the strip stops.
3. A slow drag released halfway between two years snaps to the nearer one. The first and last years reach the band, and the strip cannot scroll past them.
4. Tapping a year left of the band makes it the start year. Tapping a year right of the band makes it the end year. Tapping a year in the band closes the popover.
5. Opening the popover shows the current year in the band with no visible jump and no haptic tick.
6. With only the current year (no older entries), the title has no chevron and does nothing when tapped.
7. VoiceOver in English and Danish: the title reads "Service year, 2026 to 2027, button" / "Tjenesteår, 2026 til 2027". In the popover, swiping up or down changes the year and the Year tab follows.
8. The largest standard text size (Settings > Accessibility > Larger Text, slider at the right end without "Larger Accessibility Sizes"): the strip fits inside the popover on the smallest iPhone available.
9. iPad, full screen: the popover appears under the title and works the same way.
10. **Decision:** is jumping years with the strip faster and clearer than swiping the Year tab's pages? If not, record "REJECTED, fall back to menu" in `plans/README.md` and in the Linear issue, and ask for a follow-up plan that swaps the popover for a native `Menu` (see "Maintenance notes").

## Done criteria

All must hold:

- [ ] `Scripts/verify.sh` exits 0.
- [ ] `TheocraticYearStripLayoutTests` has 15 passing tests, and `TheocraticYearTests.spellsOutBothCalendarYearsForVoiceOver` passes.
- [ ] `grep -c '"year.picker.' Hugo/Resources/Localizable.xcstrings` prints `4`.
- [ ] `grep -rn "viewAligned" Hugo/Features/ServiceYear` prints nothing.
- [ ] `git show --stat HEAD` lists only the eight in-scope files.
- [ ] `plans/README.md` status row updated (or left to the reviewer if they said so).

## STOP conditions

Stop and report back, without improvising, if:

- The drift check lists a Swift file and the code differs from the "Current state" excerpts.
- `TheocraticYear.availableYears` no longer returns a gap-free range. The layout assumes it does.
- The isolation or API errors in Step 3 are not fixed by the substitutions listed there.
- A build or test fails twice after a reasonable fix attempt.
- The change seems to need a file outside the in-scope list, for example `ServiceYearPageView.swift` or `AppRootView.swift`.
- In the simulator, the popover appears as a full sheet on iPhone despite `.presentationCompactAdaptation(.popover)`.

## Maintenance notes

- **The fallback.** If the owner rejects the strip, keep `yearTitle`, the chevron and `jump(to:)` from Step 4, drop `isYearPickerPresented`, and replace the `Button` + `.popover` with a `Menu` whose label is the same `HStack` and whose content is `Picker` over `years.reversed()` (newest first) bound to a `Binding` that calls `jump(to:)`. Then delete `TheocraticYearPicker.swift`, `TheocraticYearStripLayout.swift`, its tests and the `year.picker.hint` key. `spokenName` and the other three keys stay useful.
- **Data import.** When import adds old years, `availableYears` still returns a gap-free range, so the strip works without changes. A strip with many years is where the momentum matters; check it with 15 or more years.
- **Offsets and insets.** The layout assumes the strip's content offset is 0 when the first year is in the band (padding is in the content, not in `contentMargins`). If someone adds `contentMargins` or `safeAreaPadding` to the strip, the snapping and the year in the band will drift by that inset.
- **Text size.** The popover is capped at `.xxLarge`. If owners report that is too small for some users, the next step is showing the native menu at accessibility sizes, not widening the strip.
- **Review focus.** Check that the pager changes only when the strip comes to rest (not on every tick), that the title is plain text with a single year, and that `ServiceYearPageView.swift` is untouched.

## Revision 1 (2026-11-06, after the owner's first look on device)

The owner likes the strip and wants three tweaks before the device check is finished. Apply them on top of commit `ad0ba60` (Steps 1–5 are already done; do not redo them). The same Scope, Git workflow, STOP conditions and commands apply. In scope for this revision: `TheocraticYearStripLayout.swift`, `TheocraticYearStripLayoutTests.swift`, `TheocraticYearPicker.swift`, `ServiceYearView.swift`, `Theme.swift`. Nothing else.

What changes:

1. **More room.** The popover gets more vertical padding (24 instead of 16) and more space between the strip and the hint (12 instead of 8). Side padding stays 16, because the popover must fit on a 375-point iPhone and the strip's edge fade already gives visual room.
2. **Wider strip that peeks.** The strip shows the band plus one and a half cells on each side (5 cells instead of 4), so the next years peek in, half visible and faded. Cells get wider (68 pt instead of 64) for more space between the years. The strip is capped at 320 pt. Below the cap it is `5 * cellWidth`, and it is never narrower than the band. The side space is `(stripWidth - 2 * cellWidth) / 2` and becomes the edge padding, so `offset(for:)` stays `index * cellWidth` and the scroll range still ends with the last year in the band.
3. **Centered title.** A hidden copy of the chevron goes before the year text, so the text sits in the exact center and the visible chevron hangs to its right.

### Step R1: Layout

In `Hugo/Features/ServiceYear/Domain/TheocraticYearStripLayout.swift`, replace:

```swift
    let cellWidth: CGFloat

    /// `years` is the pager's list of years, which has no gaps. An empty list
    /// gives a strip with a single year; callers show the picker only with two
    /// or more years.
    init(years: [TheocraticYear], cellWidth: CGFloat) {
        let fallback = TheocraticYear(startYear: 0)
        self.firstYear = years.min() ?? fallback
        self.lastYear = years.max() ?? fallback
        self.cellWidth = cellWidth
    }
```

with:

```swift
    let cellWidth: CGFloat
    /// The visible width: the band (two cells) and one and a half cells on each
    /// side, so the next years peek in at the edges. Never wider than the
    /// caller's maximum and never narrower than the band.
    let stripWidth: CGFloat

    /// `years` is the pager's list of years, which has no gaps. An empty list
    /// gives a strip with a single year; callers show the picker only with two
    /// or more years.
    init(years: [TheocraticYear], cellWidth: CGFloat, maximumStripWidth: CGFloat = .infinity) {
        let fallback = TheocraticYear(startYear: 0)
        self.firstYear = years.min() ?? fallback
        self.lastYear = years.max() ?? fallback
        self.cellWidth = cellWidth
        self.stripWidth = max(cellWidth * 2, min(cellWidth * 5, maximumStripWidth))
    }
```

Then replace:

```swift
    /// Space before the first cell and after the last. With it, the scroll
    /// range is exactly the offsets that put a theocratic year in the band.
    var edgePadding: CGFloat {
        cellWidth
    }

    /// The visible width: the band (two cells) and one cell on each side.
    var stripWidth: CGFloat {
        cellWidth * 4
    }
```

with:

```swift
    /// Space before the first cell and after the last: what the strip shows
    /// beside the band. With it, the scroll range is exactly the offsets that
    /// put a theocratic year in the band.
    var edgePadding: CGFloat {
        (stripWidth - cellWidth * 2) / 2
    }
```

### Step R2: Layout tests

In `HugoTests/Features/ServiceYear/Domain/TheocraticYearStripLayoutTests.swift`:

Replace the whole `showsTheBandAndOneYearOnEachSide` test with these three tests:

```swift
    @Test
    func showsTheBandWithTheNextYearsPeekingIn() {
        let strip = layout(2024...2026)
        #expect(strip.stripWidth == 320)
        #expect(strip.edgePadding == 96)
    }

    @Test
    func capsTheStripAtTheMaximumWidth() {
        let years = (2024...2026).map(TheocraticYear.init(startYear:))
        let strip = TheocraticYearStripLayout(years: years, cellWidth: cellWidth, maximumStripWidth: 300)
        #expect(strip.stripWidth == 300)
        #expect(strip.edgePadding == 86)
        #expect(strip.offset(for: year(2025)) == 64)
    }

    @Test
    func neverNarrowsTheStripBelowTheBand() {
        let years = (2024...2026).map(TheocraticYear.init(startYear:))
        let strip = TheocraticYearStripLayout(years: years, cellWidth: cellWidth, maximumStripWidth: 100)
        #expect(strip.stripWidth == 128)
        #expect(strip.edgePadding == 0)
    }
```

Replace the whole `endsTheScrollRangeWithTheLastYearInTheBand` test with:

```swift
    @Test
    func endsTheScrollRangeWithTheLastYearInTheBand() {
        let years = (2019...2026).map(TheocraticYear.init(startYear:))
        let strips = [
            TheocraticYearStripLayout(years: years, cellWidth: cellWidth),
            TheocraticYearStripLayout(years: years, cellWidth: cellWidth, maximumStripWidth: 300),
        ]
        for strip in strips {
            let contentWidth = strip.edgePadding * 2 + strip.cellWidth * CGFloat(strip.calendarYears.count)
            #expect(contentWidth - strip.stripWidth == strip.offset(for: year(2026)))
        }
    }
```

Replace the whole `emphasizesTheTwoYearsInTheBand` test with:

```swift
    @Test
    func emphasizesTheTwoYearsInTheBand() {
        let strip = layout(2024...2026)
        let dimmed = TheocraticYearStripLayout.dimmedEmphasis
        // The strip is 320 wide, so the band's cells are centered at 128 and 192.
        #expect(strip.emphasis(forCellMidX: 128) == 1)
        #expect(strip.emphasis(forCellMidX: 192) == 1)
        #expect(strip.emphasis(forCellMidX: 160) == 1)
        // The neighbouring cells are centered at 64 and 256, the peeking ones at 0 and 320.
        #expect(strip.emphasis(forCellMidX: 64) == dimmed)
        #expect(strip.emphasis(forCellMidX: 256) == dimmed)
        #expect(strip.emphasis(forCellMidX: 0) == dimmed)
        #expect(strip.emphasis(forCellMidX: -100) == dimmed)
        let halfway = strip.emphasis(forCellMidX: 96)
        #expect(abs(halfway - (1 + dimmed) / 2) < 0.0001)
    }
```

Leave every other test unchanged.

**Verify**: "Focused tests" command with only `-only-testing:HugoTests/TheocraticYearStripLayoutTests` → `** TEST SUCCEEDED **`, 17 tests passed.

### Step R3: Tokens and picker

**R3a.** In `Hugo/DesignSystem/Theme/Theme.swift`, replace `static let yearPickerCellWidth: CGFloat = 64` with these two lines:

```swift
        static let yearPickerCellWidth: CGFloat = 68
        static let yearPickerMaximumStripWidth: CGFloat = 320
```

**R3b.** In `Hugo/Features/ServiceYear/Views/TheocraticYearPicker.swift`, make exactly these three replacements:

- `TheocraticYearStripLayout(years: years, cellWidth: cellWidth)` →
  `TheocraticYearStripLayout(years: years, cellWidth: cellWidth, maximumStripWidth: HugoLayout.Size.yearPickerMaximumStripWidth)`
  (if the line passes 120 characters, break the arguments onto separate lines the way swift-format wants).
- `VStack(spacing: HugoLayout.Spacing.compact) {` → `VStack(spacing: HugoLayout.Spacing.regular) {`
- `.padding(HugoLayout.Spacing.spacious)` → these two lines:

  ```swift
        .padding(.horizontal, HugoLayout.Spacing.spacious)
        .padding(.vertical, HugoLayout.Spacing.card)
  ```

Do not change anything else in the picker (the mask, band capsule, slash, snapping and accessibility stay as they are).

**Verify**: "Build only" → `** BUILD SUCCEEDED **`; "Lint" → exit 0.

### Step R4: Center the title

In `Hugo/Features/ServiceYear/Screens/ServiceYearView.swift`, replace the Button's label content:

```swift
                            HStack(spacing: HugoLayout.Spacing.tight) {
                                yearTitle
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
```

with:

```swift
                            HStack(spacing: HugoLayout.Spacing.tight) {
                                yearTitleChevron
                                    .hidden()
                                yearTitle
                                yearTitleChevron
                            }
```

and add this property directly after the `yearTitle` property:

```swift

    /// The chevron after the year title. A hidden copy before the title keeps
    /// the year text optically centered.
    private var yearTitleChevron: some View {
        Image(systemName: "chevron.down")
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
    }
```

**Verify**: "Build only" → `** BUILD SUCCEEDED **`; `grep -c 'Image(systemName: "chevron.down")' Hugo/Features/ServiceYear/Screens/ServiceYearView.swift` → `1`; "Lint" → exit 0.

### Step R5: Gate and commit

`Scripts/verify.sh` → exit 0. Stage only the five files above by explicit path and commit with `feat: give the year picker more room and center the Year title`.

### Revision done criteria

- [ ] `Scripts/verify.sh` exits 0, and `TheocraticYearStripLayoutTests` has 17 passing tests.
- [ ] `git show --stat HEAD` lists only the five revision files.
- [ ] `grep -rn "viewAligned" Hugo/Features/ServiceYear` prints nothing.

### Revision owner check

Repeat owner checks 1–5 and 8 from the list above, and also check:
- The year text in the title sits in the center of the navigation bar, with the chevron hanging to its right.
- Half a year peeks in, faded, on each side of the strip, and the popover has visibly more room above and below.
- On the smallest iPhone, at the default and the largest standard text size, the whole popover fits on screen without being clipped.

## Revision 2 (2026-11-06, owner request: slide the pages)

The owner wants the Year tab's pages to slide to the chosen year instead of jumping, to see whether it feels more fluid. This overrides the earlier out-of-scope line "Animating the pager's jump". It is a trial; the owner may ask to undo it after the device check.

Apply on top of commit `d5226e0`. The only in-scope file is `Hugo/Features/ServiceYear/Screens/ServiceYearView.swift`. The Git workflow, STOP conditions and commands from above still apply.

### Step S1: Animate the jump

**S1a.** Add this property directly after `@State private var isYearPickerPresented = false`:

```swift
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

**S1b.** Replace:

```swift
    /// Shows `year` on the pager. The existing `onChange(of: scrollPosition)`
    /// handler updates `displayedYear` and animates the title.
    private func jump(to year: TheocraticYear) {
        scrollPosition = year.id
    }
```

with:

```swift
    /// Slides the pager to `year`, or jumps there with Reduce Motion on. The
    /// existing `onChange(of: scrollPosition)` handler updates `displayedYear`
    /// and animates the title.
    private func jump(to year: TheocraticYear) {
        withAnimation(reduceMotion ? nil : Motion.presence) {
            scrollPosition = year.id
        }
    }
```

Change nothing else: not the `onChange` handlers, not `onAppear`, not the picker.

**Verify**: "Build only" → `** BUILD SUCCEEDED **`; "Lint" → exit 0; `grep -c "Motion.presence" Hugo/Features/ServiceYear/Screens/ServiceYearView.swift` → `1`.

### Step S2: Gate and commit

`Scripts/verify.sh` → exit 0. Stage only `ServiceYearView.swift` by explicit path and commit with `feat: slide the Year pages to the year chosen in the picker`.

### Revision 2 done criteria

- [ ] `Scripts/verify.sh` exits 0.
- [ ] `git show --stat HEAD` lists only `ServiceYearView.swift`.

### Revision 2 owner check

- Picking a year one or two years away slides the pages behind the popover smoothly, and the title digits still roll.
- **Long jump:** with entries spread over many years (add one entry about ten years back), flick from the newest to the oldest year. If the slide stutters or takes too long, report it. A possible follow-up is to slide only for nearby years and jump for far ones.
- With Reduce Motion on, the pages jump with no slide.
- Decide: keep the slide, or undo Revision 2.

## Revision 3 (2026-11-06, owner request: bigger tap area for the title)

The owner finds the year title hard to tap. Cause: the title `Button` uses `.buttonStyle(.plain)` with no content shape, so only drawn pixels (the glyphs and the visible chevron) take taps. The gaps between digits and the hidden balancing chevron don't. Fix: give the label a rectangular content shape, at least `HugoLayout.Size.minimumHitTarget` (44 pt) tall, with a little horizontal padding.

Apply on top of commit `77c50c7`. The only in-scope file is `Hugo/Features/ServiceYear/Screens/ServiceYearView.swift`. Git workflow, STOP conditions and commands from above still apply.

### Step T1: Enlarge the tap area

Replace:

```swift
                            HStack(spacing: HugoLayout.Spacing.tight) {
                                yearTitleChevron
                                    .hidden()
                                yearTitle
                                yearTitleChevron
                            }
                        }
```

with:

```swift
                            HStack(spacing: HugoLayout.Spacing.tight) {
                                yearTitleChevron
                                    .hidden()
                                yearTitle
                                yearTitleChevron
                            }
                            .padding(.horizontal, HugoLayout.Spacing.compact)
                            .frame(minHeight: HugoLayout.Size.minimumHitTarget)
                            .contentShape(.rect)
                        }
```

Change nothing else. The padding is symmetric, so the title stays centered.

**Verify**: "Build only" → `** BUILD SUCCEEDED **`; "Lint" → exit 0; `grep -c "contentShape(.rect)" Hugo/Features/ServiceYear/Screens/ServiceYearView.swift` → `1`.

### Step T2: Gate and commit

`Scripts/verify.sh` → exit 0. Stage only `ServiceYearView.swift` by explicit path and commit with `fix: enlarge the Year title's tap area`.

### Revision 3 owner check

- Tapping anywhere on the title, including between the digits, just left of the year, and slightly above or below it, opens the picker.
- The title is still centered and the navigation bar height doesn't change.
