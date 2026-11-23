# Plan 148: Solid, larger total hours on the month detail page

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 07d4c61..HEAD -- Hugo/Features/ServiceYear/Views/MonthHeadline.swift Hugo/Features/ServiceYear/Screens/MonthDetailView.swift`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). Never touch, stage or commit it.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW. One view, no logic. The month card on the year page must look the same as before.
- **Depends on**: none
- **Category**: ui
- **Planned at**: commit `07d4c61`, 2026-11-23
- **Issue**: [SLN-329](https://linear.app/sebastianln/issue/SLN-329)

## Why this matters

The total at the top of a month page is the number the user opened the page
for. It is drawn faded, so it reads as secondary, and the owner sees this on
months that have activity too. After this plan the number is the full primary
color and larger than the large title style. The unit word stays secondary.
The month card on the year page is not changed.

## Current state

`Hugo/Features/ServiceYear/Screens/MonthDetailView.swift:67-72` (the `header`):

```swift
MonthHeadline(
    seconds: month.contribution.total,
    size: .large,
    isFaded: month.summary == nil && schoolCredits.isEmpty
)
```

`Hugo/Features/ServiceYear/Views/MonthHeadline.swift:30-42` (the cause of the fade):

```swift
HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.compact) {
    Text(headline.value, format: .number)
        .font(.system(size == .large ? .largeTitle : .title, design: .serif, weight: .bold))
        .foregroundStyle(isFaded ? .tertiary : .primary)
        ...
    Text(unitLabel)
        .font(.system(size == .large ? .title2 : .title3, design: .serif, weight: .semibold))
        .foregroundStyle(isFaded ? .tertiary : .secondary)
}
```

Two things fade the number, and the second one is the likely cause of what the
owner sees on a month with activity:

1. `isFaded` makes it `.tertiary` for a month with no entries and no school
   credit (the page then shows "0 hours").
2. The headline sits in the submit section's **header** (`MonthDetailView.swift`
   line ~130, `} header: { header }`). A `List` or `Form` section header
   supplies its own secondary foreground. `.foregroundStyle(.primary)` is a
   hierarchical style: it means "the primary level of the style the view
   inherits", so inside that header it resolves to a gray, not to black. Only
   an explicit `Color.primary` is the real primary color.

I could not confirm point 2 on a device. Step 1 tests it.

The number is also only `.largeTitle` (34 pt at the default size), which is
barely bigger than the `.title` used on the card.

`MonthHeadline` is also used by `ServiceYearMonthRow.swift:127` (regular size)
and previews. Only the `.large` size changes.

Rules from `AGENTS.md` that apply: SwiftUI only, Dynamic Type safe, extremely
native with small tasteful touches, readable from age 13 to 70.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |

## Scope

**In scope**:

- `Hugo/Features/ServiceYear/Views/MonthHeadline.swift`

**Out of scope**:

- `MonthDetailView.swift` (the `isFaded:` argument stays; the headline decides for itself).
- The month card (`ServiceYearMonthRow`) and the `.regular` size.
- New strings. No user-facing text changes.
- Any other screen.

## Git workflow

- Work on `main`. One commit, for example `feat(service-year): make month total solid and larger`.
- Do not push. Never stage `Hugo/Resources/Localizable.xcstrings`.

## Steps

### Step 1: Make the `.large` headline solid

First, the quick test. In `MonthHeadline.swift` change the number's style from
`.primary` to `Color.primary` (so `isFaded ? .tertiary : Color.primary`; if the
ternary does not type-check, write `AnyShapeStyle` on both branches). Build
and run on a device or simulator and open a month with entries. If the number
is now clearly black (white in dark mode), the header was the cause. Keep that
change and tell the owner. If it is still gray, STOP and report: the fade comes
from somewhere else (look for `.opacity`, `.secondary` or `.tint` set by
`MonthDetailView` on the section or its header).

Then, in the same file, add a computed property and use it for both texts:

```swift
/// The large headline is never faded: it is the page's main number.
private var fades: Bool { isFaded && size == .regular }
```

Replace the number's style with `fades ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.primary)`.
For the unit label use `.secondary` when `size == .large`, otherwise
`fades ? .tertiary : .secondary`. Update the `isFaded` doc comment to say it
applies to the regular size only.

**Verify**: `grep -n "fades" Hugo/Features/ServiceYear/Views/MonthHeadline.swift` shows the property and its uses.

### Step 2: Make the large number bigger, scaling with Dynamic Type

Text styles stop at `.largeTitle`, so a bigger number needs a scaled metric.
Add to `MonthHeadline`:

```swift
@ScaledMetric(relativeTo: .largeTitle) private var largeNumberSize: CGFloat = 56
```

For `.large`, use `.font(.system(size: largeNumberSize, weight: .bold, design: .serif))`
on the number. Keep the current text-style font for `.regular` (build the
font in a small `numberFont` computed property). Add `.monospacedDigit()` to
the number, plus `.lineLimit(1)` and `.minimumScaleFactor(0.5)` so it never
clips. Keep the unit at `.title2` serif semibold for `.large`.
`@ScaledMetric` scales with the user's text size, so this is not a fixed size.

Put the number and unit in `ViewThatFits(in: .horizontal)` with two options:
the current `HStack` (first baseline), then a `VStack(alignment: .leading)`
with the number above the unit. At accessibility sizes the wide layout does
not fit, so the stacked one is used and nothing clips. Keep
`.animation(.snappy, value: headline)`, `.contentTransition(.numericText(...))`
and the accessibility modifiers on the outer container, unchanged. Build the
number and unit once as small `private var` views so both layouts share them.

**Verify**: `Scripts/verify.sh` exits 0.

### Step 3: Add a preview for accessibility sizes

Add a preview next to the existing ones:

```swift
#Preview("Large, accessibility size") {
    MonthHeadline(seconds: 142 * 3_600, size: .large)
        .dynamicTypeSize(.accessibility3)
        .padding()
}
```

**Verify**: `Scripts/verify.sh` exits 0.

## Test plan

No logic changes, so no new unit tests. Existing `HeadlineDuration` tests must keep passing.

Owner check on device (the gate cannot see layout):

- Open a month with entries: the number is full black (white in dark mode), clearly larger than before, and the unit word is gray. This is the check for the owner's report that the number looked faded.
- Open an empty month: "0 hours" is also solid, not faded.
- Settings > Accessibility > Larger Text at the largest size: number and unit stack, nothing is cut off, the page still scrolls.
- The month cards on the year page look exactly as before, including the faded empty month.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `git status --short` shows only the in-scope file (plus the owner's `Localizable.xcstrings`, unstaged)
- [ ] `plans/README.md` row updated

## STOP conditions

Stop and report if:

- `MonthHeadline` no longer has the `isFaded` or `size` parameters.
- Step 1's quick test shows the number is still gray with `Color.primary`.
- The number clips at the largest accessibility size and `ViewThatFits` does not fix it.
- Any change is needed in `ServiceYearMonthRow` to keep the card unchanged.

## Maintenance notes

- 56 pt is a starting point at the default size. To make it larger or smaller, change only the `@ScaledMetric` default.
- A new size on `MonthHeadline` should decide for itself whether it fades.
- Text drawn in a section header that must look primary needs `Color.primary`, not the hierarchical `.primary`. The same trap can affect other headers in the app.
