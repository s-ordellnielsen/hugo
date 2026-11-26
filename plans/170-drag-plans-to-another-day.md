# Plan 170: Drag a day's plans to another day in the Planner

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
- **Risk**: MEDIUM. Drag and drop, the day popovers of plan 160 and the context menus of plan 166 all live on the same day cell. Only a real device can show whether long-press, tap and drag get along, so the plan stops for an owner check after the view step.
- **Depends on**: 160 (day popovers). Runs after 166 (context menus), 167 (hover effects), 168 (two columns) and 169 in the iPad batch, so expect a refreshed baseline.
- **Category**: ux
- **Planned at**: commit `16b697c`, 2026-11-26
- **Issue**: [SLN-342](https://linear.app/sebastianln/issue/SLN-342)

## Why this matters

Plans change ("I'll go on Thursday instead of Tuesday"). Today the only way to
move a plan is to delete it and add it again: `PlanFormView` says so in its doc
comment ("The day itself is fixed; to move a plan, delete it and add it again").
In Apple's Calendar on iPad you press and hold an event and drag it to another
day. After this plan, Hugo's Planner works the same way for a day's plans. It's
an extra shortcut. Tapping a day still opens its popover, and editing stays as
it is.

**Drag unit: all of a day's plans.** A day cell (`PlannerDayCell`) draws each
category's plans as one bar (`PlannerBar`, 6 points high, `items` = the
category's plans on the day), and it draws no single plans. A 6-point bar is too
small to grab with a finger, especially for older users. The cell is the only
target the size of a fingertip. So dragging a cell moves every plan on that day
(the `.plan` bars' `items`). Unplanned bars are logged time (entries), and they
never move. To move only one of two categories, the user keeps the existing
route (delete and add). A finer drag from the day popover's plan cards is a
possible follow-up, not part of this plan.

**Rules.**
- A move changes only each plan's `date`, to the target day's midday (as `PlanService.add` stores it). Duration, start minute and category stay.
- The target must not be in the past. This matches `PlannerDayDestination`, which also treats a past day differently (`day.isPast`). Dropping on the source day does nothing. A past source day is fine, which lets "I missed Tuesday, move it to Friday" work.
- Only days in the shown month are targets. The pager (`PlannerPager`) does not turn pages during a drag, and cross-month moves are out of scope.
- No undo: Hugo has no undo pattern (no `UndoManager` use). Dragging back undoes a move.
- Sync: a move is a plain change of `Plan.date` on a synced row, so CloudKit needs no schema change. `SyncDeduplicator` does not merge plans. If sync ever left two rows with the same `id`, the move updates every row with that id, so they stay together.

**Accessibility.** VoiceOver users keep the route they have today (delete and
add). This plan adds no accessibility action. A real VoiceOver move would need a
day picker. Note it as a follow-up in your report if you think it matters.

## Current state

`Hugo/Features/Planner/Views/PlannerCalendarGrid.swift` (after plans 160, 166 and
167): a generic `PlannerCalendarGrid<DayPopover: View>` whose stored properties
are, in this order: `month: PlannerMonth`, `onSelect: ((CalendarDay) -> Void)?`,
`onAddPlan`, `onLogTime` (plan 166), `presentedDay: Binding<CalendarDay?>` and
`@ViewBuilder dayPopover`. Each day is:

```swift
ForEach(month.days) { day in
    Button {
        onSelect?(day.id)
    } label: {
        PlannerDayCell(day: day)
    }
    .buttonStyle(.plain)
    .disabled(onSelect == nil)
    .contentShape(.contextMenuPreview, .rect(cornerRadius: HugoLayout.Spacing.regular))  // plan 166
    .contextMenu { ... }  // plan 166
    .contentShape(.hoverEffect, .rect(cornerRadius: HugoLayout.CornerRadius.calendarDay))  // plan 167
    .hoverEffect(.highlight)  // plan 167
    .popover(isPresented: isPresented(day.id)) {
        dayPopover(day.id)
    }
}
```

plus `extension PlannerCalendarGrid where DayPopover == EmptyView { init(month:onSelect:) }`.
Plan 167 added `HugoLayout.CornerRadius.calendarDay` (8) to `Theme.swift`. This
plan reuses it and must not add it again.

`Hugo/Features/Planner/Views/PlannerMonthPage.swift` (after plans 166 and 168):
queries `entries`, `plans` and `trackers` for the month. It builds `plannerMonth`
with `PlannerMonth.make(...)`, holds `presentedDay` and `popoverDestination`, and
has `open(_:_:)` (plan 166). Its `body` is a `ScrollView` holding plan 168's
`AdaptiveTwoColumnStack`; the grid call sits in the stack's `trailing:` `VStack`:

```swift
PlannerCalendarGrid(
    month: plannerMonth, onSelect: select,
    onAddPlan: { open($0, .addPlan) }, onLogTime: { open($0, .logTime) },
    presentedDay: $presentedDay
) { day in
    dayPopover(for: day)
}
```

It has no `@Environment(\.modelContext)` yet.

`Hugo/Features/Planner/Domain/PlannerMonth.swift`: `PlannerDay` has `id: CalendarDay`,
`bars: [PlannerBar]`, `isToday`, `isPast` (`day < today`).
`Hugo/Features/Planner/Domain/PlanMatcher.swift`: `PlannerBar` has `kind` (`.plan` / `.unplanned`)
and `items: [PlannedItem]` (empty for unplanned).
`Hugo/Features/Planner/Domain/PlannedItem.swift`: `id` is the plan's `id.uuidString`
("Repeating plans will use their own scheme", so parse with `UUID(uuidString:)` and skip failures).

`Hugo/Features/Planner/Domain/CalendarDay.swift`:
`nonisolated struct CalendarDay: Hashable, Comparable, Identifiable, Sendable` with
`year`, `month`, `day`, `midday(calendar:)`, `startDate(calendar:)`. It is not `Codable`.

`Hugo/Features/Planner/Services/PlanService.swift`:

```swift
@MainActor
struct PlanService {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) { ... }

    @discardableResult
    func add(_ draft: PlanDraft) throws -> Plan { ... plan.date = draft.day.midday(calendar: calendar) ... }
    func update(_ plan: Plan, with draft: PlanDraft) throws { try context.performIsolatedChange { ... } }
    func delete(_ plan: Plan) throws { try context.performIsolatedChange { context.delete(plan) } }
}
```

`ModelContext.performIsolatedChange` (`Hugo/Persistence/ModelContext+IsolatedChange.swift`)
saves pending changes first, runs the closure, saves, and rolls back on error.

`HugoTests/Features/Planner/Services/PlanServiceTests.swift` is the test
pattern: `@MainActor struct`, a fixed UTC Gregorian `calendar`,
`InMemoryModelContainer.make()`, `ModelContext(container)`, `Tracker(name:type:)`,
and a private `date(_:_:_:hour:)` helper. Read the file and reuse its helpers.

`Hugo/DesignSystem/Modifiers/ErrorAlert.swift`: `.errorAlert(message: Binding<String?>)`.

SDK facts (iOS 26, checked in the SwiftUI interface):
- `draggable(_ payload:)` (iOS 16) has no optional-payload form before iOS 27, so a day without plans must not get the modifier at all (Step 3 shows how, without changing the `Button`'s identity).
- `dropDestination(for:action:isTargeted:)` (iOS 16) is the only form with a hover state on iOS 26. It is marked "to be deprecated" (version 100000) in favor of the `DropSession` form, whose hover API is iOS 27. Use the iOS 16 form.
- `CodableRepresentation(contentType:)` with `.visibility(.ownProcess)` keeps the payload inside Hugo, so dragging a day into another app gives that app nothing.

Rules from `AGENTS.md`: value logic in `nonisolated` Domain types with Swift
Testing tests mirroring the source path; SwiftData writes in `Services`; no
schema change; vanilla+ look; `Scripts/verify.sh` before each commit.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `xcrun swift-format lint --strict <files>` | exit 0 |
| Format fix | `xcrun swift-format format -i <files>` | then re-run lint; use when `lint --strict` fails on formatting only |

## Scope

**In scope**:

- `Hugo/Features/Planner/Domain/CalendarDay.swift` (add `Codable`)
- `Hugo/Features/Planner/Domain/PlanMoveRequest.swift` (create)
- `Hugo/Features/Planner/Domain/PlanMoveRule.swift` (create)
- `HugoTests/Features/Planner/Domain/PlanMoveRequestTests.swift` (create)
- `HugoTests/Features/Planner/Domain/PlanMoveRuleTests.swift` (create)
- `Hugo/Features/Planner/Services/PlanService.swift` (one method)
- `HugoTests/Features/Planner/Services/PlanServiceTests.swift` (new tests)
- `Hugo/Features/Planner/Views/PlannerCalendarGrid.swift`
- `Hugo/Features/Planner/Views/PlannerMonthPage.swift`

**Out of scope**:

- `PlannerDayCell`, `PlannerBarView`, `PlannerDaySheet`, `PlanFormView` and its model, `PlannerView`/`PlannerPager`.
- Moving one category or one plan, moving across months, undo, VoiceOver move actions, new strings.

## Git workflow

- Work on `main`. Commit per step (Conventional Commits), for example `feat(planner): move plans to another day`.
- Do not push.

## Steps

### Step 1: The payload and the rule (Domain), with tests

In `CalendarDay.swift`, add `Codable` to the declaration:
`nonisolated struct CalendarDay: Hashable, Comparable, Identifiable, Sendable, Codable {`.
It must be in this file: the compiler only synthesizes `Codable` in the type's own file.

Create `Hugo/Features/Planner/Domain/PlanMoveRequest.swift`:

```swift
import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// What dragging a Planner day carries: the ids of the day's plans and the day
/// they come from. Ids, not models, so the drop reads fresh rows.
nonisolated struct PlanMoveRequest: Codable, Equatable, Sendable, Transferable {
    let planIDs: [UUID]
    let sourceDay: CalendarDay

    /// The plans on `day`, or nil when it has none. Logged time (unplanned
    /// bars) never moves. Items whose id is not a plan's UUID are skipped.
    init?(day: PlannerDay) {
        let ids = day.bars
            .filter { $0.kind == .plan }
            .flatMap(\.items)
            .compactMap { UUID(uuidString: $0.id) }
        guard !ids.isEmpty else { return nil }
        self.init(planIDs: ids, sourceDay: day.id)
    }

    init(planIDs: [UUID], sourceDay: CalendarDay) {
        self.planIDs = planIDs
        self.sourceDay = sourceDay
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
            .visibility(.ownProcess)
    }
}
```

Create `Hugo/Features/Planner/Domain/PlanMoveRule.swift` (one type per file,
named after it; it needs no imports):

```swift
/// Where a day's plans may be dropped: on a day that is not in the past and is
/// not the day they come from. Matches `PlannerDayDestination`, which also
/// treats past days apart.
nonisolated enum PlanMoveRule {
    static func canDrop(from source: CalendarDay, on target: PlannerDay) -> Bool {
        !target.isPast && target.id != source
    }

    /// Whether `target` shows the drop highlight. The payload is unknown while
    /// hovering, so only the target's own state counts.
    static func acceptsDrops(_ target: PlannerDay) -> Bool {
        !target.isPast
    }
}
```

Create two test files (`struct`, Swift Testing, `@testable import Hugo` each):
`HugoTests/Features/Planner/Domain/PlanMoveRequestTests.swift` with tests 1 to 4
and 8, and `HugoTests/Features/Planner/Domain/PlanMoveRuleTests.swift` with
tests 5 to 7. Build days with `PlannerMonth.make(...)` as
`PlannerDayDestinationTests` does: read that file and copy the helpers each file
needs (fixed UTC calendar, `now` 2026-11-03 12:00, `Tracker`, `Entry`,
`PlannedItem`). Tests:

1. `dayWithPlansCarriesTheirIDs`: two plans in two categories on 2026-11-10 → `planIDs` holds both ids (any order; compare as `Set`), `sourceDay` is 2026-11-10.
2. `dayWithOnlyLoggedTimeCarriesNothing`: an entry and no plan on 2026-11-03 → `nil`.
3. `emptyDayCarriesNothing`: → `nil`.
4. `itemWithNonUUIDIDIsSkipped`: a `PlannedItem` with `id: "repeat:1"` and one normal plan → only the normal id.
5. `cannotDropOnPastDay`: target 2026-11-01 → `canDrop` false, `acceptsDrops` false.
6. `cannotDropOnSourceDay`: source and target 2026-11-10 → false.
7. `canDropOnTodayAndLater`: source 2026-11-01, targets 2026-11-03 and 2026-11-20 → true.
8. `requestRoundTripsThroughJSON`: encode with `JSONEncoder`, decode with `JSONDecoder` → equal.

If a test needs `@MainActor` for isolation reasons, add it to the struct, as `HugoTests/App/AppTabTests.swift` has.

**Verify**: lint the changed files; `Scripts/verify.sh` exits 0 with 8 more tests.
Commit `feat(planner): describe moving a day's plans`.

### Step 2: The service method, with tests

In `PlanService.swift`, after `update`, add:

```swift
    /// Moves the plans with `planIDs` to `day`, keeping their duration, start
    /// time and category. Rows that share an id move together. Returns how many
    /// rows moved.
    @discardableResult
    func move(planIDs: [UUID], to day: CalendarDay) throws -> Int {
        guard !planIDs.isEmpty else { return 0 }
        let descriptor = FetchDescriptor<Plan>(predicate: #Predicate<Plan> { planIDs.contains($0.id) })
        let plans = try context.fetch(descriptor)
        let date = day.midday(calendar: calendar)
        try context.performIsolatedChange {
            for plan in plans { plan.date = date }
        }
        return plans.count
    }
```

In `PlanServiceTests.swift`, add:

1. `moveChangesOnlyTheDate`: add a plan on 2026-11-04 (7 200 s, start 600, Field Service); move it to 2026-11-06 → returns 1; fetched `date == date(2026, 11, 6, hour: 12)`, duration 7 200, startMinute 600, category unchanged.
2. `moveLeavesOtherPlansAlone`: two plans on 2026-11-04; move one id → the other keeps 2026-11-04.
3. `moveWithNoIDsDoesNothing`: returns 0, nothing changes.
4. `moveWithUnknownIDReturnsZero`.

**Verify**: `Scripts/verify.sh` exits 0 with 4 more tests.
Commit `feat(planner): move plans to another day`.

### Step 3: Drag and drop on the calendar

**3a. Grid.** `HugoLayout.CornerRadius.calendarDay` already exists (plan 167);
do not add it. If it does not exist, STOP. In `PlannerCalendarGrid`:

- Add a stored property after `presentedDay`:
  ```swift
  /// Called when a day's plans are dropped on `target`. Returns whether the
  /// drop was accepted. Nil turns drag and drop off.
  var onDropPlans: ((PlanMoveRequest, PlannerDay) -> Bool)? = nil
  ```
  Keep its position before `dayPopover`, so the trailing-closure call still works.
  The stored properties are now, in order: `month`, `onSelect`, `onAddPlan`,
  `onLogTime`, `presentedDay`, `onDropPlans`, `dayPopover`.
- Add `@State private var dropTarget: CalendarDay?`.
- Change the `Button`'s label from `PlannerDayCell(day: day)` to
  `dragSource(PlannerDayCell(day: day), day: day)`, and add a private helper:
  ```swift
  /// The cell, draggable only when the day has plans and drops are on. The
  /// modifier goes on the label, not on the `Button`, so the button (and the
  /// popover anchored to it) keeps its identity when a day gains or loses plans.
  @ViewBuilder
  private func dragSource(_ cell: PlannerDayCell, day: PlannerDay) -> some View {
      if onDropPlans != nil, let request = PlanMoveRequest(day: day) {
          cell.draggable(request)
      } else {
          cell
      }
  }
  ```
- On the `Button`, after `.hoverEffect(.highlight)` (plan 167) and before `.popover(...)`, add:
  ```swift
  .background {
      if dropTarget == day.id {
          RoundedRectangle(cornerRadius: HugoLayout.CornerRadius.calendarDay)
              .fill(.primary.opacity(0.1))
              .overlay {
                  RoundedRectangle(cornerRadius: HugoLayout.CornerRadius.calendarDay)
                      .strokeBorder(.primary.opacity(0.35), lineWidth: 1)
              }
      }
  }
  .dropDestination(for: PlanMoveRequest.self) { requests, _ in
      guard let request = requests.first, let onDropPlans else { return false }
      return onDropPlans(request, day)
  } isTargeted: { isTargeted in
      if isTargeted, onDropPlans != nil, PlanMoveRule.acceptsDrops(day) {
          dropTarget = day.id
      } else if dropTarget == day.id {
          dropTarget = nil
      }
  }
  ```
  After this step the day `Button`'s chain is, in this order: `.buttonStyle(.plain)`,
  `.disabled(onSelect == nil)`, `.contentShape(.contextMenuPreview, ...)`,
  `.contextMenu { ... }`, `.contentShape(.hoverEffect, ...)`, `.hoverEffect(.highlight)`,
  `.background { drop target }`, `.dropDestination(...)`, `.popover(...)`. Plan 172
  adds an `.overlay` for its keyboard ring between `.dropDestination` and `.popover`.
- Update the `EmptyView` extension's `init` to pass `onDropPlans: nil` if the compiler asks for it.

**3b. Month page.** In `PlannerMonthPage`:

- Add `@Environment(\.modelContext) private var context` and `@State private var moveError: String?`.
- Pass `onDropPlans: movePlans` to the grid, after `presentedDay:` (edit the call in place, inside the `trailing:` `VStack` of plan 168's stack). The complete call becomes:
  ```swift
  PlannerCalendarGrid(
      month: plannerMonth, onSelect: select,
      onAddPlan: { open($0, .addPlan) }, onLogTime: { open($0, .logTime) },
      presentedDay: $presentedDay, onDropPlans: movePlans
  ) { day in
      dayPopover(for: day)
  }
  ```
- Add `.errorAlert(message: $moveError)` after `.onScrollGeometryChange(...)`.
- Add:
  ```swift
  /// Moves the dragged day's plans to `target`. Past days and the source day
  /// refuse the drop.
  private func movePlans(_ request: PlanMoveRequest, to target: PlannerDay) -> Bool {
      guard PlanMoveRule.canDrop(from: request.sourceDay, on: target) else { return false }
      do {
          try PlanService(context: context).move(planIDs: request.planIDs, to: target.id)
          return true
      } catch {
          moveError = error.localizedDescription
          return false
      }
  }
  ```

The `@Query` for `plans` refreshes the calendar on its own after the save.

**Verify**: lint the changed files; `Scripts/verify.sh` exits 0 with the same
count as after Step 2. Commit `feat(planner): drag a day's plans to another day`.

**STOP here for the owner check** (see "Done criteria"). Report, and wait.

## Test plan

- Eight Domain tests (payload, rule, JSON) and four service tests. The gesture wiring is checked by the owner.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0 with 12 more tests than before
- [ ] No schema file changed, no strings added
- [ ] `Localizable.xcstrings` not staged or committed
- [ ] `plans/README.md` row updated (unless a reviewer maintains it)

Owner check on the iPad (Sean), with a finger and with the trackpad:

1. Press and hold a future day with plans, drag it to a later day, let go: the plans appear there with the same durations and start times, and the source day has none.
2. While dragging, only today and later days light up. A past day does not, and dropping on it changes nothing.
3. Dropping back on the source day changes nothing.
4. A day with only logged time can't be picked up. An empty day can't either.
5. Tapping a day still opens its popover. If plan 166 added a context menu, a long press without moving still shows it.
6. Drag a day into another app (Notes): nothing is dropped.
7. Logged time stays on its day. A moved plan's day shows the plan bar, and the source day now shows its entries as unplanned time.

Owner check on the iPhone (Mona): the same drag works, and tapping is unchanged.

## STOP conditions

Stop and report if:

- The drift check shows changes you cannot place.
- `#Predicate<Plan> { planIDs.contains($0.id) }` does not compile or fails its test.
- `HugoLayout.CornerRadius.calendarDay` does not exist (plan 167 adds it). Do not add it here.
- On the device, the drag never starts, or it starts and the tap stops opening the popover. Report which one; do not move `.draggable` onto the `Button`.
- The drop highlight sticks after a drag ends.

## Maintenance notes

- Plan 172 (arrow keys) draws a keyboard highlight on the same cell and reuses `HugoLayout.CornerRadius.calendarDay` (added by plan 167). Keep both highlights in the grid.
- Plan 168 already moved the grid into a two-column layout's trailing column. `onDropPlans` travels with the grid.
- Repeating plans (planned in `plans/README.md`, "Planner: next steps") will produce `PlannedItem`s without rows. `PlanMoveRequest` skips non-UUID ids, so dragging a day of repeating plans will move only its one-off plans until repeating plans define their own move.
- A finer drag (one category from the day popover's plan cards) and a VoiceOver "Move to…" action are possible follow-ups.
