# Plan 167: Hover effects on cards and day cells

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat <BASELINE>..HEAD -- Hugo/Features/ServiceYear/Views Hugo/Features/Entries/Views/EntryRow.swift Hugo/Features/Overview/Views Hugo/Features/Planner/Views Hugo/DesignSystem/Theme`
> The reviewer sets <BASELINE> at dispatch to the commit after the previous plan in the batch (166–173). Expected: no output. STOP on any output.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). This plan adds no strings. Never stage that file.

## Status

- **Priority**: P3
- **Effort**: S + owner
- **Risk**: LOW. Hover effects only show with a pointer (trackpad or mouse) on iPad. Touch and iPhone are unaffected.
- **Depends on**: 166 (it touches the same rows; run it first so the modifiers sit in a known order)
- **Category**: ux
- **Planned at**: commit `16b697c`, 2026-11-26
- **Issue**: [SLN-348](https://linear.app/sebastianln/issue/SLN-348)

## Why this matters

With a trackpad on iPad, buttons that are custom cards give no sign that they
can be clicked. Only the Overview's + button has a hover effect
(`.hoverEffect(.lift)` in `MonthlyProgressCard.swift`). System list rows
(Settings, a month's details) already highlight on their own.

After this plan, every tappable card and cell on the three main tabs shows the
system highlight when the pointer moves over it. The highlight takes the shape
of the card (rounded) instead of a plain rectangle.

## Current state

The effect follows a view's content shape. A rounded card therefore needs
`.contentShape(.hoverEffect, .rect(cornerRadius: ...))` before `.hoverEffect`.
`.contentShape(.hoverEffect, ...)` only affects the hover shape: it does not
change the tap area or the context-menu preview shape (`.contextMenuPreview`).

Tappable custom cards and cells, with the shape each one draws:

| # | File | Element | Visible shape |
|---|---|---|---|
| 1 | `Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift` | the month card `NavigationLink` (`.buttonStyle(.card)`, then `.contentShape(.contextMenuPreview, .rect(cornerRadius: HugoLayout.CornerRadius.card))`, then `.contextMenu`) | rounded, `CornerRadius.card` |
| 2 | `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift` | the year totals `NavigationLink { ServiceYearDetailView } label: { TheocraticYearTotalsView }` with `.buttonStyle(.card)` | no background; use `CornerRadius.card` |
| 3 | `Hugo/Features/Entries/Views/EntryRow.swift` | the row `Button` (card, `.clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))`) | rounded, `CornerRadius.card` |
| 4 | `Hugo/Features/Overview/Views/OverviewListView.swift` | `DateEntryRow`'s `Button` (a line inside a day card) | small rounded rect |
| 5 | same file | `OverviewCarriedEntriesView`'s `Button` (gray card) | rounded, `CornerRadius.card` |
| 6 | `Hugo/Features/Overview/Views/ReportReminderCard.swift` | the card `Button` (`.buttonStyle(.plain)`) | rounded, `CornerRadius.card` |
| 7 | `Hugo/Features/Overview/Views/MonthlyProgressCard.swift` | the plan pace `Button(action: onShowPlanPace)` with `.buttonStyle(.card)` (a small line of text and a chevron) | capsule |
| 8 | `Hugo/Features/Planner/Views/PlannerCalendarGrid.swift` | each day's `Button` (label `PlannerDayCell`, no background). After plan 166 its chain is `.buttonStyle(.plain)`, `.disabled(onSelect == nil)`, `.contentShape(.contextMenuPreview, .rect(cornerRadius: HugoLayout.Spacing.regular))`, `.contextMenu { ... }`, `.popover(...)` | small rounded rect |
| 9 | `Hugo/Features/Planner/Views/PlannerLoggedEntryList.swift` | each row `Button` | small rounded rect |
| 10 | `Hugo/Features/Planner/Views/PlannedCategoryCard.swift` | the header `Button` (when the card has one plan) and each `line(_:)` `Button` | small rounded rect |

Already handled, do not touch: the Overview's + button (`.hoverEffect(.lift)`,
a floating glass button), system list rows, toolbar buttons.

Out of this plan on purpose: the year picker strip (`TheocraticYearPicker`),
option cards in onboarding and settings (`PublisherStatusOptionRow`,
`SelectableOptionRow`, `CategoryKindPicker`), color swatches. They are less used
and can follow if the owner likes the result.

Token values: `HugoLayout.CornerRadius.card` is 32, `HugoLayout.Spacing.regular`
is 12. A Planner day cell gets its own token, `HugoLayout.CornerRadius.calendarDay`
(8), which Step 1 adds. Plans 170 (drop target) and 172 (keyboard ring) reuse it
for the same cell, so they must not add it again. Plan 166's context-menu
preview shape on the day cell stays as plan 166 wrote it (12). The rows and
plan lines in the table (#4, #9, #10) keep `HugoLayout.Spacing.regular`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` (run as `sh -c 'Scripts/verify.sh; echo "VERIFY_EXIT=$?"'`) | `VERIFY_EXIT=0` |
| Format check | `xcrun swift-format lint --strict <files>` | exit 0 |
| Format fix | `xcrun swift-format format -i <files>` | then re-run lint; use when `lint --strict` fails on formatting only |

## Scope

**In scope**: the nine files in the table above, hover modifiers only, and
`Hugo/DesignSystem/Theme/Theme.swift` (one corner radius token).

**Out of scope**: everything else, including `CardButtonStyle` (it does not know
each card's shape), sizes, colors and any behavior.

## Git workflow

- Work on `main`. Two commits (one per step), messages given in the steps. Do not push.
- Stage files by explicit path.

## Steps

### Step 1: The day-cell corner radius token

In `Hugo/DesignSystem/Theme/Theme.swift`, in `HugoLayout.CornerRadius`, after
`calendarBar`, add:

```swift
        /// The hover, drop and keyboard highlight around a Planner day.
        static let calendarDay: CGFloat = 8
```

**Verify**: lint `Theme.swift`; `Scripts/verify.sh` → `VERIFY_EXIT=0`, same test
count. Commit `feat(design): add a corner radius token for Planner days`.

### Step 2: Add the modifiers

Add exactly these two lines, in this order, to each element in the table,
directly after its `.buttonStyle(...)` modifier (for #1, after the existing
`.contextMenu { ... }`; for #3, #4 and #9, after the existing
`.entryContextMenu(...)` from plan 166; for #8, after `.contextMenu { ... }` and
before `.popover`):

| # | Lines to add |
|---|---|
| 1, 2, 3, 5, 6 | `.contentShape(.hoverEffect, .rect(cornerRadius: HugoLayout.CornerRadius.card))` then `.hoverEffect(.highlight)` |
| 4, 9, 10 | `.contentShape(.hoverEffect, .rect(cornerRadius: HugoLayout.Spacing.regular))` then `.hoverEffect(.highlight)` |
| 8 | `.contentShape(.hoverEffect, .rect(cornerRadius: HugoLayout.CornerRadius.calendarDay))` then `.hoverEffect(.highlight)` |
| 7 | `.contentShape(.hoverEffect, .capsule)` then `.hoverEffect(.highlight)` |

After this step the day `Button` in #8 has this chain, in this order:
`.buttonStyle(.plain)`, `.disabled(onSelect == nil)`,
`.contentShape(.contextMenuPreview, ...)`, `.contextMenu { ... }`,
`.contentShape(.hoverEffect, ...)`, `.hoverEffect(.highlight)`, `.popover(...)`.
Plans 170 and 172 add a drop target and a keyboard ring between `.hoverEffect`
and `.popover`.

For #10 there are two buttons (the header `Button` in `body`, after its
`.buttonStyle(.plain)`; and the `Button` in `line(_:)`, after its
`.buttonStyle(.plain)`). Add the two lines to both.

Do not add `.hoverEffect` anywhere else, and do not change the existing
`.hoverEffect(.lift)` on the Overview's + button.

**Verify**: `grep -rn "hoverEffect(.highlight)" Hugo | wc -l` prints 11.
`grep -rn "contentShape(.hoverEffect" Hugo | wc -l` prints 11. Lint the nine
files. `Scripts/verify.sh` → `VERIFY_EXIT=0`, same test count as before.
Commit `feat: add pointer hover effects to cards and day cells`.

## Test plan

- No unit test: a pointer-only visual effect. The owner check is the test.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, same test count
- [ ] 11 `.hoverEffect(.highlight)` and 11 `.contentShape(.hoverEffect, ...)` added, plus the `calendarDay` token, nothing else changed
- [ ] `plans/README.md` row updated

Owner check on the iPad (Sean) with a trackpad or mouse (light and dark mode):

1. Overview: move the pointer over the report reminder, an entry card ("by entry"), an entry line ("by date"), the carried-in line and the plan pace line. Each highlights in its own shape.
2. Planner: day cells highlight as a rounded square; in a day popover, plan cards and logged entries highlight per row.
3. Service Year: the year totals card and each month card highlight with rounded corners; the zoom into a month still works.
4. Click still works everywhere; touch shows no change.
5. If the highlight on the big cards (month cards, entry cards) feels too heavy, say so: the alternative for big cards is no effect, keeping it on the small cells only.

No iPhone (Mona) check needed (hover does not exist there), but the iPhone must build and look as before.

If the iPad has no trackpad or mouse, check on this Mac as "My Mac (Designed for iPad)" if it builds and launches, and note it.

## STOP conditions

Stop and report if:

- The drift check shows any output.
- An element in the table no longer exists or has a different button style.
- `hoverEffect(.highlight)` on a `NavigationLink` with `.buttonStyle(.card)` does not compile.

## Maintenance notes

- New tappable cards should get the same two lines with their own corner radius.
- Plan 169 (Service Year grid) reuses `ServiceYearMonthRow` for every month, so the hover effect added to it here carries over. No second change is needed.
- Plan 168 (two columns) moves cards around but should not need to touch these modifiers.
- Related: SLN-80 ("Hover Interactions on iPad", done earlier) added the + button's lift.
