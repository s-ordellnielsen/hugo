# Plan 159: Keep content at a readable width on iPad

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 9a7dc2e..HEAD -- Hugo/DesignSystem Hugo/Features/Overview/Screens Hugo/Features/ServiceYear Hugo/Features/Settings/Screens Hugo/Features/Categories Hugo/Features/Planner/Screens`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). This plan adds no strings. Never stage that file.

## Status

- **Priority**: P2
- **Effort**: M + owner
- **Risk**: LOW. Each change is a width cap that does nothing when the window is narrower than the cap, so the iPhone and iPad sheets are unaffected. The one real risk is `contentMargins` reaching a nested horizontal scroll view (Step 4 handles the one known case).
- **Depends on**: none
- **Category**: ux, accessibility
- **Planned at**: commit `9a7dc2e`, 2026-11-26
- **Issue**: [SLN-337](https://linear.app/sebastianln/issue/SLN-337)

## Why this matters

On a 13" iPad in landscape the Overview's entry rows, the Service Year cards and
the Settings lists are about 1,000 points wide. A category name sits at the left
edge and its duration at the right, and older readers lose the line. UIKit has
had a "readable content guide" for this since iOS 9, and Apple's own apps keep
text near 672 points wide at the default text size. Hugo has no equivalent.

After this plan, full-width screens keep their content in a centered column of
`HugoLayout.Size.readableContentWidth` (672 points), scaled with Dynamic Type so
that people with large text still get the full width. The scroll view itself
stays full width, so the user can scroll from anywhere and the scroll indicator
stays at the screen edge.

This plan does not move, add or remove any content. It is the first of three
small iPad plans (159, 160, 161). They share no code and can run in any order.

## Current state

- `Hugo/DesignSystem/Theme/Theme.swift` holds `HugoLayout` with `Spacing`, `CornerRadius`, `Size` (for example `monthlyProgressDiameter = 360`, `minimumHitTarget = 44`), `Typography` and `Opacity`. No width cap exists.
- `Hugo/DesignSystem/Modifiers/` holds `ContentHeightSheetDetents.swift`, `EditorialNavigationTitle.swift`, `ErrorAlert.swift`.
- Pure geometry in the design system is a `nonisolated struct` or `enum` with tests, for example `Hugo/DesignSystem/Components/MarkedProgressBarGeometry.swift` and `HugoTests/DesignSystem/Components/MarkedProgressBarGeometryTests.swift`.
- `contentMargins` is used twice today: `EntryDetailView.swift:52` (`.contentMargins(.top, 0, for: .scrollContent)`) and `OnboardingWelcomePage.swift:55`.
- Scroll-view screens that fill the iPad's width:
  - `Hugo/Features/Overview/Screens/OverviewView.swift`: `ScrollView { VStack { ... } .motion(Motion.presence, value: reminderMonth) .padding() } .frame(maxWidth: .infinity)`.
  - `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift`: `return ScrollView {` at line 54, the content ends with `.padding()` at line 75, and the scroll view has `.frame(maxWidth: .infinity)` at line 77. Each page is `.containerRelativeFrame(.horizontal)` inside the horizontal pager in `ServiceYearView`.
- `List`/`Form` screens that are tab roots or pushed (full width on iPad):
  - Settings: `SettingsView`, `GeneralSettingsView`, `ReportSettingsView`, `OverseerSettingsView`, `PublisherStatusSelectionView`, `GreetingTemplateView`, `CloudSyncStatusView`, `DebugSettingsView` (all in `Hugo/Features/Settings/Screens/`).
  - Categories: `CategoryListView`, `CategoryDetailView` (`Hugo/Features/Categories/Screens/`).
  - Planner settings: `PlannerTargetSettingsView`, `BufferScopeSettingsView` (`Hugo/Features/Planner/Screens/`).
  - Service Year: `ServiceYearDetailView`, `MonthDetailView` (`Hugo/Features/ServiceYear/Screens/`).
- `Hugo/Features/Categories/Views/CategoryColorPicker.swift:32` has a `ScrollView(.horizontal)` of color swatches inside `CategoryDetailView`'s `Form` and `AddCategoryView`'s `Form`.

Decisions (owner-facing, made while planning):

- **672 points**, UIKit's readable width at the default text size, scaled with `@ScaledMetric(relativeTo: .body)`. At accessibility sizes the cap passes the screen width, so large-text users keep the full width.
- **Planner month page is out of scope.** The calendar grid keeps the full width like Apple's Calendar. A later plan may put words into day cells, which uses that width.
- **Sheets are out of scope.** iPad sheets are already narrower than 672 points. The modifier is a no-op there, so it is not added to them.
- **Two techniques.** Content inside a `ScrollView` gets a frame cap (no environment side effects). `List` and `Form` get wider `contentMargins`, because a frame on a list would shrink its scroll area and move the scroll indicator.

Rules from `AGENTS.md` that apply: generic UI goes in `Hugo/DesignSystem` under a role folder (`Modifiers`), tokens in `Theme`, pure logic gets tests that mirror the source path, Swift Testing, 4-space indentation, `Scripts/verify.sh` before each commit.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |

## Scope

**In scope**:

- `Hugo/DesignSystem/Theme/Theme.swift` (one token)
- `Hugo/DesignSystem/Modifiers/ReadableContentWidth.swift` (create)
- `Hugo/DesignSystem/Modifiers/ReadableWidthGeometry.swift` (create)
- `HugoTests/DesignSystem/Modifiers/ReadableWidthGeometryTests.swift` (create)
- `OverviewView.swift`, `ServiceYearPageView.swift`
- The 14 `List`/`Form` screens listed under "Current state"
- `CategoryColorPicker.swift` (one modifier on the horizontal scroll view)

**Out of scope**:

- `PlannerMonthPage`, `PlannerView`, every sheet (`AddEntryView`, `PlanFormView`, `PlannerDaySheet`, `EntryDetailView`, `SubmitReportView`, `HelpView`, onboarding, `AddCategoryView`, `SchoolCreditFormView`, `OverseerManualEntryView`, `CategoryPicker`, `CarriedInBreakdownSheet`).
- Any change to card sizes, the progress circle or what the screens contain.
- Any check on `horizontalSizeClass` or the device idiom. The cap depends on width only.

## Git workflow

- Work on `main`. Commit per step. Conventional Commits, for example `feat(design): add a readable width modifier`.
- Do not push.

## Steps

### Step 1: Add the token and the geometry

In `Theme.swift`, inside `HugoLayout.Size`, after `yearPickerMaximumStripWidth`:

```swift
        /// Widest a column of text should be at the default text size, as
        /// UIKit's readable content guide. Scaled with Dynamic Type where used.
        static let readableContentWidth: CGFloat = 672
```

Create `Hugo/DesignSystem/Modifiers/ReadableWidthGeometry.swift`:

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

`minimumMargin` is a literal default, not `HugoLayout.Spacing.roomy`, because
`HugoLayout` is main-actor isolated under the project's default isolation and
this type is `nonisolated`.

**Verify**: `swift-format lint --strict Hugo/DesignSystem/Modifiers/ReadableWidthGeometry.swift Hugo/DesignSystem/Theme/Theme.swift` exits 0.

### Step 2: Test the geometry

Create `HugoTests/DesignSystem/Modifiers/ReadableWidthGeometryTests.swift` (a
`struct`, `import Testing`, `@testable import Hugo`), with `maxWidth: 672`:

1. `phoneWidthKeepsSystemMargin`: container 393, expect `nil`.
2. `iPadPortraitWidensMargin`: container 834, expect `81`.
3. `largeIPadLandscapeWidensMargin`: container 1376, expect `352`.
4. `marginAtMinimumKeepsSystemMargin`: container 712 (margin exactly 20), expect `nil`.
5. `marginJustAboveMinimumApplies`: container 714, expect `21`.
6. `nonFiniteWidthKeepsSystemMargin`: container `.infinity`, expect `nil`.

**Verify**: `Scripts/verify.sh` exits 0, with 6 more tests than before. Commit `feat(design): add a readable width token and list margin geometry`.

### Step 3: Add the two modifiers

Create `Hugo/DesignSystem/Modifiers/ReadableContentWidth.swift`:

```swift
import SwiftUI

extension View {
    /// Caps content inside a `ScrollView` at a readable width and centers it.
    /// Put it on the scroll view's content, not on the scroll view, so the
    /// whole screen still scrolls and the indicator stays at the edge.
    func readableContentWidth() -> some View {
        modifier(ReadableContentWidth())
    }

    /// Caps the rows of a `List` or `Form` at a readable width by widening its
    /// horizontal content margins. Put it on the `List` or `Form`.
    func readableListWidth() -> some View {
        modifier(ReadableListWidth())
    }
}

private struct ReadableContentWidth: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var maxWidth = HugoLayout.Size.readableContentWidth

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

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

`contentMargins(_:_:for:)` takes an optional length; `nil` keeps the system
default. If it does not compile with an optional, STOP (see STOP conditions).

**Verify**: `Scripts/verify.sh` exits 0. Commit `feat(design): add readable width modifiers`.

### Step 4: Apply them

Scroll-view screens, on the content inside the `ScrollView`, directly after the
content's existing `.padding()`:

- `OverviewView.swift`: after `.padding()` on the `VStack` (keep `.motion(...)` before it as is), add `.readableContentWidth()`. Keep the scroll view's `.frame(maxWidth: .infinity)`.
- `ServiceYearPageView.swift`: after the `.padding()` at line 75, add `.readableContentWidth()`. Do not put anything on the horizontal pager in `ServiceYearView`.

`List`/`Form` screens: add `.readableListWidth()` directly on the `List` or
`Form` (after its closing brace, before `.navigationTitle`, `.toolbar` and other
modifiers) in each of the 14 files listed under "Current state". If a file
already sets a horizontal `contentMargins` on that list, STOP.

Nested scroll view: in `CategoryColorPicker.swift`, on the
`ScrollView(.horizontal)` at line 32, add
`.contentMargins(.horizontal, 0, for: .scrollContent)`, with a one-line comment:
`// Keeps a parent list's readable-width margins out of the swatch row.`
A horizontal scroll view's default margin is already 0, so this changes nothing
on iPhone.

Then search for any other nested `ScrollView` inside the 14 screens or their
views (`grep -n "ScrollView" ` on each file and on the views it embeds). If you
find one, give it the same line and list it in your report.

**Verify**: `Scripts/verify.sh` exits 0. Commit `feat: keep full-width screens at a readable width on iPad`.

## Test plan

- The six geometry tests. The modifiers are view wiring, checked by the build and the owner check below.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, with 6 more tests than before
- [ ] `HugoLayout.Size.readableContentWidth` exists and is used only through the two modifiers
- [ ] The two scroll-view screens and the 14 list screens use the modifiers
- [ ] No file checks `horizontalSizeClass` or the idiom for this
- [ ] `Localizable.xcstrings` is not staged or committed
- [ ] `plans/README.md` row updated

Owner check on the iPad (Sean), after Step 4:

1. Overview, a Service Year page, the Service Year detail, a month's detail, Settings and two Settings pages: in portrait and landscape the content is a centered column, and scrolling with a finger in the empty side area still scrolls.
2. The same screens at the largest accessibility text size: the content uses the whole width again.
3. Hugo in a half-width window next to another app: the content fills the window with normal margins.
4. A category's page: the color swatches scroll all the way to both edges, and the first swatch is not pushed inward.
5. The Planner is unchanged.

Owner check on the iPhone (Mona): the same screens look exactly as before.

## STOP conditions

Stop and report if:

- `contentMargins(_:_:for:)` does not accept `nil` as the length. Report the compiler error. Do not replace it with `0`: that would remove the list's system margin on iPhone.
- A screen in the list is no longer a `List` or `Form`, or already sets horizontal content margins.
- `OverviewView` or `ServiceYearPageView` no longer has a `ScrollView` whose content ends in `.padding()`.
- The geometry tests pass but the build shows a concurrency error about `HugoLayout` in a `nonisolated` context.

## Maintenance notes

- New full-width screens should use `.readableContentWidth()` (scroll content) or `.readableListWidth()` (lists and forms). Sheets do not need it.
- `contentMargins` reaches scroll views nested inside the list. A new horizontal scroll view inside one of these lists needs `.contentMargins(.horizontal, 0, for: .scrollContent)`, as `CategoryColorPicker` has.
- If the Planner later gets text in day cells, decide then whether its page should also get a cap, probably a wider one.
