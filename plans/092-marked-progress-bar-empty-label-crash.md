# Plan 092: Stop the Planner header crashing when the plan goes past the target

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 333c857..HEAD -- Hugo/DesignSystem/Components/MarkedProgressBar.swift HugoTests/DesignSystem/Components/MarkedProgressBarTests.swift`
> Expected: no output. If a file is listed, compare the "Current state" excerpts below with the live code. On any mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1 (crash in code that ships in the next build)
- **Effort**: S
- **Risk**: LOW (one private layout type; no data, schema or string change)
- **Depends on**: none (fixes a bug from plan 091, commit `a43cb85`)
- **Category**: bug
- **Planned at**: commit `333c857`, 2026-11-06
- **Issue**: [SLN-301](https://linear.app/sebastianln/issue/SLN-301)

## Why this matters

The app crashes with `EXC_BREAKPOINT` in `MarkedProgressBarLayout` (`MarkedProgressBar.swift:223`) as soon as the Planner header has to draw a target marker. That happens when the month's logged time plus its still-planned time goes past the monthly target, which is exactly what a motivated user does.

Cause: `MarkedProgressBarLayout` is a SwiftUI `Layout` with two children, the track and the marker label. When a marker is set, it always reads `subviews[1]`. But a label that renders nothing (`EmptyView`, which the convenience initializer uses, or an `if` whose condition is false) produces **no** subview, so `subviews` has one element and `subviews[1]` traps (index out of range). `PlannerProgressBar` uses the convenience initializer with a marker, so it crashes every time `projectedSeconds > targetSeconds`.

The reviewer reproduced the crash by rendering `PlannerProgressBar(loggedSeconds: 10 h, stillPlannedSeconds: 20 h, targetSeconds: 25 h)` with `ImageRenderer` in a test (the test process crashed). The fix below was then applied in a scratch worktree, and the same render succeeded: a bar 52 pt tall with the marker at the target and no label.

## Current state

- `Hugo/DesignSystem/Components/MarkedProgressBar.swift`. The public view's body passes two children to the layout. The second is the label:

  ```swift
  // MarkedProgressBar.swift:28-51
          MarkedProgressBarLayout(
              marker: marker,
              markerPosition: marker ?? 0.5,
              ...
          ) {
              ZStack(alignment: .leading) {
                  ProgressTrack(...)
                  ...
              }
              .accessibilityHidden(true)
              markerLabel
                  .fixedSize(horizontal: false, vertical: true)
                  .accessibilityHidden(true)
          }
  ```

  ```swift
  // MarkedProgressBar.swift:80-86
  extension MarkedProgressBar where MarkerLabel == EmptyView {
      init(filled: Double, extended: Double? = nil, marker: Double? = nil) {
          self.init(filled: filled, extended: extended, marker: marker) {
              EmptyView()
          }
      }
  }
  ```

  The layout (lines 219–258) reads `subviews[1]` twice and places it once:

  ```swift
      func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
          let width = max(0, proposal.width ?? 0)
          guard marker != nil else { return CGSize(width: width, height: markerHeight) }

          let labelSize = subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil))
          let labelGap = labelSize.height > 0 ? self.labelGap : 0
          return CGSize(width: width, height: labelSize.height + labelGap + markerHeight)
      }

      func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
          ...
          let labelSize = subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil))
          let labelGap = labelSize.height > 0 ? self.labelGap : 0
          let markerCenter = physicalPosition(for: markerPosition, width: width)
          let labelCenter = min(max(markerCenter, labelSize.width / 2), width - labelSize.width / 2)

          subviews[1].place(
              at: CGPoint(x: bounds.minX + labelCenter, y: bounds.minY + labelSize.height / 2),
              anchor: .center,
              proposal: ProposedViewSize(width: width, height: labelSize.height)
          )
          subviews[0].place(
              ...
          )
      }

      private func physicalPosition(for fraction: Double, width: CGFloat) -> CGFloat {
  ```

- `Hugo/Features/Planner/Views/PlannerProgressBar.swift` (do not edit) is the caller that crashes:

  ```swift
  MarkedProgressBar(
      filled: loggedSeconds / scale,
      extended: projectedSeconds / scale,
      marker: projectedSeconds > targetSeconds ? targetSeconds / scale : nil
  )
  ```

- The two other callers (`CurrentMonthCalculationPreview`, `PlannerTargetPreviewView`) always pass a `Text` label, so they are not affected. They must keep working unchanged.
- `HugoTests/DesignSystem/Components/MarkedProgressBarTests.swift` holds one geometry test (`interpolatedFillStaysClampedAndExtensionNeverMovesBehindSolidFill`). New tests go in the same struct.
- Theme facts for the test: `HugoLayout.Size.goalTrackHeight` is 12 and `HugoLayout.Spacing.tight` is 4, so `markerHeight` is 20.
- Project facts: Swift 6, default actor isolation `MainActor`; tests use Swift Testing (`import Testing`, `@Test`, `#expect`). `ImageRenderer` must run on the main actor.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/MarkedProgressBarTests -only-testing:HugoTests/MarkedProgressBarGeometryTests` | `** TEST SUCCEEDED **` |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Full gate | `Scripts/verify.sh` | exit 0 (several minutes) |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run the same command again.

## Scope

**In scope** (the only files you may modify):
- `Hugo/DesignSystem/Components/MarkedProgressBar.swift` (only `MarkedProgressBarLayout`)
- `HugoTests/DesignSystem/Components/MarkedProgressBarTests.swift`

**Out of scope**:
- `PlannerProgressBar.swift` and every other caller. Do not "fix" the crash by giving callers a label; the shared component must accept an empty label.
- `MarkedProgressBarGeometry`, `ProgressTrack`, `ProgressMarker` and the public `MarkedProgressBar` initializers.
- Any visual change. With a label present, layout must stay exactly as it is.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- Never stage, edit, stash or discard files in `plans/` or `.claude/`. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage the two in-scope files by explicit path.
- One commit: `fix: stop the marked progress bar crashing without a marker label`

## Steps

### Step 1: Write the failing regression test

In `HugoTests/DesignSystem/Components/MarkedProgressBarTests.swift`, change the first line block to import SwiftUI as well:

```swift
import SwiftUI
import Testing

@testable import Hugo
```

and add these two tests inside `struct MarkedProgressBarTests`, after the existing test:

```swift
    /// A marker without a label gives the layout only one subview. This used
    /// to crash (index out of range) in the Planner header whenever the plan
    /// went past the monthly target.
    @Test @MainActor
    func markerWithoutLabelRendersAtMarkerHeight() throws {
        let renderer = ImageRenderer(
            content: MarkedProgressBar(filled: 0.4, extended: 1, marker: 0.8).frame(width: 300))
        let image = try #require(renderer.uiImage)
        #expect(image.size.height == HugoLayout.Size.goalTrackHeight + 2 * HugoLayout.Spacing.tight)
    }

    @Test @MainActor
    func plannerBarPastTheTargetRenders() throws {
        let renderer = ImageRenderer(
            content: PlannerProgressBar(
                loggedSeconds: 10 * 3_600, stillPlannedSeconds: 20 * 3_600, targetSeconds: 25 * 3_600
            )
            .frame(width: 300))
        #expect(renderer.uiImage != nil)
    }
```

**Verify**: run the focused tests. Expected: the run does NOT succeed. The test process crashes (`Restarting after unexpected exit, crash, or test timeout` and `** TEST FAILED **`). This proves the tests reproduce the bug. If instead they pass, STOP and report.

### Step 2: Let the layout handle a missing label

In `MarkedProgressBar.swift`, inside `MarkedProgressBarLayout` only:

1. Add this helper directly before `private func physicalPosition(for fraction: Double, width: CGFloat) -> CGFloat {`:

   ```swift
       /// The marker label's size. An empty label (`EmptyView`, or an `if` that
       /// produced nothing) gives the layout no second subview, so its size is zero.
       private func labelSize(in subviews: Subviews, width: CGFloat) -> CGSize {
           guard subviews.count > 1 else { return .zero }
           return subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil))
       }

   ```

2. Replace both occurrences of
   `        let labelSize = subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil))`
   with
   `        let labelSize = labelSize(in: subviews, width: width)`.

3. In `placeSubviews`, wrap the `subviews[1].place(...)` call in `if subviews.count > 1 { ... }` (re-indent it by four spaces). Leave the `subviews[0].place(...)` call after it unchanged.

**Verify**:
- `grep -n "subviews\[1\]" Hugo/DesignSystem/Components/MarkedProgressBar.swift` → exactly two lines: one in `labelSize(in:width:)` and one inside the new `if`.
- The focused tests → `** TEST SUCCEEDED **`.

### Step 3: Run the gate and commit

Run `Scripts/verify.sh`. Stage the two in-scope files by path and commit with the message from "Git workflow".

**Verify**: `Scripts/verify.sh` exits 0. `git show --stat HEAD` lists only the two in-scope files.

## Test plan

- `markerWithoutLabelRendersAtMarkerHeight`: the shared component with a marker and no label renders, and its height is the marker height (20 pt) with no label gap.
- `plannerBarPastTheTargetRenders`: the real crashing caller renders.
- Existing `MarkedProgressBarTests` and `MarkedProgressBarGeometryTests` keep passing (labelled bars are untouched).

## Done criteria

- [ ] Step 1's tests crashed before the fix (record the output in your report).
- [ ] `Scripts/verify.sh` exits 0.
- [ ] `grep -c "subviews\[1\]" Hugo/DesignSystem/Components/MarkedProgressBar.swift` → `2`.
- [ ] `git show --stat HEAD` lists only the two in-scope files.
- [ ] Owner check on device: in the Planner, plan more than the month's target. The header shows the bar with a target marker and no crash. Settings → Planner target and Settings → current-month calculation still show their bars with labels as before.

## STOP conditions

Stop and report back (do not improvise) if:

- The drift check shows changes and the excerpts above no longer match.
- Step 1's tests pass before the fix.
- The fix seems to need a change outside `MarkedProgressBarLayout` or the test file.
- A step's verification fails twice after a reasonable fix attempt.

## Maintenance notes

- Any new `Layout` in `DesignSystem` that takes optional content must check `subviews.count` instead of assuming a fixed number of children. `EmptyView` and a false `if` contribute zero subviews.
- Plan 091's review missed this because `PlannerProgressBar` only shows a marker when planned time exceeds the target, and no test rendered that case. The render tests added here cover it.
