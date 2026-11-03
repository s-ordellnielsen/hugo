# Plan 057: Try the Year page header without its card background (experiment)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. Your reviewer maintains `plans/README.md`; do not edit it.
>
> **Drift check (run first)**:
> `git diff --stat 32a49cc..HEAD -- Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift Hugo/DesignSystem/Components/CenteredProgressBar.swift`
> If either file changed, compare the "Current state" excerpts against the live code. On a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW (visual experiment, easy to revert)
- **Depends on**: plans/056-year-header-chevron-and-spacing.md (DONE)
- **Category**: direction
- **Planned at**: commit `32a49cc`, 2026-11-03

## Why this matters

The owner wants to try the Year page header without its rounded card background,
because it may separate the header from the month cards below it. This is an
experiment: the work stays on its own branch and is not merged until the owner has
looked at it. The rest of the header's layout should follow from the missing card.

## Current state

`Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift`, end of `body`:

```swift
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HugoLayout.Spacing.card)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint("year.header.a11y.hint")
```

`Hugo/DesignSystem/Components/CenteredProgressBar.swift` draws the track with
`.fill(Color(.tertiarySystemFill))`. That color was chosen to sit on the white card
(`secondarySystemGroupedBackground`). Without the card the bar sits directly on the
page background (`systemGroupedBackground`, light gray in Light Mode), where
`tertiarySystemFill` is too faint.

The header is placed in `ServiceYearPageView` inside a `VStack(spacing: HugoLayout.Spacing.card)`
(24 pt) with a `.padding()` around the scroll content, and wrapped in a
`NavigationLink` with `.buttonStyle(.card)` (`CardButtonStyle`, which sets
`contentShape(Rectangle())` so the whole header area stays tappable). The month cards below
have 24 pt inner padding (`ServiceYearMonthRow`), so their text starts 24 pt inside the card edge.

Spacing tokens are in `Hugo/DesignSystem/Theme/Theme.swift` (`HugoLayout.Spacing`:
tight 4, small 6, compact 8, regular 12, spacious 16, roomy 20, card 24, section 32).
Read `AGENTS.md` for conventions. Use tokens, never raw numbers.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope** (the only files you may modify):
- `Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift`
- `Hugo/DesignSystem/Components/CenteredProgressBar.swift`

**Out of scope**: `ServiceYearPageView`, `ServiceYearMonthRow`, `CardButtonStyle`, strings, the detail screen.

## Git workflow

Work on the branch your worktree provides. Do not merge it anywhere. Conventional Commits, one commit,
for example `feat: remove the card background from the year header`.
End the message with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
Run `Scripts/install-hooks.sh` once. Do NOT push.

## Steps

### Step 1: Remove the card chrome

In `TheocraticYearTotalsView.swift` delete the `.background(Color(.secondarySystemGroupedBackground))`
and `.clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))` lines. Keep the
accessibility modifiers.

### Step 2: Let the padding follow

- Replace `.padding(HugoLayout.Spacing.card)` with
  `.padding(.horizontal, HugoLayout.Spacing.card)` and
  `.padding(.vertical, HugoLayout.Spacing.regular)`. The horizontal padding keeps the
  header text aligned with the text inside the month cards below; the smaller vertical padding
  stops the header from floating far from the top and from the first card (the stack already adds 24 pt).
- Keep everything else in the header (chevron, eyebrow, spacing between lines) unchanged.

### Step 3: Make the bar track readable on the page background

In `CenteredProgressBar.swift` change the track fill from `Color(.tertiarySystemFill)` to
`Color(.secondarySystemFill)`. Change nothing else in that file.

**Verify**: `Scripts/verify.sh` -> exit 0.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -n "background\|clipShape" Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift` returns no matches
- [ ] `git diff --stat` shows only the two in-scope files changed

## STOP conditions

- The excerpts above do not match the files (drift).
- `Scripts/verify.sh` fails twice on the same issue after a reasonable fix.
- Removing the background changes the tap area or the accessibility behaviour in a way you can see in code
  (for example the `NavigationLink` no longer wraps the header). Report it instead of fixing it.

## Maintenance notes

Reviewer: look at the header in the simulator in Light and Dark Mode. Check that the bar track is visible,
that the header text lines up with the text in the month cards, and that the gap to the first card looks right.
If the experiment is rejected, `git revert` the single commit; no other file is affected.
