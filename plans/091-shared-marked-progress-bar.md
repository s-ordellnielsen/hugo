# Plan 091: Share a clipped, animated marked progress bar between Planner and Settings

> **Executor instructions**: This is a planning handoff, not a request to
> implement before the owner starts it. Read the complete plan, follow each
> verification gate, and stop on the listed conflicts. This plan goes before
> 083 and 084 despite its higher number. Update Linear and the plan index as
> implementation progresses; owner acceptance is required before Done.
>
> **Drift check**: planned against `9be5c03`, revised 2026-11-06.
> Run `git diff --stat 9be5c03..HEAD -- Hugo/DesignSystem Hugo/Features/Planner/Views/PlannerProgressBar.swift Hugo/Features/Planner/Views/PlannerStatusHeader.swift HugoTests/DesignSystem`.
> No implementation differences are expected before this plan. If these paths
> changed, compare the excerpts and contracts below before editing; stop if
> their behavior or ownership no longer matches.

## Status

* **Status**: DONE (full verification passed; owner tested and accepted 2026-11-06)
* **Priority**: P1
* **Effort**: M + owner device check
* **Risk**: MED — shared drawing and animation replace a live Planner visual.
* **Depends on**: none. Execute **091 → 083 → 084**.
* **Category**: tech-debt / direction
* **Planned at**: commit `9be5c03`, revised 2026-11-06
* **Issue**: [SLN-300](https://linear.app/sebastianln/issue/SLN-300)

## Why this matters

The Planner header and two upcoming Settings pages need the same drawing: a rounded track, solid fill, optional faded extension, and optional marker. A shared component prevents three implementations from drifting and provides one place to contain near-zero fills. The setting pages add meaningful labels and real calculations in plans 083 and 084; this prerequisite changes drawing, not target math.

The first draft of this plan included uncompiled full component code. This revision replaces it with a bounded interface, drawing contract, and geometry/visual checks. Do not copy the old draft's offset implementation or assume merely clipping a final stack proves intermediate animation frames are correct.

## Current state

`Hugo/Features/Planner/Views/PlannerProgressBar.swift:5–43` at `9be5c03`:

```swift
struct PlannerProgressBar: View {
    let loggedSeconds: TimeInterval
    let stillPlannedSeconds: TimeInterval
    let targetSeconds: TimeInterval

    private var projectedSeconds: TimeInterval { loggedSeconds + stillPlannedSeconds }

    var body: some View {
        GeometryReader { proxy in
            let scale = max(targetSeconds, projectedSeconds, 1)
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(Color.hugoAccent.opacity(0.35))
                    .frame(width: width * min(1, projectedSeconds / scale))
                Capsule()
                    .fill(Color.hugoAccent)
                    .frame(width: width * min(1, loggedSeconds / scale))
                if projectedSeconds > targetSeconds {
                    Rectangle()
                        .fill(.primary)
                        .frame(width: 2)
                        .offset(x: width * targetSeconds / scale - 1)
                }
            }
        }
        .frame(height: HugoLayout.Size.goalTrackHeight)
        .motion(Motion.progress, value: projectedSeconds)
        .accessibilityHidden(true)
    }
}
```

`PlannerStatusHeader.swift:34–41` wraps that view in `.padding(.vertical, HugoLayout.Spacing.tight)`.

Relevant existing infrastructure:

* `Hugo/DesignSystem/Theme/Theme.swift`: `goalTrackHeight = 12`, `Spacing.tight = 4`, and other standard spacing tokens. `Color.hugoAccent` is System Teal.
* `Hugo/DesignSystem/Motion/Motion.swift`: `Motion.progress` is the existing progress spring. `.motion(_:value:)` currently substitutes a short ease-in/out animation under Reduce Motion; that still interpolates width. The new component must disable spatial interpolation locally under Reduce Motion without changing the app-wide modifier.
* `Hugo/DesignSystem/Components/CenteredProgressBar.swift` serves the Year page; its centered trail and knob are a different visual. Do not migrate it.
* `Hugo/Features/Planner/Views/PlannedCategoryCard.swift` and calendar day bars have separate outlines/category semantics. Do not migrate them speculatively.
* `Scripts/check-layout.sh` rejects feature types in DesignSystem, including comments naming `Entry`, `Tracker`, `SubmittedReport`, `TheocraticYear`, or `PublisherStatus`.
* SwiftUI-only, iOS/iPadOS 26+, Swift 6 complete concurrency checking and MainActor default isolation. Generic UI and pure geometry belong inside `DesignSystem/Components`; tests mirror their source folder.

## Component contract

### Interface and ownership

Create `Hugo/DesignSystem/Components/MarkedProgressBar.swift`. A generic optional marker label is sufficient; do not create a chart framework or an API accepting feature models.

```swift
struct MarkedProgressBar<MarkerLabel: View>: View {
    // Interface sketch, not a complete implementation.
    init(
        filled: Double,
        extended: Double? = nil,
        marker: Double? = nil,
        @ViewBuilder markerLabel: () -> MarkerLabel
    )
}

extension MarkedProgressBar where MarkerLabel == EmptyView {
    init(filled: Double, extended: Double? = nil, marker: Double? = nil)
}
```

The inputs are normalized fractions, not hours or dates. At this generic drawing boundary, clamp finite fractions to 0...1. The extension cannot end before the solid fill. The caller supplies semantic labels and handles nil/zero target meaning. The component knows nothing about Planner, settings, statuses, or persistence.

The component hides its shapes and optional marker label from VoiceOver because the containing feature must expose one equivalent semantic summary. Document that obligation in the component comment. The Planner already has readable amounts; the Settings plans explicitly add summaries.

### Drawing and near-zero fills

* Track: `Capsule`, `.quaternary`, height `goalTrackHeight`.
* Solid fill: `.hugoAccent`. Faded extension: the same color at opacity 0.35, drawn underneath the solid fill so the visible remainder has no seam.
* Entire track/fill drawing is clipped to the track's capsule. Marker and label are **outside** that clip.
* A zero fraction draws no colored path at all. A tiny positive fraction draws only the visible sliver inside the rounded leading cap; do not give it a minimum visible width or change the represented value.
* Preserve a round exposed trailing end at ordinary fill lengths. Do not let a capsule narrower than its height turn into a vertical pill that escapes the track.
* A suitable construction is a fill capsule with length `max(end, height)`, anchored explicitly at the track's leading origin and shifted by `end - length`, then intersected with the fixed track capsule. At zero the path is empty. An equivalent custom `Shape` may calculate the same path. **Do not** center the short capsule in the track and then apply that offset; parent layout must not change its origin or width.
* To keep spring overshoot safe, animate the scalar fraction(s) and clamp the **interpolated** value inside the drawing operation. Clamping only the destination before applying implicit frame/offset animation is not enough: the intermediate width may overshoot, go negative, or leave a sliver at rest. A small `Animatable` Shape with path-time clamping is an appropriate implementation. Keep it private to this component.
* The containment clip remains active throughout animation, not only at rest. Animate solid and extended endpoints together so a fading segment never trails behind the solid fill or develops a gap during interruption.

### Marker, label, and layout

* Marker: 2 pt wide capsule, full primary contrast, height `goalTrackHeight + 2 * Spacing.tight` (20 pt today). It extends 4 pt above/below the track. At endpoint positions keep the complete marker inside the available horizontal bounds rather than drawing half outside the row.
* Always reserve that 20 pt track/marker envelope, even with no marker, so showing a marker does not change row height. The optional label adds its measured height above it.
* Center the label over its marker where possible; shift the **label**, not the semantic marker position, inward when it meets an edge.
* Measure the label against the available width and permit multiline wrapping at large text sizes. Measure and place with the same constrained proposal. An unconstrained `sizeThatFits(.unspecified)` followed by x-clamping will still overflow for a label wider than the track; do not use it as the sole layout strategy.
* No fixed label height, text scaling, one-line truncation, negative-width geometry, or feedback loop from a GeometryReader/preference/state measurement.
* A private SwiftUI `Layout` can perform the constrained label placement. Honor the project's concurrency settings through correct isolation; do not add `@unchecked Sendable`, unsafe isolation escapes, or legacy dispatch to force compilation.
* Respect semantic leading/trailing layout. English and Danish are required now; do not hardcode physical left/right positioning that would make future RTL fill direction inconsistent with SwiftUI.

### Motion and accessibility

* Animate only when fraction inputs change, using `Motion.progress`. Render the initial values immediately. No first-appearance sweep, looping effect, or implicit animation of the whole row/list.
* Rapid changes must retarget from the current visual state; do not queue animations, add sleeps, or use timers/tasks to replay movement.
* Read `accessibilityReduceMotion` locally. With Reduce Motion, suppress spatial interpolation entirely (an instant update or nonspatial cross-fade is acceptable). Do not use the current `.motion` fallback if it still animates width.
* Treat solid/extended/marker input changes as one value-driven update. Changes in logged versus planned amounts can preserve the total; watching only `projectedSeconds` misses those changes.
* The component is passive, not a slider or an accessibility adjustable element. Semantic values come from caller text, never a bare percentage alone.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Focused tests/build | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/MarkedProgressBarGeometryTests -only-testing:HugoTests/PlannerMonthStatusTests` | `** TEST SUCCEEDED **`; both suites appear |
| DesignSystem boundary | `Scripts/check-layout.sh` | Exit 0 |
| Format | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | Exit 0 |
| Whitespace | `git diff --check` | Exit 0 |
| Full gate before every implementation commit | `Scripts/verify.sh` | Exit 0: layout, format, serial tests, analyze |

## Scope

**In scope**:

* `Hugo/DesignSystem/Components/MarkedProgressBar.swift` (new)
* `Hugo/DesignSystem/Components/MarkedProgressBarGeometry.swift` (new, small internal pure geometry value for drawing/tests)
* `HugoTests/DesignSystem/Components/MarkedProgressBarGeometryTests.swift` (new, mirrors source)
* `Hugo/Features/Planner/Views/PlannerProgressBar.swift` (delegate drawing only)
* `Hugo/Features/Planner/Views/PlannerStatusHeader.swift` (remove the padding now reserved internally)
* This plan's index status and SLN-300 workflow state.

**Out of scope**:

* Settings pages/strings (083 and 084), other progress components, category/calendar bars.
* Domain calculations, target rules, stored defaults, model schema, or generic graph abstractions.
* Changing the shared `.motion` modifier app-wide. Local suppression under Reduce Motion is sufficient.
* Localization: preview-only literal examples are fine; the generic component produces no user-facing strings itself.

## Git workflow

Work on `main` directly, with no branch, worktree, push, or agent co-authorship trailer. Preserve existing owner edits and never use blanket staging or destructive cleanup. Run `Scripts/verify.sh` before committing the scoped implementation; suggested message `refactor: share a clipped marked progress bar`. Keep completion-status documentation in a separate commit and run the gate before it too. SLN-300 goes In Progress at implementation start and In Testing after verification; only owner acceptance makes it Done.

## Steps

### Step 1: Implement tested geometry, then the component

Add a small nonisolated `MarkedProgressBarGeometry` value alongside the component. It normalizes/clamps endpoints and calculates the fill length/origin plus marker center for a given available width and track height. Use that exact value in the production drawing, including when resolving animated scalar values; do not test a disconnected helper while the actual shape uses a different formula. Keep domain values and localization out.

Add Swift Testing coverage before integrating it:

* Fraction 0 produces an empty fill, not a minimum-length visible rectangle/capsule.
* Very small positives (0.001, 0.01), ordinary fractions, and 1 produce the intended endpoint with no visible path outside the track after clipping.
* Fractions below 0 and above 1, including sampled overshoot values, normalize without negative dimensions. Zero-width layout is harmless.
* Extended endpoint never precedes solid, including during interpolated/retargeted samples.
* Endpoint marker centers stay within bounds by half the marker width.
* Test the **visible clipped path/intersection**, not only the unbounded capsule rectangle (which intentionally begins outside the track). Use points safely within/outside the path, not assumptions about anti-aliased edge pixels.

Implement the component to the contract above. The file may contain private `Shape` and `Layout` helpers; do not introduce a new catch-all folder or generic framework. Constrain label measurement and allow its height to expand. Keep animation state in SwiftUI's animatable values, not a parallel unstructured task.

**Verify**: focused test/build command succeeds and the geometry suite is actually listed; `Scripts/check-layout.sh` exits 0. Compilation is necessary but does not replace the visual checks below.

### Step 2: Delegate Planner drawing without changing its math

Keep `PlannerProgressBar` as the feature adapter with its existing inputs and `projectedSeconds`. Replace its body with the shared component call:

```swift
var body: some View {
    let scale = max(targetSeconds, projectedSeconds, 1)
    MarkedProgressBar(
        filled: loggedSeconds / scale,
        extended: projectedSeconds / scale,
        marker: projectedSeconds > targetSeconds ? targetSeconds / scale : nil)
}
```

The Planner still shows a marker only when projected time exceeds target, and scales to max(target, projected). It does not pass a marker label. The shared component hides its drawing and owns animation.

Remove exactly `.padding(.vertical, HugoLayout.Spacing.tight)` immediately following the `PlannerProgressBar(...)` call in `PlannerStatusHeader`. The new component's 20 pt envelope replaces the old 12 pt track plus 8 pt external padding, keeping total header height unchanged. Do not remove padding elsewhere in the header.

**Verify**: focused tests pass; `PlannerProgressBar.swift` no longer draws `Capsule` or uses a `GeometryReader`. Inspect the diff: target, projected totals, marker condition, and feature accessibility text remain unchanged.

### Step 3: Add visual and interruption previews

In `MarkedProgressBar.swift`, include previews for empty/0.001/0.01/normal/full fills; faded-only and solid-only fills; markers at both endpoints and middle; optional labels wider than the available space; and a button that rapidly switches input tuples. Use normal SwiftUI Button initializers, not nonexistent `Button(verbatim:)`. Preview text should be literal-only and never extracted as production copy.

Include a narrow-width comparison, largest accessibility Dynamic Type, Danish-length goal label, light/dark appearance, and a Reduce Motion environment preview. Both label and track should use the same proposed width. Use a long enough example to actually trigger multiline measurement.

Observe changes from near zero to full and back, then interrupt them by tapping again. Inspect slow animations or frame captures for overflow, residual slivers, out-of-order extended/solid endpoints, and moving/clipped labels. Also exercise a logged/planned redistribution with the same projected total to prove both fills update. Record which previews were actually inspected and any device observations; there is no snapshot harness, so do not claim automated visual coverage.

**Verify**: focused build/tests and format checks pass; record the preview matrix and outcome. Any geometry or layout defect blocks the Planner switch from acceptance.

### Step 4: Run the full gate and request the Planner device check

Run `Scripts/verify.sh` and `git diff --check`, inspect the staged diff, and commit explicit in-scope paths. Update SLN-300 to In Testing with commit and verification results. Record that 083 is waiting on the owner check.

**Verify**: Implementation commit `a43cb85` landed on 2026-11-06. `Scripts/verify.sh` passed, and the owner tested the Planner and confirmed it works that day. SLN-300 is Done.

## Test plan

* `MarkedProgressBarGeometryTests` uses the exact production geometry and verifies clipping-relevant points and normalized/interpolated inputs.
* Existing `PlannerMonthStatusTests` remain unchanged and pass: this plan must not alter their numbers.
* Preview/manual matrix covers the behaviors unit tests cannot establish: label wrapping, rendering/animation frames, interruption, two fill styles, layout direction, Dynamic Type, light/dark, and Reduce Motion.
* Owner device check confirms the header's total height and semantics are unchanged, with the intended slightly taller rounded marker and better-contained near-zero fill.

## Done criteria

* [x] Generic shared bar exists; DesignSystem boundary check passes.
* [x] Production geometry has tests; focused suites and `Scripts/verify.sh` pass.
* [x] Zero/tiny fill and intermediate spring states stay contained; no minimum fake progress.
* [x] Endpoint/long labels remain inside the available width and can wrap.
* [x] Planner delegates drawing and preserves scale, marker visibility, and header height.
* [x] Reduce Motion suppresses spatial progress interpolation locally.
* [x] Owner tested and accepted the Planner on 2026-11-06.

## STOP conditions

* Existing Planner inputs/scale/marker behavior no longer match the excerpts.
* Meeting the design seems to require changing target math, another bar, app-wide motion, or adding unsafe concurrency escapes.
* Tiny fills cannot remain contained during interpolation, or long marker labels require truncation/fixed heights.
* New tests assert only unused helper math rather than production geometry.
* Verification fails twice after a targeted fix, or unrelated tests fail without an identified cause.

## Maintenance notes

Plans 083 and 084 consume the same drawing with feature-owned meanings and labels. They must not duplicate fill geometry. Do not migrate `CenteredProgressBar` or category bars merely because they have “progress” in their names. Add new color/configuration knobs only when a real caller needs them. The new marker is a 2 × 20 pt capsule rather than the old 2 × 12 pt rectangle; that and near-zero containment are the intended Planner visual differences.
