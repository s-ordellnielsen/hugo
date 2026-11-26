# Plan 172: Arrow keys in the Planner

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat <BASELINE>..HEAD -- Hugo/Features/Planner HugoTests/Features/Planner Hugo/DesignSystem/Theme`
> The reviewer sets <BASELINE> at dispatch to the commit after the previous plan in the batch (166–173). Expected: no output. STOP on any output.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). This plan adds no strings. Never stage that file.

## Status

- **Priority**: P2
- **Effort**: M + owner
- **Risk**: MEDIUM. The iPadOS focus system decides which view gets key presses, and the Planner is a paging `ScrollView` of `ScrollView`s. Whether the focused page receives the arrow keys before a scroll view uses them can only be seen with a hardware keyboard on the iPad. The plan stops for that check.
- **Depends on**: 160 (day popovers), 161 (menu commands: ⌘T Go to Today, ⌘1–3). Runs after 167 (hover), which adds the shared corner radius token `HugoLayout.CornerRadius.calendarDay`, and after 170 (drag), which reuses it.
- **Category**: ux, accessibility
- **Planned at**: commit `16b697c`, 2026-11-26
- **Issue**: [SLN-343](https://linear.app/sebastianln/issue/SLN-343)

## Why this matters

Plan 161 gave Hugo menu bar commands and Return/Esc in forms. The Planner
calendar still needs a finger or the pointer. Apple's Calendar on iPad lets a
keyboard user move between days with the arrow keys and open a day with Return.
After this plan, with a hardware keyboard:

| Key | Does |
|---|---|
| ← → | Move the highlight one day |
| ↑ ↓ | Move the highlight one week |
| ⌘← ⌘→ | Show the previous or next month (the pager) |
| Return or Space | Open the highlighted day, exactly as a tap does (`PlannerDayDestination`, popover) |
| Esc | Remove the highlight |

Decisions:
- **The highlight stays in the month.** A move that would leave the month does nothing: ↑ from the 3rd stays on the 3rd. Months change only with ⌘← and ⌘→, which avoids an accidental page turn.
- **The first arrow press** shows the highlight without moving it, on today in the current month, otherwise on the 1st.
- **No menu items** for ⌘← and ⌘→. A menu item would take those keys from the page, and the Planner would need new `AppCommandActions`. ⌘T (Go to Today, plan 161) already exists and stays as it is.
- **The highlight only shows while the page has keyboard focus**, so touch users never see it.
- **VoiceOver is unaffected.** Day cells keep their labels, values and hints, and VoiceOver navigation doesn't use this focus.

## Current state

`Hugo/Features/Planner/Screens/PlannerView.swift` contains `PlannerView` and
`private struct PlannerPager`. The pager:

```swift
@State private var scrollPosition: YearMonth?
@State private var displayedMonth: YearMonth?
...
private var months: [YearMonth] { PlannerMonth.reachableMonths(from: today) }
private var currentMonth: YearMonth { today.yearMonth() }
private var activeMonth: YearMonth { displayedMonth ?? currentMonth }
...
ScrollView(.horizontal) {
    LazyHStack(spacing: 0) {
        ForEach(months, id: \.self) { month in
            PlannerMonthPage(
                month: month, today: today,
                targetSeconds: PlannerTarget.seconds(...),
                rule: status?.yearlyGoalRule,
                onScrolledFromTopChange: { scrolledPages[month] = $0 }
            )
            .containerRelativeFrame(.horizontal)
        }
    }
    .scrollTargetLayout()
}
.scrollTargetBehavior(.paging)
.scrollPosition(id: $scrollPosition)
...
.onChange(of: scrollPosition) { _, newValue in
    guard let newValue, months.contains(newValue) else { return }
    withAnimation(.snappy) { displayedMonth = newValue }
}
.onChange(of: resetToken) { withAnimation { scrollPosition = currentMonth; displayedMonth = currentMonth } }
```

`months` is the current month and the next 11 (`PlannerMonth.reachableMonths`).

`Hugo/Features/Planner/Views/PlannerMonthPage.swift` (after plans 166, 168 and
170) has an explicit `init(month:today:targetSeconds:rule:onScrolledFromTopChange:)`,
`@State presentedDay` and `popoverDestination`, `select(_:)` (sets the
destination, then `presentedDay`), `open(_:_:)` and `movePlans(_:to:)`. Its
`body` is one `ScrollView` that wraps plan 168's `AdaptiveTwoColumnStack`
(leading `PlannerStatusHeader`, trailing a `VStack` with the grid and the intro
card), followed by `.frame(maxWidth: .infinity)`, `.onScrollGeometryChange(...)`
and `.errorAlert(message: $moveError)`. The grid call, inside the trailing
`VStack`, is:

```swift
PlannerCalendarGrid(
    month: plannerMonth, onSelect: select,
    onAddPlan: { open($0, .addPlan) }, onLogTime: { open($0, .logTime) },
    presentedDay: $presentedDay, onDropPlans: movePlans
) { day in
    dayPopover(for: day)
}
```

`Hugo/Features/Planner/Views/PlannerCalendarGrid.swift` (after plans 166, 167
and 170): generic over `DayPopover`, with stored properties in this order:
`month`, `onSelect`, `onAddPlan`, `onLogTime`, `presentedDay`, `onDropPlans`,
and `@ViewBuilder dayPopover`. Each day is a `Button` whose label is the cell
(wrapped by `dragSource`), with this chain, in order: `.buttonStyle(.plain)`,
`.disabled(onSelect == nil)`, `.contentShape(.contextMenuPreview, ...)`,
`.contextMenu { ... }`, `.contentShape(.hoverEffect, ...)`,
`.hoverEffect(.highlight)`, `.background { drop target }`,
`.dropDestination(...)`, `.popover(...)`.

Domain types: `CalendarDay` (`year`, `month`, `day`, `yearMonth`, `Comparable`),
`YearMonth` (`year`, `month`, `lastDay(calendar:)`, `nextMonth(calendar:)`),
`CalendarDay(_ date:calendar:)`. All `nonisolated`.

The app uses no `@FocusState` outside `OverseerManualEntryView` and no
`.onKeyPress` or `.focusable` anywhere (checked with grep).

`PlannerDaySheet` and `PlanFormView` close with Esc since plan 161
(`.keyboardShortcut(.cancelAction)` on their close buttons).

Rules from `AGENTS.md`: pure logic in a `nonisolated` Domain type with Swift
Testing tests mirroring the source path; `Scripts/verify.sh` before each commit.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `xcrun swift-format lint --strict <files>` | exit 0 |
| Format fix | `xcrun swift-format format -i <files>` | then re-run lint; use when `lint --strict` fails on formatting only |

## Scope

**In scope**:

- `Hugo/Features/Planner/Domain/PlannerKeyboardNavigation.swift` (create)
- `HugoTests/Features/Planner/Domain/PlannerKeyboardNavigationTests.swift` (create)
- `Hugo/Features/Planner/Views/PlannerCalendarGrid.swift` (one parameter, one overlay)
- `Hugo/Features/Planner/Views/PlannerMonthPage.swift`
- `Hugo/Features/Planner/Screens/PlannerView.swift` (`PlannerPager` only)

**Out of scope**:

- `HugoCommands`, `AppRootView`, menu items, strings, `PlannerDayCell`, the day popover contents, scrolling the page to keep the highlight in view.

## Git workflow

- Work on `main`. Commit per step (Conventional Commits).
- Do not push.

## Steps

### Step 1: Navigation math, with tests

Create `Hugo/Features/Planner/Domain/PlannerKeyboardNavigation.swift`:

```swift
import Foundation

/// One arrow-key step in the Planner calendar.
nonisolated enum PlannerKeyboardMove: Sendable {
    case previousDay
    case nextDay
    case previousWeek
    case nextWeek

    var dayOffset: Int {
        switch self {
        case .previousDay: -1
        case .nextDay: 1
        case .previousWeek: -7
        case .nextWeek: 7
        }
    }
}

/// Where the keyboard highlight goes in a Planner month. The highlight never
/// leaves the month: months change only with ⌘← and ⌘→.
nonisolated enum PlannerKeyboardNavigation {
    /// The day the highlight starts on: today in the current month, otherwise the 1st.
    static func startDay(in month: YearMonth, today: CalendarDay) -> CalendarDay {
        today.yearMonth == month ? today : CalendarDay(year: month.year, month: month.month, day: 1)
    }

    /// The highlighted day after `move`. Without a highlighted day in `month`,
    /// the first press only shows the highlight on the start day. A move that
    /// would leave the month keeps the current day.
    static func day(
        after move: PlannerKeyboardMove, from day: CalendarDay?, in month: YearMonth, today: CalendarDay,
        calendar: Calendar = .current
    ) -> CalendarDay {
        guard let day, day.yearMonth == month else { return startDay(in: month, today: today) }
        let target = day.day + move.dayOffset
        guard (1...month.lastDay(calendar: calendar)).contains(target) else { return day }
        return CalendarDay(year: month.year, month: month.month, day: target)
    }
}
```

Create `HugoTests/Features/Planner/Domain/PlannerKeyboardNavigationTests.swift`
(`struct`, Swift Testing, `@testable import Hugo`, a fixed Gregorian UTC
`calendar`; add `@MainActor` to the struct only if isolation requires it).
`november = YearMonth(year: 2026, month: 11)`, `today = CalendarDay(year: 2026, month: 11, day: 26)`:

1. `startsOnTodayInTheCurrentMonth`: `startDay(in: november, today:)` → Nov 26.
2. `startsOnTheFirstInOtherMonths`: December 2026 → Dec 1.
3. `firstPressShowsTheStartDay`: `day(after: .nextDay, from: nil, ...)` → Nov 26 (not 27).
4. `dayFromAnotherMonthRestarts`: from Oct 31, in November → Nov 26.
5. `arrowsMoveOneDayOrOneWeek`: from Nov 10: `.nextDay` → 11, `.previousDay` → 9, `.nextWeek` → 17, `.previousWeek` → 3.
6. `staysAtTheStartOfTheMonth`: from Nov 1 `.previousDay` → Nov 1; from Nov 3 `.previousWeek` → Nov 3.
7. `staysAtTheEndOfTheMonth`: from Nov 30 `.nextDay` → Nov 30; from Nov 26 `.nextWeek` → Nov 26.
8. `leapFebruaryHas29Days`: in February 2028, from Feb 28 `.nextDay` → Feb 29.

**Verify**: lint both files; `Scripts/verify.sh` exits 0 with 8 more tests.
Commit `feat(planner): add keyboard navigation for the calendar`.

### Step 2: Highlight in the grid

`HugoLayout.CornerRadius.calendarDay` already exists (plan 167 adds it, plan 170
reuses it). Do not add it. If it does not exist, STOP.

In `PlannerCalendarGrid`, add a stored property after `onDropPlans` and before
`dayPopover`. The stored properties are then, in order: `month`, `onSelect`,
`onAddPlan`, `onLogTime`, `presentedDay`, `onDropPlans`, `keyboardDay`, and the
trailing `dayPopover` closure.

```swift
    /// The day the hardware keyboard has highlighted, or nil.
    var keyboardDay: CalendarDay? = nil
```

On each day's `Button`, after `.dropDestination(...)` (plan 170) and directly
before `.popover(...)`, add:

```swift
.overlay {
    if keyboardDay == day.id {
        RoundedRectangle(cornerRadius: HugoLayout.CornerRadius.calendarDay)
            .strokeBorder(.tint, lineWidth: 2)
            .accessibilityHidden(true)
    }
}
```

The `.tint` inside the tabs is `.primary` (plan 163 resets it), so the ring is
black in light mode and white in dark mode, like the system's keyboard focus
ring in a monochrome app.

After this step the day `Button`'s full chain is, in this order: `.buttonStyle(.plain)`,
`.disabled(onSelect == nil)`, `.contentShape(.contextMenuPreview, ...)`,
`.contextMenu { ... }`, `.contentShape(.hoverEffect, ...)`, `.hoverEffect(.highlight)`,
`.background { drop target }`, `.dropDestination(...)`, `.overlay { keyboard ring }`,
`.popover(...)`.

If the `EmptyView` convenience `init` stops compiling, pass `keyboardDay: nil` in it.

**Verify**: `Scripts/verify.sh` exits 0, same count. Commit `feat(planner): draw a keyboard highlight on a day`.

### Step 3: Keys on the month page, month change in the pager

**3a. Month page.** In `PlannerMonthPage`:

- Add stored properties `let isActive: Bool` and `var onChangeMonth: ((Int) -> Void)? = nil`. Add both to the explicit `init` as `isActive: Bool = false` and `onChangeMonth: ((Int) -> Void)? = nil` (after `onScrolledFromTopChange`), and assign them.
- Add state:
  ```swift
  /// The day the hardware keyboard highlights. Shown only while the page has keyboard focus.
  @State private var keyboardDay: CalendarDay?
  @FocusState private var isKeyboardFocused: Bool
  ```
- Pass `keyboardDay: isKeyboardFocused ? keyboardDay : nil` to `PlannerCalendarGrid`, after `onDropPlans:` and before the trailing closure. The complete call is:
  ```swift
  PlannerCalendarGrid(
      month: plannerMonth, onSelect: select,
      onAddPlan: { open($0, .addPlan) }, onLogTime: { open($0, .logTime) },
      presentedDay: $presentedDay, onDropPlans: movePlans,
      keyboardDay: isKeyboardFocused ? keyboardDay : nil
  ) { day in
      dayPopover(for: day)
  }
  ```
- The focus modifiers go on the page's outer `ScrollView` (the one that wraps plan 168's `AdaptiveTwoColumnStack`), at the end of its modifier chain: after `.onScrollGeometryChange(...)` and after `.errorAlert(message: $moveError)` (plan 170). Add:
  ```swift
  .focusable()
  .focusEffectDisabled()
  .focused($isKeyboardFocused)
  .onKeyPress(phases: .down) { press in
      handleKey(press, in: plannerMonth)
  }
  .onAppear {
      if isActive { isKeyboardFocused = true }
  }
  .onChange(of: isActive) { _, active in
      isKeyboardFocused = active
  }
  .onChange(of: presentedDay) { _, day in
      // Take the keys back when the day's popover closes.
      if day == nil, isActive { isKeyboardFocused = true }
  }
  ```
  `plannerMonth` here is the value built in `body`. If the closure can't see it, call `self.plannerMonth`.
- Add:
  ```swift
  /// Arrow keys move the highlight, ⌘← and ⌘→ change month, Return or Space
  /// opens the highlighted day, Esc removes the highlight.
  private func handleKey(_ press: KeyPress, in plannerMonth: PlannerMonth) -> KeyPress.Result {
      // Arrow keys report the function and numeric-pad flags; only ⌘ and the
      // other modifiers count.
      let modifiers = press.modifiers.subtracting([.numericPad, .function])
      if modifiers == .command {
          switch press.key {
          case .leftArrow: onChangeMonth?(-1); return .handled
          case .rightArrow: onChangeMonth?(1); return .handled
          default: return .ignored
          }
      }
      guard modifiers.isEmpty else { return .ignored }
      let move: PlannerKeyboardMove
      switch press.key {
      case .leftArrow: move = .previousDay
      case .rightArrow: move = .nextDay
      case .upArrow: move = .previousWeek
      case .downArrow: move = .nextWeek
      case .return, .space:
          guard let keyboardDay else { return .ignored }
          select(keyboardDay)
          return .handled
      case .escape:
          guard keyboardDay != nil else { return .ignored }
          keyboardDay = nil
          return .handled
      default:
          return .ignored
      }
      keyboardDay = PlannerKeyboardNavigation.day(
          after: move, from: keyboardDay, in: month, today: plannerMonth.today)
      return .handled
  }
  ```
  If `switch` on `KeyEquivalent` does not compile, use `if press.key == .leftArrow { ... } else if ...`.

**3b. Pager.** In `PlannerPager` (`PlannerView.swift`):

- Add `@Environment(\.accessibilityReduceMotion) private var reduceMotion`.
- Pass `isActive: month == activeMonth, onChangeMonth: showMonth(offsetBy:)` to `PlannerMonthPage` (after `onScrolledFromTopChange:`).
- Add:
  ```swift
  /// Pages to the month `offset` away from the shown one, within the reachable months.
  private func showMonth(offsetBy offset: Int) {
      guard let index = months.firstIndex(of: activeMonth) else { return }
      let target = index + offset
      guard months.indices.contains(target) else { return }
      withAnimation(reduceMotion ? nil : .snappy) {
          scrollPosition = months[target]
      }
  }
  ```
  The existing `.onChange(of: scrollPosition)` then updates `displayedMonth` and the title.

**Verify**: lint the changed files; `Scripts/verify.sh` exits 0, same count.
Commit `feat(planner): move between days with the arrow keys`.

**STOP here for the owner check** (see "Done criteria"). Report, and wait.

## Test plan

- Eight navigation tests. Focus and key handling are checked by the owner on the iPad.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0 with 8 more tests than before
- [ ] No strings, no menu items, no changes outside the scope list
- [ ] `Localizable.xcstrings` not staged or committed
- [ ] `plans/README.md` row updated (unless a reviewer maintains it)

Owner check on the iPad (Sean) with a hardware keyboard:

1. Open the Planner and press →: a ring appears on today. Press → ↓ ← ↑: it moves one day or one week and never leaves the month.
2. Press Return on a day with plans: its popover opens. Press Esc: it closes, and the arrows still move the ring.
3. Press Space on an empty future day: Add Plan opens. Esc closes it.
4. Press ⌘→ twice and ⌘← once: the month pages, and the arrows work on the new month (the ring starts on the 1st).
5. ⌘T (Go to Today) and ⌘1–3 still work. On the Overview tab the arrow keys do nothing new.
6. Tap a day with a finger: no ring appears, and the popover opens as before.
7. VoiceOver on (without the keyboard): the calendar reads day by day as before.

Owner check on the iPhone (Mona): nothing changes.

## STOP conditions

Stop and report if:

- The drift check shows any output.
- `HugoLayout.CornerRadius.calendarDay` does not exist (plan 167 adds it). Do not add it here.
- On the iPad, the arrow keys scroll the page or the pager instead of moving the ring. Try `.focusable(interactions: .edit)` instead of `.focusable()` once, and report what each did. Do not add UIKit key commands.
- The ring never appears because the page never gets focus. Report it; do not force focus with a timer.
- With VoiceOver on, the page becomes one element or the days stop being read.

## Maintenance notes

- Plan 170 draws a drop highlight with the same `calendarDay` radius. Keep both highlights in the grid, the drop one as a `.background` and the keyboard one as an `.overlay`.
- Plan 168 put the grid in a two-column layout's trailing column but kept the page's `ScrollView` as the outer view, so the focus modifiers sit on that `ScrollView`. If a later change moves the grid out of it, keep the focus modifiers on the view that contains the grid.
- If menu items are wanted later ("Previous Month ⌘←" / "Next Month ⌘→"), add them to `HugoCommands` through `AppCommandActions`, and remove the ⌘ handling from `handleKey`, so the keys are not handled twice.
- On a small iPad window the ring could move below the visible part of the page. Scrolling it into view (`ScrollViewReader`) is a follow-up.
