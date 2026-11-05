# Plan 070: Open a day sheet from the calendar to add, edit and log plans

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 2e8a451..HEAD -- Hugo/Features/Entries Hugo/Features/Categories/Screens/CategoryPicker.swift HugoTests/Features/Entries Hugo/Resources/Localizable.xcstrings`
> Plans 067-069 must be DONE first (they change `Localizable.xcstrings`; that is
> expected). For any change to the Entries files, compare the "Current state"
> excerpts against the live code; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (writes user data; extends the Add Entry form that every user relies on)
- **Depends on**: plans/067-plan-model-schema-v12.md, plans/068-planner-domain-math.md, plans/069-planner-tab-and-calendar.md, plans/073-planner-calendar-polish.md
- **Category**: direction
- **Planned at**: commit `2e8a451`, 2026-11-04

## Why this matters

Plan 069 shows plans on a calendar but gives no way to create them. This plan
makes every day tappable. The tap opens a sheet that lists the day's plans and
logged entries and lets the user add, edit and delete plans, add an entry, and
"log" a plan: open the normal Add Entry form already filled with the plan's
date, duration, category and start time. That one tap turns "I planned 2 hours
of field service" into a logged entry without retyping, and it is the main way
the Planner saves the user time.

## Product rules (decided with the owner, do not change)

1. Tapping any day of a reachable month opens the **day sheet**.
2. The day sheet has two sections:
   - **Planned**: the day's plans as cards (duration, category, start time if
     any). Tapping a card opens the plan form for editing. Under the cards, an
     "Add Plan" button. Plans can be added to any day of a reachable month,
     including earlier days of the current month.
   - **Logged**: only for today and earlier days. The day's entries, using the
     existing `EntryRow` (tap opens the existing `EntryDetailView`), and an
     "Add Entry" button that opens `AddEntryView` seeded with the day.
3. **Log** button: on today and earlier days, each plan card whose bar is not
   full (`!PlannerBar.isFull`, plan 068's matching) has a "Log" button. It opens
   `AddEntryView` pre-filled with the plan's day, its category, its start time
   and the plan's **remaining** time (`PlannerBar.remainingSeconds`, so a 2-hour
   plan with 1 hour logged suggests 1 hour). The user still taps Add to save.
   The plan stays (plans and entries are compared, never merged). A full plan
   has no Log button, so users do not log a plan twice by mistake.
4. **Plan form** fields: duration (the existing wheel picker), category (the
   existing `CategoryPicker`), optional start time (the existing
   `EntryTimePickerView`, which has a Clear button). Save is disabled until the
   duration is above zero and a category is chosen. Editing shows a Delete
   button with a confirmation. The day itself is not editable; delete and re-add
   to move a plan.
5. Plan cards show durations as words via `ServiceDurationFormatter.hoursString`
   ("2 hours", "1 hour, 30 minutes"), because "02:00" next to a start time
   "10:00" reads as two clock times.
6. Each plan card shows the same fill as the calendar: a full-width
   `PlannerBarShape` (plan 069) with the bar's `fraction`, and on today and
   earlier days the line "1 hour of 2 hours logged".

## Current state

- `Hugo/Features/Entries/Screens/AddEntryView.swift`:

  ```swift
  @State private var form: AddEntryFormModel

  init(seededDate: Date? = nil) {
      _form = State(initialValue: AddEntryFormModel(seededDate: seededDate))
  }
  ```

  It shows a `DurationWheelPicker(duration: $form.durationInSeconds, minuteInterval: durationMinuteInterval, maxDuration: 24 * 60 * 60)`,
  a category button that sets `form.isCategoryPickerPresented = true`, a
  `DatePicker("entry.date.label", selection: $form.date, in: ...Date.now, displayedComponents: .date)`,
  a time button, and a Bible studies stepper. `.task { form.reconcileSelection(with: trackers) }`
  and `.onChange(of: trackers)` keep the category valid. The toolbar has a
  cancel `Button("navigation.dismiss", systemImage: "xmark", role: .cancel)` and
  `Button("entry.add.label", systemImage: "plus", action: submit).buttonStyle(.glassProminent).tint(.hugoAccent)`.
  Sheets: `CategoryPicker(selection: $form.selectedTracker).presentationDetents([.medium])`
  and `EntryTimePickerView(date: $form.time).presentationDetents([.height(HugoLayout.Size.addEntryCompactSheetHeight)])`.
  `.errorAlert(message: $form.validationMessage)`.

- `Hugo/Features/Entries/State/AddEntryFormModel.swift`:

  ```swift
  init(calendar: Calendar = .current, now: Date = .now, seededDate: Date? = nil) {
      self.calendar = calendar
      self.now = now
      self.date = calendar.startOfDay(for: seededDate ?? now)
  }
  ...
  func reconcileSelection(with trackers: [Tracker]) {
      if let selectedTracker, trackers.contains(where: { $0.id == selectedTracker.id }) {
          return
      }
      selectedTracker = trackers.first(where: \.isDefault) ?? trackers.first
  }
  ```

  `time: Date?` holds an optional time of day; `combinedDate` merges `date` with
  `time`'s hour and minute. `durationInSeconds: TimeInterval = 0`.

- `Hugo/Features/Entries/Views/EntryRow.swift`: `EntryRow(entry: Entry, selectedEntry: Binding<Entry?>)`,
  a card-style button (`HugoLayout.Spacing.card` padding, `HugoLayout.CornerRadius.card`,
  background `Color(.secondarySystemBackground)` in dark mode, `Color(.systemBackground)` in light mode).
- `Hugo/Features/Entries/Screens/EntryDetailView.swift`: `EntryDetailView(entry:)`,
  presented by `OverviewListView` with `.sheet(item: $selectedEntry) { EntryDetailView(entry: $0).presentationDetents([.medium, .large]) }`.
  Its delete flow is the pattern for deleting a plan:

  ```swift
  .confirmationDialog("entry.delete.confirmation.label", isPresented: $deleteConfirmationShown) {
      Button("entry.delete.confirmation.action", role: .destructive) {
          do {
              try context.performIsolatedChange { context.delete(entry) }
              dismiss()
          } catch {
              deletionError = error.localizedDescription
          }
      }
  } message: {
      Text("entry.delete.confirmation.message")
  }
  ```

- `Hugo/Persistence/ModelContext+IsolatedChange.swift`: `context.performIsolatedChange { ... }`
  saves pending edits, applies the closure, saves, and rolls back only the
  closure's changes on failure. Use it for every plan write.
- `Hugo/Features/Categories/Screens/CategoryPicker.swift`: `CategoryPicker(selection: Binding<Tracker?>, dismissOnSelection: Bool = false)`.
- `Hugo/Features/Entries/Screens/EntryTimePickerView.swift`: `EntryTimePickerView(date: Binding<Date?>)`,
  with Done and (when set) Clear buttons.
- Services pattern: `Hugo/Features/Reports/Services/ReportSubmissionService.swift`
  (`@MainActor struct ... { private let context: ModelContext; private let calendar: Calendar; init(context:calendar: = .current) }`).
  Service tests: `HugoTests/Features/Categories/Services/CategoryDeletionServiceTests.swift`
  (`@MainActor struct`, `InMemoryModelContainer.make()`, `ModelContext(container)`).
- Form model tests: `HugoTests/Features/Entries/State/AddEntryFormModelTests.swift`
  (`@MainActor struct`, fixed UTC calendar, private `date(...)` helper).
- From plans 067-069: `Plan(date:duration:startMinute:tracker:)`, `plan.setCategory(_:)`,
  `CalendarDay` (`midday(calendar:)`, `startDate(calendar:)`, `dateRange(calendar:)`,
  `Identifiable`), `PlannedItem(plan, trackers:)` (`id` is `plan.id.uuidString`,
  `categoryType`, `trackerID`, `startMinute`, `duration`, `color`),
  `PlannerDay.make(day:items:entries:trackers:today:)` whose `bars` hold one
  `PlannerBar` per plan (same `id` as the item; `fraction`, `filledSeconds`,
  `remainingSeconds`, `isFull`, `kind`), `PlannerBarShape(fraction:color:)`,
  `PlannerCalendarGrid(month:)`, `PlannerDayCell(day:)`,
  `PlannerMonthPage(month:today:onScrolledFromTopChange:)`.
- Plan 073 made the calendar bars thin strips (6 pt, no text or icon) and aligned
  grid cells to the top of their row. Keep both when you edit the grid in Step 7.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Layout | `Scripts/check-layout.sh` | exit 0, no output |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/AddEntryFormModelTests -only-testing:HugoTests/PlanFormModelTests -only-testing:HugoTests/PlanServiceTests` | `** TEST SUCCEEDED **` |
| Strings valid JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | no output |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:
- `Hugo/Features/Entries/Screens/AddEntryView.swift` (init parameters only)
- `Hugo/Features/Entries/State/AddEntryFormModel.swift` (init parameters, `reconcileSelection`)
- `HugoTests/Features/Entries/State/AddEntryFormModelTests.swift` (new tests)
- `Hugo/Features/Planner/Views/PlannerCalendarGrid.swift`, `PlannerDayCell.swift`, `PlannerMonthPage.swift`
- `Hugo/Resources/Localizable.xcstrings` (new keys only)
- Create: `Hugo/Features/Planner/Services/PlanService.swift`,
  `Hugo/Features/Planner/State/PlanFormModel.swift`,
  `Hugo/Features/Planner/Screens/PlanFormView.swift`,
  `Hugo/Features/Planner/Screens/PlannerDaySheet.swift`,
  `Hugo/Features/Planner/Views/PlannedItemRow.swift`,
  `HugoTests/Features/Planner/Services/PlanServiceTests.swift`,
  `HugoTests/Features/Planner/State/PlanFormModelTests.swift`

**Out of scope**:
- `EntryRow`, `EntryDetailView`, `CategoryPicker`, `EntryTimePickerView`: reuse as they are.
- Any other behavior of `AddEntryView` (the date range limit, Bible studies, submit).
- Repeating plans, moving a plan to another day, notes on plans.
- The status header (plan 071) and Overview (plan 072).

## Git workflow

- Branch: `advisor/070-planner-day-sheet`
- Conventional Commits, for example `feat: add and log plans from the planner day sheet`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Let Add Entry start from a plan

In `AddEntryFormModel`:

1. Add `private let preferredTrackerID: UUID?`.
2. Extend the initializer, keeping existing callers valid:

   ```swift
   init(
       calendar: Calendar = .current,
       now: Date = .now,
       seededDate: Date? = nil,
       seededDuration: TimeInterval? = nil,
       preferredTrackerID: UUID? = nil,
       seededStartMinute: Int? = nil
   ) {
       self.calendar = calendar
       self.now = now
       self.date = calendar.startOfDay(for: seededDate ?? now)
       self.durationInSeconds = max(0, seededDuration ?? 0)
       self.preferredTrackerID = preferredTrackerID
       if let seededStartMinute {
           self.time = calendar.date(
               bySettingHour: seededStartMinute / 60, minute: seededStartMinute % 60, second: 0, of: self.date)
       }
   }
   ```

3. In `reconcileSelection(with:)`, prefer the seeded category before the default:

   ```swift
   selectedTracker =
       trackers.first(where: { $0.id == preferredTrackerID })
       ?? trackers.first(where: \.isDefault) ?? trackers.first
   ```

In `AddEntryView`, extend the init the same way and pass the values through:

```swift
init(
    seededDate: Date? = nil,
    seededDuration: TimeInterval? = nil,
    preferredTrackerID: UUID? = nil,
    seededStartMinute: Int? = nil
) {
    _form = State(
        initialValue: AddEntryFormModel(
            seededDate: seededDate, seededDuration: seededDuration,
            preferredTrackerID: preferredTrackerID, seededStartMinute: seededStartMinute))
}
```

Add to `AddEntryFormModelTests`:
- `seedsDurationCategoryAndStartTimeFromAPlan`: with the UTC calendar,
  `now: date(2026, 11, 4, hour: 15)`, `seededDate: date(2026, 11, 4, hour: 12)`,
  `seededDuration: 7_200`, `preferredTrackerID: ldc.id`, `seededStartMinute: 600`;
  call `reconcileSelection(with: [fieldService(isDefault: true), ldc])`. Expect
  `durationInSeconds == 7_200`, `selectedTracker?.id == ldc.id`, and
  `combinedDate` at 2026-11-04 10:00.
- `unknownPreferredCategoryFallsBackToDefault`: a `preferredTrackerID` that matches
  no tracker selects the default tracker.

**Verify**: Focused tests (only `AddEntryFormModelTests`) → `** TEST SUCCEEDED **`, old tests included.

### Step 2: `PlanService`

`Hugo/Features/Planner/Services/PlanService.swift`:

```swift
import Foundation
import SwiftData

/// What the plan form produces.
struct PlanDraft {
    let day: CalendarDay
    let duration: TimeInterval
    /// Minutes after midnight, or nil.
    let startMinute: Int?
    let tracker: Tracker
}

/// Creates, changes and deletes plans. Every write is saved on its own, so a
/// failure never discards other edits.
@MainActor
struct PlanService {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    @discardableResult
    func add(_ draft: PlanDraft) throws -> Plan {
        let plan = Plan(
            date: draft.day.midday(calendar: calendar), duration: draft.duration,
            startMinute: draft.startMinute, tracker: draft.tracker)
        try context.performIsolatedChange { context.insert(plan) }
        return plan
    }

    func update(_ plan: Plan, with draft: PlanDraft) throws {
        try context.performIsolatedChange {
            plan.date = draft.day.midday(calendar: calendar)
            plan.duration = draft.duration
            plan.startMinute = draft.startMinute
            plan.setCategory(draft.tracker)
        }
    }

    func delete(_ plan: Plan) throws {
        try context.performIsolatedChange { context.delete(plan) }
    }
}
```

`PlanServiceTests` (`@MainActor`, UTC calendar, `InMemoryModelContainer.make()`,
`ModelContext(container)`):
- `addStoresMiddayOnThePlannedDay`: adding a draft for 4 Nov 2026 stores
  `date == date(2026, 11, 4, hour: 12)`, the duration, the start minute and the
  tracker's id and name.
- `updateChangesDurationCategoryAndStartTime`: update an added plan to another
  tracker, 1 h, no start minute; fetch and check all three.
- `deleteRemovesThePlan`: after `delete`, `fetch(FetchDescriptor<Plan>())` is empty.

### Step 3: `PlanFormModel`

`Hugo/Features/Planner/State/PlanFormModel.swift`:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class PlanFormModel {
    let day: CalendarDay
    var durationInSeconds: TimeInterval
    /// Only the hour and minute are used.
    var startTime: Date?
    var selectedTracker: Tracker?
    var isCategoryPickerPresented = false
    var isTimePickerPresented = false
    var validationMessage: String?

    private let preferredTrackerID: UUID?
    private let calendar: Calendar

    init(day: CalendarDay, plan: Plan? = nil, calendar: Calendar = .current) {
        self.day = day
        self.calendar = calendar
        self.durationInSeconds = plan?.duration ?? 0
        self.preferredTrackerID = plan?.categoryID
        self.startTime = plan?.startMinute.flatMap { minute in
            calendar.date(
                bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day.startDate(calendar: calendar))
        }
    }

    var isSaveDisabled: Bool {
        durationInSeconds <= 0 || selectedTracker == nil
    }

    var startMinute: Int? {
        startTime.map { calendar.component(.hour, from: $0) * 60 + calendar.component(.minute, from: $0) }
    }

    func reconcileSelection(with trackers: [Tracker]) {
        if let selectedTracker, trackers.contains(where: { $0.id == selectedTracker.id }) {
            return
        }
        selectedTracker =
            trackers.first(where: { $0.id == preferredTrackerID })
            ?? trackers.first(where: \.isDefault) ?? trackers.first
    }

    func draft() -> PlanDraft? {
        guard durationInSeconds > 0, let selectedTracker else {
            validationMessage = String(
                localized: "planner.plan.validation.invalid",
                defaultValue: "Choose a duration and a category.",
                comment: "Shown when a plan cannot be saved because the duration is zero or no category is chosen.")
            return nil
        }
        validationMessage = nil
        return PlanDraft(day: day, duration: durationInSeconds, startMinute: startMinute, tracker: selectedTracker)
    }
}
```

`PlanFormModelTests` (`@MainActor`, UTC calendar):
- A new form has duration 0, `isSaveDisabled == true`, and `draft()` returns nil
  and sets `validationMessage`.
- Editing a plan (2 h, start minute 630, tracker LDC) pre-fills the duration,
  `startMinute == 630`, and after `reconcileSelection(with: [fieldService(isDefault: true), ldc])`
  selects LDC.
- Clearing `startTime` gives `startMinute == nil` in the draft.

**Verify**: Focused tests → `** TEST SUCCEEDED **` with all three suites.

### Step 4: The plan form screen

`Hugo/Features/Planner/Screens/PlanFormView.swift`, built like `AddEntryView`:

- `init(day: CalendarDay, plan: Plan? = nil)` stores `plan` and creates
  `_form = State(initialValue: PlanFormModel(day: day, plan: plan))`.
- `@AppStorage(UserDefaultsKeys.durationMinuteInterval) private var durationMinuteInterval = 1`,
  `@Environment(\.dismiss)`, `@Environment(\.modelContext) private var context`,
  `@Query private var trackers: [Tracker]`, `@State private var isDeleteConfirmationShown = false`.
- `Form` sections, in order:
  1. `Section("entry.duration.label")` with `DurationWheelPicker(duration: $form.durationInSeconds, minuteInterval: durationMinuteInterval, maxDuration: 24 * 60 * 60)`.
  2. A category button identical to `AddEntryView`'s.
  3. A start-time button: `HStack { Text("planner.plan.startTime"); Spacer(); Text(time or "planner.plan.startTime.none").foregroundStyle(.secondary) }`,
     with `footer: { Text("planner.plan.startTime.footer") }`. Format the time
     with `.formatted(date: .omitted, time: .shortened)`.
  4. Only when editing: `Section { Button("planner.plan.delete", role: .destructive) { isDeleteConfirmationShown = true } }`.
- `.navigationTitle(plan == nil ? "planner.plan.add" : "planner.plan.edit")`, inline.
- Toolbar: the same cancel button as `AddEntryView`, and
  `Button("planner.plan.save", systemImage: "checkmark", action: save).buttonStyle(.glassProminent).tint(.hugoAccent).disabled(form.isSaveDisabled)`.
- Sheets: `CategoryPicker(selection: $form.selectedTracker).presentationDetents([.medium])`
  and `EntryTimePickerView(date: $form.startTime).presentationDetents([.height(HugoLayout.Size.addEntryCompactSheetHeight)])`.
- `.confirmationDialog("planner.plan.delete.confirm", isPresented: $isDeleteConfirmationShown, titleVisibility: .visible) { Button("planner.plan.delete", role: .destructive, action: delete) }`.
- `.errorAlert(message: $form.validationMessage)`, `.task { form.reconcileSelection(with: trackers) }`,
  `.onChange(of: trackers) { _, newTrackers in form.reconcileSelection(with: newTrackers) }`.
- `save()`: `guard let draft = form.draft() else { return }`, then
  `PlanService(context: context).add(draft)` or `.update(plan, with: draft)`;
  `dismiss()` on success; on error set `form.validationMessage = error.localizedDescription`.
- `delete()`: `PlanService(context: context).delete(plan)`, then `dismiss()`; same error handling.
- `#Preview { PlanFormView(day: CalendarDay(.now)).modelContainer(.preview) }`.

### Step 5: The plan card

`Hugo/Features/Planner/Views/PlannedItemRow.swift`: a card matching `EntryRow`'s
look (same padding, corner radius and light/dark background). Layout:
`HStack(spacing: HugoLayout.Spacing.spacious)` with
- a `Button(action: onEdit)` wrapping: category icon (`.title2`, frame
  `HugoLayout.Size.entryIcon`), then a `VStack(alignment: .leading)` with
  `Text(ServiceDurationFormatter.hoursString(from: item.duration))` (`.bold`) +
  `Text(item.categoryName)` (`.secondary`), and below them, when `item.startMinute`
  is set, a `Label` with `systemImage: "clock"` showing the start time in
  `.callout`/`.secondary`. `.buttonStyle(.plain)`. Accessibility: combine; label
  = category name; value = `ServiceDurationFormatter.accessibilityString(from:)`
  plus the start time; hint `"planner.plan.edit.hint"`.
- when `onLog` is non-nil, a trailing `Button("planner.plan.log", action: onLog).buttonStyle(.bordered).tint(.hugoAccent)`
  with `.accessibilityLabel(Text("planner.plan.log.a11y"))`.

Below that `HStack`, inside the same card, when `bar` is non-nil:
`PlannerBarShape(fraction: bar.fraction, color: <the item's color, as in PlannerBarView>)`
framed to full width and `height: HugoLayout.Size.calendarBarHeight`, `.accessibilityHidden(true)`; and when
`showsProgress` is true, a `.footnote`/`.secondary` line
`String(localized: "planner.plan.progress", defaultValue: "\(logged) of \(planned) logged", comment: ...)`
with both durations from `ServiceDurationFormatter.hoursString`. Add the same
sentence to the card's accessibility value.

Properties: `let item: PlannedItem`, `var bar: PlannerBar? = nil`,
`var showsProgress = false`, `let onEdit: () -> Void`, `var onLog: (() -> Void)? = nil`.
Do not nest the Log button inside the edit button's label.

### Step 6: The day sheet

`Hugo/Features/Planner/Screens/PlannerDaySheet.swift`:

```swift
struct PlannerDaySheet: View {
    let day: CalendarDay
    let today: Date

    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [Entry]
    @Query private var plans: [Plan]
    @Query private var trackers: [Tracker]

    @State private var isAddingPlan = false
    @State private var editingPlan: Plan?
    @State private var loggingItem: PlannedItem?
    @State private var isAddingEntry = false
    @State private var selectedEntry: Entry?

    init(day: CalendarDay, today: Date) {
        self.day = day
        self.today = today
        let range = day.dateRange()
        let start = range.lowerBound
        let end = range.upperBound
        _entries = Query(filter: #Predicate<Entry> { $0.date >= start && $0.date < end }, sort: \Entry.date)
        _plans = Query(filter: #Predicate<Plan> { $0.date >= start && $0.date < end }, sort: \Plan.createdAt)
    }
    ...
}
```

Body:
- `NavigationStack { ScrollView { VStack(alignment: .leading, spacing: HugoLayout.Spacing.section) { ... }.padding() } }`
  with `.background(Color(.systemGroupedBackground))`, title
  `Text(day.startDate(), format: .dateTime.weekday(.wide).day().month(.wide))` via
  `.navigationTitle(...)` (use `day.startDate().formatted(.dateTime.weekday(.wide).day().month(.wide))`),
  inline display mode, and a leading cancel toolbar button like `AddEntryView`'s.
- **Planned section**: header `Text("planner.legend.planned").font(.headline)`;
  `items` (below) as `PlannedItemRow`s, or `Text("planner.day.planned.empty")` in
  `.secondary`; then `Button("planner.plan.add", systemImage: "plus") { isAddingPlan = true }`
  with `.buttonStyle(.bordered)`.
- **Logged section**, only when `canLog`: header `Text("planner.legend.logged").font(.headline)`;
  `ForEach(entries) { EntryRow(entry: $0, selectedEntry: $selectedEntry) }`, or
  `Text("planner.day.logged.empty")` in `.secondary`; then
  `Button("entry.add.label", systemImage: "plus") { isAddingEntry = true }` with `.buttonStyle(.bordered)`.
- Helpers:

  ```swift
  private var canLog: Bool { day <= CalendarDay(today) }

  private var items: [PlannedItem] {
      plans.map { PlannedItem($0, trackers: trackers) }
          .sorted { ($0.startMinute ?? Int.max) < ($1.startMinute ?? Int.max) }
  }

  /// The day's bars, matched by plan 068's rules. Plan bars share the item's id.
  private var barsByID: [String: PlannerBar] {
      let plannerDay = PlannerDay.make(
          day: day, items: items, entries: entries, trackers: trackers, today: CalendarDay(today))
      return Dictionary(plannerDay.bars.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
  }
  ```

  Compute `let bars = barsByID` once at the top of `body`. For each item pass
  `bar: bars[item.id]`, `showsProgress: canLog`,
  `onEdit: { editingPlan = plans.first { $0.id.uuidString == item.id } }`, and
  `onLog: canLog && !(bars[item.id]?.isFull ?? false) ? { loggingItem = item } : nil`.
  Store the bar's remaining time when Log is tapped:
  `@State private var loggingSeconds: TimeInterval = 0`, set
  `loggingSeconds = bars[item.id]?.remainingSeconds ?? item.duration` before
  setting `loggingItem`.
- Sheets:
  - `.sheet(isPresented: $isAddingPlan) { PlanFormView(day: day) }`
  - `.sheet(item: $editingPlan) { PlanFormView(day: day, plan: $0) }`
  - `.sheet(item: $loggingItem) { item in AddEntryView(seededDate: day.midday(), seededDuration: (loggingSeconds / 60).rounded(.down) * 60, preferredTrackerID: item.trackerID, seededStartMinute: item.startMinute) }`
  - `.sheet(isPresented: $isAddingEntry) { AddEntryView(seededDate: day.midday()) }`
  - `.sheet(item: $selectedEntry) { EntryDetailView(entry: $0).presentationDetents([.medium, .large]) }`
- `#Preview { PlannerDaySheet(day: CalendarDay(.now), today: .now).modelContainer(.preview) }`.

### Step 7: Make days tappable

1. `PlannerCalendarGrid`: add `var onSelect: ((CalendarDay) -> Void)? = nil`.
   Wrap each `PlannerDayCell(day: day)` in
   `Button { onSelect?(day.id) } label: { PlannerDayCell(day: day) }.buttonStyle(.plain).disabled(onSelect == nil)`.
2. `PlannerDayCell`: add `.accessibilityHint(Text("planner.day.a11y.hint"))` and
   `.accessibilityAddTraits(.isButton)`.
3. `PlannerMonthPage`: add `@State private var selectedDay: CalendarDay?`, pass
   `onSelect: { selectedDay = $0 }` to the grid, and add
   `.sheet(item: $selectedDay) { PlannerDaySheet(day: $0, today: today).presentationDetents([.medium, .large]) }`.

### Step 8: Strings

Add to `Hugo/Resources/Localizable.xcstrings` (same format as plan 069 Step 9):

| Key | English | Danish |
|---|---|---|
| `planner.plan.add` | Add Plan | Tilføj plan |
| `planner.plan.edit` | Edit Plan | Rediger plan |
| `planner.plan.edit.hint` | Opens the plan | Åbner planen |
| `planner.plan.save` | Save | Gem |
| `planner.plan.delete` | Delete Plan | Slet plan |
| `planner.plan.delete.confirm` | Delete this plan? | Slet denne plan? |
| `planner.plan.log` | Log | Registrér |
| `planner.plan.log.a11y` | Log this plan as an entry | Registrér planen som udført tid |
| `planner.plan.startTime` | Start Time | Starttidspunkt |
| `planner.plan.startTime.none` | None | Intet |
| `planner.plan.startTime.footer` | Optional. Shown on the day only. | Valgfrit. Vises kun på dagen. |
| `planner.plan.validation.invalid` | Choose a duration and a category. | Vælg en varighed og en kategori. |
| `planner.day.planned.empty` | Nothing planned for this day. | Intet planlagt for denne dag. |
| `planner.day.logged.empty` | Nothing logged on this day. | Intet udført på denne dag. |
| `planner.day.a11y.hint` | Opens the day | Åbner dagen |
| `planner.plan.progress` | %1$@ of %2$@ logged | %1$@ af %2$@ udført |

**Verify**: JSON check prints nothing; every key above has `en` and `da`.

### Step 9: Full gate

**Verify**: `Scripts/verify.sh` → exit 0.

## Test plan

- `AddEntryFormModelTests`: two new tests (Step 1); all existing tests still pass.
- `PlanServiceTests`: three tests (Step 2).
- `PlanFormModelTests`: three tests (Step 3).
- Manual (owner): tap today, add a 2-hour Field Service plan at 10:00, see an
  empty outlined bar; tap Log, change the duration to 1 hour, save: the bar is
  half full in the sheet and on the calendar, and the card says "1 hour of
  2 hours logged". Tap Log again: the form suggests 1 hour. Save: the bar is
  full and the Log button disappears.
  Tap a future day: no Logged section. Edit and delete a plan. Check with
  VoiceOver and at the largest Dynamic Type size. Check a second device after
  sync shows the same plans.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -n "seededDuration" Hugo/Features/Entries/Screens/AddEntryView.swift` → at least one match
- [ ] `grep -rn "context.insert\|context.delete" Hugo/Features/Planner` → matches only in `Services/PlanService.swift`
- [ ] All 16 string keys exist with `en` and `da`
- [ ] `grep -n "uncovered" Hugo/Features/Planner/Screens/PlannerDaySheet.swift` → no matches (bars decide Log)
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- Plans 067-069 are not DONE.
- An existing `AddEntryFormModelTests` test fails after Step 1.
- Stacked sheets (day sheet → plan form → category picker) do not present in
  the simulator. Report it; do not replace sheets with navigation pushes on your own.
- `Plan` does not conform to `Identifiable` for `.sheet(item:)` (SwiftData
  models normally do). Report; do not add a wrapper type.
- You need to change `EntryRow`, `EntryDetailView` or `CategoryPicker`.

## Maintenance notes

- Repeating plans (future) will show occurrences as `PlannedItem`s that have no
  `Plan` row. `onEdit` then needs a second path ("edit this occurrence" or
  "edit the series"). The `plans.first { $0.id.uuidString == item.id }` lookup is
  the place to branch.
- Logging deliberately keeps the plan. A plan's "done" state is its full bar,
  derived from logged time; never add a stored done flag.
- Planned follow-up (owner idea, not in v1): suggestion pills in `AddEntryView`
  for the chosen day's plans that are not full, using the same
  `seededDuration`/`preferredTrackerID`/`seededStartMinute` values this plan
  adds. Future entry presets would be a second source of the same pills. See
  the Planner notes in `plans/README.md`.
- `EntryRow` shows durations as "02:00" while plan cards say "2 hours". That
  mismatch predates this plan (it is in the 2026-10-12 audit's open
  accessibility findings); fix it everywhere at once, not here.
- Review focus: every plan write goes through `PlanService`, and the seeded
  `AddEntryView` still saves only when the user taps Add.
