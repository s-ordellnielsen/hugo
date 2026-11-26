# Plan 160: Open Planner days and Add Entry in popovers on iPad

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 8020494..HEAD -- Hugo/Features/Planner Hugo/Features/Overview Hugo/DesignSystem`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> (Plan 159 already landed before `8020494`: `Theme.swift` has `readableContentWidth`
> in `HugoLayout.Size`, `OverviewView` has `.readableContentWidth()` after its
> `.padding()`, and `Hugo/DesignSystem/Modifiers/` has `ReadableContentWidth.swift`
> and `ReadableWidthGeometry.swift`. Leave all of that as is.)
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). This plan adds no strings. Never stage that file.

## Status

- **Priority**: P2
- **Effort**: M + owner
- **Risk**: MEDIUM. Popovers can't be checked from this Mac (no `Simulator.app`, nothing can be tapped), and earlier iPad work failed on exactly that kind of untested interaction. The plan therefore stops after each screen for an owner check on the real iPad.
- **Depends on**: none
- **Category**: ux
- **Planned at**: commit `9a7dc2e`, 2026-11-26; drift baseline refreshed to `8020494` after plan 159
- **Issue**: [SLN-338](https://linear.app/sebastianln/issue/SLN-338)

## Why this matters

Apple's Calendar on iPad opens a tapped event, and the form for a new event, in a
popover that points at what was tapped. The rest of the screen stays visible and
undimmed. Hugo opens every Planner day and Add Entry as a sheet that covers the
middle of the iPad and dims the calendar, so the user loses sight of which day
they tapped.

After this plan, on a regular-width iPad:

- tapping a Planner day opens the day sheet's content in a popover anchored to that day cell;
- tapping an empty future day opens Add Plan in a popover anchored to that day cell (the destination logic of plan 147 is unchanged);
- the Overview's + button opens Add Entry in a popover anchored to the button.

On iPhone and in compact-width iPad windows, SwiftUI shows the same popovers as
sheets (a popover's default compact adaptation). There is one code path and no
size-class check.

This replaces nothing else. Entry detail, Submit Report and the other Add Entry
entry points stay as sheets.

## Current state

`Hugo/Features/Planner/Views/PlannerMonthPage.swift`:

```swift
@State private var selectedDay: CalendarDay?
@State private var addingPlanDay: CalendarDay?
...
PlannerCalendarGrid(month: plannerMonth, onSelect: select)
...
.sheet(item: $selectedDay) { day in
    PlannerDaySheet(day: day, today: today)
        .presentationDetents([.medium, .large])
}
.sheet(item: $addingPlanDay) { day in
    PlanFormView(day: day)
}

/// An empty day opens Add Plan directly; every other day opens the day sheet.
private func select(_ day: CalendarDay) {
    guard let plannerDay = plannerMonth.days.first(where: { $0.id == day }),
        PlannerDayDestination(day: plannerDay) == .addPlan
    else {
        selectedDay = day
        return
    }
    addingPlanDay = day
}
```

`Hugo/Features/Planner/Views/PlannerCalendarGrid.swift` is a non-generic view
with `let month: PlannerMonth` and `var onSelect: ((CalendarDay) -> Void)? = nil`.
Each day is:

```swift
ForEach(month.days) { day in
    Button {
        onSelect?(day.id)
    } label: {
        PlannerDayCell(day: day)
    }
    .buttonStyle(.plain)
    .disabled(onSelect == nil)
}
```

Check the grid's call sites with `grep -rn "PlannerCalendarGrid(" Hugo` (at
planning time: only `PlannerMonthPage`, plus any `#Preview`).

`PlannerDayDestination` (`Hugo/Features/Planner/Domain/PlannerDayDestination.swift`)
is `nonisolated enum PlannerDayDestination: Equatable, Sendable { case daySheet, addPlan }`.

`PlannerDaySheet` and `PlanFormView` each wrap their content in their own
`NavigationStack`, with a close button (`role: .cancel`, calls `dismiss()`).
`PlannerDaySheet` presents further sheets from inside: Add Plan (`+`), edit plan,
log time (`AddEntryView`), and `EntryDetailView`. `PlanFormView` and
`AddEntryView` present `CategoryPicker` (`.presentationDetents([.medium])`) and
`EntryTimePickerView` as sheets.

`Hugo/Features/Overview/Screens/OverviewView.swift` owns
`@State private var showingAddEntry = false`, passes
`onAddEntry: { showingAddEntry = true }` to `MonthlyProgressCard`, and has
`.sheet(isPresented: $showingAddEntry) { AddEntryView() }`.

`Hugo/Features/Overview/Views/MonthlyProgressCard.swift` has `let onAddEntry: () -> Void`
and draws the button:

```swift
Button(action: onAddEntry) {
    Label("entry.add.label", systemImage: "plus")
        .padding(HugoLayout.Spacing.regular)
}
.buttonBorderShape(.circle)
.font(.largeTitle)
.labelStyle(.iconOnly)
.buttonStyle(.glass)
.hoverEffect(.lift)
.padding(.trailing, HugoLayout.Spacing.compact)
.padding(.bottom, HugoLayout.Spacing.compact)
```

The app already uses one popover: the year picker in `ServiceYearView.swift:124`
(`.popover(isPresented:)` with `.presentationCompactAdaptation(.popover)`).

Facts about SwiftUI popovers that this plan relies on:

- A popover sizes itself to its content's ideal size. A `NavigationStack` with a `ScrollView` or `Form` has no ideal size, so the content needs `.frame(idealWidth:idealHeight:)`. In a sheet, the sheet proposes a size and the ideal values are ignored.
- Without `.presentationCompactAdaptation`, a popover shows as a sheet in compact width. Presentation modifiers on the content (`.presentationDetents`) then apply to that sheet.

Rules from `AGENTS.md` that apply: generic UI in `Hugo/DesignSystem/Modifiers`,
tokens in `HugoLayout`, no UIKit, no `horizontalSizeClass` checks outside one
adaptive modifier (this plan needs none), `Scripts/verify.sh` before each commit.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |

## Scope

**In scope**:

- `Hugo/DesignSystem/Theme/Theme.swift` (two tokens)
- `Hugo/DesignSystem/Modifiers/PopoverContentSize.swift` (create)
- `Hugo/Features/Planner/Views/PlannerCalendarGrid.swift`
- `Hugo/Features/Planner/Views/PlannerMonthPage.swift`
- `Hugo/Features/Overview/Views/MonthlyProgressCard.swift`
- `Hugo/Features/Overview/Screens/OverviewView.swift`

**Out of scope**:

- `PlannerDaySheet`, `PlanFormView`, `AddEntryView` and their inner sheets. They are presented differently, but their code does not change.
- Add Entry from `OverviewListView`'s empty state, `ServiceYearMonthRow`, `MonthDetailView` and the day sheet's log button.
- `EntryDetailView`, `SubmitReportView`, `PlanPaceSheet`.
- Renaming `PlannerDaySheet`. It is a popover on iPad now, but a rename is churn for no user gain.

## Git workflow

- Work on `main`. Commit per step. Conventional Commits, for example `feat(planner): open a day in a popover on iPad`.
- Do not push.

## Steps

### Step 1: Popover size tokens and modifier

In `Theme.swift`, inside `HugoLayout.Size`, add:

```swift
        /// Ideal size of a form or detail shown in a popover on iPad. A sheet
        /// ignores it.
        static let popoverWidth: CGFloat = 400
        static let popoverHeight: CGFloat = 600
```

Create `Hugo/DesignSystem/Modifiers/PopoverContentSize.swift`:

```swift
import SwiftUI

extension View {
    /// Gives popover content a size. A popover sizes itself to its content's
    /// ideal size, and a navigation stack with a form or scroll view has none.
    /// When the popover shows as a sheet (iPhone, narrow iPad windows), the
    /// sheet proposes its own size and these values do nothing.
    func popoverContentSize() -> some View {
        frame(idealWidth: HugoLayout.Size.popoverWidth, idealHeight: HugoLayout.Size.popoverHeight)
    }
}
```

**Verify**: `Scripts/verify.sh` exits 0. Commit `feat(design): add a popover content size`.

### Step 2: Planner days in popovers

**2a. The grid presents a popover per day.** Make `PlannerCalendarGrid`
generic over its popover content:

```swift
struct PlannerCalendarGrid<DayPopover: View>: View {
    let month: PlannerMonth
    var onSelect: ((CalendarDay) -> Void)? = nil
    /// The day whose popover is open. Each cell anchors its own popover, so the
    /// arrow points at the tapped day.
    var presentedDay: Binding<CalendarDay?> = .constant(nil)
    @ViewBuilder var dayPopover: (CalendarDay) -> DayPopover
```

On each day's `Button`, after `.disabled(onSelect == nil)`, add:

```swift
.popover(isPresented: isPresented(day.id)) {
    dayPopover(day.id)
}
```

with a private helper:

```swift
private func isPresented(_ day: CalendarDay) -> Binding<Bool> {
    Binding(
        get: { presentedDay.wrappedValue == day },
        set: { isPresented in
            if !isPresented, presentedDay.wrappedValue == day {
                presentedDay.wrappedValue = nil
            }
        }
    )
}
```

Add an extension so call sites without a popover (previews) still compile:

```swift
extension PlannerCalendarGrid where DayPopover == EmptyView {
    init(month: PlannerMonth, onSelect: ((CalendarDay) -> Void)? = nil) {
        self.init(month: month, onSelect: onSelect, presentedDay: .constant(nil)) { _ in EmptyView() }
    }
}
```

If the memberwise initializer with a trailing closure does not compile as written,
write an explicit `init(month:onSelect:presentedDay:dayPopover:)` and keep the
extension.

**2b. The month page drives it.** In `PlannerMonthPage.swift`, replace the two
state properties with:

```swift
/// The day whose popover is open.
@State private var presentedDay: CalendarDay?
/// What the open (or closing) popover shows. Never reset on dismissal: the
/// content stays on screen during the dismiss animation, and saving a plan
/// makes an empty day non-empty, so recomputing it would flip Add Plan to the
/// day view while it closes.
@State private var popoverDestination: PlannerDayDestination = .daySheet
```

Change `select(_:)` to set both (keep its doc comment):

```swift
private func select(_ day: CalendarDay) {
    let plannerDay = plannerMonth.days.first { $0.id == day }
    popoverDestination = plannerDay.map(PlannerDayDestination.init(day:)) ?? .daySheet
    presentedDay = day
}
```

Pass the binding and the popover content to the grid, and delete both `.sheet` modifiers:

```swift
PlannerCalendarGrid(month: plannerMonth, onSelect: select, presentedDay: $presentedDay) { day in
    dayPopover(for: day)
}
```

```swift
@ViewBuilder
private func dayPopover(for day: CalendarDay) -> some View {
    if popoverDestination == .addPlan {
        PlanFormView(day: day)
            .popoverContentSize()
    } else {
        PlannerDaySheet(day: day, today: today)
            .presentationDetents([.medium, .large])
            .popoverContentSize()
    }
}
```

`PlanFormView` had no detents as a sheet; keep it that way.

**Verify**: `Scripts/verify.sh` exits 0. Commit `feat(planner): open a day in a popover on iPad`.

**STOP here for the owner check of Step 2** (see "Done criteria"). Report, and
continue with Step 3 only when the owner says the Planner part works on both devices.

### Step 3: Overview Add Entry in a popover

In `MonthlyProgressCard.swift`, replace `let onAddEntry: () -> Void` with
`@Binding var isAddingEntry: Bool`, change the button's action to
`isAddingEntry = true`, and after `.hoverEffect(.lift)` (before the two
`.padding` lines, so the arrow points at the button and not at its padding) add:

```swift
.popover(isPresented: $isAddingEntry) {
    AddEntryView()
        .popoverContentSize()
}
```

Update the card's `#Preview`s, if any, to pass `isAddingEntry: .constant(false)`.

In `OverviewView.swift`, pass `isAddingEntry: $showingAddEntry` instead of
`onAddEntry:`, and delete `.sheet(isPresented: $showingAddEntry) { AddEntryView() }`.
Keep `showingAddEntry` in `OverviewView`, so plan 161 or a later change can open
Add Entry from elsewhere on the screen.

**Verify**: `Scripts/verify.sh` exits 0. Commit `feat(overview): open Add Entry in a popover on iPad`.

## Test plan

- No new unit tests: this is presentation wiring with no new logic. `PlannerDayDestination` keeps its tests from plan 147.
- The owner checks below are the real test. Screenshots from `simctl` can't show a popover, because nothing can be tapped from this Mac.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, with the same number of tests as before
- [ ] No `.sheet` is left in `PlannerMonthPage`; `OverviewView` has no Add Entry sheet
- [ ] No `horizontalSizeClass` or idiom check was added
- [ ] `Localizable.xcstrings` is not staged or committed
- [ ] `plans/README.md` row updated

Owner check after Step 2, on the iPad (Sean), portrait and landscape:

1. Tap a day with plans: a popover points at the day and shows its plans. It is big enough to read without scrolling for a normal day.
2. Tap an empty future day: Add Plan opens in a popover. Save a plan; the popover closes without switching to the day view on the way out, and the plan appears on the calendar.
3. Tap a past empty day: the day popover with the "day has passed" text.
4. Inside the day popover, tap +, edit a plan, log a plan's time and open a logged entry. Each opens on top as a sheet, and closing it returns to the popover. Note anything that looks wrong.
5. Tap outside the popover: it closes. Swipe to another month and tap a day there: it works the same.
6. Hugo in a narrow window: tapping a day opens a sheet, as on iPhone.

Owner check after Step 2, on the iPhone (Mona): tapping a day opens the half-height day sheet as before, and an empty day opens Add Plan as before.

Owner check after Step 3: on the iPad the Overview + button opens Add Entry in a popover pointing at the button. Pick a category and a time (they open on top), add the entry, and it appears in the list. On the iPhone the + button opens the full Add Entry sheet as before.

## STOP conditions

Stop and report if:

- The drift check shows changes beyond plan 159's files.
- On the iPhone, the day sheet no longer starts at half height (the detents did not carry over to the adapted sheet). Report it; do not add a size-class branch.
- A sheet presented from inside a popover (Step 2 check 4) closes the popover, fails to appear or leaves the app stuck. Report which one; do not redesign the day popover.
- The popover is cut off or tiny on the iPad. Report the screen and orientation, so the owner can pick new values for `popoverWidth` and `popoverHeight`.

## Maintenance notes

- Other Add Entry entry points can get the same treatment by moving their presentation onto the tapped button and adding `.popoverContentSize()`. Do it only if the owner likes Step 3.
- If a future iPad layout shows a day's plans beside the calendar, `PlannerCalendarGrid`'s popover can stay unused by passing `.constant(nil)`.
