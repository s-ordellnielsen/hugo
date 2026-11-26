# Plan 166: Context menus on entries and Planner days

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 16b697c..HEAD -- Hugo/Features/Entries Hugo/Features/Overview/Views/OverviewListView.swift Hugo/Features/ServiceYear/Views/MonthEntriesSection.swift Hugo/Features/Planner`
> This is the first plan of the batch (166–173), so the baseline stays `16b697c`. Expected: no output. STOP on any output.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit, under `planner.target.*`). Never stage that file with
> `git add`. See Step 5 for the strings.

## Status

- **Priority**: P2
- **Effort**: M + owner
- **Risk**: LOW to MEDIUM. Context menus only add a way to reach actions that exist today. The risk is in presentation: the Duplicate sheet and the delete confirmation are presented from rows that can sit inside a Planner day popover (plan 160), and the Planner day cell now has both a tap popover and a long-press menu.
- **Depends on**: none (plans 159–163 are in place)
- **Category**: ux
- **Planned at**: commit `16b697c`, 2026-11-26
- **Issue**: [SLN-347](https://linear.app/sebastianln/issue/SLN-347)

## Why this matters

Hugo has one context menu today (the Service Year month card: Add Entry and
Submit). On iPad with a trackpad, right-click is expected everywhere, and on
iPhone a long press is the standard shortcut. Today the only way to delete an
entry is to open it and use its More menu, and there is no way to repeat an
entry ("I did the same two hours of field service as yesterday") except typing
it again.

After this plan:

- **Entries** (Overview, both list styles; a Planner day's logged entries; a
  month's details in Service Year) have a context menu with **Edit**,
  **Duplicate** and **Delete Entry**.
  - Edit opens what tapping opens. It is left out in a month's details, where
    the row is a `NavigationLink` (see Decisions).
  - Duplicate opens Add Entry filled with the entry's duration, category and
    start time, dated today. The user checks it and taps Add.
  - Delete Entry asks for the same confirmation as the entry's own More menu.
- **Planner days** have a context menu with **Add Plan** (today and later) and
  **Log Time** (today and earlier). Both open in the day's popover (plan 160),
  so the result looks the same as tapping.

The same menus appear on iPhone with a long press.

## Decisions (owner can override)

1. **Duplicate opens Add Entry instead of copying at once.** An instant copy
   would add an entry dated in the past (the original's date) or silently dated
   today, and a mistaken tap would add time to the report without the user
   seeing a form. Opening the filled form costs one tap (Add) and shows exactly
   what will be saved. Bible studies are not copied: they belong to a specific
   conversation and are usually different.
2. **No Edit item in a month's details.** Those rows are
   `NavigationLink(destination:)` rows inside a pushed `List`. Opening them from
   a menu needs value-based navigation, and that kind of change caused the
   iPad navigation problems reverted on 2026-11-23. The row itself still opens
   on tap.
3. **No "Copy plans to another day".** It needs a day chooser and a new
   service, for a task that plan 170 (drag a plan to another day) covers more
   directly. Simplicity first.
4. **Carried-in entries get no menu.** None of the rows that get the menu
   show carried-in entries (each list filters them out, see Current state),
   and they cannot be edited anyway.

## Current state

### Entries

`Hugo/Features/Entries/Views/EntryRow.swift` (Overview, "by entry" style) is a
`Button` that sets `selectedEntry = entry`; its label is a card:

```swift
var body: some View {
    Button {
        selectedEntry = entry
    } label: {
        HStack(spacing: HugoLayout.Spacing.spacious) {
            ...
        }
        .padding(.vertical, HugoLayout.Spacing.card)
        .padding(.horizontal, HugoLayout.Spacing.card)
        .background(...)
        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Text(category.name))
    .accessibilityValue(accessibilityValue)
    .buttonStyle(.plain)
}
```

`Hugo/Features/Overview/Views/OverviewListView.swift` uses `EntryRow` in
`OverviewEntryList`, and has a private `DateEntryRow` inside `OverviewDateList`
(the "by date" style):

```swift
private struct DateEntryRow: View {
    var entry: Entry
    @Binding var selectedEntry: Entry?

    var body: some View {
        let category = entry.resolvedCategory()
        Button {
            selectedEntry = entry
        } label: {
            HStack { ... }
            .padding(.vertical, HugoLayout.Spacing.small / 2)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(...)
        .accessibilityValue(...)
    }
}
```

`OverviewListView` presents `EntryDetailView` for `selectedEntry` as a sheet.
It passes only `groups.regular` (no carried-in entries) to both lists.

`Hugo/Features/Planner/Views/PlannerLoggedEntryList.swift` (inside
`PlannerDaySheet`, which plan 160 shows in a popover on iPad) has
`let onSelect: (Entry) -> Void` and rows built by `private func row(_ entry: Entry) -> some View`:

```swift
return Button {
    onSelect(entry)
} label: {
    HStack(spacing: HugoLayout.Spacing.regular) { ... }
    .font(.callout)
    .padding(.vertical, HugoLayout.Spacing.regular)
    .padding(.horizontal, HugoLayout.Spacing.spacious)
    .contentShape(.rect)
}
.buttonStyle(.plain)
.accessibilityElement(children: .combine)
.accessibilityLabel(Text(category.name))
.accessibilityValue(Text(ServiceDurationFormatter.accessibilityString(from: entry.duration)))
```

`PlannerDaySheet` passes `loggedEntries`, which is `entries.filter { !$0.isCarriedIn }`.

`Hugo/Features/ServiceYear/Views/MonthEntriesSection.swift`:

```swift
ForEach(logged) { entry in
    NavigationLink(destination: EntryDetailView(entry: entry)) {
        entryRow(entry)
    }
    .swipeActions {
        Button("entry.delete.label", systemImage: "trash", role: .destructive) {
            delete(entry)
        }
    }
}
```

(`logged` is `entries.filter { !$0.isCarriedIn }`.)

`Hugo/Features/Entries/Screens/EntryDetailView.swift` deletes like this, which
the menu must match:

```swift
Button("entry.delete.label", systemImage: "trash", role: .destructive) {
    deleteConfirmationShown = true
}
...
.confirmationDialog(
    "entry.delete.confirmation.label",
    isPresented: $deleteConfirmationShown
) {
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
...
.errorAlert(message: $deletionError)
```

`Hugo/Features/Entries/Screens/AddEntryView.swift`:

```swift
init(
    seededDate: Date? = nil,
    seededDuration: TimeInterval? = nil,
    preferredTrackerID: UUID? = nil,
    seededStartMinute: Int? = nil
)
```

Its `AddEntryFormModel` uses `calendar.startOfDay(for: seededDate ?? now)` as
the date, so `seededDate: nil` means today. `preferredTrackerID` selects that
category if it still exists, otherwise the default category. The date picker
allows only `...Date.now`, so Add Entry must never be seeded with a future day.
`Entry.tracker` is optional (`Tracker?`), and `Tracker.id` is a `UUID`.

### Planner days

`Hugo/Features/Planner/Views/PlannerCalendarGrid.swift` (after plan 160):

```swift
struct PlannerCalendarGrid<DayPopover: View>: View {
    let month: PlannerMonth
    var onSelect: ((CalendarDay) -> Void)? = nil
    var presentedDay: Binding<CalendarDay?> = .constant(nil)
    @ViewBuilder var dayPopover: (CalendarDay) -> DayPopover
    ...
                ForEach(month.days) { day in
                    Button {
                        onSelect?(day.id)
                    } label: {
                        PlannerDayCell(day: day)
                    }
                    .buttonStyle(.plain)
                    .disabled(onSelect == nil)
                    .popover(isPresented: isPresented(day.id)) {
                        dayPopover(day.id)
                    }
                }
```

plus `extension PlannerCalendarGrid where DayPopover == EmptyView { init(month:onSelect:) }`.

`Hugo/Features/Planner/Views/PlannerMonthPage.swift` (after plan 160) owns
`@State private var presentedDay: CalendarDay?` and
`@State private var popoverDestination: PlannerDayDestination = .daySheet`,
calls `PlannerCalendarGrid(month: plannerMonth, onSelect: select, presentedDay: $presentedDay) { day in dayPopover(for: day) }`, and:

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

`Hugo/Features/Planner/Domain/PlannerDayDestination.swift`:

```swift
/// What tapping a Planner day opens. ...
nonisolated enum PlannerDayDestination: Equatable, Sendable {
    case daySheet
    case addPlan

    init(day: PlannerDay) {
        self = day.bars.isEmpty && !day.isPast ? .addPlan : .daySheet
    }
}
```

`PlannerDay` (`Hugo/Features/Planner/Domain/PlannerMonth.swift`) has
`let isToday: Bool` and `let isPast: Bool` (`day < today`), and `id: CalendarDay`.
`CalendarDay.startDate(calendar:)` returns the day's first moment.
`PlannerDayCell` makes its label one accessibility element
(`.accessibilityElement(children: .ignore)` with a label, value, hint
"Opens the day" and `.isButton`).

The only existing context menu is in `ServiceYearMonthRow.swift`, which is the
pattern to follow:

```swift
.contentShape(.contextMenuPreview, .rect(cornerRadius: HugoLayout.CornerRadius.card))
.contextMenu {
    quickActions
}
```

### Strings

Existing keys to reuse: `entry.delete.label` ("Delete Entry" / "Slet fra
rapport"), `entry.delete.confirmation.label`, `entry.delete.confirmation.action`,
`entry.delete.confirmation.message`, `planner.plan.add` ("Add Plan" / "Tilføj
plan"). New keys (Step 5): `entry.action.edit`, `entry.action.duplicate`,
`planner.day.action.logTime`.

Rules from `AGENTS.md` that apply: logic in `nonisolated` Domain types with
Swift Testing tests mirroring the source path; views stay visual; a view used
by several features but naming `Entry` belongs to the Entries feature, not
`DesignSystem`; get a category with `entry.resolvedCategory()`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `xcrun swift-format lint --strict <files>` | exit 0 |
| Format fix | `xcrun swift-format format -i <files>` | then re-run lint; use when `lint --strict` fails on formatting only |

Run `Scripts/verify.sh` as `sh -c 'Scripts/verify.sh; echo "VERIFY_EXIT=$?"'`
and read the `VERIFY_EXIT=` line. Tests before this plan: 653.

## Scope

**In scope**:

- `Hugo/Features/Entries/Domain/EntryDuplicateSeed.swift` (create)
- `HugoTests/Features/Entries/Domain/EntryDuplicateSeedTests.swift` (create)
- `Hugo/Features/Entries/Views/EntryContextMenu.swift` (create)
- `Hugo/Features/Entries/Views/EntryRow.swift`
- `Hugo/Features/Overview/Views/OverviewListView.swift` (`DateEntryRow` only)
- `Hugo/Features/Planner/Views/PlannerLoggedEntryList.swift`
- `Hugo/Features/ServiceYear/Views/MonthEntriesSection.swift`
- `Hugo/Features/Planner/Domain/PlannerDayDestination.swift`
- `Hugo/Features/Planner/Domain/PlannerDayActions.swift` (create)
- `HugoTests/Features/Planner/Domain/PlannerDayActionsTests.swift` (create)
- `Hugo/Features/Planner/Views/PlannerCalendarGrid.swift`
- `Hugo/Features/Planner/Views/PlannerMonthPage.swift`
- `Hugo/Resources/Localizable.xcstrings` (three keys, staged by script only)

**Out of scope**:

- `EntryDetailView`, `AddEntryView`, `AddEntryFormModel`, `PlanFormView`, `PlannerDaySheet`, `PlannerDayCell`.
- The Service Year month card's existing context menu.
- Plans (the cards inside a day): no context menu on them in this plan.
- Hover effects (plan 167), drag and drop (plans 170 and 171), arrow keys (plan 172).

## Git workflow

- Work on `main`. Commit per step with the messages given. Do not push.
- Stage files by explicit path. Never `git add -A`, `git add .` or `git add Hugo/Resources/Localizable.xcstrings`.

## Steps

**Note on strings.** Steps 2 to 4 use the keys `entry.action.edit`,
`entry.action.duplicate` and `planner.day.action.logTime`, which Step 5 adds.
That is fine: a key missing from the catalog shows as its own name at runtime
only until Step 5. If a build added any of the three keys to the working
catalog on its own, the Step 5 script's `key already present` assertion fails:
STOP and report.

### Step 1: The duplicate seed, with tests

Create `Hugo/Features/Entries/Domain/EntryDuplicateSeed.swift`:

```swift
import Foundation

/// What Duplicate fills Add Entry with: the entry's duration, category and
/// start time. The date is left to Add Entry, which uses today, and Bible
/// studies are not copied, since they belong to one conversation.
nonisolated struct EntryDuplicateSeed: Equatable, Identifiable, Sendable {
    /// Lets a sheet present the seed. Not part of equality.
    let id = UUID()
    let duration: TimeInterval
    let categoryID: UUID?
    /// Minutes after midnight of the entry's start, in `calendar`'s time zone.
    let startMinute: Int

    init(entryDate: Date, duration: TimeInterval, categoryID: UUID?, calendar: Calendar = .current) {
        self.duration = max(0, duration)
        self.categoryID = categoryID
        let parts = calendar.dateComponents([.hour, .minute], from: entryDate)
        self.startMinute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.duration == rhs.duration && lhs.categoryID == rhs.categoryID && lhs.startMinute == rhs.startMinute
    }
}
```

If the compiler warns that `let id = UUID()` will not be decoded or similar, ignore
it (the type is not `Codable`). If it rejects the stored `let` with a default
in a `nonisolated` struct, write `let id: UUID` and set `self.id = UUID()` in `init`.

Create `HugoTests/Features/Entries/Domain/EntryDuplicateSeedTests.swift`
(`import Foundation`, `import Testing`, `@testable import Hugo`, a `struct`),
with a fixed UTC Gregorian calendar as in `ReportComposerTests`:

1. `copiesDurationAndCategory`: duration 5_400, a fixed `UUID()` → same values.
2. `startMinuteComesFromTheEntryTime`: entry at 2026-11-20 14:35 UTC → `875`.
3. `midnightIsMinuteZero`: entry at 2026-11-20 00:00 UTC → `0`.
4. `negativeDurationBecomesZero`: duration -60 → `0`.
5. `missingCategoryStaysNil`: `categoryID: nil` → `nil`.

**Verify**: lint both files; `Scripts/verify.sh` → `VERIFY_EXIT=0`, 658 tests.
Commit `feat(entries): add the seed for duplicating an entry`.

### Step 2: The entry context menu

Create `Hugo/Features/Entries/Views/EntryContextMenu.swift`:

```swift
import SwiftData
import SwiftUI

extension View {
    /// Edit, Duplicate and Delete Entry on long press or right-click. Edit runs
    /// `onEdit` and is left out when it is nil. Duplicate opens Add Entry filled
    /// from the entry, dated today. Delete asks for the same confirmation as the
    /// entry's own More menu. Do not use it on carried-in entries.
    func entryContextMenu(_ entry: Entry, onEdit: (() -> Void)? = nil) -> some View {
        modifier(EntryContextMenu(entry: entry, onEdit: onEdit))
    }
}

private struct EntryContextMenu: ViewModifier {
    @Environment(\.modelContext) private var context

    let entry: Entry
    let onEdit: (() -> Void)?

    @State private var duplicateSeed: EntryDuplicateSeed?
    @State private var isConfirmingDelete = false
    @State private var deletionError: String?

    func body(content: Content) -> some View {
        content
            .contextMenu {
                if let onEdit {
                    Button("entry.action.edit", systemImage: "pencil", action: onEdit)
                }
                Button("entry.action.duplicate", systemImage: "plus.square.on.square") {
                    duplicateSeed = EntryDuplicateSeed(
                        entryDate: entry.date, duration: entry.duration, categoryID: entry.tracker?.id)
                }
                Divider()
                Button("entry.delete.label", systemImage: "trash", role: .destructive) {
                    isConfirmingDelete = true
                }
            }
            .confirmationDialog(
                "entry.delete.confirmation.label",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("entry.delete.confirmation.action", role: .destructive, action: delete)
            } message: {
                Text("entry.delete.confirmation.message")
            }
            .sheet(item: $duplicateSeed) { seed in
                AddEntryView(
                    seededDuration: seed.duration,
                    preferredTrackerID: seed.categoryID,
                    seededStartMinute: seed.startMinute)
            }
            .errorAlert(message: $deletionError)
    }

    private func delete() {
        do {
            try context.performIsolatedChange { context.delete(entry) }
        } catch {
            deletionError = error.localizedDescription
        }
    }
}
```

**Verify**: lint; `Scripts/verify.sh` → `VERIFY_EXIT=0`, 658 tests.
Commit `feat(entries): add an entry context menu`.

### Step 3: Use it on the entry rows

- `EntryRow.swift`: after `.buttonStyle(.plain)` add, in this order:
  ```swift
  .contentShape(.contextMenuPreview, .rect(cornerRadius: HugoLayout.CornerRadius.card))
  .entryContextMenu(entry) { selectedEntry = entry }
  ```
- `OverviewListView.swift`, `DateEntryRow`: after the last accessibility modifier add
  `.entryContextMenu(entry) { selectedEntry = entry }`.
- `PlannerLoggedEntryList.swift`, `row(_:)`: after the last accessibility modifier add
  `.entryContextMenu(entry) { onSelect(entry) }`.
- `MonthEntriesSection.swift`: on the `NavigationLink`, after `.swipeActions { ... }`, add
  `.entryContextMenu(entry)` (no Edit, see Decision 2). Keep the swipe action as it is.

**Verify**: lint the four files; `Scripts/verify.sh` → `VERIFY_EXIT=0`, 658 tests.
Commit `feat: add Edit, Duplicate and Delete to entry context menus`.

### Step 4: Planner day menu

**4a. Which actions a day offers.** Create
`Hugo/Features/Planner/Domain/PlannerDayActions.swift`:

```swift
/// The context-menu actions of a Planner day. Plans belong to today and later;
/// logged time belongs to today and earlier, since Add Entry cannot date an
/// entry in the future.
nonisolated struct PlannerDayActions: Equatable, Sendable {
    let canAddPlan: Bool
    let canLogTime: Bool

    init(day: PlannerDay) {
        canAddPlan = !day.isPast
        canLogTime = day.isPast || day.isToday
    }
}
```

Create `HugoTests/Features/Planner/Domain/PlannerDayActionsTests.swift`. Build
days with `PlannerMonth.make(...)` exactly as `PlannerDayDestinationTests` does
(copy its helper and its fixed `now` of 2026-11-03 12:00 UTC):

1. `pastDayOffersLogTimeOnly`: 2026-11-01 → `canAddPlan == false`, `canLogTime == true`.
2. `todayOffersBoth`: 2026-11-03 → both true.
3. `futureDayOffersAddPlanOnly`: 2026-11-10 → `canAddPlan == true`, `canLogTime == false`.

**4b. A destination for Log Time.** In `PlannerDayDestination.swift`, add a case
and update the doc comment's first sentence:

```swift
/// What a Planner day opens. Tapping a day with no plans and no logged entries
/// goes straight to Add Plan, unless it is in the past ...; every other tap opens
/// the day sheet. `logTime` is only reached from the day's context menu.
nonisolated enum PlannerDayDestination: Equatable, Sendable {
    case daySheet
    case addPlan
    /// Add Entry dated that day. Never returned by `init(day:)`.
    case logTime
    ...
```

Leave `init(day:)` unchanged.

**4c. The grid shows the menu.** In `PlannerCalendarGrid.swift`, add two properties
after `onSelect` (and before `presentedDay`). The stored properties are then,
in this order: `month`, `onSelect`, `onAddPlan`, `onLogTime`, `presentedDay`,
and the trailing `dayPopover` closure. Later plans add `onDropPlans` (170) and
`keyboardDay` (172) between `presentedDay` and `dayPopover`.

```swift
/// Context-menu actions. Nil hides the item.
var onAddPlan: ((CalendarDay) -> Void)? = nil
var onLogTime: ((CalendarDay) -> Void)? = nil
```

and, on each day's `Button`, after `.disabled(onSelect == nil)` and before `.popover`:

```swift
.contentShape(.contextMenuPreview, .rect(cornerRadius: HugoLayout.Spacing.regular))
.contextMenu {
    let actions = PlannerDayActions(day: day)
    if actions.canAddPlan, let onAddPlan {
        Button("planner.plan.add", systemImage: "calendar.badge.plus") { onAddPlan(day.id) }
    }
    if actions.canLogTime, let onLogTime {
        Button("planner.day.action.logTime", systemImage: "plus.circle") { onLogTime(day.id) }
    }
}
```

After this step the day `Button`'s modifier chain is, in this order:
`.buttonStyle(.plain)`, `.disabled(onSelect == nil)`, `.contentShape(.contextMenuPreview, ...)`,
`.contextMenu { ... }`, `.popover(...)`. Later plans insert their lines between
`.contextMenu` and `.popover` (167 hover, 170 drop target, 172 keyboard ring).

The memberwise initializer gains the two parameters (with defaults). Keep the
`EmptyView` extension compiling (it does not pass them, and it still calls
`self.init(month: month, onSelect: onSelect, presentedDay: .constant(nil)) { _ in EmptyView() }`). If the memberwise
initializer no longer accepts the trailing `dayPopover` closure after the new
defaulted properties, write an explicit
`init(month:onSelect:onAddPlan:onLogTime:presentedDay:dayPopover:)` and note it.

**4d. The month page opens them in the day's popover.** In `PlannerMonthPage.swift`:

- The grid call becomes, in full (argument order matters: it follows the
  property order above):
  ```swift
  PlannerCalendarGrid(
      month: plannerMonth, onSelect: select,
      onAddPlan: { open($0, .addPlan) }, onLogTime: { open($0, .logTime) },
      presentedDay: $presentedDay
  ) { day in
      dayPopover(for: day)
  }
  ```
- Add:
  ```swift
  /// Opens `destination` in the day's popover, as a tap would.
  private func open(_ day: CalendarDay, _ destination: PlannerDayDestination) {
      popoverDestination = destination
      presentedDay = day
  }
  ```
- Replace the whole body of `dayPopover(for:)` (keep its `@ViewBuilder`
  attribute and signature) with a `switch` over all three cases:
  ```swift
  @ViewBuilder
  private func dayPopover(for day: CalendarDay) -> some View {
      switch popoverDestination {
      case .addPlan:
          PlanFormView(day: day)
              .popoverContentSize()
      case .logTime:
          AddEntryView(seededDate: day.startDate())
              .popoverContentSize()
      case .daySheet:
          PlannerDaySheet(day: day, today: today)
              .presentationDetents([.medium, .large])
              .popoverContentSize()
      }
  }
  ```

**Verify**: lint the five files; `Scripts/verify.sh` → `VERIFY_EXIT=0`, 661 tests
(658 + 3). `grep -rn "PlannerDayDestination" Hugo` shows no `switch` that now
fails to cover `.logTime` (the build would fail; this is a reminder).
Commit `feat(planner): add Add Plan and Log Time to the day context menu`.

### Step 5: Strings

Run this from the repo root. It inserts the keys in alphabetical position in the
working file and stages the committed version of the file plus only these keys:

```sh
python3 - <<'EOF'
import subprocess
path = 'Hugo/Resources/Localizable.xcstrings'
def key(name, comment, en, da):
    return f'''    "{name}" : {{
      "comment" : "{comment}",
      "localizations" : {{
        "da" : {{
          "stringUnit" : {{
            "state" : "translated",
            "value" : "{da}"
          }}
        }},
        "en" : {{
          "stringUnit" : {{
            "state" : "translated",
            "value" : "{en}"
          }}
        }}
      }}
    }},
'''
inserts = [
    ('    "entry.action.tracker.change" : {\n',
     key('entry.action.duplicate', 'Context-menu item on an entry. Opens Add Entry filled with the entry, dated today.', 'Duplicate', 'Dupliker')
     + key('entry.action.edit', 'Context-menu item on an entry. Opens the entry.', 'Edit', 'Rediger')),
    ('    "planner.day.logged.header" : {\n',
     key('planner.day.action.logTime', 'Context-menu item on a Planner day (today or earlier). Opens Add Entry dated that day.', 'Log Time', 'Registrér tid')),
]
def insert(text):
    for anchor, block in inserts:
        assert text.count(anchor) == 1, 'anchor not found once: ' + anchor
        assert block.split('"')[1] not in text, 'key already present'
        text = text.replace(anchor, block + anchor, 1)
    return text
work = open(path, encoding='utf-8').read()
open(path, 'w', encoding='utf-8').write(insert(work))
head = subprocess.run(['git', 'show', 'HEAD:' + path], capture_output=True, text=True, check=True).stdout
blob = subprocess.run(['git', 'hash-object', '-w', '--stdin'], input=insert(head),
                      capture_output=True, text=True, check=True).stdout.strip()
subprocess.run(['git', 'update-index', '--cacheinfo', '100644,' + blob + ',' + path], check=True)
EOF
```

**Verify**: `git diff --cached Hugo/Resources/Localizable.xcstrings | grep -c '^+'`
prints 52 (3 keys × 17 lines, plus the `+++` header line);
`git diff Hugo/Resources/Localizable.xcstrings` still shows the owner's
`planner.target` hunks. `Scripts/verify.sh` → `VERIFY_EXIT=0`, 661 tests.
Never run `git add` on the catalog. Commit `feat: add context-menu strings`.

## Test plan

- `EntryDuplicateSeedTests` (5) and `PlannerDayActionsTests` (3).
- Menus, sheets and the confirmation are checked by the owner.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, 661 tests
- [ ] Four entry row types use `.entryContextMenu`; `MonthEntriesSection` passes no `onEdit`
- [ ] The Planner grid shows the day menu; `PlannerMonthPage` opens both actions in the day popover
- [ ] The catalog commit holds only the three new keys; the owner's edits are still unstaged
- [ ] `plans/README.md` row updated

Owner check on the iPad (Sean) (right-click with a trackpad, and long press), English and Danish:

1. Overview, both list styles: right-click an entry → Edit opens it; Duplicate opens Add Entry with the same duration, category and start time, dated today; Delete Entry asks first, and Cancel keeps the entry.
2. A Planner day with logged time: open it, then right-click a logged entry → same three items; Duplicate opens on top of the day popover.
3. A month's details in Service Year: right-click an entry → Duplicate and Delete Entry only; tapping still opens the entry; swipe to delete still works.
4. Planner: right-click a past day → Log Time only; today → Add Plan and Log Time; a future day → Add Plan only. Each opens in the day's popover. Tapping a day still opens the popover as before.
5. VoiceOver on: on an entry row and a Planner day, the rotor's Actions include the menu ("Show Context Menu" or the items). Report what VoiceOver offers.

Owner check on the iPhone (Mona): long press shows the same menus; everything opens as a sheet.

## STOP conditions

Stop and report if:

- The drift check shows changes beyond the expected ones.
- Any of the four entry lists includes carried-in entries (check that each still filters with `!isCarriedIn` or `groups.regular`).
- The context menu on a Planner day stops tapping from opening the popover, or long press opens the popover.
- A sheet or confirmation presented from inside the day popover closes the popover or does not appear.
- The catalog script's assertions fail or the cached diff is not exactly the three keys.

## Maintenance notes

- Plans 167 (hover), 168 (two columns), 170 (drag a plan) and 172 (arrow keys) also change `PlannerCalendarGrid` and `PlannerMonthPage`. The final day-cell modifier chain, after all of them: `.buttonStyle(.plain)`, `.disabled(onSelect == nil)`, `.contentShape(.contextMenuPreview, ...)`, `.contextMenu`, `.contentShape(.hoverEffect, ...)`, `.hoverEffect(.highlight)`, `.background { drop target }`, `.dropDestination`, `.overlay { keyboard ring }`, `.popover`. The final stored-property order: `month`, `onSelect`, `onAddPlan`, `onLogTime`, `presentedDay`, `onDropPlans`, `keyboardDay`, `dayPopover`. A drag source (170) and a context menu can live on the same view; long press then lifts for both.
- Plan 167 adds hover effects to the same rows; it uses `.contentShape(.hoverEffect, ...)`, which does not replace the `.contextMenuPreview` shape added here.
- SLN-217 (undo for destructive actions) would cover Delete Entry from the menu too.
- If plans ever get a context menu, reuse `PlannerDayActions` for what a day allows.
