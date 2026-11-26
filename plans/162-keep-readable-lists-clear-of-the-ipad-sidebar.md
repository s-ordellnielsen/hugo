# Plan 162: Keep readable-width lists clear of the iPad sidebar

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat b198210..HEAD -- Hugo/DesignSystem/Modifiers HugoTests/DesignSystem/Modifiers`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). This plan adds no strings. Never stage that file.

## Status

- **Priority**: P1 (a visible layout bug introduced by plan 159)
- **Effort**: S + owner
- **Risk**: LOW. Two design-system files and their test change. The 14 screens that use `.readableListWidth()` do not change.
- **Depends on**: 159
- **Category**: bug, ux
- **Planned at**: commit `b198210`, 2026-11-26
- **Issue**: [SLN-340](https://linear.app/sebastianln/issue/SLN-340)

## Why this matters

Plan 159 added `.readableListWidth()`, which widens a `List`'s horizontal
content margins so its rows form a centered, readable column. The owner then
opened Settings on the iPad with the sidebar shown (iPad Pro 11", landscape,
dark mode). The rows started at the sidebar's edge with their left corners
hidden under it, and a wide gap was left on the right.

Cause: the iPadOS 26 sidebar floats over the detail. The detail's `List` spans
the whole window, and the sidebar is a leading safe-area inset. A `List`
normally keeps its rows clear of that inset through its default content margin.
`.readableListWidth()` replaces that margin with `(width - maxWidth) / 2`
measured over the whole width, so the column is centered on the window, not on
the visible area, and its leading part sits under the sidebar. Measured on the
screenshot, the rows end about 16% from the right edge while the sidebar covers
about 20% on the left. Symmetric margins over the full width give exactly that.

After this plan, the margins are computed inside the safe area. Each side's
margin is that side's safe-area inset plus the same extra space, so the column
is centered in the visible area next to the sidebar, and it is unchanged when
there is no sidebar.

## Current state

`Hugo/DesignSystem/Modifiers/ReadableWidthGeometry.swift`:

```swift
import CoreGraphics

/// The horizontal content margin that keeps a list's rows at a readable width.
nonisolated enum ReadableWidthGeometry {
    /// The margin for each side of a list `containerWidth` wide, so its rows are
    /// at most `maxWidth` wide. `nil` when the list's own margin is already
    /// enough, so the system default stays in place on narrow screens.
    static func listMargin(
        containerWidth: CGFloat, maxWidth: CGFloat, minimumMargin: CGFloat = 20
    ) -> CGFloat? {
        guard containerWidth.isFinite, maxWidth.isFinite else { return nil }
        let margin = (containerWidth - maxWidth) / 2
        return margin > minimumMargin ? margin : nil
    }
}
```

`Hugo/DesignSystem/Modifiers/ReadableContentWidth.swift` holds two modifiers.
`ReadableContentWidth` (a frame cap for content inside a `ScrollView`) is NOT
part of this bug: scroll-view content is already laid out inside the safe area.
Leave it unchanged. The list modifier is:

```swift
private struct ReadableListWidth: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var maxWidth = HugoLayout.Size.readableContentWidth
    @State private var containerWidth: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .contentMargins(
                .horizontal,
                ReadableWidthGeometry.listMargin(containerWidth: containerWidth, maxWidth: maxWidth),
                for: .scrollContent
            )
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                containerWidth = width
            }
    }
}
```

`HugoTests/DesignSystem/Modifiers/ReadableWidthGeometryTests.swift` has six
tests of `listMargin` with `maxWidth: 672`: phone 393 → `nil`; 834 → `81`;
1376 → `352`; 712 → `nil`; 714 → `21`; `.infinity` → `nil`.

`listMargin` is used only by `ReadableListWidth` (check with
`grep -rn "listMargin" Hugo HugoTests`).

Rules from `AGENTS.md` that apply: Swift Testing, tests mirror the source path,
`nonisolated` value logic, 4-space indentation, `Scripts/verify.sh` before each commit.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `xcrun swift-format lint --strict <files>` | exit 0 |

## Scope

**In scope**:

- `Hugo/DesignSystem/Modifiers/ReadableWidthGeometry.swift`
- `Hugo/DesignSystem/Modifiers/ReadableContentWidth.swift` (the `ReadableListWidth` struct only)
- `HugoTests/DesignSystem/Modifiers/ReadableWidthGeometryTests.swift`

**Out of scope**:

- The 14 screens that call `.readableListWidth()`, `ReadableContentWidth`, the sidebar's selection color (a separate, older problem), `AppRootView`.

## Git workflow

- Work on `main`. One commit: `fix(design): keep readable-width lists clear of the iPad sidebar`.
- Do not push.

## Steps

### Step 1: Margins per side, inside the safe area

Replace the contents of `ReadableWidthGeometry.swift` with:

```swift
import CoreGraphics

/// The horizontal content margins that keep a list's rows at a readable width.
nonisolated enum ReadableWidthGeometry {
    /// A list's leading and trailing content margins.
    struct ListMargins: Equatable, Sendable {
        let leading: CGFloat
        let trailing: CGFloat
    }

    /// Margins that center rows at most `maxWidth` wide in the part of a list
    /// `containerWidth` wide that its safe area leaves visible. The iPad's
    /// sidebar floats over the list as a leading safe-area inset, and a list's
    /// content margins replace its default margin, so each side gets its inset
    /// plus the same extra space. `nil` when the extra space would not exceed
    /// `minimumMargin`, so the system default stays in place on narrow screens.
    static func listMargins(
        containerWidth: CGFloat, leadingInset: CGFloat = 0, trailingInset: CGFloat = 0,
        maxWidth: CGFloat, minimumMargin: CGFloat = 20
    ) -> ListMargins? {
        guard containerWidth.isFinite, leadingInset.isFinite, trailingInset.isFinite, maxWidth.isFinite
        else { return nil }
        let visibleWidth = containerWidth - max(0, leadingInset) - max(0, trailingInset)
        let extra = (visibleWidth - maxWidth) / 2
        guard extra > minimumMargin else { return nil }
        return ListMargins(leading: max(0, leadingInset) + extra, trailing: max(0, trailingInset) + extra)
    }
}
```

### Step 2: Use it in the modifier

In `ReadableContentWidth.swift`, replace `ReadableListWidth` with:

```swift
private struct ReadableListWidth: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var maxWidth = HugoLayout.Size.readableContentWidth
    @State private var container = Container()

    /// The list's width and the safe-area insets beside it (the iPad sidebar is
    /// a leading inset).
    struct Container: Equatable {
        var width: CGFloat = 0
        var leadingInset: CGFloat = 0
        var trailingInset: CGFloat = 0
    }

    func body(content: Content) -> some View {
        let margins = ReadableWidthGeometry.listMargins(
            containerWidth: container.width, leadingInset: container.leadingInset,
            trailingInset: container.trailingInset, maxWidth: maxWidth)
        content
            .contentMargins(.leading, margins?.leading, for: .scrollContent)
            .contentMargins(.trailing, margins?.trailing, for: .scrollContent)
            .onGeometryChange(for: Container.self) { proxy in
                Container(
                    width: proxy.size.width, leadingInset: proxy.safeAreaInsets.leading,
                    trailingInset: proxy.safeAreaInsets.trailing)
            } action: { newValue in
                container = newValue
            }
    }
}
```

Leave the `readableListWidth()` doc comment as is.

### Step 3: Tests

Rewrite `ReadableWidthGeometryTests.swift` for `listMargins` (`maxWidth: 672`
throughout; compare with `ReadableWidthGeometry.ListMargins(leading:trailing:)`):

1. `phoneWidthKeepsSystemMargin`: width 393 → `nil`.
2. `iPadPortraitWidensMargin`: width 834 → `81 / 81`.
3. `largeIPadLandscapeWidensMargin`: width 1376 → `352 / 352`.
4. `marginAtMinimumKeepsSystemMargin`: width 712 → `nil`.
5. `marginJustAboveMinimumApplies`: width 714 → `21 / 21`.
6. `nonFiniteWidthKeepsSystemMargin`: width `.infinity` → `nil`.
7. `sidebarShiftsColumnRight`: width 1210, leading inset 240 → `389 / 149` (visible 970, extra 149).
8. `sidebarOnNarrowScreenKeepsSystemMargin`: width 834, leading inset 240 → `nil` (extra -39).
9. `trailingInsetIsKeptClear`: width 1210, trailing inset 100 → `219 / 319` (visible 1110, extra 219).
10. `negativeInsetCountsAsZero`: width 834, leading inset -10 → `81 / 81`.

**Verify**: `grep -rn "listMargin(" Hugo HugoTests` prints nothing (the old function is gone).
`Scripts/verify.sh` exits 0 with 4 more tests than before (649 → 653).
Commit `fix(design): keep readable-width lists clear of the iPad sidebar`.

## Test plan

- The ten geometry tests above. The modifier wiring is checked by the owner.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, 653 tests
- [ ] Only the three in-scope files changed; no screen file changed
- [ ] `Localizable.xcstrings` not staged or committed
- [ ] `plans/README.md` row updated

Owner check on the iPad, after the install:

1. Settings with the sidebar shown, landscape: the rows sit fully to the right of the sidebar with all four corners visible, centered in the space next to it.
2. The same with the sidebar hidden: the column is centered in the window, as plan 159 shipped it.
3. Portrait with the sidebar shown: the rows have normal margins next to the sidebar.
4. A pushed Settings page (General) and a month's details: same as 1 and 2.
5. The Overview and a Service Year page with the sidebar shown: the content is centered next to the sidebar (these use the other modifier; report if they look off).

## STOP conditions

Stop and report if:

- The drift check shows changes.
- `contentMargins(.leading, nil, for:)` does not compile.
- `listMargin` is used anywhere besides `ReadableListWidth` and its tests.

## Maintenance notes

- Observed on iPadOS 26 (2026-11-26): a `List`'s horizontal content margins replace its default margin, which is what keeps rows clear of the floating sidebar. Any modifier that sets them must add the safe-area insets itself.
- If the owner check shows the rows now start too far right (the sidebar width counted twice), SwiftUI adds content margins to the safe area in that context. Then `listMargins` should return `extra` alone for each side.
