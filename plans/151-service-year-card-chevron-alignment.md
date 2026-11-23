# Plan 151: Align the Service Year card chevron with the month eyebrow

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 07d4c61..HEAD -- Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift Hugo/Features/ServiceYear/Views/MonthHeadline.swift`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). Never touch, stage or commit it.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW. One small view, no logic.
- **Depends on**: none
- **Category**: ui
- **Planned at**: commit `07d4c61`, 2026-11-23
- **Issue**: [SLN-332](https://linear.app/sebastianln/issue/SLN-332)

## Why this matters

On a month card the chevron sits in the vertical middle of the header, next to
the big number. It reads as belonging to the number, but it points to the
whole card. After this plan it sits on the same line as the small uppercase
month name (the eyebrow) and is a little smaller, like the disclosure
indicator in a native list row that sits at the top.

## Current state

`Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift`, `header` (lines
about 92-110):

```swift
fileprivate var header: some View {
    HStack {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
            monthTitle
            duration
        }

        Spacer(minLength: HugoLayout.Spacing.regular)

        if !month.isFuture {
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}
```

`HStack` with no alignment centers the chevron against the whole
`VStack` (eyebrow plus the large number). `monthTitle` is
`Text(month.displayName)` at `.caption`, uppercase, tracked, semibold. The
`VStack`'s first text baseline is the eyebrow's baseline.

This `header` is the only place the chevron is drawn on the card. Future
months show no chevron.

Rules from `AGENTS.md` that apply: SwiftUI only, Dynamic Type safe, no fixed
offsets.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |

## Scope

**In scope**:

- `Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift`

**Out of scope**:

- `MonthHeadline`, `MonthDetailView`, the breakdown rows.
- Any new strings. No text changes.

## Git workflow

- Work on `main`. One commit, for example `fix(service-year): align card chevron with month eyebrow`.
- Do not push. Never stage `Hugo/Resources/Localizable.xcstrings`.

## Steps

### Step 1: Align on the first text baseline and shrink

In `header` change `HStack {` to `HStack(alignment: .firstTextBaseline) {`.
Change the chevron font from `.footnote.weight(.semibold)` to
`.caption2.weight(.semibold)`, so it is a step smaller and in the same family
as the `.caption` eyebrow. Do not add `.offset` or `.padding` to nudge it.

Why this works: a stack aligns on the first baseline of its children. For the
`VStack` that is the eyebrow's baseline, and an SF Symbol image has a text
baseline too. Both scale with Dynamic Type, so they stay together at every
size, and a two-line number or title does not move the chevron.

If the symbol sits a point or two off the eyebrow's cap height, accept it.
Baseline alignment matches how native list rows align text and symbols. Do not
add an offset.

**Verify**: `Scripts/verify.sh` exits 0.

### Step 2: Check the preview

Open the `ServiceYearMonthRow` preview and a year page with several months.
The chevron must be on the eyebrow line, at the trailing edge, for months
that are not in the future. Future months show no chevron and look unchanged.

**Verify**: owner check below.

## Test plan

No logic changes, so no new unit tests.

Owner check on device:

- Cards: the chevron is level with the month name (for example NOVEMBER), not the middle of the card, and is smaller than before.
- Dynamic Type: at the smallest, default and largest accessibility sizes the chevron stays on the eyebrow line and is not clipped.
- A title that wraps to two lines (a long Danish month name at a large size, or the eyebrow breaking at an accessibility size): the chevron sits on the first line.
- Dark mode and the zoom transition into the month page look the same as before.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -n "firstTextBaseline" Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift` shows the header
- [ ] `grep -n "\.offset" Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift` returns no matches
- [ ] `git status --short` shows only the in-scope file (plus the owner's `Localizable.xcstrings`, unstaged)
- [ ] `plans/README.md` row updated

## STOP conditions

Stop and report if:

- The header was restructured and no longer has the chevron in an `HStack` next to the `VStack`.
- Baseline alignment puts the chevron clearly off the eyebrow and only an offset would fix it. Report with a screenshot instead of adding an offset.

## Maintenance notes

- If the eyebrow's font changes, change the chevron's text style with it, so they stay in one size family.
