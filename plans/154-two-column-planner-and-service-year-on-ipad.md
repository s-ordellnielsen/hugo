# Plan 154: Two columns for the Planner and the Service Year on iPad

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> Commit after every step. Stop at every "Owner check" until the owner answers.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 07d4c61..HEAD -- Hugo/Features/Planner/Screens/PlannerView.swift Hugo/Features/Planner/Views/PlannerMonthPage.swift Hugo/Features/Planner/Screens/PlannerDaySheet.swift Hugo/Features/ServiceYear Hugo/App/AppRootView.swift`
> Expected: no output, except changes made by plan 152 (which this plan needs). Compare
> any other change with "Current state" and STOP on a mismatch. Check that plan 152 is DONE in
> `plans/README.md`. `git status --short` may show `M Hugo/Resources/Localizable.xcstrings`
> (the owner's own edit). Never touch, stage or commit it.

## Status

- **Priority**: P2
- **Effort**: L
- **Risk**: HIGH. It changes the structure of two main screens at regular width, moves toolbars and titles out of the extracted views, and the layout can only be checked on an iPad.
- **Depends on**: 152
- **Category**: feature (iPad)
- **Planned at**: commit `07d4c61`, 2026-11-23
- **Issue**: [SLN-336](https://linear.app/sebastianln/issue/SLN-336), child of [SLN-323](https://linear.app/sebastianln/issue/SLN-323) (iPad). Ships in V1.0.

## Why this matters

On an iPad the Planner shows one month calendar across the whole screen and a
tap on a day covers it with a sheet. The Service Year shows a stack of month
cards and a tap pushes a full-screen page. Both waste the width and hide the
list the person was looking at. At regular width:

- Planner: the month calendar on one side, the selected day's plans on the other. Tapping a day updates the other side. No sheet.
- Service Year: the list of months on one side, the selected month's details on the other.

iPhone and compact width (Split View narrow, Slide Over) keep today's behavior: the day opens in a sheet and the month is a pushed screen.

## Rules from plans 136, 140 and 152 (do not bring those bugs back)

- At regular width the iPad detail has exactly ONE `NavigationStack` for the whole detail (plan 152 as shipped, `AdaptiveAppLayout`; its root and path follow the selected tab), and compact width has one per tab, both owned by `Hugo/App`. A column must NOT contain a `NavigationStack`. Two nested stacks bring back the duplicate toolbars and lost titles of plan 136.
- Never reset a stack with `.id`.
- Only the selected tab's root exists at regular width, so a tab's own `@State` (the selected day, the selected month, scroll positions) is recreated when the person switches tabs and back. Plan 152 already hoists `displayedYear` and `displayedMonth` into `AppNavigationState`. Put the new selection (`selectedDay` for the Planner, the selected month for the Service Year) there too, as plain optional values with the same restore-on-appear pattern, so the details column survives a tab switch.
- A column cannot use `.navigationTitle` or `.toolbar` of its own: they would attach to the tab's one navigation bar and replace the Planner or Year title. So the shared content views carry no title, no toolbar and no sheets. The sheet or pushed screen wrapper adds those back.

## Current state

`PlannerMonthPage.swift` (verify before editing) holds `selectedDay` and presents the day as a sheet:

```swift
@State private var selectedDay: CalendarDay?
...
PlannerCalendarGrid(month: plannerMonth, onSelect: { selectedDay = $0 })
...
.sheet(item: $selectedDay) { day in
    PlannerDaySheet(day: day, today: today)
        .presentationDetents([.medium, .large])
}
```

`PlannerView` builds `PlannerPager`, a horizontal pager of `PlannerMonthPage`s with
`displayedMonth` and a month title in `editorialNavigationTitle`.

`PlannerDaySheet.swift` mixes the content with the sheet chrome. It owns a
`NavigationStack` (line 35), the title (`editorialNavigationTitle`, line 54), a
dismiss button and an "add plan" `ToolbarItem`, and four sheets (add plan, edit plan,
log from plan, entry detail). The content is a `ScrollView` with `plannedSection`
and `PlannerLoggedEntryList`, plus the "planner.day.planned.empty" text when a day
has no plans.

`ServiceYearPageView` lists `ServiceYearMonthRow`s inside a `ScrollView`.
`ServiceYearMonthRow.swift:34` wraps each card in a `NavigationLink` to
`MonthDetailView` with a zoom transition. `MonthDetailView` is a `List` (submit
section, summary section, `MonthEntriesSection`) with `editorialNavigationTitle`,
a `ToolbarItem(placement: .primaryAction)` add menu, and four sheets (add entry,
submit, add and edit school credit). `MonthEntriesSection` pushes `EntryDetailView`.

After plan 152, the Year tab pushes `MonthDetailView` by `YearRoute.month` and a
destination view in `ServiceYear/Views` rebuilds the `ServiceMonth` from the database
for a `YearMonth`. This plan reuses that view as the month column. Read plan 152
and the code it left before starting.

## Design

### `TwoColumnLayout` (generic container)

`Hugo/DesignSystem/Components/TwoColumnLayout.swift`. It names no feature type.

```swift
struct TwoColumnLayout<Primary: View, Secondary: View>: View {
    @ViewBuilder var primary: () -> Primary
    @ViewBuilder var secondary: () -> Secondary
}
```

- Regular width and not an accessibility Dynamic Type size: an `HStack` with the primary column (flexible, about 55 percent) and a `Divider` and the secondary column. Each column scrolls on its own and keeps the page background.
- Otherwise: only the primary. The secondary is not built.
- It is the only place in this plan that reads `horizontalSizeClass` and `dynamicTypeSize`. The decision is a pure rule `TwoColumnRule.showsSecondary(sizeClass:dynamicTypeSize:)` (`nonisolated enum`, same file), so it can be tested. At `.accessibility1` and larger a half-width column is unreadable, so it falls back to one column.
- It puts `\.showsSecondaryColumn` (a `Bool` environment value, default `false`) into the environment of both columns. Screens read that value, not the size class, to decide between "select" and "present or push".

### Selection state per screen

An `@Observable @MainActor` class per screen, owned with `@State` by the screen's root, never by the pager page:

- `PlannerSelection` in `Hugo/Features/Planner/State/PlannerSelection.swift`: `selectedDay: CalendarDay?`, `select(_:)`, `monthDidChange(to: YearMonth, today: CalendarDay)`. When the displayed month changes, the selection becomes today if today is in that month, otherwise `nil`. A day outside the month is cleared. The empty right column then shows a short hint ("Select a day").
- `YearSelection` in `Hugo/Features/ServiceYear/State/YearSelection.swift`: `selectedMonth: YearMonth?`, `select(_:)`, `yearDidChange(to:now:)`. When the year changes, the selection becomes the current month if the year contains it, otherwise `nil`.

On compact width the same state drives today's presentation: `PlannerSelection.selectedDay` is the item of `.sheet(item:)`. Year keeps the pushed month through `YearRoute.month` (plan 152) and does not use `YearSelection` at compact width.

### Extracted content views

- `PlannerDayContent(day:today:onAddPlan:...)` in `Planner/Views`: everything inside the day sheet's `ScrollView` (planned section, logged entries, the empty state) and the add plan, edit plan and log sheets. No `NavigationStack`, no title, no toolbar. It shows its own heading (the weekday and date as a `Text`) and an Add Plan `Button` at the top, so it works as a column. `PlannerDaySheet` becomes a thin wrapper: `NavigationStack`, `editorialNavigationTitle`, the dismiss and add toolbar items, and `PlannerDayContent`. The wrapper's add button and the content's add button must not both show in the sheet: the content takes `showsAddButton: Bool`, and the wrapper passes `false`.
- `MonthDetailContent(month:schoolCredits:)` in `ServiceYear/Views`: the `List`, its sheets and the add menu moved into the list as a leading row or section header button. `MonthDetailView` stays as the pushed screen: it adds `editorialNavigationTitle` and the `primaryAction` add menu, and passes `showsAddMenu: false` to the content.

Entry rows in the month column and the day column open `EntryDetailView` as a plain
`.sheet(item:)`, not a push (a push needs a stack) and not an inspector (a third
column does not fit an 11 inch iPad). `MonthEntriesSection` gets a closure
`onSelectEntry: ((Entry) -> Void)?`. When it is `nil` it pushes as today. When set, the
caller shows the sheet.

### Plan 147 (tap an empty day opens Add Plan directly)

If plan 147 has landed, a tap on an empty day at compact width opens Add Plan directly.
In two-column mode a tap on an empty day only selects it. The right column then shows its
empty state ("planner.day.planned.empty") with the Add Plan button, so the person sees the
day first. Branch on `showsSecondaryColumn`, not on a size class. If 147 has not landed,
there is nothing to do, and the empty state must still show the button.

### Year month cards at regular width

`ServiceYearMonthRow` reads `showsSecondaryColumn`. When true, a tap calls
`onSelect(month.id)` and the card shows a selected state (tinted border, plus
`.accessibilityAddTraits(.isSelected)`). The `NavigationLink`, the zoom transition and
`matchedTransitionSource` are used only when it is false. Future months stay
non-tappable as today. The context menu stays.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| No nested stacks | `grep -n "NavigationStack" Hugo/Features/Planner/Views/PlannerDayContent.swift Hugo/Features/ServiceYear/Views/MonthDetailContent.swift` | no matches |

## Scope

**In scope**:

- `Hugo/DesignSystem/Components/TwoColumnLayout.swift` (create)
- `Hugo/Features/Planner/State/PlannerSelection.swift`, `Views/PlannerDayContent.swift` (create), `Screens/PlannerDaySheet.swift`, `Screens/PlannerView.swift`, `Views/PlannerMonthPage.swift`
- `Hugo/Features/ServiceYear/State/YearSelection.swift`, `Views/MonthDetailContent.swift` (create), `Screens/MonthDetailView.swift`, `Screens/ServiceYearView.swift`, `Views/ServiceYearPageView.swift`, `Views/ServiceYearMonthRow.swift`, `Views/MonthEntriesSection.swift`
- Tests: `HugoTests/DesignSystem/Components/TwoColumnRuleTests.swift`, `HugoTests/Features/Planner/State/PlannerSelectionTests.swift`, `HugoTests/Features/ServiceYear/State/YearSelectionTests.swift` (create)

**Out of scope**:

- `AppRootView` and the tab structure (plan 152).
- The adaptive inspector (plan 153).
- Any change to the iPhone screens, titles or toolbars.
- Restyling the calendar grid or the month cards beyond the selected state.
- Persisting the selection across launches.

## Git workflow

- Work on `main`. Commit per step, Conventional Commits, for example `refactor: extract the planner day content from its sheet`.
- Do not push. Never stage `Hugo/Resources/Localizable.xcstrings`.

## Steps

### Step 1: `TwoColumnLayout` and its rule, with tests

Create `TwoColumnLayout.swift` with `TwoColumnRule` and the `\.showsSecondaryColumn`
environment value (use the `@Entry` macro). Create `TwoColumnRuleTests`:
`regularWithStandardTypeShowsSecondary`, `compactHidesSecondary`, `nilHidesSecondary`,
`accessibilityTypeHidesSecondary` (for `.accessibility1` and `.accessibility5`),
`largestNonAccessibilityTypeStillShowsSecondary` (`.xxxLarge`).

**Verify**: `Scripts/verify.sh` exits 0, with 5 more tests. `grep -rn "horizontalSizeClass" Hugo/DesignSystem/Components` matches only this file.

### Step 2: Extract `PlannerDayContent`, no visible change

Create `PlannerDayContent` from the body of `PlannerDaySheet` as described. Make
`PlannerDaySheet` a wrapper that keeps its stack, title, dismiss and add toolbar
items. At compact width and in the sheet nothing may change.

**Verify**: `Scripts/verify.sh` exits 0, the nested-stack grep for `PlannerDayContent.swift` returns no matches. Owner check on iPhone: open a day, add a plan, edit a plan, log a plan, open an entry. It all works as before.

### Step 3: Planner selection state and tests

Create `PlannerSelection` and `PlannerSelectionTests`: `selectSetsDay`,
`monthChangeSelectsTodayWhenInMonth`, `monthChangeClearsSelectionWhenTodayIsElsewhere`,
`monthChangeKeepsNothingFromAnotherMonth`. Use fixed `CalendarDay` values and a fixed `Calendar`.

**Verify**: `Scripts/verify.sh` exits 0, with 4 more tests.

### Step 4: Use `TwoColumnLayout` in the Planner

In `PlannerPager`, create `@State private var selection = PlannerSelection()` and wrap
the pager's `ScrollView` in `TwoColumnLayout(primary:secondary:)`. The primary is the
current pager. `PlannerMonthPage` gets an `onSelectDay` closure and a `selectedDay`
value instead of owning `selectedDay`:

- Calendar tap: `selection.select(day)`.
- `showsSecondaryColumn == false`: `PlannerView` presents `.sheet(item: $selection.selectedDay)` with `PlannerDaySheet`, as before.
- `showsSecondaryColumn == true`: no sheet. The secondary is `PlannerDayContent` for `selection.selectedDay`, or a short hint when it is `nil`. The calendar marks the selected day (check how `PlannerCalendarGrid` marks today and add one selected state, with `.isSelected`).

The month title and `scrollPosition` logic in `PlannerPager` stay. Call `selection.monthDidChange` from the existing `onChange(of: scrollPosition)`.

**Verify**: `Scripts/verify.sh` exits 0. Owner check on iPhone: unchanged. Owner check on iPad, below.

**Owner check on a real iPad. Stop until the owner answers.** Test portrait, landscape, Split View (full, half and one third, where the third falls back to the sheet) and at the largest Dynamic Type (accessibility sizes must show one column and the sheet):

1. The calendar is on one side, the day on the other. Tapping a day updates the day with no sheet.
2. Swiping to another month moves the selection to today or clears it.
3. Add plan, edit plan and log from a plan open sheets and return to the day column.
4. Rotating keeps the selected day.
5. Tapping the Planner tab again goes to the current month (plan 152 reselect) and the selection follows.
6. VoiceOver reads the selected day and the column order (calendar, then day).
7. The Planner title and the person icon in the navigation bar are unchanged and appear once.

### Step 5: Extract `MonthDetailContent`, no visible change

Create `MonthDetailContent` from the body of `MonthDetailView` (the `List` and its
four sheets). Add `showsAddMenu: Bool`: when true, the content shows the add menu as the
first row's trailing button. `MonthDetailView` keeps its title and `primaryAction` menu and
passes `showsAddMenu: false`. Add `onSelectEntry` to `MonthEntriesSection` as described.

**Verify**: `Scripts/verify.sh` exits 0, the nested-stack grep for `MonthDetailContent.swift` returns no matches. Owner check on iPhone: open a month, add an entry, submit, add and edit school credit, open an entry. All unchanged.

### Step 6: Year selection state and tests

Create `YearSelection` and `YearSelectionTests`: `selectSetsMonth`,
`yearChangeSelectsCurrentMonthWhenInYear`, `yearChangeClearsSelectionOtherwise`.

**Verify**: `Scripts/verify.sh` exits 0, with 3 more tests.

### Step 7: Use `TwoColumnLayout` in the Service Year

In `ServiceYearView`, create `@State private var selection = YearSelection()` and wrap the
pager in `TwoColumnLayout`. At `showsSecondaryColumn == true` the primary is the pager and
the secondary is the month destination view from plan 152, for `selection.selectedMonth`
(or a hint when `nil`), without a title or toolbar. The year totals card keeps its
`NavigationLink` to `ServiceYearDetailView` (a push from the primary, which is the tab's
one stack). Rows follow "Year month cards at regular width". Call `yearDidChange` from the
existing `onChange(of: scrollPosition)`.

**Verify**: `Scripts/verify.sh` exits 0. Owner check on iPhone: unchanged, including the zoom transition.

**Owner check on a real iPad. Stop until the owner answers.** Same matrix as Step 4:

1. Months on one side, the month's details on the other. Tapping a month updates the details with no push and no zoom.
2. The year totals card still pushes the year detail with a back button. Going back keeps the selected month.
3. Switching tabs and back keeps the selected month and any pushed screen (plan 152).
4. Tapping the Year tab again returns to the current year and the current month.
5. Add entry, submit report and school credit sheets work from the details column.
6. Opening an entry from the details column opens a sheet.
7. The year title, the year picker, Help menu and person icon in the navigation bar are unchanged and appear once. The month name does not replace the year title.
8. At accessibility Dynamic Type sizes, the Year tab shows one column and a month tap pushes as on iPhone.

## Test plan

- `TwoColumnRuleTests` (5), `PlannerSelectionTests` (4), `YearSelectionTests` (3). The layouts themselves are checked by the owner on an iPad in Steps 4 and 7.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, with 12 more tests
- [ ] `grep -rn "NavigationStack" Hugo/Features/Planner/Views/PlannerDayContent.swift Hugo/Features/ServiceYear/Views/MonthDetailContent.swift` returns no matches
- [ ] `grep -rn "horizontalSizeClass" Hugo/Features/Planner Hugo/Features/ServiceYear` returns no matches
- [ ] No `.id(` resets a stack, and `AppRootView.swift` is untouched by this plan
- [ ] The owner checks in Steps 2, 4, 5 and 7 are answered
- [ ] `git status --short` shows only in-scope files (plus the owner's `Localizable.xcstrings`, unstaged)
- [ ] `plans/README.md` row updated

## STOP conditions

Stop and report if:

- Plan 152 is not done.
- A column would need its own `NavigationStack`, or a title or toolbar from a column replaces the tab's.
- The month column loses the zoom or push at compact width (iPhone must not change).
- The two columns are unusable at regular width with the sidebar open on an 11 inch iPad in portrait. Report it, and ask the owner whether the sidebar should hide in portrait or the container should need a wider threshold.
- Moving the sheets into the content views makes a sheet present twice or not at all.

## Maintenance notes

- New content that should work as a sheet, a push and a column follows the pattern here: a content view without title, toolbar or stack, and a thin wrapper that adds them.
- Screens decide between "select" and "present" with `showsSecondaryColumn`, never with the size class.
- If the owner later wants entry details in an inspector next to the two columns, use plan 153's `adaptiveDetail` for the entry rows, after checking the width on an 11 inch iPad.
- The accessibility fallback (`.accessibility1` and larger) is a guess. If the owner wants two columns at larger sizes, change `TwoColumnRule` and its tests.
