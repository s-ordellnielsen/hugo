# Plan 147: Open Add Plan directly from an empty Planner day

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 07d4c61..HEAD -- Hugo/Features/Planner`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). Never stage or commit that file as a whole. See Step 3 for the string.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW. One tap path changes. A day with logged entries but no plans must still open the day sheet, or the user loses sight of those entries.
- **Depends on**: none
- **Category**: ux
- **Planned at**: commit `07d4c61`, 2026-11-23
- **Issue**: [SLN-328](https://linear.app/sebastianln/issue/SLN-328)

## Why this matters

Tapping a Planner day with nothing on it shows a sheet with one line: "Nothing
planned yet. Tap + to add a plan." The user then has to tap again. After this
plan, tapping an empty day opens the Add Plan sheet for that day. Cancelling
returns to the calendar. Days with plans open the day sheet as before. An empty
day in the past keeps the day sheet, with an empty state that explains the day
is in the past and that the user can log time instead.

## Current state

`Hugo/Features/Planner/Views/PlannerMonthPage.swift` builds a `PlannerMonth` and shows the calendar:

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

`onSelect` passes `day.id`, a `CalendarDay`. The month has `plannerMonth.days: [PlannerDay]`.
`PlannerDay` (`Hugo/Features/Planner/Domain/PlannerMonth.swift`) has `bars: [PlannerBar]`
("Plan bars, one per category ..., then unplanned bars", unplanned bars come
from logged entries; carried-in entries are skipped), `planned`, `logged`, `isToday`, `isPast`.
`PlannerBar.kind` is `.plan` or `.unplanned`. So a day with no plans and no
logged entries has `bars.isEmpty`.

`PlannerDaySheet` shows `planner.day.planned.empty` when there are no plan bars:
"Nothing planned yet. Tap + to add a plan." (key in `Hugo/Resources/Localizable.xcstrings`, comment "Shown in the Planner day sheet when the day has no plans. + is the Add Plan button in the navigation bar."). Its `+` toolbar button sets `isAddingPlan` and presents `PlanFormView(day: day)`.

`PlanFormView(day: CalendarDay, plan: Plan? = nil)` has its own `NavigationStack`, a dismiss button (`dismiss()`), and saves via `PlanService`. It can be presented from any view.

Decision (owner): empty day opens Add Plan directly; days with plans open the day
sheet; past empty day keeps the sheet with a better empty state. A day with logged
entries but no plans counts as not empty, so the sheet still shows the entries.

Another plan (154, iPad two columns) will later show the day's plans in a column.
Keep the decision in one small function that takes a `PlannerDay`, so that plan can reuse it.

Rules from `AGENTS.md` that apply: logic in a testable value type, not in the view body; `Domain` is `nonisolated` where possible; tests mirror source layout; Swift Testing; new strings in the catalog in English and Danish with comments.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |

## Scope

**In scope**:

- `Hugo/Features/Planner/Domain/PlannerDayDestination.swift` (create)
- `HugoTests/Features/Planner/Domain/PlannerDayDestinationTests.swift` (create)
- `Hugo/Features/Planner/Views/PlannerMonthPage.swift`
- `Hugo/Features/Planner/Screens/PlannerDaySheet.swift`
- `Hugo/Resources/Localizable.xcstrings` (add one key only, see Step 3)

**Out of scope**:

- `PlanFormView`, `PlanFormModel`, `PlanService`.
- The calendar grid, the day cell, the iPad layout.

## Git workflow

- Work on `main`. Commit per step. Conventional Commits, for example `feat(planner): open Add Plan from an empty day`.
- Do not push.

## Steps

### Step 1: Create the decision type

Create `Hugo/Features/Planner/Domain/PlannerDayDestination.swift`:

```swift
/// What tapping a Planner day opens. A day with no plans and no logged
/// entries goes straight to Add Plan, unless it is in the past, where adding a plan
/// makes little sense. Every other day opens the day sheet.
nonisolated enum PlannerDayDestination: Equatable, Sendable {
    case daySheet
    case addPlan

    init(day: PlannerDay) {
        self = day.bars.isEmpty && !day.isPast ? .addPlan : .daySheet
    }
}
```

Today counts as not past (`isPast` is `day < today`), so an empty today opens Add Plan.

**Verify**: `swift-format lint --strict Hugo/Features/Planner/Domain/PlannerDayDestination.swift` exits 0.

### Step 2: Test it

Create `HugoTests/Features/Planner/Domain/PlannerDayDestinationTests.swift`, `struct`,
Swift Testing. Build days with `PlannerMonth.make(...)` as `PlannerMonthTests` does
(fixed UTC Gregorian calendar, `now` of 2026-11-03 12:00, `Tracker(name:type:iconName:)`,
`Entry(date:duration:tracker:)`, and a `PlannedItem` built the way `PlannerMonthTests` builds its items;
copy its helper rather than inventing one). Tests:

1. `emptyFutureDayOpensAddPlan`: no items or entries, day 2026-11-10, expect `.addPlan`.
2. `emptyTodayOpensAddPlan`: day 2026-11-03, expect `.addPlan`.
3. `emptyPastDayOpensDaySheet`: day 2026-11-01, expect `.daySheet`.
4. `dayWithPlanOpensDaySheet`: a plan on a future day, expect `.daySheet`.
5. `dayWithOnlyLoggedEntryOpensDaySheet`: an entry on today, no plan, expect `.daySheet`.

**Verify**: `Scripts/verify.sh` exits 0, with 5 more tests than before.

### Step 3: Open Add Plan from the month page, and improve the past-day empty state

In `PlannerMonthPage.swift`:

- Add `@State private var addingPlanDay: CalendarDay?`.
- Replace the grid's `onSelect` with a small private method `select(_ day: CalendarDay)` that looks up the `PlannerDay` in `plannerMonth.days` by `id` and sets `addingPlanDay = day` when `PlannerDayDestination(day: plannerDay) == .addPlan`, otherwise `selectedDay = day`. If the lookup fails, set `selectedDay`.
- Add `.sheet(item: $addingPlanDay) { day in PlanFormView(day: day) }`. Do not add detents, to match how the day sheet presents the same form.
- Keep the existing `.sheet(item: $selectedDay)` as is. The two sheets are never open together.

In `PlannerDaySheet.swift` `plannedSection`, show a different line when `day < CalendarDay(today)` and there are no plan bars:
a new string `planner.day.planned.empty.past`, for example
English "This day has passed, so nothing was planned. Use Add Entry on the Overview to log your time."
Danish "Dagen er gået, og der var ikke planlagt noget. Brug Tilføj registrering på Oversigt for at registrere din tid."
Check the actual tab and button names in the catalog (for example the key for the Add Entry button and the Overview tab title) and use those exact words in both languages.
Comment: "Shown in the Planner day sheet when a past day has no plans. Tells the user to log time instead." Keep the existing string for today and future days.

Strings: do not stage the owner's uncommitted `Localizable.xcstrings` edits. Add only your key
(with both languages and the comment) and commit only your hunks with `git add -p Hugo/Resources/Localizable.xcstrings`.
If the file's existing diff overlaps or conflicts with where your key goes, STOP and ask.

**Verify**: `Scripts/verify.sh` exits 0, and `git diff --cached --stat` shows only your key in the catalog.

## Test plan

- The five decision tests. The view wiring is a build plus the owner check below.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, with 5 more tests than before
- [ ] Tapping an empty today or future day opens Add Plan; Cancel returns to the calendar
- [ ] A day with a plan or a logged entry opens the day sheet
- [ ] A past empty day opens the day sheet with the new text
- [ ] The owner's other `Localizable.xcstrings` edits are still uncommitted and unstaged
- [ ] `plans/README.md` row updated

Owner check on device: tap an empty future day, save a plan, and confirm it appears on the
calendar; tap the same day and confirm the day sheet opens; cancel Add Plan on another empty day
and confirm you are back on the calendar; tap a past empty day and read the text, in English and Danish.

## STOP conditions

Stop and report if:

- `PlannerMonthPage` no longer owns `selectedDay` and the day sheet as described.
- Presenting `PlanFormView` straight from the month page fails (for example it needs the day sheet's environment).
- The catalog diff conflicts with the owner's edits.

## Maintenance notes

- Plan 154 (iPad two columns) should call `PlannerDayDestination(day:)` rather than copy the check.
- A day with only logged entries still opens the day sheet on purpose, so the entries stay visible.
