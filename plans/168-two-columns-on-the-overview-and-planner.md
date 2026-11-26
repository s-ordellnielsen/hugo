# Plan 168: Two columns on the Overview and the Planner on wide iPad screens

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat <BASELINE>..HEAD -- Hugo/DesignSystem Hugo/Features/Overview/Screens/OverviewView.swift Hugo/Features/Planner/Views/PlannerMonthPage.swift`
> The reviewer sets <BASELINE> at dispatch to the commit after the previous plan in the batch (166–173). Expected: no output. STOP on any output.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). This plan adds no strings. Never stage that file.

## Status

- **Priority**: P2
- **Effort**: M + owner
- **Risk**: MEDIUM. Two whole-screen layouts change on wide iPads. Earlier iPad work (plans 152–154, reverted on 2026-11-23) failed on state that reset when the layout changed, so this plan keeps one view tree and switches only the layout (`AnyLayout`), and it stops for an owner check after each screen.
- **Depends on**: 159 (readable width), 162; runs after 166 and 167
- **Category**: ux
- **Planned at**: commit `16b697c`, 2026-11-26
- **Issue**: [SLN-344](https://linear.app/sebastianln/issue/SLN-344)

## Why this matters

On a wide iPad the Overview is one centered column of 672 points: the report
reminder, the big progress circle, then this month's entries far below. The
Planner page is one column too: the month's numbers, then the calendar. In
landscape most of the screen is empty, and the entries or the calendar start
below the fold.

After this plan, when the container is wide enough:

- **Overview:** the report reminder and progress card sit in a left column 400
  points wide. This month's entries sit in a right column, at most the
  readable width (672 points, scaled with Dynamic Type).
- **Planner:** the month's numbers (`PlannerStatusHeader`) sit in a left
  column 380 points wide. The calendar fills the rest, with the intro card
  under it in a month without plans, as today.

Narrow widths (iPhone, iPad portrait, split view, Slide Over) and every
accessibility text size keep today's single column exactly.

Decisions (owner to confirm on the device):

- **Breakpoint: 880 points of content width**, measured, never the size class. An 11" iPad in portrait (about 800 points of content) stays one column. Landscape, with or without the sidebar (about 940 or 1,180 points), gets two columns.
- **The narrow column is on the left in both screens**, because it comes first in today's single column. VoiceOver order and visual order are therefore the same in both layouts, and the view tree does not change when the layout switches.
- **The columns scroll together.** One scroll view, as today. A left column that stays put while the right one scrolls would need two scroll views and a different view tree on each side of the breakpoint. That resets state on rotation, which is how the earlier iPad work broke. The left columns are short, so they stay visible most of the time anyway.
- **The Planner legend stays under the calendar.** It is part of `PlannerCalendarGrid` and explains the calendar's bars.

## Current state

`Hugo/Features/Overview/Screens/OverviewView.swift`, `OverviewDayView.body`:

```swift
        ScrollView {
            VStack {
                if let reminderMonth {
                    ReportReminderCard(month: reminderMonth)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    Spacer(minLength: HugoLayout.Spacing.section)
                }
                MonthlyProgressCard(
                    value: metrics.progress, fill: fill,
                    planStatus: pace.map(MonthlyProgressStatus.make(pace:)),
                    isAddingEntry: $showingAddEntry,
                    onShowPlanPace: { showingPlanPace = true })
                Spacer(minLength: HugoLayout.Spacing.section)

                OverviewListView(entries: entries)
            }
            .motion(Motion.presence, value: reminderMonth)
            .padding()
            .readableContentWidth()
        }
        .frame(maxWidth: .infinity)
```

`MonthlyProgressCircle` caps itself at `HugoLayout.Size.monthlyProgressDiameter`
(360). `OverviewListView(entries:)` holds `@State` (`selectedEntry`, `shownStyle`,
`showAddEntrySheet`). Keeping one view tree keeps that state.

`Hugo/Features/Planner/Views/PlannerMonthPage.swift`, `body` (after plan 166,
which only changes the grid call; plan 167 does not touch this file):

```swift
        ScrollView {
            VStack(spacing: HugoLayout.Spacing.card) {
                PlannerStatusHeader(
                    status: PlannerMonthStatus.make(
                        month: plannerMonth, targetSeconds: targetSeconds, rule: rule))
                PlannerCalendarGrid(
                    month: plannerMonth, onSelect: select,
                    onAddPlan: { open($0, .addPlan) }, onLogTime: { open($0, .logTime) },
                    presentedDay: $presentedDay
                ) { day in
                    dayPopover(for: day)
                }
                if !plannerMonth.hasPlans {
                    PlannerIntroCard()
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .onScrollGeometryChange(for: Bool.self) { ... }
```

Each month page is `.containerRelativeFrame(.horizontal)` inside the horizontal
pager in `PlannerView`. The page's own width is the container width, so a
measurement inside the page is correct. The Planner has no readable-width cap
(plan 159 left it out on purpose). Each day cell anchors its own popover (plan 160).

`Hugo/DesignSystem/Modifiers/ReadableContentWidth.swift` (plans 159 and 162)
holds `readableContentWidth()` (a frame cap at
`@ScaledMetric(relativeTo: .body) HugoLayout.Size.readableContentWidth`, 672)
and `readableListWidth()`. Pure geometry sits in `nonisolated` types with tests
(`ReadableWidthGeometry.swift` and its tests in
`HugoTests/DesignSystem/Modifiers/ReadableWidthGeometryTests.swift`). The app is
main-actor by default, so a value type used across isolation (for example with
`onGeometryChange`) must be `nonisolated`.

`HugoLayout.Size` in `Hugo/DesignSystem/Theme/Theme.swift` already holds
feature sizes (`monthlyProgressDiameter`, `calendarDayMinHeight`,
`readableContentWidth`, `popoverWidth`, `popoverHeight`).

`AGENTS.md`: a `DesignSystem` component names no feature type and is used by two
or more features (here: Overview and Planner). Tests use Swift Testing and
mirror the source path.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `xcrun swift-format lint --strict <files>` | exit 0 |
| Format fix | `xcrun swift-format format -i <files>` | then re-run lint; use when `lint --strict` fails on formatting only |

## Scope

**In scope**:

- `Hugo/DesignSystem/Theme/Theme.swift` (three tokens)
- `Hugo/DesignSystem/Components/TwoColumnBreakpoint.swift` (create)
- `Hugo/DesignSystem/Components/AdaptiveTwoColumnStack.swift` (create)
- `HugoTests/DesignSystem/Components/TwoColumnBreakpointTests.swift` (create)
- `Hugo/Features/Overview/Screens/OverviewView.swift`
- `Hugo/Features/Planner/Views/PlannerMonthPage.swift`

**Out of scope**:

- `PlannerView` (the pager), `PlannerCalendarGrid`, `PlannerDayCell`, `PlannerStatusHeader`, `MonthlyProgressCard`, `OverviewListView`, `ReportReminderCard`: their contents do not change.
- Navigation, sheets, popovers, `AppRootView`.
- The Service Year page (plan 169).

## Git workflow

- Work on `main`. Commit per step, Conventional Commits. Do not push.

## Steps

### Step 1: Tokens, breakpoint and tests

In `Theme.swift`, inside `HugoLayout.Size`, after `popoverHeight`, add:

```swift
        /// Content width from which a screen shows two columns side by side.
        /// An 11" iPad in portrait stays below it; landscape is above it.
        static let twoColumnMinimumWidth: CGFloat = 880
        /// The Overview's left column on wide screens: the progress card.
        static let overviewProgressColumnWidth: CGFloat = 400
        /// The Planner's left column on wide screens: the month's numbers.
        static let plannerStatusColumnWidth: CGFloat = 380
```

Create `Hugo/DesignSystem/Components/TwoColumnBreakpoint.swift`:

```swift
import CoreGraphics

/// Whether a screen has room for two columns side by side.
nonisolated enum TwoColumnBreakpoint {
    /// Two columns when the available width reaches `minimumWidth`, never at
    /// accessibility text sizes (they need the whole width for one column).
    static func usesTwoColumns(
        availableWidth: CGFloat, minimumWidth: CGFloat, isAccessibilitySize: Bool
    ) -> Bool {
        guard availableWidth.isFinite, minimumWidth.isFinite, !isAccessibilitySize else { return false }
        return availableWidth >= minimumWidth
    }
}
```

Create `HugoTests/DesignSystem/Components/TwoColumnBreakpointTests.swift`
(`import Testing`, `@testable import Hugo`, a `struct`; add `@MainActor` only if
it does not compile without). With `minimumWidth: 880`:

1. `phoneIsOneColumn`: 361 → false.
2. `iPadPortraitIsOneColumn`: 802 → false.
3. `exactlyMinimumIsTwoColumns`: 880 → true.
4. `iPadLandscapeIsTwoColumns`: 1178 → true.
5. `accessibilitySizeIsAlwaysOneColumn`: 1178 with `isAccessibilitySize: true` → false.
6. `nonFiniteWidthIsOneColumn`: `.infinity` → false.

**Verify**: lint the three files; `Scripts/verify.sh` exits 0 with 6 more tests than before.
Commit `feat(design): add a two-column breakpoint`.

### Step 2: The adaptive stack

Create `Hugo/DesignSystem/Components/AdaptiveTwoColumnStack.swift`:

```swift
import SwiftUI

/// Two views side by side on wide screens and stacked otherwise. The leading
/// view comes first in both layouts, so reading order and VoiceOver order
/// match, and the view tree stays the same when the layout switches (state in
/// either view survives a rotation).
struct AdaptiveTwoColumnStack<Leading: View, Trailing: View>: View {
    /// The leading column's width when side by side.
    let leadingWidth: CGFloat
    /// Whether text columns are capped at the readable width, as
    /// `.padding()` followed by `.readableContentWidth()` did: the stacked
    /// layout as a whole (inset included), and the trailing column when side
    /// by side.
    var capsAtReadableWidth = false
    /// Padding around the stack, like `.padding()`. It is applied inside the
    /// cap, so a stacked screen caps at the same total width as before.
    var inset: CGFloat = 0
    var spacing: CGFloat = HugoLayout.Spacing.section
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var readableWidth = HugoLayout.Size.readableContentWidth
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        let isSideBySide = TwoColumnBreakpoint.usesTwoColumns(
            availableWidth: availableWidth - 2 * inset, minimumWidth: HugoLayout.Size.twoColumnMinimumWidth,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize)
        let layout =
            isSideBySide
            ? AnyLayout(HStackLayout(alignment: .top, spacing: spacing))
            : AnyLayout(VStackLayout(spacing: 0))
        layout {
            leading
                .frame(width: isSideBySide ? leadingWidth : nil)
            trailing
                .frame(maxWidth: isSideBySide && capsAtReadableWidth ? readableWidth : .infinity)
        }
        .padding(inset)
        .frame(maxWidth: maxWidth(isSideBySide: isSideBySide))
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            availableWidth = width
        }
    }

    private func maxWidth(isSideBySide: Bool) -> CGFloat {
        guard capsAtReadableWidth else { return .infinity }
        return isSideBySide ? leadingWidth + spacing + readableWidth + 2 * inset : readableWidth
    }
}
```

Notes:
- Stacked spacing is 0 on purpose. The Overview keeps its own `Spacer(minLength:)` between items, so the narrow layout looks exactly as today. Callers add their own vertical spacing inside `leading` when needed.
- The width is measured after `.frame(maxWidth: .infinity)`, so it is the full space the caller gives (the inset included, which the breakpoint subtracts), not the capped width.
- Stacked, the cap is `readableWidth` in total, inset included. That is exactly what `.padding()` followed by `.readableContentWidth()` gave (672 points, padding inside). Side by side, the stack is as wide as the leading column, the spacing, the trailing column (at most `readableWidth`) and the inset, and is centered.
- Do not add an animation. The switch happens on rotation, where the system animates the layout.

**Verify**: lint; `Scripts/verify.sh` exits 0, same test count as after Step 1.
Commit `feat(design): add an adaptive two-column stack`.

### Step 3: Overview

In `OverviewView.swift`, replace the `VStack { ... }` inside the `ScrollView`,
together with its `.padding()` and `.readableContentWidth()`, with the stack.
Keep `.motion`. The stack takes over both modifiers: `inset` is the same 16
points as `.padding()`, and `capsAtReadableWidth` caps the stacked layout at
672 points with the padding inside, as today. So the stacked (narrow) layout
stays exactly as it is now. Wide, the cap is the 400-point column, the spacing
and a trailing column of at most 672 points, centered.

```swift
        ScrollView {
            AdaptiveTwoColumnStack(
                leadingWidth: HugoLayout.Size.overviewProgressColumnWidth, capsAtReadableWidth: true,
                inset: HugoLayout.Spacing.spacious
            ) {
                VStack(spacing: 0) {
                    if let reminderMonth {
                        ReportReminderCard(month: reminderMonth)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        Spacer(minLength: HugoLayout.Spacing.section)
                    }
                    MonthlyProgressCard(
                        value: metrics.progress, fill: fill,
                        planStatus: pace.map(MonthlyProgressStatus.make(pace:)),
                        isAddingEntry: $showingAddEntry,
                        onShowPlanPace: { showingPlanPace = true })
                    Spacer(minLength: HugoLayout.Spacing.section)
                }
            } trailing: {
                OverviewListView(entries: entries)
            }
            .motion(Motion.presence, value: reminderMonth)
        }
        .frame(maxWidth: .infinity)
```

The trailing `Spacer(minLength:)` inside the leading `VStack` keeps today's gap
above the list when stacked. Side by side it adds empty space under the card,
which is harmless. The original `VStack` had default spacing, so check in the
build that the narrow layout keeps the same gaps. If the card and the list are
visibly closer or further apart than before, use `VStack` (default spacing) for
the leading column instead of `VStack(spacing: 0)` and note it.

**Verify**: lint; `Scripts/verify.sh` exits 0, same test count.
`grep -n "readableContentWidth\|\.padding()" Hugo/Features/Overview/Screens/OverviewView.swift` prints nothing.
Commit `feat(overview): show the progress card beside the entries on wide screens`.

**STOP here for the owner check of Step 3** (see "Done criteria"). Continue with
Step 4 only after the owner says the Overview works on both devices.

### Step 4: Planner month page

In `PlannerMonthPage.swift`, replace the `VStack(spacing: HugoLayout.Spacing.card) { ... }`
inside the `ScrollView`, together with the `.padding()` after it, with the stack
below. `inset: HugoLayout.Spacing.spacious` is the same 16 points as `.padding()`,
and the Planner has no readable-width cap, as today.

**Move the existing `PlannerCalendarGrid(...) { day in ... }` call, do not
retype it.** Cut the whole call with its trailing closure out of the old
`VStack`, including every argument earlier plans added (plan 166 added
`onAddPlan` and `onLogTime`; copy the call exactly as it is in the file), and
paste it unchanged where the placeholder comment is:

```swift
            AdaptiveTwoColumnStack(
                leadingWidth: HugoLayout.Size.plannerStatusColumnWidth,
                inset: HugoLayout.Spacing.spacious, spacing: HugoLayout.Spacing.card
            ) {
                PlannerStatusHeader(
                    status: PlannerMonthStatus.make(
                        month: plannerMonth, targetSeconds: targetSeconds, rule: rule))
                    .padding(.bottom, HugoLayout.Spacing.card)
            } trailing: {
                VStack(spacing: HugoLayout.Spacing.card) {
                    // <the existing PlannerCalendarGrid(...) { day in ... } call, moved unchanged>
                    if !plannerMonth.hasPlans {
                        PlannerIntroCard()
                    }
                }
            }
```

The narrow order stays numbers, calendar, intro card, exactly as today, so the
iPhone does not change. On wide screens the numbers sit on the left, and the
calendar with the intro card under it on the right.

`.padding(.bottom, HugoLayout.Spacing.card)` on the header restores the gap
between the numbers and the calendar when stacked (the stacked spacing is 0).
Side by side it adds empty space under the header, which is harmless.

**Verify**: lint; `Scripts/verify.sh` exits 0, same test count.
Commit `feat(planner): show the month's numbers beside the calendar on wide screens`.

## Test plan

- Six breakpoint tests (Step 1). The layouts are checked on the devices.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, 6 more tests than before this plan
- [ ] No `horizontalSizeClass` in the new files
- [ ] `Localizable.xcstrings` not staged
- [ ] `plans/README.md` row updated

Owner check after Step 3 (Overview), on the iPad (Sean):

1. Landscape, sidebar hidden and shown: the progress card on the left, this month's entries on the right, both starting at the top.
2. Portrait: one column, exactly as before.
3. Rotate with an entry's details open, and with the list style switched to "by entry": nothing closes or resets.
4. Landscape at the largest accessibility text size: one column.
5. VoiceOver in landscape: the reminder, then the card, then the list.
6. The + button's Add Entry popover still points at the button.
7. The page does not flash from one column to two: switch to the Overview tab and relaunch the app in landscape, and watch the first appearance. It must not show one column for a moment and then jump to two.

On the iPhone (Mona): the Overview looks exactly as before.

Owner check after Step 4 (Planner), on the iPad (Sean):

1. Landscape: the month's numbers on the left, the calendar on the right (with the intro card under it in a month without plans). Swiping between months still pages.
2. Tapping a day still opens its popover pointing at the day.
3. Portrait and iPhone (Mona): one column, exactly as before.
4. A page does not flash from one column to two on first appearance (open the Planner tab in landscape), and not while swiping between months: each month page must already be two columns as it slides in.

## STOP conditions

Stop and report if:

- The drift check shows changes to the code this plan quotes.
- `AnyLayout` switching resets `OverviewListView`'s state on rotation (owner check 3). Report it. Do not switch to two separate view trees.
- The Planner pager stops paging or a page shows the wrong width after Step 4.
- The narrow Overview shows different gaps that the Step 3 fallback does not fix.
- A page visibly flashes from one column to two on first appearance or while swiping Planner months (owner check 7 of Step 3, check 4 of Step 4). Report it. Do not add a timer, a delay or a fixed fallback width.

## Maintenance notes

- Plan 169 (Service Year grid) and plan 173 (width audit) reuse `TwoColumnBreakpoint` and `HugoLayout.Size.twoColumnMinimumWidth`.
- Plans 166 (context menus), 167 (hover effects), 170 (drag a plan) and 172 (Planner arrow keys) touch `PlannerCalendarGrid`, `PlannerDayCell` and entry rows. This plan only moves `PlannerCalendarGrid` inside the stack's trailing closure, so they do not conflict: later plans edit the grid call where it now sits, and the page's `ScrollView` and its modifiers stay where they are.
- A future pinned left column needs two scroll views and must keep the view tree stable across the breakpoint. Do not do it without a device check plan.
