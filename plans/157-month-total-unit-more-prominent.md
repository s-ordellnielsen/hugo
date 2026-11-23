# Plan 157: Make the unit next to the month total more prominent

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat b980d57..HEAD -- Hugo/Features/ServiceYear/Views/MonthHeadline.swift`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). Never touch, stage or commit it.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW. One color in one view.
- **Depends on**: plan 148 (done)
- **Category**: ui
- **Planned at**: commit `b980d57`, 2026-11-23
- **Issue**: [SLN-329](https://linear.app/sebastianln/issue/SLN-329) (reopened after the owner's device check of plan 148)

## Why this matters

Plan 148 made the month total solid and larger, and the owner confirmed it looks
good on a device. The unit next to it ("hours") still looks faded, and the owner
wants it more prominent: `.secondary` or even `.primary`.

The unit is already written as `.secondary`, but the headline sits in a section
header, where a hierarchical style resolves against the header's own secondary
foreground. So the unit draws fainter than a normal secondary label, the same
effect that made the number look faded before plan 148. After this plan the unit
on the month page is the full primary color. The month cards on the Year page
keep their current look.

## Current state

`Hugo/Features/ServiceYear/Views/MonthHeadline.swift`:

```swift
private var unit: some View {
    Text(unitLabel)
        .font(unitFont)
        .foregroundStyle(fades ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
}
```

`fades` is `isFaded && size == .regular`. `size == .large` is the month page,
`.regular` is the card on the Year page. The number already uses
`AnyShapeStyle(Color.primary)`.

Rules from `AGENTS.md` that apply: SwiftUI only; Dynamic Type safe; vanilla and native.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |

## Scope

**In scope**:

- `Hugo/Features/ServiceYear/Views/MonthHeadline.swift`

**Out of scope**:

- `MonthDetailView`, `ServiceYearMonthRow`, any other screen, any string.

## Git workflow

- Work on `main`. One commit, for example `fix(service-year): make the month total unit solid`.
- Do not push. Never stage `Hugo/Resources/Localizable.xcstrings`.

## Steps

### Step 1: Use the explicit primary color for the large unit

Change `unit` to:

```swift
private var unit: some View {
    Text(unitLabel)
        .font(unitFont)
        .foregroundStyle(unitStyle)
}

/// On the month page the unit is as solid as the number. On a card it stays a
/// secondary label, and fades with the number for an empty month.
private var unitStyle: AnyShapeStyle {
    if size == .large { return AnyShapeStyle(Color.primary) }
    return fades ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary)
}
```

Use `Color.primary`, not the hierarchical `.primary`, so the section header does
not fade it. The number, fonts, layout and the regular size stay as they are.

If the owner finds it too strong, `Color.secondary` is a one-word change.
Do not change it yourself.

**Verify**: `Scripts/verify.sh` exits 0.

## Test plan

No logic changed, so no unit test. Owner check on a device:

- Month page: "hours" next to the number is full black (white in dark mode) and clearly more visible than before. If it looks too heavy next to the number, tell the reviewer, who can switch it to `Color.secondary`.
- Month cards on the Year page look exactly as before, including the faded empty month.
- Largest text size: number and unit stack, nothing is cut off.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -n "unitStyle" Hugo/Features/ServiceYear/Views/MonthHeadline.swift` shows the property and its use
- [ ] `git status --short` shows only the in-scope file (plus the owner's `Localizable.xcstrings`, unstaged)
- [ ] `plans/README.md` row updated

## STOP conditions

Stop and report if:

- `MonthHeadline` no longer has the `size` and `fades` properties.
- You need to change another file.

## Maintenance notes

- Inside a section header, hierarchical styles (`.primary`, `.secondary`) resolve against the header's own foreground. Use `Color.primary` or `Color.secondary` for text that must look like a normal label.
