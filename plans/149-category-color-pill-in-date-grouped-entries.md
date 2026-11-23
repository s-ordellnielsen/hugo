# Plan 149: Category color pill in the date-grouped entry list

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 07d4c61..HEAD -- Hugo/Features/Overview/Views/OverviewListView.swift Hugo/Features/Entries/Domain/EntryCategory.swift Hugo/DesignSystem/Theme/CategoryColorStyle.swift Hugo/DesignSystem/Theme/Theme.swift`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). Never touch, stage or commit it.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW. Display only. The one model touch is a new field on a value type that nothing persists.
- **Depends on**: none
- **Category**: ui
- **Planned at**: commit `07d4c61`, 2026-11-23
- **Issue**: [SLN-330](https://linear.app/sebastianln/issue/SLN-330)

## Why this matters

In the Overview list grouped by date, each row shows `10.00  Field Service  2:00`.
Categories already have a color (see `CONTEXT.md`, "Category color"), but this
list shows none of it. After this plan a slim vertical capsule in the
category's color sits between the time and the name:
`10.00 | Field Service         2:00`. The list grouped by entry uses icons and
is not changed. The color is only a visual aid: the name still says which
category it is, so the pill is hidden from VoiceOver.

## Current state

`Hugo/Features/Overview/Views/OverviewListView.swift`, `DateEntryRow` (about
lines 205-245):

```swift
let category = entry.resolvedCategory()
...
HStack {
    Text(entry.date, format: .dateTime.hour().minute())
        .monospacedDigit()
        .foregroundStyle(.secondary)
    Text(category.name)
    Spacer()
    ...
```

`entry.resolvedCategory()` returns `EntryCategory`
(`Hugo/Features/Entries/Domain/EntryCategory.swift`), a `nonisolated` value type
with `key`, `name`, `iconName`, `type`, `trackerID`, `allowsBibleStudies`. It
has no color. It is built in three places, all inside `resolvedCategory`: from
the live `tracker`, from the `storedTracker` snapshot, and the untracked
fallback. Views must not read `entry.tracker` (AGENTS.md).

How color is represented: `Tracker` stores `colorHue` and `colorTone`;
`Tracker.categoryColor` (`Hugo/Features/Categories/Domain/TrackerCategoryColor.swift`)
returns `CategoryColor?`, where `nil` means Automatic. The shared helper
`CategoryColorStyle` (`Hugo/DesignSystem/Theme/CategoryColorStyle.swift`) is a
`ShapeStyle` that turns `CategoryColor?` into the right color for light or dark
mode and falls back to `.hugoAccent` (system teal, the "teal fallback" of plan
029) for `nil`. Reuse it. Other views already do, for example
`.foregroundStyle(CategoryColorStyle(tracker.categoryColor))` in
`CategoryListView.swift:25`. Do not use the old `hue/sat/bri` fields from plan 029.

A deleted category leaves only the snapshot (name, icon, kind), which has no
color. An untracked entry has none either. Both get `nil`, so they draw in
`.hugoAccent`, which is how Automatic looks.

Rules from `AGENTS.md` that apply: new code goes where section 7 says; a
view that shows a category belongs to its feature; tests mirror source
layout; Dynamic Type safe.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |

## Scope

**In scope**:

- `Hugo/Features/Entries/Domain/EntryCategory.swift` (add a `color` field)
- `Hugo/Features/Overview/Views/OverviewListView.swift` (draw the pill in `DateEntryRow`)
- `Hugo/DesignSystem/Theme/Theme.swift` (one size token)
- `HugoTests/Features/Entries/Domain/EntryCategoryTests.swift` (add tests)

**Out of scope**:

- `OverviewEntryList` / `EntryRow` (the icon list), the carried-in sheet.
- Anything stored: no change to `Tracker`, no schema change, no migration.
- A new reusable view. The pill is a few lines used once, so keep it inline in `DateEntryRow` (Overview feature). If a second feature ever needs it, it goes in `Hugo/DesignSystem/Components` and takes a `ShapeStyle`, never a category.
- New strings. The pill has no text.

## Git workflow

- Work on `main`. Commit per step. Conventional Commits, for example `feat(overview): show category color pill in date list`.
- Do not push. Never stage `Hugo/Resources/Localizable.xcstrings`.

## Steps

### Step 1: Carry the color on `EntryCategory`

In `EntryCategory.swift` add `let color: CategoryColor?` with the doc comment
"`nil` means Automatic. A deleted or untracked category has no stored color,
so it is `nil` too." Set it in `resolvedCategory`:

- live tracker: `color: tracker.categoryColor`
- snapshot: `color: nil`
- untracked: `color: nil`

`CategoryColor` is `Hashable`, so `EntryCategory` stays `Hashable`.

**Verify**: `grep -rn "EntryCategory(" Hugo HugoTests --include='*.swift'` shows only these three calls, and `Scripts/verify.sh` builds.

### Step 2: Test it

In `HugoTests/Features/Entries/Domain/EntryCategoryTests.swift` add:

1. `liveTrackerColorIsCarried`: create a `Tracker`, give it a color with `tracker.setCategoryColor(...)` (build a `CategoryColor` from `Hugo/Domain/CategoryColor.swift`; look at `CategoryColorPreset` for a ready value), attach it to an entry, expect `entry.resolvedCategory().color == tracker.categoryColor` and not `nil`.
2. `automaticTrackerHasNoColor`: a new `Tracker` gives `color == nil`.
3. `snapshotAndUntrackedHaveNoColor`: both fallbacks give `nil`.

**Verify**: `Scripts/verify.sh` exits 0, with 3 more tests than before.

### Step 3: Draw the pill

Add `static let categoryPillWidth: CGFloat = 4` to `HugoLayout.Size` in
`Hugo/DesignSystem/Theme/Theme.swift`, beside `calendarBarHeight`.

In `DateEntryRow`, replace `Text(category.name)` with:

```swift
Text(category.name)
    .padding(.leading, HugoLayout.Spacing.regular)
    .overlay(alignment: .leading) {
        Capsule()
            .fill(CategoryColorStyle(category.color))
            .frame(width: HugoLayout.Size.categoryPillWidth)
            .accessibilityHidden(true)
    }
```

Why an overlay: it is exactly as tall as the text, so the pill follows the
line height at every Dynamic Type size and spans two lines if a long name
wraps. The row's `HStack` spacing puts a gap before the pill, and the padding
puts a gap after it. Check the gaps by eye in Step 4 and adjust only the padding.

Leave the row's `.accessibilityElement(children: .combine)` and its label as
they are. The label already says time and category name.

**Verify**: `Scripts/verify.sh` exits 0.

### Step 4: Look at it

Run the `OverviewView` preview or the simulator with at least three categories
of different colors, one Automatic and one entry whose category was deleted.
Confirm each row's color, that Automatic and deleted ones are teal, and that
the pill is visible in dark mode.

**Verify**: owner check below.

## Test plan

- The three `EntryCategoryTests` above. The project has no snapshot tests.

Owner check on device:

- Date list: each row has a slim pill in its category color between time and name. Automatic categories are teal.
- Change a category's color in Categories, return to Overview: the pill follows.
- Dark mode: the pill uses the lighter tone and is still visible.
- Largest accessibility text size: the pill stays as tall as the name, and a wrapped name gets a taller pill.
- VoiceOver: a row reads time, category name, duration, and nothing about the pill.
- The by-entry list still shows icons and looks unchanged.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, with 3 more tests than before
- [ ] `grep -n "\.tracker" Hugo/Features/Overview/Views/OverviewListView.swift` returns no matches
- [ ] `git status --short` shows only the in-scope files (plus the owner's `Localizable.xcstrings`, unstaged)
- [ ] `plans/README.md` row updated

## STOP conditions

Stop and report if:

- `EntryCategory` is built in more than the three places above.
- `CategoryColorStyle` or `Tracker.categoryColor` no longer exist.
- The pill needs a fixed height to look right (it should not).

## Maintenance notes

- Any other place that shows an entry's category in color should read `entry.resolvedCategory().color` and draw it with `CategoryColorStyle`.
- Entries of a deleted category fall back to teal. Keeping their old color would need a color field on the entry snapshot. That is a schema change and needs its own plan.
