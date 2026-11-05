# Plan 074: Make the Planner day sheet about plans, and fill Add Entry when logging a plan

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat ddc2964..HEAD -- Hugo/Features/Planner HugoTests/Features/Planner Hugo/Resources/Localizable.xcstrings CONTEXT.md`
> Expected: no output. If any file is listed, compare the "Current state"
> excerpts below with the live code; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW (one screen and one new value type; no schema or data changes)
- **Depends on**: plans/070-planner-day-sheet.md (DONE, commits `4cf4a80`, `ddc2964`)
- **Category**: bug + direction (owner feedback after testing 070)
- **Planned at**: commit `ddc2964`, 2026-11-05
- **Issue**: [SLN-277](https://linear.app/sebastianln/issue/SLN-277)

## Why this matters

The owner tested the day sheet from plan 070 and found four problems:

1. **Layout bug.** On a day with no plans and no entries, the sheet's content
   shrinks to the width of one short line and sits in the middle, with the
   sheet's see-through glass showing on both sides. A `ScrollView` in this app
   takes the width of its content; `OverviewView` and `PlannerMonthPage` stretch
   theirs with `.frame(maxWidth: .infinity)`, the day sheet does not.
2. **Wrong focus.** The sheet is for planning, but logged entries get the same
   large cards and the same weight as plans. Entries should stay visible but
   look smaller and secondary.
3. **Buttons in the sections feel out of place.** The owner decided: one **+**
   in the navigation bar that adds a plan, and **no** general "Add Entry" in the
   day sheet. Planned time is logged with each plan's Log button; unplanned
   time is logged from the Overview, where most logging already happens.
4. **Log does not fill in the duration.** Tapping Log opens Add Entry with the
   right category and start time but a duration of 00:00 (confirmed by the
   owner). Cause: the remaining time is kept in a separate `@State var
   loggingSeconds` that the view's `body` never reads; SwiftUI gives the sheet
   closure the old value (0) on first presentation. The fix puts every value
   Add Entry needs into one value, `PlanLogSeed`, and uses that value as the
   sheet's item, so nothing can go stale.

## Owner decisions (do not change)

- Toolbar: leading close button (as today), trailing **+** button that opens
  the plan form. No other toolbar buttons. No buttons inside the sections.
- No "Add Entry" anywhere in the day sheet. The only way to log from the
  Planner is a plan's **Log** button.
- Plan cards (`PlannedItemRow`) keep their current design, unchanged.
- The "Planned" section header goes away: plans are the main content.
- Logged entries: shown only when the day has entries, under a small header
  "Logged · 1 hour" (the day's logged total), as compact one-line rows (icon,
  category name, duration in words, chevron) inside one rounded box. Tapping a
  row still opens `EntryDetailView`.
- Empty day text: "Nothing planned yet. Tap + to add a plan."

Target layout (medium sheet):

```
 ✕     Wednesday, 5 November      +
┌───────────────────────────────────┐
│ ⛺ 2 hours                 [ Log ] │
│    Field Service                  │
│    🕙 10:00                        │
│ ▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░  │
│ 1 hour of 2 hours logged          │
└───────────────────────────────────┘

Logged · 1 hour
┌───────────────────────────────────┐
│ ⛺ Field Service          1 hour › │
└───────────────────────────────────┘
```

## Current state

Files (all compile and pass `Scripts/verify.sh` at `ddc2964`):

- `Hugo/Features/Planner/Screens/PlannerDaySheet.swift`: the day sheet (the only screen this plan rewrites). Today:

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
      @State private var loggingSeconds: TimeInterval = 0
      @State private var isAddingEntry = false
      @State private var selectedEntry: Entry?

      init(day: CalendarDay, today: Date) { ... builds the two @Query filters for the day ... }

      var body: some View {
          let bars = barsByID
          NavigationStack {
              ScrollView {
                  VStack(alignment: .leading, spacing: HugoLayout.Spacing.section) {
                      plannedSection(bars: bars)
                      if canLog {
                          loggedSection
                      }
                  }
                  .padding()
              }
              .background(Color(.systemGroupedBackground))
              ...
              .sheet(item: $loggingItem) { item in
                  AddEntryView(
                      seededDate: day.midday(),
                      seededDuration: (loggingSeconds / 60).rounded(.down) * 60,
                      preferredTrackerID: item.trackerID,
                      seededStartMinute: item.startMinute)
              }
              .sheet(isPresented: $isAddingEntry) {
                  AddEntryView(seededDate: day.midday())
              }
              ...
  ```

  `plannedSection` shows a "planner.legend.planned" header, the plan cards or
  `Text("planner.day.planned.empty")`, then a bordered "planner.plan.add"
  button. `loggedSection` shows a "planner.legend.logged" header, full
  `EntryRow` cards or `Text("planner.day.logged.empty")`, then a bordered
  "entry.add.label" button. `startLogging(_:bars:)` sets `loggingSeconds` and
  then `loggingItem`. `barsByID` calls `PlannerDay.make(...)` and builds a
  dictionary of bars by id.

- `Hugo/Features/Planner/Domain/PlannerMonth.swift`: `PlannerDay` (`bars: [PlannerBar]`, `logged: TimeSplit`, `planned: TimeSplit`) and `TimeSplit` (`total: TimeInterval`). `PlannerDay.make(day:items:entries:trackers:today:)`.
- `Hugo/Features/Planner/Domain/PlanMatcher.swift`: `PlannerBar` (`id`, `kind`, `seconds`, `filledSeconds`, `remainingSeconds`, `isFull`, `fraction`), `LoggedCategoryTime`, and `PlanMatcher.bars(plans:logged:)`. A plan bar's `id` equals the `PlannedItem.id`.
- `Hugo/Features/Planner/Domain/PlannedItem.swift`: `PlannedItem` (`id: String`, `day: CalendarDay`, `duration`, `startMinute: Int?`, `categoryName`, `categoryIconName`, `categoryType`, `trackerID: UUID?`, `color`). It has a memberwise init (used in tests).
- `Hugo/Features/Planner/Domain/CalendarDay.swift`: `CalendarDay.midday(calendar:)` returns 12:00 on the day.
- `Hugo/Features/Planner/Views/PlannedItemRow.swift`: the plan card. Unchanged by this plan. Its card background, to copy for the logged box:

  ```swift
  @Environment(\.colorScheme) private var colorScheme
  ...
  .background(
      colorScheme == .dark
          ? Color(.secondarySystemBackground)
          : Color(.systemBackground)
  )
  .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
  ```

- `Hugo/Domain/ServiceDurationFormatter.swift`: `hoursString(from:)` ("1 hour, 30 minutes") and `accessibilityString(from:)`.
- `Entry.resolvedCategory()` returns an `EntryCategory` with `name` and `iconName`. Always use it; never read `entry.tracker` directly (AGENTS.md rule).
- `Hugo/DesignSystem/Theme/Theme.swift` (`HugoLayout`): `Spacing.tight 4, small 6, compact 8, regular 12, spacious 16, roomy 20, card 24, section 32`; `CornerRadius.compactCard 24, card 32`; `Size.labelReservedIconWidth 24`.
- Localized strings with values use this pattern (from `PlannedItemRow`):

  ```swift
  String(
      localized: "planner.plan.progress", defaultValue: "\(logged) of \(planned) logged",
      comment: "On a plan in the Planner day sheet: how much of the plan is logged. Logged time, planned time.")
  ```

- Domain test pattern: `HugoTests/Features/Planner/Domain/PlanMatcherTests.swift`. Its helpers:

  ```swift
  private func plan(
      _ id: String, _ trackerID: UUID, type: TrackerType, hours: Double, startMinute: Int? = nil
  ) -> PlannedItem {
      PlannedItem(
          id: id, day: CalendarDay(year: 2026, month: 11, day: 5), duration: hours * 3_600,
          startMinute: startMinute, categoryName: "Category", categoryIconName: "figure.walk",
          categoryType: type, trackerID: trackerID, color: nil)
  }

  private func time(
      _ id: UUID, name: String, type: TrackerType, seconds: TimeInterval
  ) -> LoggedCategoryTime {
      LoggedCategoryTime(
          key: id.uuidString, name: name, iconName: "figure.walk", type: type, color: nil,
          seconds: seconds)
  }
  ```

- `CONTEXT.md` (repo root) is the domain glossary. AGENTS.md: "add a term there in the same change when you introduce a new domain concept." Its "## Planning" section ends with:

  ```markdown
  **Unplanned time**:
  Logged time on a day that no plan covers, including time beyond a plan.

  ## Sync
  ```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Layout | `Scripts/check-layout.sh` | exit 0, no output |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/PlanLogSeedTests` | `** TEST SUCCEEDED **` |
| Strings valid JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | no output |
| Full gate | `Scripts/verify.sh` | exit 0 (takes several minutes) |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run
the same command again; that is not a failure.

## Scope

**In scope** (the only files you may modify or create):
- Create `Hugo/Features/Planner/Domain/PlanLogSeed.swift`
- Create `HugoTests/Features/Planner/Domain/PlanLogSeedTests.swift`
- Create `Hugo/Features/Planner/Views/PlannerLoggedEntryList.swift`
- Modify `Hugo/Features/Planner/Screens/PlannerDaySheet.swift`
- Modify `Hugo/Resources/Localizable.xcstrings` (the keys named in Step 5 only)
- Modify `CONTEXT.md` (one new term, Step 6)

**Out of scope** (do not touch):
- `PlannedItemRow.swift`, `PlanFormView.swift`, `PlanFormModel.swift`, `PlanService.swift`: the plan card and form stay as they are.
- `AddEntryView.swift`, `AddEntryFormModel.swift`: their seeding parameters already work; only the caller was wrong.
- `EntryRow.swift`, `EntryDetailView.swift`: the compact rows are new and live in the Planner; `EntryRow` keeps its current look everywhere else.
- `PlannerMonthPage.swift`, `PlannerCalendarGrid.swift`, `PlannerDayCell.swift`, `PlannerLegend.swift`.
- `plans/` and `.claude/` (owner's files).

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- The working tree holds uncommitted owner files in `plans/` and `.claude/`. Never stage, edit, stash or discard them. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage only in-scope files, by explicit path.
- Two commits, Conventional Commits style (see `git log --oneline -5`):
  1. After Step 2: `fix: fill in the plan's remaining time when logging a plan`
  2. After Step 7: `feat: put plans first in the planner day sheet`
- A pre-commit hook formats staged Swift files. That is expected.

## Steps

### Step 1: Add `PlanLogSeed`

Create `Hugo/Features/Planner/Domain/PlanLogSeed.swift` with exactly this content:

```swift
import Foundation

/// What Add Entry starts with when the user logs a plan: the plan's day,
/// category and start time, and the part of the plan not covered yet.
nonisolated struct PlanLogSeed: Identifiable, Equatable, Sendable {
    /// The plan item's id.
    let id: String
    /// 12:00 on the plan's day.
    let date: Date
    /// The plan's remaining time, rounded down to whole minutes.
    let duration: TimeInterval
    let trackerID: UUID?
    /// Minutes after midnight, or nil.
    let startMinute: Int?

    /// `bar` is the plan's bar from `PlannerDay.make`. Without a bar, the whole
    /// plan counts as remaining.
    init(item: PlannedItem, bar: PlannerBar?, calendar: Calendar = .current) {
        let remaining = bar?.remainingSeconds ?? item.duration
        self.id = item.id
        self.date = item.day.midday(calendar: calendar)
        self.duration = (remaining / 60).rounded(.down) * 60
        self.trackerID = item.trackerID
        self.startMinute = item.startMinute
    }
}
```

### Step 2: Test `PlanLogSeed`, then use it in the day sheet

Create `HugoTests/Features/Planner/Domain/PlanLogSeedTests.swift`. A plain
`struct PlanLogSeedTests` (no `@MainActor` needed), with a fixed UTC calendar
property like `AddEntryFormModelTests`:

```swift
private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()
```

and the `plan(...)` and `time(_:name:type:seconds:)` helpers copied from
`PlanMatcherTests` (see Current state). Build bars with the real matcher:
`PlanMatcher.bars(plans: [item], logged: [...]).first`. Tests:

1. `unloggedPlanSeedsTheWholePlan`: item `plan("p", fieldServiceID, type: .main, hours: 2, startMinute: 600)`, no logged time. Expect `seed.id == "p"`, `seed.duration == 7_200`, `seed.trackerID == fieldServiceID`, `seed.startMinute == 600`, and `seed.date == calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 12))`.
2. `partlyLoggedPlanSeedsOnlyTheRemainingTime`: 2-hour plan, logged `time(fieldServiceID, name: "Field Service", type: .main, seconds: 3_600)`. Expect `seed.duration == 3_600`.
3. `remainingTimeIsRoundedDownToWholeMinutes`: 1-hour plan, logged 1_830 seconds in the same category (remaining 1_770 s). Expect `seed.duration == 1_740`.
4. `missingBarSeedsTheWholePlan`: `PlanLogSeed(item: item, bar: nil, calendar: calendar)` for a 1.5-hour plan. Expect `seed.duration == 5_400`.

Always pass `calendar: calendar` to `PlanLogSeed`.

Then in `PlannerDaySheet.swift`, replace the two-value logging state with the seed:

- Delete `@State private var loggingItem: PlannedItem?`, `@State private var loggingSeconds: TimeInterval = 0` and the `startLogging(_:bars:)` function.
- Add `@State private var loggingSeed: PlanLogSeed?`.
- In `plannedSection`, change the Log closure to `{ loggingSeed = PlanLogSeed(item: item, bar: bars[item.id]) }`.
- Replace the `.sheet(item: $loggingItem)` block with:

  ```swift
  .sheet(item: $loggingSeed) { seed in
      AddEntryView(
          seededDate: seed.date,
          seededDuration: seed.duration,
          preferredTrackerID: seed.trackerID,
          seededStartMinute: seed.startMinute)
  }
  ```

**Verify**: Focused tests → `** TEST SUCCEEDED **` with 4 tests in `PlanLogSeedTests`.
**Verify**: `grep -n "loggingSeconds\|loggingItem\|startLogging" Hugo/Features/Planner/Screens/PlannerDaySheet.swift` → no output.

Commit 1 (stage only `PlanLogSeed.swift`, `PlanLogSeedTests.swift`, `PlannerDaySheet.swift`).

### Step 3: Add the compact logged list

Create `Hugo/Features/Planner/Views/PlannerLoggedEntryList.swift`:

```swift
import SwiftUI

/// The day's logged entries in the Planner day sheet: a small header with the
/// day's logged total and one compact row per entry. Secondary to the plans
/// above it; tapping a row opens the entry.
struct PlannerLoggedEntryList: View {
    let entries: [Entry]
    let total: TimeInterval
    let onSelect: (Entry) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var header: String {
        let total = ServiceDurationFormatter.hoursString(from: total)
        return String(
            localized: "planner.day.logged.header", defaultValue: "Logged · \(total)",
            comment: "Header above the logged entries in the Planner day sheet. The day's logged time in words.")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
            Text(header)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 {
                        Divider()
                            .padding(
                                .leading,
                                HugoLayout.Spacing.spacious + HugoLayout.Size.labelReservedIconWidth
                                    + HugoLayout.Spacing.regular)
                    }
                    row(entry)
                }
            }
            .background(
                colorScheme == .dark
                    ? Color(.secondarySystemBackground)
                    : Color(.systemBackground)
            )
            .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.compactCard))
        }
    }

    private func row(_ entry: Entry) -> some View {
        let category = entry.resolvedCategory()
        return Button {
            onSelect(entry)
        } label: {
            HStack(spacing: HugoLayout.Spacing.regular) {
                Image(systemName: category.iconName)
                    .foregroundStyle(.secondary)
                    .frame(width: HugoLayout.Size.labelReservedIconWidth)
                Text(category.name)
                Spacer(minLength: HugoLayout.Spacing.compact)
                Text(ServiceDurationFormatter.hoursString(from: entry.duration))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
            .font(.callout)
            .padding(.vertical, HugoLayout.Spacing.regular)
            .padding(.horizontal, HugoLayout.Spacing.spacious)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(category.name))
        .accessibilityValue(Text(ServiceDurationFormatter.accessibilityString(from: entry.duration)))
    }
}
```

Do not add a `#Preview` that builds `Entry` rows by hand unless it compiles
on the first try; a preview is optional for this view.

**Verify**: `Scripts/check-layout.sh` → exit 0, no output.

### Step 4: Rework the day sheet

Edit `Hugo/Features/Planner/Screens/PlannerDaySheet.swift`:

1. Delete `@State private var isAddingEntry = false` and its
   `.sheet(isPresented: $isAddingEntry) { AddEntryView(seededDate: day.midday()) }` block.
2. Replace the `barsByID` computed property with one that returns the whole day:

   ```swift
   /// The day's plans matched with its logged time (plan 068's rules).
   private var plannerDay: PlannerDay {
       PlannerDay.make(day: day, items: items, entries: entries, trackers: trackers, today: CalendarDay(today))
   }
   ```

3. At the top of `body`, replace `let bars = barsByID` with:

   ```swift
   let plannerDay = self.plannerDay
   let bars = Dictionary(plannerDay.bars.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
   ```

4. Make the scroll content full width, and show the logged list only when the
   day has entries. The `ScrollView` content becomes:

   ```swift
   ScrollView {
       VStack(alignment: .leading, spacing: HugoLayout.Spacing.section) {
           plannedSection(bars: bars)
           if !entries.isEmpty {
               PlannerLoggedEntryList(entries: entries, total: plannerDay.logged.total) { entry in
                   selectedEntry = entry
               }
           }
       }
       .frame(maxWidth: .infinity, alignment: .leading)
       .padding()
   }
   ```

5. Add the **+** button to the existing `.toolbar`, after the close button:

   ```swift
   ToolbarItem {
       Button("planner.plan.add", systemImage: "plus") {
           isAddingPlan = true
       }
   }
   ```

   Do not give it `.buttonStyle(.glassProminent)` or a tint: prominent styling
   is for confirming actions (Add, Save) in this app.

6. `plannedSection(bars:)` becomes (no header, no button):

   ```swift
   private func plannedSection(bars: [String: PlannerBar]) -> some View {
       VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
           if items.isEmpty {
               Text("planner.day.planned.empty")
                   .foregroundStyle(.secondary)
           }
           ForEach(items) { item in
               PlannedItemRow(
                   item: item,
                   bar: bars[item.id],
                   showsProgress: canLog,
                   onEdit: { editingPlan = plans.first(where: { $0.id.uuidString == item.id }) },
                   onLog: canLog && !(bars[item.id]?.isFull ?? false)
                       ? { loggingSeed = PlanLogSeed(item: item, bar: bars[item.id]) } : nil
               )
           }
       }
   }
   ```

7. Delete the old `loggedSection` property. Keep `canLog`, `items`, the
   `init`, the close button, the plan-form sheets, the `loggingSeed` sheet and
   the `selectedEntry` sheet (`EntryDetailView(entry:)` with
   `.presentationDetents([.medium, .large])`).
8. Update the type's doc comment to:

   ```swift
   /// One day in the Planner: its plans first, then, on days with logged
   /// entries, a smaller list of those entries. Logging a plan opens Add Entry
   /// filled from the plan.
   ```

**Verify**:
- `grep -n "isAddingEntry\|entry.add.label\|planner.day.logged.empty\|planner.legend\|EntryRow(\|barsByID\|loggedSection" Hugo/Features/Planner/Screens/PlannerDaySheet.swift` → no output.
- `grep -n "frame(maxWidth: .infinity, alignment: .leading)" Hugo/Features/Planner/Screens/PlannerDaySheet.swift` → one match.
- `grep -n "systemImage: \"plus\"" Hugo/Features/Planner/Screens/PlannerDaySheet.swift` → one match, inside `.toolbar`.

### Step 5: Strings

Edit `Hugo/Resources/Localizable.xcstrings` (Xcode JSON: 2-space indent,
`" : "` between key and value, keys in alphabetical order; copy the shape of
the neighbouring `planner.*` entries, each with a `comment` and `en` and `da`
`stringUnit`s with `"state" : "translated"`):

| Change | Key | English | Danish |
|---|---|---|---|
| Change both values and the comment | `planner.day.planned.empty` | Nothing planned yet. Tap + to add a plan. | Intet planlagt endnu. Tryk på + for at tilføje en plan. |
| Add | `planner.day.logged.header` | Logged · %@ | Udført · %@ |
| Delete the whole entry | `planner.day.logged.empty` | | |

New comment for `planner.day.planned.empty`: "Shown in the Planner day sheet
when the day has no plans. + is the Add Plan button in the navigation bar."
Comment for `planner.day.logged.header`: use the same comment as in Step 3's
`String(localized:)` call.

Do not change any other key. `planner.legend.planned`, `planner.legend.logged`
and `entry.add.label` are still used elsewhere; keep them.

**Verify**:
- JSON check → no output.
- `python3 -I -c "import json;d=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'];print(d['planner.day.planned.empty']['localizations']['en']['stringUnit']['value']);print(d['planner.day.logged.header']['localizations']['da']['stringUnit']['value']);print('planner.day.logged.empty' in d)"` →
  ```
  Nothing planned yet. Tap + to add a plan.
  Udført · %@
  False
  ```
- `git diff --numstat -- Hugo/Resources/Localizable.xcstrings` → only a few lines changed (roughly 20 added, 20 removed); no unrelated keys reformatted.

### Step 6: Glossary

In `CONTEXT.md`, under `## Planning`, add after the **Unplanned time** entry
and before `## Sync` (keep one blank line between entries):

```markdown
**Logging a plan**:
Opening Add Entry filled from a plan: its day, category and start time, and the part of the plan that logged time has not covered yet. The user still saves the entry, and the plan stays.
```

**Verify**: `grep -n "Logging a plan" CONTEXT.md` → one match.

### Step 7: Full gate

**Verify**: `Scripts/verify.sh` → exit 0, and its output contains `** TEST SUCCEEDED **` and `** ANALYZE SUCCEEDED **`.

Commit 2 (stage only `PlannerLoggedEntryList.swift`, `PlannerDaySheet.swift`,
`Localizable.xcstrings`, `CONTEXT.md`). Then `git status --short` must show
only `plans/` and `.claude/` entries.

## Test plan

- `PlanLogSeedTests` (new, 4 tests, Step 2): whole plan, partly logged plan,
  rounding down to whole minutes, and no bar. Test 2 is the regression test for
  issue 4: the seed carries the remaining time itself, so the sheet cannot read
  a stale value.
- All existing tests keep passing (`Scripts/verify.sh`).
- Manual (owner, on a device or simulator):
  1. Open an empty future day: the text "Nothing planned yet. Tap + to add a
     plan." starts at the leading edge, the grey background fills the sheet
     edge to edge, and no Logged section shows.
  2. Tap **+**: the plan form opens. Add a 2-hour Field Service plan at 10:00
     for today.
  3. Tap **Log**: Add Entry shows 02:00, Field Service and 10:00. Change the
     duration to 1 hour and add it.
  4. The sheet shows "1 hour of 2 hours logged" on the card and, below,
     "Logged · 1 hour" with one compact row. Tap Log again: Add Entry shows
     01:00. Tap the compact row: the entry opens.
  5. VoiceOver: the + button reads "Add Plan"; the Logged header is a heading;
     each compact row reads its category and duration.
  6. Largest Dynamic Type size: compact rows wrap without clipping.
  7. Danish: review "Intet planlagt endnu. Tryk på + for at tilføje en plan."
     and "Udført · 1 time".

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `PlanLogSeedTests` has 4 passing tests
- [ ] `grep -rn "loggingSeconds\|isAddingEntry\|AddEntryView(seededDate: day" Hugo/Features/Planner` → no output
- [ ] `grep -rn "planner.day.logged.empty" Hugo` → no output
- [ ] `grep -c "ToolbarItem" Hugo/Features/Planner/Screens/PlannerDaySheet.swift` → `2`
- [ ] `git diff --stat ddc2964..HEAD` lists only the six in-scope files
- [ ] `git status --short` shows only `plans/` and `.claude/` entries
- [ ] `plans/README.md` status row updated (skip if a reviewer maintains it)

## STOP conditions

Stop and report back (do not improvise) if:

- The drift check lists a file and the live code no longer matches the
  "Current state" excerpts.
- `PlannerDay` has no `logged` property, or `TimeSplit` has no `total`.
- `ForEach(Array(entries.enumerated()), id: \.element.id)` does not compile
  because `Entry` is not `Identifiable`. Report the compiler error.
- Making the content full width needs a change outside `PlannerDaySheet.swift`.
- You find you need to change `PlannedItemRow`, `AddEntryView`,
  `AddEntryFormModel`, `EntryRow` or `EntryDetailView`.
- A step's verification fails twice after a reasonable fix attempt.

## Maintenance notes

- Never hand a sheet values through a second `@State` next to its `item`.
  Put everything the sheet needs into the item (here `PlanLogSeed`). Plan 070
  did the opposite and the duration arrived as 0.
- `PlanLogSeed` is a natural source for the planned "suggestion pills" in Add
  Entry (see `plans/README.md`, "Planner: next steps"): the same
  duration/category/start-time values. If that lands, consider moving the seed
  type next to Add Entry and giving it a second initializer for presets.
- The day sheet no longer offers Add Entry. If users ask for logging
  unplanned time from the Planner, revisit with the owner before adding a
  button; the decision (2026-11-05) was to keep the sheet about planning.
- Plan 071 (status header) and 072 (Overview pace) do not touch the day sheet.
- `PlannerDayCell` carries `.accessibilityAddTraits(.isButton)` while it is
  also wrapped in a `Button` (plan 070). Owner should check VoiceOver does not
  say "button" twice; out of scope here.
