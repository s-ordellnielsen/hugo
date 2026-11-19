# Plan 133: Build the Monthly Target preview once per render instead of three times

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 6472b73..HEAD -- Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift`
> Expected: no output. If the file changed, compare it with "Current state" and STOP on a mismatch.
> Also `git status --short` must show only
> `M Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` (the owner's own
> edit; never touch or commit it) and untracked plan files.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW. One file, no change to any displayed value.
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `6472b73`, 2026-11-19
- **Issue**: [SLN-316](https://linear.app/sebastianln/issue/SLN-316)

## Why this matters

`PlannerTargetSettingsView` (Settings > General > Monthly Target) reads its
`preview` property three times in `body`. `preview` is a computed property, so
each read runs `PlannerTarget.creditedBeforeCurrentMonth`, which builds a whole
`TheocraticYearReport`. That is the screen's main cost: in a device time
profile taken while tracking a freeze (plan 132, Revision 3), about two thirds of
the main thread's time was spent in that report builder. The freeze itself came
from a different cause and is fixed. This plan only removes the avoidable
repeated work, so that any redraw of this screen costs a third as much. It also
follows `AGENTS.md`, which says not to do complex computation inside a view's
`body`. The Planner tab already does it the right way: `PlannerView` computes
`let credited = creditedBeforeCurrentMonth` once at the top of its `body`.

Out of scope on purpose: caching the result across redraws. Do that only if the
screen is still slow after this change.

## Current state

`Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift`, lines 43 to 62
(verify these match before editing):

```swift
    private var creditedBeforeCurrentMonth: TimeInterval {
        PlannerTarget.creditedBeforeCurrentMonth(
            entries: yearEntries, submissions: submissions, trackers: trackers, schoolCredits: schoolCredits,
            status: status, now: now, calendar: calendar, locale: locale)
    }

    private var preview: PlannerTargetPreview {
        PlannerTargetPreview.make(
            base: base, extraHours: extraHours, status: status,
            creditedBeforeCurrentMonth: creditedBeforeCurrentMonth,
            now: now, calendar: calendar, locale: locale)
    }

    var body: some View {
        List {
            Section {
                PlannerTargetPreviewView(preview: preview, hasGoal: hasGoal)
                    .padding(.vertical, HugoLayout.Spacing.regular)
            }

            if status?.yearlyGoalRule != nil {
                Section {
                    SelectableOptionRow(
                        title: Text("planner.target.base.monthlyGoal"),
                        description: Text(preview.monthlyBaseDescription),
                        isSelected: base == .monthlyGoal
                    ) {
                        base = .monthlyGoal
                    }
                    SelectableOptionRow(
                        title: Text("planner.target.base.yearlyGoalShare"),
                        description: Text(preview.adjustedDescription),
                        isSelected: base == .yearlyGoalShare
```

`grep -n "preview" Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift`
currently shows the property at line 49, three reads in `body` (lines 59, 67 and
74), and two `.modelContainer(.preview)` lines in the previews at the bottom
(lines 144 and 154), which are unrelated to this change.

Convention to match: `PlannerView.swift` (lines 74 to 82) computes the credited
time once into a local `let` at the top of `body`:

```swift
    var body: some View {
        let credited = creditedBeforeCurrentMonth
        NavigationStack {
```

`body` of a `View` is a `@ViewBuilder`, so a `let` statement before the first
view is allowed.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint one file | `xcrun swift-format lint --strict <file>` | exit 0, no output |
| Whole gate | `Scripts/verify.sh` | exit 0 (lint, all tests, analyze). Takes several minutes. |

## Scope

**In scope** (the only file you may modify):

- `Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift`
- `plans/README.md` (status row)

**Out of scope** (do NOT touch):

- `PlannerTarget.swift`, `PlannerTargetPreview.swift`, `PlannerTargetPreviewView.swift`: the maths and the preview model do not change.
- `BufferScopeSettingsView.swift` and anything about the "Counts in" row, the `.motion` line or the `@AppStorage` properties. They were part of a separate freeze fix and must stay as they are.
- `PlannerView.swift`: it already builds the credited time once.
- `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`: the owner's uncommitted edit. Never stage it.

## Git workflow

- Commit straight to `main`. Do not create a branch or a worktree.
- One commit after `Scripts/verify.sh` exits 0, Conventional Commits: `refactor: build the Monthly Target preview once per render`.
- Stage by explicit path only. Never `git add -A` or `git add .`. Do not push.

## Steps

### Step 1: Turn `preview` into a function and call it once

In `PlannerTargetSettingsView.swift`:

1. Replace `private var preview: PlannerTargetPreview {` with `private func makePreview() -> PlannerTargetPreview {`. Keep its body exactly as it is.
2. At the very top of `var body: some View {`, before `List {`, add:

```swift
        let preview = makePreview()
```

3. Do not change any other line. The three reads (`preview`, `preview.monthlyBaseDescription`, `preview.adjustedDescription`) now read the local constant, so the year report is built once per `body` evaluation.

**Verify**:
- `xcrun swift-format lint --strict Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift` → exit 0.
- `grep -n "makePreview" Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift` → exactly two lines: the function declaration and the single call at the top of `body`.
- `grep -n "preview" Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift | grep -v "modelContainer"` → the function, the local `let preview`, and the same three reads as before.

### Step 2: Run the gate and commit

Run `Scripts/verify.sh`, with the full output redirected to a file under
`/private/tmp/claude-501/-Users-sebastiannielsen-Documents-Areas-Personal-Apps-Hugo/aac047fd-971a-4205-b00b-3f151b982d7b/scratchpad/`
(for example `verify-133.log`), and take the exit code from the script itself.
Then stage the one file by explicit path and commit with the message from
"Git workflow".

**Verify**: exit code 0, and the log contains `** TEST SUCCEEDED **` and `** ANALYZE SUCCEEDED **`.

## Test plan

No new test. The change moves where a value is computed, not what it is, and no
seam in this codebase counts view-body evaluations. The existing
`PlannerTargetPreviewTests` and `PlannerTargetTests` keep covering the values.
Say this in NOTES.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0.
- [ ] `grep -c "makePreview" Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift` prints `2`.
- [ ] Only `PlannerTargetSettingsView.swift` changed in the commit.
- [ ] `plans/README.md` status row updated (unless the reviewer maintains it).

## STOP conditions

Stop and report back (do not improvise) if:

- The code at "Current state" does not match, for example `preview` is no longer a computed property or is read a different number of times.
- `body` fails to compile with the added `let` (then say so; do not restructure the view).
- A step's verification fails twice.
- The change appears to need any file outside the scope list.

## Maintenance notes

- If this screen still feels slow, the next step is to cache `creditedBeforeCurrentMonth` so it is rebuilt only when entries, reports, categories, school credit or the status change, not on every redraw (for example a `@State` value refreshed from `.task(id:)`). That needs a stable signature of the `@Query` results, which is why it is deliberately not part of this plan.
- Do not read the same `@AppStorage` keys from a page pushed from this screen: a pushed page that declared its own `@AppStorage` for the keys this screen declares froze the app (plan 132, Revision 3). Pass bindings instead.
- A reviewer should check that no displayed value changes: open Settings > General > Monthly Target and compare the preview bar, both base descriptions and the Buffer stepper.
