# Plan 145: Size the Overview detail sheets to their content

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 07d4c61..HEAD -- Hugo/Features/Overview Hugo/DesignSystem/Modifiers`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). Never touch, stage or commit it. This plan adds no strings.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW. Presentation only. The risk is a sheet that opens too small on a very large Dynamic Type size or when content changes, which the owner check covers.
- **Depends on**: none
- **Category**: ui
- **Planned at**: commit `07d4c61`, 2026-11-23
- **Issue**: [SLN-326](https://linear.app/sebastianln/issue/SLN-326)

## Why this matters

The Overview detail sheets hold little content but open at `.medium`, so half
the sheet is empty. After this plan, each opens just tall enough for its
content and can still be dragged to `.large`.

## Current state

Sheets in scope, with their detents today:

- `Hugo/Features/Overview/Screens/OverviewView.swift` ~line 113: `PlanPaceSheet(pace: pace).presentationDetents([.medium])`.
- `Hugo/Features/Overview/Views/OverviewListView.swift` ~line 74: `EntryDetailView(entry: entry).presentationDetents([.medium, .large])`; and ~line 286: `CarriedInBreakdownSheet(...).presentationDetents([.medium])`.
- `Hugo/Features/Overview/Views/ReportReminderCard.swift` ~line 62: `NavigationStack { SubmitReportView(month: month).presentationDetents([.medium, .large]) }`.

What each sheet is made of (this decides how to measure):

- `PlanPaceSheet`: a plain `VStack` with `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)`. No scroll view. The `maxHeight: .infinity` stretches it, so it must be removed or the measurement returns the sheet height, not the content height.
- `CarriedInBreakdownSheet`: a `List`. A `List` is a scroll view and reports no intrinsic height. Its rows are a title section plus one row per category, so the height grows with the number of categories.
- `EntryDetailView`: `NavigationStack { Form { ... } }` plus a toolbar. Same problem: `Form` scrolls.
- `SubmitReportView` inside a `NavigationStack`: a form, same problem. It also changes while open (rounding choices, buttons).

Decision: measure the content, not the scroll view.

- For `PlanPaceSheet`, measure the `VStack` itself (no scroll view involved).
- For `List`/`Form` sheets, do NOT try to measure the scroll view. A scroll view proposes no height to its parent, so `onGeometryChange` on it reports the sheet's own height. Leave these sheets alone (`.medium`, `.large`) unless Step 3 shows a clean way to measure. Entry detail and report submission are forms with a wheel picker and several rows, and `.medium` is close to their natural height anyway.
- `CarriedInBreakdownSheet` is the only `List` sheet worth sizing, because it has two rows in the common case. Convert nothing. Use a row-count based height only if Step 3 shows it is needed. Otherwise leave it at `.medium`.

So the expected outcome is: the modifier is applied to `PlanPaceSheet` for sure, and to another sheet only if its content is a plain stack. State in the commit message which sheets got the modifier and why the others did not.

Rules from `AGENTS.md` that apply: SwiftUI only, no UIKit; code in `DesignSystem` names no feature type; modifiers live in `Hugo/DesignSystem/Modifiers` (see `EditorialNavigationTitle.swift` for the style and doc comment tone); tests use Swift Testing.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |

## Scope

**In scope**:

- `Hugo/DesignSystem/Modifiers/ContentHeightSheetDetents.swift` (create)
- `Hugo/Features/Overview/Screens/PlanPaceSheet.swift` (remove `maxHeight: .infinity` only if needed)
- `Hugo/Features/Overview/Screens/OverviewView.swift`
- `Hugo/Features/Overview/Views/OverviewListView.swift` and `ReportReminderCard.swift` only if Step 3 says a sheet can be measured

**Out of scope**:

- Pickers with long lists (`CategoryPicker`, time pickers). They keep `.medium`.
- Planner sheets, Add Entry, Settings.
- Any change to what the sheets show.

## Git workflow

- Work on `main`. Commit per step. Conventional Commits, for example `feat(overview): size the plan pace sheet to its content`.
- Do not push. Never stage `Hugo/Resources/Localizable.xcstrings`.

## Steps

### Step 1: Create the modifier

Create `Hugo/DesignSystem/Modifiers/ContentHeightSheetDetents.swift`:

```swift
import SwiftUI

/// Opens a sheet just tall enough for its content, and lets the user drag it
/// to full height. Apply it to the sheet's content view, which must have an
/// intrinsic height (a stack, not a `List`, `Form` or `ScrollView`).
/// The sheet starts at `.medium` until the content has been measured.
extension View {
    func sheetHeightFitsContent() -> some View {
        modifier(ContentHeightSheetDetents())
    }
}

private struct ContentHeightSheetDetents: ViewModifier {
    @State private var measuredHeight: CGFloat?

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { measuredHeight = $0 }
            .presentationDetents(detents)
    }

    private var detents: Set<PresentationDetent> {
        guard let measuredHeight else { return [.medium, .large] }
        return [.height(measuredHeight), .large]
    }
}
```

`fixedSize(horizontal: false, vertical: true)` makes the view take its ideal
height instead of the sheet height, so the measurement is the content height.
If `.medium` inside the set before measuring causes a visible jump on open,
use `[.medium]` before measuring and keep `[.height, .large]` after.
Detent sets with `.height` change while the sheet is open; the sheet animates
to the new height, which is the wanted behavior when content changes.

If strict concurrency rejects the closure, fix it with the smallest change. No `@unchecked Sendable`.

**Verify**: `swift-format lint --strict Hugo/DesignSystem/Modifiers/ContentHeightSheetDetents.swift` exits 0.

### Step 2: Apply it to the plan pace sheet

In `OverviewView.swift` replace `.presentationDetents([.medium])` on `PlanPaceSheet` with `.sheetHeightFitsContent()`. Keep `.presentationDragIndicator(.visible)`.
In `PlanPaceSheet.swift`, remove `maxHeight: .infinity` from the final `.frame(...)` so it reads `.frame(maxWidth: .infinity, alignment: .topLeading)`.

**Verify**: build succeeds (`Scripts/verify.sh` exit 0). In a preview or simulator the sheet is shorter than before and shows all its content.

### Step 3: Decide on the other three sheets, from the code

Read `CarriedInBreakdownSheet`, `EntryDetailView` and `SubmitReportView`. Each is a `List` or `Form`, so by the decision above leave them at their current detents. The only exception is a sheet whose content you can change to a plain stack without changing how it looks. Do not rewrite a `Form` into a stack to get the modifier.
Record the outcome per sheet in the commit message.

**Verify**: `git diff --stat` shows only the files listed under "In scope".

## Test plan

Pure layout. No unit test is meaningful. The gate is a build plus the owner check below.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] The plan pace sheet opens at its content height and can be dragged to large
- [ ] `git status --short` shows only in-scope files (plus the owner's `Localizable.xcstrings`, unstaged)
- [ ] `plans/README.md` row updated

Owner check on device: open the plan pace sheet at default size, at the largest
accessibility Dynamic Type size (the sheet must grow, never clip), in landscape
and on iPad, and while the logged time changes (add an entry in another sheet,
return). Confirm the sheet never covers less than its content.

## STOP conditions

Stop and report if:

- The measured height equals the full sheet height after `fixedSize` (the modifier cannot measure this content).
- Content clips at the largest Dynamic Type size.
- You find you must restructure a `Form` or `List` to use the modifier.

## Maintenance notes

- Use `sheetHeightFitsContent()` only on stack-based content. Lists and forms keep `.medium, .large`.
- If a future sheet has a scroll view, measure its content inside the scroll view, not the scroll view.
