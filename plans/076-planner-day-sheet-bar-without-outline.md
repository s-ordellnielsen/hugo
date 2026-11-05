# Plan 076: Draw the day sheet's progress bar without an outline

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 418b41e..HEAD -- Hugo/Features/Planner/Views`
> Expected: no output. If any file is listed, compare the "Current state"
> excerpt below with the live code; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW (one view, drawing only)
- **Depends on**: plans/075-planner-plans-per-category.md (DONE, commits `4453300`, `418b41e`)
- **Category**: design (owner feedback after testing 075)
- **Planned at**: commit `418b41e`, 2026-11-05
- **Issue**: [SLN-279](https://linear.app/sebastianln/issue/SLN-279)

## Why this matters

After plan 075 the bars in the Planner's calendar grid look right to the owner:
their outline and fill read as one color. The wide progress bar on each card in
the day sheet does not. The owner sees "a very dark outline" around it, with a
partial or full fill inside, on empty and partly filled bars.

Both places draw `PlannerBarShape` (a 15% tint, a fill in `color`, and a
1-point outline in `color`). On a tiny grid bar the outline is barely visible.
On a bar the width of a card, the outline frames the pale unfilled part and
reads as a dark border.

Owner decision (2026-11-05): the day sheet's bar becomes a plain progress bar:
a neutral gray track with a fill in the category color, and **no outline**.
The grid bars and the legend stay as they are, because they show the "planned
= outlined, logged = filled" idea that the legend explains.

## Current state

`Hugo/Features/Planner/Views/PlannedCategoryCard.swift` (from plan 075), in `body`:

```swift
            PlannerBarShape(fraction: bar.fraction, color: color)
                .frame(maxWidth: .infinity)
                .frame(height: HugoLayout.Size.calendarBarHeight)
                .accessibilityHidden(true)
```

`PlannedCategoryCard` is the only user of `PlannerBarShape` outside
`PlannerBarView.swift` and `PlannerLegend.swift`.

The app's existing progress track (in `Hugo/DesignSystem/Components/CenteredProgressBar.swift`):

```swift
                Capsule()
                    .fill(Color(.secondarySystemFill))
                    .frame(height: HugoLayout.Size.goalTrackHeight)
```

Conventions: `swift-format` line length 120, 4-space indentation.
`HugoLayout.Size.calendarBarHeight` is 6.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Layout | `Scripts/check-layout.sh` | exit 0, no output |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Full gate | `Scripts/verify.sh` | exit 0 (takes several minutes) |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run
the same command again; that is not a failure.

## Scope

**In scope** (the only file you may modify):
- `Hugo/Features/Planner/Views/PlannedCategoryCard.swift`

**Out of scope** (do not touch):
- `PlannerBarView.swift` (including `PlannerBarShape`), `PlannerLegend.swift`, `PlannerDayCell.swift`: the grid and legend stay as they are.
- Everything else, including `plans/` and `.claude/` (owner's files).

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- The working tree holds uncommitted owner files in `plans/` and `.claude/`. Never stage, edit, stash or discard them. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage only `Hugo/Features/Planner/Views/PlannedCategoryCard.swift`, by explicit path.
- One commit: `fix: draw the planner day sheet bar without an outline`
- A pre-commit hook formats staged Swift files. That is expected.

## Steps

### Step 1: Replace the bar in the card

In `PlannedCategoryCard.swift`, replace the four lines shown in Current state with:

```swift
            progressBar
                .frame(height: HugoLayout.Size.calendarBarHeight)
                .accessibilityHidden(true)
```

Add this private property to `PlannedCategoryCard`, directly after the
`startTimeText(for:)` function:

```swift
    /// A gray track filled from the left in the category's color. Unlike the
    /// calendar's bars it has no outline: on a bar this wide, an outline reads
    /// as a dark border around the unfilled part.
    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.secondarySystemFill))
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * bar.fraction)
            }
        }
    }
```

`bar.fraction` is already clamped to 0...1 by `PlannerBar`.

**Verify**: `grep -n "PlannerBarShape\|strokeBorder\|stroke(" Hugo/Features/Planner/Views/PlannedCategoryCard.swift` → no output.
**Verify**: `grep -c "PlannerBarShape" Hugo/Features/Planner/Views/PlannerBarView.swift Hugo/Features/Planner/Views/PlannerLegend.swift` → both files still list at least 1.
**Verify**: Layout → exit 0. Lint → exit 0.

### Step 2: Full gate

**Verify**: `Scripts/verify.sh` → exit 0, and its output contains `** TEST SUCCEEDED **` and `** ANALYZE SUCCEEDED **`.

Commit (stage only `PlannedCategoryCard.swift`). Then `git status --short` must
show only `plans/` and `.claude/` entries.

## Test plan

No unit tests: this is drawing only, and the fraction it draws is covered by
`PlanMatcherTests`. Manual (owner, simulator or device, light and dark mode):

1. Day sheet, a plan with nothing logged: a gray track, no colored border.
2. Partly logged: the colored part starts at the left, the rest is gray, no border.
3. Fully logged or more: a solid bar in the category color.
4. The calendar grid's bars and the legend look the same as before (outlined).

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -n "PlannerBarShape" Hugo/Features/Planner/Views/PlannedCategoryCard.swift` → no output
- [ ] `git diff --stat 418b41e..HEAD` lists only `PlannedCategoryCard.swift`
- [ ] `git status --short` shows only `plans/` and `.claude/` entries
- [ ] `plans/README.md` status row updated (skip if a reviewer maintains it)

## STOP conditions

Stop and report back (do not improvise) if:

- The drift check lists a file and the live code no longer matches the excerpt.
- The four lines in Current state are not in `PlannedCategoryCard.swift` exactly once.
- You find you need to change any other file.
- A step's verification fails twice after a reasonable fix attempt.

## Maintenance notes

- The day sheet bar and the grid bars now look different on purpose: the grid
  uses outlines to tell planned from logged at a glance; the sheet has a
  progress line under the bar and needs no outline.
- If the owner later wants the grid bars without outlines too, change
  `PlannerBarShape` and update `PlannerLegend`, whose "planned" swatch is an
  empty outlined bar.
