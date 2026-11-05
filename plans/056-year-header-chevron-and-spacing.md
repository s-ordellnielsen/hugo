# Plan 056: Shrink the header chevron and add space above the pace line

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. Your reviewer maintains `plans/README.md`; do not edit it.
>
> **Drift check (run first)**:
> `git diff --stat b249953..HEAD -- Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift`
> If the file changed, compare the "Current state" excerpt against the live code. On a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/055-yearly-goal-header-polish.md (DONE)
- **Category**: direction
- **Planned at**: commit `b249953`, 2026-11-03
- **Issue**: [SLN-259](https://linear.app/sebastianln/issue/SLN-259)

## Why this matters

Two review notes from the owner on the Year page header. The chevron that signals
"tap for details" is too large (it inherits the body font size), and the totals sit
too close to the pace line and progress bar below them.

## Current state

`Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift`, in `body`:

```swift
VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {   // compact = 8
    HStack {
        eyebrow
        Spacer(minLength: HugoLayout.Spacing.regular)
        Image(systemName: "chevron.right")
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }
    ...
    if let fraction = progress?.barFraction, let paceSentence = progress?.paceSentence {
        Text(paceSentence)
            .font(.subheadline)
            .fontWeight(.semibold)
            .padding(.top, HugoLayout.Spacing.compact)
        CenteredProgressBar(...)
    }
}
```

Spacing tokens live in `Hugo/DesignSystem/Theme/Theme.swift` (`HugoLayout.Spacing`:
tight 4, small 6, compact 8, regular 12, spacious 16, roomy 20, card 24, section 32).
Read `AGENTS.md` for conventions. Use tokens, never raw numbers.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope** (the only file you may modify):
- `Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift`

**Out of scope**: everything else, including `CenteredProgressBar`, the detail screen and strings.

## Git workflow

Conventional Commits, one commit, for example `fix: shrink the year header chevron and add space above the pace line`.
End the message with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
Run `Scripts/install-hooks.sh` once. Do NOT push.

## Steps

### Step 1: Smaller chevron

Add `.font(.footnote)` to the chevron `Image`, after `Image(systemName: "chevron.right")`
and before `.foregroundStyle(.secondary)`. Add `.fontWeight(.semibold)` right after the font so it
stays legible at the smaller size.

### Step 2: More space between the totals and the pace line

Change the pace line's `.padding(.top, HugoLayout.Spacing.compact)` to
`.padding(.top, HugoLayout.Spacing.spacious)`. With the stack spacing this gives 24 pt
between the totals and the pace line (it was 16). The gap between the pace line and the
bar stays 8 pt. Change nothing else.

**Verify**: `Scripts/verify.sh` -> exit 0.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `git diff --stat` shows only `TheocraticYearTotalsView.swift` changed, a handful of lines
- [ ] `grep -n "Spacing.spacious" Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift` finds the pace line padding

## STOP conditions

- The excerpt above does not match the file (drift).
- `Scripts/verify.sh` fails twice on the same issue after a reasonable fix.

## Maintenance notes

Reviewer: look at the header in the simulator (chevron size, 24 pt gap) at default and
the largest Dynamic Type size. If 24 pt is still tight, use `HugoLayout.Spacing.roomy` (20) for the padding.
