# Plan 075: Match and show plans per category, and draw bar fills in the bar's color

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 4b01234..HEAD -- Hugo/Features/Planner HugoTests/Features/Planner Hugo/Resources/Localizable.xcstrings CONTEXT.md`
> Expected: no output. If any file is listed, compare the "Current state"
> excerpts below with the live code; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW-MEDIUM (changes the Planner's matching output and one screen; no schema or data changes)
- **Depends on**: plans/074-planner-day-sheet-fixes.md (DONE, commits `0e2ec93`, `4b01234`)
- **Category**: bug + design (owner feedback after testing 074)
- **Planned at**: commit `4b01234`, 2026-11-05

## Why this matters

The owner tested the Planner after plan 074 and asked for three changes.

1. **Bar colors.** Every Planner bar (calendar grid, day sheet cards, legend)
   has a full-color outline but a fill at 55% opacity, so the outline and the
   fill look like two shades. The fill must use the same color as the outline.
2. **Logging more than planned adds a second bar.** With a 2-hour Field
   Service plan and 4 hours of Field Service logged, the calendar day shows two
   bars: the full plan and an extra "unplanned" bar for the 2 extra hours.
   Owner rule: logged time gets its own bar **only** when its category has no
   plan on that day. Extra time stays on the plan's bar (shown full; the day
   sheet says "4 hours of 2 hours logged").
3. **Per-plan bars suggest matching that Hugo does not do.** Hugo matches logged
   time to plans per category and ignores start times (an entry does not record
   whether the user picked its time or Hugo guessed it). With two Field Service
   plans (2 h at 10:00, 3 h at 14:00) and one 2½-hour entry at 14:00, the 10:00
   plan shows full and the 14:00 plan nearly empty. That is misleading. The
   owner decided: keep the simple matching, and show **one bar per category per
   day**, in the calendar grid and in the day sheet. In the day sheet, plans of
   one category share one card with one bar, one progress line and one Log
   button; each plan is a line on that card that opens the plan.

## Owner decisions (do not change)

- Matching stays per category, by day totals. Start times never affect matching.
- One plan bar per category per day, everywhere. Its length is the category's
  total planned time that day.
- Time beyond a category's plans stays on that category's bar. An unplanned bar
  appears only for a category with no plan that day (after other plans of the
  same kind took what they could, as today).
- The day sheet card for a category with **one** plan looks and behaves exactly
  like today's card (`PlannedItemRow`): its main part opens the plan.
- With **several** plans the card's header shows the total and the category,
  and each plan is a line below it ("🕙 10:00 ... 2 hours ›", or "No start time"
  when the plan has none). Tapping a line opens that plan.
- Log fills Add Entry with the category's remaining time and the start time of
  the first plan (in start-time order) that is not covered yet.

Target day sheet card with two plans:

```
┌───────────────────────────────────┐
│ ⛺ 5 hours                 [ Log ] │
│    Field Service                  │
│    🕙 10:00            2 hours  › │
│    🕙 14:00            3 hours  › │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░  │
│ 2 hours, 30 minutes of 5 hours    │
│ logged                            │
└───────────────────────────────────┘
```

## Current state

All files compile and pass `Scripts/verify.sh` at `4b01234`.

### `Hugo/Features/Planner/Views/PlannerBarView.swift` (bar drawing)

```swift
/// The rounded rectangle behind a bar: outline and tint in `color`, filled from
/// the left up to `fraction`. Also drawn on its own in legends.
struct PlannerBarShape: View {
    let fraction: Double
    let color: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: HugoLayout.CornerRadius.calendarBar)
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                shape.fill(color.opacity(0.15))
                Rectangle()
                    .fill(color.opacity(0.55))
                    .frame(width: proxy.size.width * min(1, max(0, fraction)))
            }
        }
        .clipShape(shape)
        .overlay { shape.strokeBorder(color, lineWidth: 1) }
    }
}
```

### `Hugo/Features/Planner/Domain/PlanMatcher.swift` (matching)

`LoggedCategoryTime` (key, name, iconName, type, color, seconds), then:

```swift
nonisolated struct PlannerBar: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case plan
        case unplanned
    }

    /// The plan item's id, or `unplanned:` followed by the category key.
    let id: String
    let kind: Kind
    let categoryName: String
    let categoryIconName: String
    let color: CategoryProgressColor?
    /// The plan's duration, or the unplanned logged time.
    let seconds: TimeInterval
    /// Logged time counted toward this bar. Equals `seconds` for unplanned time.
    let filledSeconds: TimeInterval

    var fraction: Double { seconds > 0 ? min(1, filledSeconds / seconds) : 0 }
    var remainingSeconds: TimeInterval { max(0, seconds - filledSeconds) }
    var isFull: Bool { remainingSeconds < 60 }
}

/// Matches one day's logged time to its plans: the same category first, then
/// the same kind (main or separate). Logged time left over becomes unplanned bars.
nonisolated enum PlanMatcher {
    static func bars(plans: [PlannedItem], logged: [LoggedCategoryTime]) -> [PlannerBar] {
        // sorts plans by startMinute (nil last, then input order) into `ordered`
        // pass 1: each plan takes time from its own category (plan.categoryKey)
        // pass 2: each plan takes time from any category of the same kind
        // one .plan bar per plan (id = plan.id), then .unplanned bars for
        // categories with >= 60 s left, sorted by name, id "unplanned:<key>"
    }
}
```

`PlannerBar` is constructed only inside `PlanMatcher.swift`.

### `Hugo/Features/Planner/Domain/PlannedItem.swift`

`PlannedItem` (`id: String`, `day: CalendarDay`, `duration`, `startMinute: Int?`,
`categoryName`, `categoryIconName`, `categoryType: TrackerType`, `trackerID: UUID?`,
`color: CategoryProgressColor?`) with `var categoryKey: String`. It is
`Identifiable, Equatable, Sendable`. Do not change this file.

### `Hugo/Features/Planner/Domain/PlannerMonth.swift`

`PlannerDay` has `let bars: [PlannerBar]` with the doc comment
`/// Plan bars in fill order, then unplanned bars.` and builds them with
`PlanMatcher.bars(plans: items, logged: Array(byCategory.values))`. Nothing else
in the app reads `bars` except `PlannerDayCell` (grid, needs no change: it
draws `day.bars` and reads `categoryName`, `seconds`, `filledSeconds`, `kind`)
and `PlannerDaySheet`.

### `Hugo/Features/Planner/Domain/PlanLogSeed.swift` (from plan 074)

```swift
nonisolated struct PlanLogSeed: Identifiable, Equatable, Sendable {
    let id: String
    let date: Date
    let duration: TimeInterval
    let trackerID: UUID?
    let startMinute: Int?

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

### `Hugo/Features/Planner/Screens/PlannerDaySheet.swift`

The relevant parts:

```swift
    var body: some View {
        let plannerDay = self.plannerDay
        let bars = Dictionary(plannerDay.bars.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HugoLayout.Spacing.section) {
                    plannedSection(bars: bars)
                    if !entries.isEmpty {
    ...
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

`items`, `canLog`, `plannerDay`, the toolbar and all `.sheet` modifiers stay.

### `Hugo/Features/Planner/Views/PlannedItemRow.swift`

Today's plan card, used only by `PlannerDaySheet`. This plan replaces it with
`PlannedCategoryCard` and deletes it. Its look (padding `HugoLayout.Spacing.card`,
corner radius `HugoLayout.CornerRadius.card`, background
`colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground)`,
icon `.title2` `.medium` in a `HugoLayout.Size.entryIcon` frame, bold hours,
secondary category name, clock `Label` for the start time, bordered `Log` button
tinted `.hugoAccent`, a `PlannerBarShape` of height `calendarBarHeight`, and a
footnote progress line) is reproduced in Step 4.

### Tests that assert the old behaviour

- `HugoTests/Features/Planner/Domain/PlanMatcherTests.swift`: bar ids equal plan
  ids (`"fs"`, `"ldc"`), `timeBeyondAPlanBecomesOneUnplannedBar` expects two bars,
  `plansFillInStartTimeOrderWithoutStartTimesLast` expects three bars. Helpers
  `plan(_:_:type:hours:startMinute:)` and `time(_:name:type:hours:)` /
  `time(_:name:type:seconds:)`.
- `HugoTests/Features/Planner/Domain/PlanLogSeedTests.swift`: uses
  `PlanLogSeed(item:bar:calendar:)`.
- `HugoTests/Features/Planner/Domain/PlannerMonthTests.swift`, test
  `planBarsAgreeWithStillPlannedTimePerKind`, filters bars by id:

  ```swift
        let mainRemaining = planned.bars.filter { ["fs", "phone"].contains($0.id) }
            .reduce(0) { $0 + $1.remainingSeconds }
        let separateRemaining = planned.bars.filter { $0.id == "ldc" }
            .reduce(0) { $0 + $1.remainingSeconds }
  ```

### Glossary (`CONTEXT.md`, section `## Planning`)

```markdown
**Covered time**:
The part of a plan that logged time on the same day accounts for: first time in the plan's category, then other time of the same kind (main or separate). The Planner draws it as the filled part of the plan's bar.

**Unplanned time**:
Logged time on a day that no plan covers, including time beyond a plan.

**Logging a plan**:
Opening Add Entry filled from a plan: its day, category and start time, and the part of the plan that logged time has not covered yet. The user still saves the entry, and the plan stays.
```

### Conventions

- `swift-format` line length 120, 4-space indentation.
- `HugoLayout` (`Hugo/DesignSystem/Theme/Theme.swift`): `Spacing.tight 4, small 6,
  compact 8, regular 12, spacious 16, roomy 20, card 24, section 32`;
  `Size.entryIcon 32`, `Size.calendarBarHeight 6`, `Size.minimumHitTarget 44`.
- Localized strings with values: `String(localized: "key", defaultValue: "\(a) of \(b)", comment: "...")`.
- Tests use Swift Testing (`@Test`, `#expect`, `#require`).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Layout | `Scripts/check-layout.sh` | exit 0, no output |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Planner tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/PlanMatcherTests -only-testing:HugoTests/PlanLogSeedTests -only-testing:HugoTests/PlannerMonthTests` | `** TEST SUCCEEDED **` |
| Strings valid JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | no output |
| Full gate | `Scripts/verify.sh` | exit 0 (takes several minutes) |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run
the same command again; that is not a failure.

## Scope

**In scope** (the only files you may modify, create or delete):
- Modify `Hugo/Features/Planner/Views/PlannerBarView.swift` (Step 1)
- Modify `Hugo/Features/Planner/Domain/PlanMatcher.swift` (Step 2)
- Modify `Hugo/Features/Planner/Domain/PlannerMonth.swift` (one doc comment, Step 2)
- Modify `Hugo/Features/Planner/Domain/PlanLogSeed.swift` (Step 3)
- Create `Hugo/Features/Planner/Views/PlannedCategoryCard.swift` (Step 4)
- Delete `Hugo/Features/Planner/Views/PlannedItemRow.swift` (Step 4)
- Modify `Hugo/Features/Planner/Screens/PlannerDaySheet.swift` (Step 5)
- Modify `HugoTests/Features/Planner/Domain/PlanMatcherTests.swift`, `PlanLogSeedTests.swift`, `PlannerMonthTests.swift`
- Modify `Hugo/Resources/Localizable.xcstrings` (one new key, Step 6)
- Modify `CONTEXT.md` (Step 7)

**Out of scope** (do not touch):
- `PlannerDayCell.swift`, `PlannerCalendarGrid.swift`, `PlannerLegend.swift`, `PlannerMonthPage.swift`: they pick up the changes without edits.
- `PlannedItem.swift`, `PlannerMonthStatus.swift`, `PlanPace.swift`, `PlannerTarget.swift`: totals do not change.
- `PlanFormView.swift`, `PlanFormModel.swift`, `PlanService.swift`, `PlannerLoggedEntryList.swift`.
- `AddEntryView.swift`, `AddEntryFormModel.swift`, anything under `Hugo/Persistence`.
- `plans/` and `.claude/` (owner's files).

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- The working tree holds uncommitted owner files in `plans/` and `.claude/`. Never stage, edit, stash or discard them. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage only in-scope files, by explicit path. Stage the deletion with `git rm Hugo/Features/Planner/Views/PlannedItemRow.swift` (or `git add` on that path after deleting it).
- Two commits, Conventional Commits style:
  1. After Step 1: `fix: fill planner bars in the same color as their outline`
  2. After Step 8: `feat: match and show planner plans per category`
- A pre-commit hook formats staged Swift files. That is expected.

## Steps

### Step 1: Same color for fill and outline

In `PlannerBarView.swift`, change the fill line `.fill(color.opacity(0.55))` to
`.fill(color)`. Keep the 15% background tint and the outline. Update the doc
comment of `PlannerBarShape` to:

```swift
/// The rounded rectangle behind a bar: an outline and a light tint in `color`,
/// and a fill in the same `color` from the left up to `fraction`. Also drawn on
/// its own in legends.
```

**Verify**: `grep -n "opacity" Hugo/Features/Planner/Views/PlannerBarView.swift` → exactly one line, containing `color.opacity(0.15)`.
**Verify**: Lint → exit 0.

Commit 1 (stage only `PlannerBarView.swift`).

### Step 2: One bar per category in `PlanMatcher`

In `PlanMatcher.swift`:

1. In `PlannerBar`, replace the `id` and `seconds` doc comments and add an
   `items` property after `filledSeconds`:

   ```swift
       /// `plan:` or `unplanned:` followed by the category key.
       let id: String
       ...
       /// The category's planned time on the day, or the unplanned logged time.
       let seconds: TimeInterval
       /// Logged time counted toward this bar. Can be more than `seconds` when
       /// more was logged than planned. Equals `seconds` for unplanned time.
       let filledSeconds: TimeInterval
       /// The category's plans on the day in start-time order. Empty for unplanned time.
       let items: [PlannedItem]
   ```

   Keep `Kind`, `categoryName`, `categoryIconName`, `color`, `fraction`,
   `remainingSeconds` and `isFull` exactly as they are. Update the struct's doc
   comment to:

   ```swift
   /// One bar in a calendar day: one category's plans and how much of them logged
   /// time covers, or logged time in a category with no plan that day.
   ```

2. Replace the whole `PlanMatcher` enum (doc comment included) with:

   ```swift
   /// Matches one day's logged time to its plans, per category. Start times are
   /// ignored: an entry does not record whether its time was picked or guessed.
   /// Each category's plans share one bar. A bar takes time from its own category
   /// first, then other time of the same kind (main or separate). Time beyond a
   /// category's plans stays on that category's bar. Logged time left over in a
   /// category with no plan becomes an unplanned bar.
   nonisolated enum PlanMatcher {
       static func bars(plans: [PlannedItem], logged: [LoggedCategoryTime]) -> [PlannerBar] {
           let ordered = plans.enumerated()
               .sorted { lhs, rhs in
                   let left = lhs.element.startMinute ?? Int.max
                   let right = rhs.element.startMinute ?? Int.max
                   return left != right ? left < right : lhs.offset < rhs.offset
               }
               .map(\.element)

           // One group per category, in the order of each category's first plan.
           var groupKeys: [String] = []
           var groupItems: [String: [PlannedItem]] = [:]
           for plan in ordered {
               if groupItems[plan.categoryKey] == nil {
                   groupKeys.append(plan.categoryKey)
               }
               groupItems[plan.categoryKey, default: []].append(plan)
           }
           let plannedSeconds = groupItems.mapValues { items in items.reduce(0) { $0 + $1.duration } }

           let categories = logged.sorted { $0.key < $1.key }
           var unused = Dictionary(categories.map { ($0.key, $0.seconds) }, uniquingKeysWith: +)
           var filled: [String: TimeInterval] = [:]

           func fill(_ group: String, from key: String, upTo limit: TimeInterval) {
               let take = min(max(0, limit - (filled[group] ?? 0)), unused[key] ?? 0)
               guard take > 0 else { return }
               filled[group, default: 0] += take
               unused[key, default: 0] -= take
           }

           for key in groupKeys {
               fill(key, from: key, upTo: plannedSeconds[key] ?? 0)
           }
           for key in groupKeys {
               let type = groupItems[key]?.first?.categoryType ?? .main
               for category in categories where (category.type ?? .main) == type {
                   fill(key, from: category.key, upTo: plannedSeconds[key] ?? 0)
               }
           }
           for key in groupKeys {
               fill(key, from: key, upTo: .infinity)
           }

           let planBars = groupKeys.compactMap { key -> PlannerBar? in
               guard let items = groupItems[key], let first = items.first else { return nil }
               return PlannerBar(
                   id: "plan:\(key)", kind: .plan, categoryName: first.categoryName,
                   categoryIconName: first.categoryIconName, color: first.color,
                   seconds: plannedSeconds[key] ?? 0, filledSeconds: filled[key] ?? 0, items: items)
           }
           let unplannedBars =
               categories
               .filter { (unused[$0.key] ?? 0) >= 60 }
               .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
               .map { category in
                   let seconds = unused[category.key] ?? 0
                   return PlannerBar(
                       id: "unplanned:\(category.key)", kind: .unplanned, categoryName: category.name,
                       categoryIconName: category.iconName, color: category.color,
                       seconds: seconds, filledSeconds: seconds, items: [])
               }
           return planBars + unplannedBars
       }
   }
   ```

   The order of the three passes matters: the third pass (time beyond a
   category's plans) runs last so that, as today, a category's extra time can
   first fill another plan of the same kind.

3. In `PlannerMonth.swift`, change only the doc comment above `let bars` to:

   ```swift
       /// Plan bars, one per category in the order of each category's first plan,
       /// then unplanned bars.
   ```

Then update the tests (they will not compile against the old ids otherwise).

`PlanMatcherTests.swift`: add a helper
`private func barID(_ id: UUID) -> String { "plan:\(id.uuidString)" }` and change
the tests as follows. Keep all helpers.

- `ownersExampleFillsEachPlanFromItsOwnCategory`: look bars up with
  `barID(fieldServiceID)` and `barID(ldcID)` instead of `"fs"` and `"ldc"`. All
  expectations stay.
- `secondPassLetsAnotherMainCategoryFillThePlan`: unchanged.
- `secondPassRespectsTheKindOfTime`: look the plan bar up with `barID(fieldServiceID)`.
- Replace `timeBeyondAPlanBecomesOneUnplannedBar` with
  `timeBeyondAPlanStaysOnThePlanBar`: plan `fs` 1 h, logged Field Service 3 h.
  Expect `bars.count == 1`, `bars.first?.kind == .plan`,
  `bars.first?.filledSeconds == 10_800`, `bars.first?.fraction == 1`,
  `bars.first?.isFull == true`.
- Replace `plansFillInStartTimeOrderWithoutStartTimesLast` with
  `plansOfOneCategoryShareOneBarInStartTimeOrder`: the same three plans
  (`none` nil, `late` 840, `early` 600, 1 h each), logged 1.5 h. Expect
  `bars.count == 1`, `bars.first?.id == barID(fieldServiceID)`,
  `bars.first?.items.map(\.id) == ["early", "late", "none"]`,
  `bars.first?.seconds == 10_800`, `bars.first?.filledSeconds == 5_400`,
  `bars.first?.fraction == 0.5`.
- `leftoverUnderAMinuteMakesNoUnplannedBar`: keep, and add
  `#expect(bars.first?.filledSeconds == 3_630)`.
- `untrackedLoggedTimeFillsAMainPlan`: unchanged.
- New `startTimesDoNotAffectMatching` (the owner's example): plans
  `plan("morning", fieldServiceID, type: .main, hours: 2, startMinute: 600)` and
  `plan("afternoon", fieldServiceID, type: .main, hours: 3, startMinute: 840)`,
  logged Field Service 2.5 h. Expect `bars.count == 1`,
  `bars.first?.seconds == 18_000`, `bars.first?.filledSeconds == 9_000`,
  `bars.first?.remainingSeconds == 9_000`.
- New `barsFollowEachCategorysFirstStartTime`: plans
  `plan("phone", phoneID, type: .main, hours: 1)` (no start time),
  `plan("fs", fieldServiceID, type: .main, hours: 1, startMinute: 600)`,
  `plan("ldc", ldcID, type: .separate, hours: 1, startMinute: 540)`, nothing
  logged. Expect `bars.map(\.id) == [barID(ldcID), barID(fieldServiceID), barID(phoneID)]`.
- New `extraTimeFillsAnotherPlanOfTheSameKindFirst`: plans `fs` (Field Service,
  main, 1 h) and `phone` (Phone, main, 1 h), logged Field Service 2 h. Expect
  `bars.count == 2`, both `isFull`, and no bar with `kind == .unplanned`.
- New `categoryWithoutAPlanStillGetsItsOwnBar`: plan `fs` (Field Service, main,
  1 h), logged Field Service 2 h and LDC (separate) 1 h. Expect `bars.count == 2`;
  the bar with id `barID(fieldServiceID)` has `filledSeconds == 7_200`; the
  unplanned bar has id `"unplanned:\(ldcID.uuidString)"` and `seconds == 3_600`.

`PlannerMonthTests.swift`, test `planBarsAgreeWithStillPlannedTimePerKind`:
replace the two id filters with filters by the plans' kind:

```swift
        let mainRemaining = planned.bars.filter { $0.items.first?.categoryType == .main }
            .reduce(0) { $0 + $1.remainingSeconds }
        let separateRemaining = planned.bars.filter { $0.items.first?.categoryType == .separate }
            .reduce(0) { $0 + $1.remainingSeconds }
```

Leave the rest of that test, and every other test in the file, unchanged.

Do not run tests yet: `PlanLogSeed` and the day sheet still use the old API. Go
on to Step 3.

### Step 3: Seed Log from a category bar

Replace the initializer of `PlanLogSeed` (keep the properties and their doc
comments, but change the `id` and `duration` comments as shown) and the struct's
doc comment:

```swift
/// What Add Entry starts with when the user logs a category's plans: the day,
/// the category, the start time of the first plan not covered yet, and the
/// category's planned time not covered yet.
nonisolated struct PlanLogSeed: Identifiable, Equatable, Sendable {
    /// The bar's id.
    let id: String
    /// 12:00 on the day.
    let date: Date
    /// The category's remaining planned time, rounded down to whole minutes.
    let duration: TimeInterval
    let trackerID: UUID?
    /// Minutes after midnight, or nil.
    let startMinute: Int?

    /// `bar` is a `.plan` bar from `PlannerDay.make` for `day`. Covered time
    /// counts against the bar's plans in start-time order, so the start time is
    /// that of the first plan with at least a minute left.
    init(bar: PlannerBar, day: CalendarDay, calendar: Calendar = .current) {
        self.id = bar.id
        self.date = day.midday(calendar: calendar)
        self.duration = (bar.remainingSeconds / 60).rounded(.down) * 60
        self.trackerID = bar.items.first?.trackerID
        var covered = bar.filledSeconds
        var startMinute: Int?
        for item in bar.items {
            if item.duration - covered >= 60 {
                startMinute = item.startMinute
                break
            }
            covered = max(0, covered - item.duration)
        }
        self.startMinute = startMinute
    }
}
```

Rewrite `PlanLogSeedTests.swift`. Keep the `calendar` property, `fieldServiceID`
and the `plan(...)` and `time(_:name:type:seconds:)` helpers. Add:

```swift
    private let day = CalendarDay(year: 2026, month: 11, day: 5)

    private func bar(_ plans: [PlannedItem], logged: [LoggedCategoryTime] = []) throws -> PlannerBar {
        try #require(PlanMatcher.bars(plans: plans, logged: logged).first { $0.kind == .plan })
    }
```

Tests (always pass `day: day, calendar: calendar`):

1. `unloggedPlanSeedsTheWholePlan`: one 2-hour plan with `startMinute: 600`.
   Expect `seed.id == "plan:\(fieldServiceID.uuidString)"`, `duration == 7_200`,
   `trackerID == fieldServiceID`, `startMinute == 600`, and
   `date == calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 12))`.
2. `partlyLoggedPlanSeedsOnlyTheRemainingTime`: 2-hour plan, 3_600 s logged.
   Expect `duration == 3_600`.
3. `remainingTimeIsRoundedDownToWholeMinutes`: 1-hour plan, 1_830 s logged.
   Expect `duration == 1_740`.
4. `startTimeComesFromTheFirstPlanNotCoveredYet`: plans 2 h at 600 (id
   `"morning"`) and 3 h at 840 (id `"afternoon"`), 9_000 s logged. Expect
   `duration == 9_000` and `startMinute == 840`.
5. `startTimeIsNilWhenThatPlanHasNone`: plans 1 h at 600 (id `"a"`) and 1 h with
   no start time (id `"b"`), 3_600 s logged. Expect `duration == 3_600` and
   `startMinute == nil`.

All logged time in these tests uses
`time(fieldServiceID, name: "Field Service", type: .main, seconds: ...)`.

**Verify**: `grep -rn "PlanLogSeed(item:" Hugo HugoTests` → only
`Hugo/Features/Planner/Screens/PlannerDaySheet.swift` (fixed in Step 5).

### Step 4: The category card

Create `Hugo/Features/Planner/Views/PlannedCategoryCard.swift`:

```swift
import SwiftUI

/// One category's plans on a day, as a card in the day sheet. Hugo matches
/// logged time per category, not per plan, so the card has one bar, one
/// progress line and one Log button for all of them. With one plan, the card's
/// main part opens it. With several, each plan is a line that opens it.
struct PlannedCategoryCard: View {
    let bar: PlannerBar
    var showsProgress = false
    let onEdit: (PlannedItem) -> Void
    var onLog: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var color: Color {
        guard let color = bar.color else { return .hugoAccent }
        return Color(hue: color.hue, saturation: color.saturation, brightness: color.brightness)
    }

    /// The plan when the category has exactly one on the day.
    private var singleItem: PlannedItem? {
        bar.items.count == 1 ? bar.items.first : nil
    }

    /// For example "1 hour of 2 hours logged". Nil unless the day sheet asks for progress.
    private var progressText: String? {
        guard showsProgress else { return nil }
        let logged = ServiceDurationFormatter.hoursString(from: bar.filledSeconds)
        let planned = ServiceDurationFormatter.hoursString(from: bar.seconds)
        return String(
            localized: "planner.plan.progress", defaultValue: "\(logged) of \(planned) logged",
            comment: "On a plan in the Planner day sheet: how much of the plan is logged. Logged time, planned time.")
    }

    private func startTimeText(for item: PlannedItem) -> String? {
        guard let minute = item.startMinute,
            let time = Calendar.current.date(
                bySettingHour: minute / 60, minute: minute % 60, second: 0, of: item.day.startDate())
        else { return nil }
        return time.formatted(date: .omitted, time: .shortened)
    }

    /// Everything the header says, for VoiceOver.
    private var headerValue: String {
        var parts = [ServiceDurationFormatter.accessibilityString(from: bar.seconds)]
        if let singleItem, let startTime = startTimeText(for: singleItem) {
            parts.append(startTime)
        }
        if let progressText {
            parts.append(progressText)
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
            HStack(spacing: HugoLayout.Spacing.spacious) {
                if let singleItem {
                    Button {
                        onEdit(singleItem)
                    } label: {
                        header(startTime: startTimeText(for: singleItem))
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(bar.categoryName))
                    .accessibilityValue(Text(headerValue))
                    .accessibilityHint(Text("planner.plan.edit.hint"))
                } else {
                    header(startTime: nil)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Text(bar.categoryName))
                        .accessibilityValue(Text(headerValue))
                }

                if let onLog {
                    Button("planner.plan.log", action: onLog)
                        .buttonStyle(.bordered)
                        .tint(.hugoAccent)
                        .accessibilityLabel(Text("planner.plan.log.a11y"))
                }
            }

            if singleItem == nil {
                VStack(spacing: 0) {
                    ForEach(bar.items) { item in
                        line(item)
                    }
                }
            }

            PlannerBarShape(fraction: bar.fraction, color: color)
                .frame(maxWidth: .infinity)
                .frame(height: HugoLayout.Size.calendarBarHeight)
                .accessibilityHidden(true)
            if let progressText {
                Text(progressText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, HugoLayout.Spacing.card)
        .padding(.horizontal, HugoLayout.Spacing.card)
        .background(
            colorScheme == .dark
                ? Color(.secondarySystemBackground)
                : Color(.systemBackground)
        )
        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
    }

    private func header(startTime: String?) -> some View {
        HStack(spacing: HugoLayout.Spacing.spacious) {
            Image(systemName: bar.categoryIconName)
                .font(.title2)
                .fontWeight(.medium)
                .frame(width: HugoLayout.Size.entryIcon, height: HugoLayout.Size.entryIcon)
            VStack(alignment: .leading) {
                Text(ServiceDurationFormatter.hoursString(from: bar.seconds))
                    .font(.body)
                    .fontWeight(.bold)
                Text(bar.categoryName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let startTime {
                    Label(startTime, systemImage: "clock")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(.rect)
    }

    /// One plan of several: its start time and duration. Opens the plan.
    private func line(_ item: PlannedItem) -> some View {
        let startTime = startTimeText(for: item)
        let duration = ServiceDurationFormatter.hoursString(from: item.duration)
        return Button {
            onEdit(item)
        } label: {
            HStack(spacing: HugoLayout.Spacing.regular) {
                if let startTime {
                    Label(startTime, systemImage: "clock")
                        .foregroundStyle(.secondary)
                } else {
                    Text("planner.plan.noStartTime")
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: HugoLayout.Spacing.compact)
                Text(duration)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
            .font(.callout)
            .frame(minHeight: HugoLayout.Size.minimumHitTarget)
            .padding(.leading, HugoLayout.Size.entryIcon + HugoLayout.Spacing.spacious)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(startTime.map { Text($0) } ?? Text("planner.plan.noStartTime"))
        .accessibilityValue(Text(ServiceDurationFormatter.accessibilityString(from: item.duration)))
        .accessibilityHint(Text("planner.plan.edit.hint"))
    }
}
```

The `header`, padding, background and `Log` button are copied from
`PlannedItemRow` on purpose, so a category with one plan looks the same as
before. Then delete `Hugo/Features/Planner/Views/PlannedItemRow.swift`.

Do not add a `#Preview` unless it compiles on the first try.

**Verify**: `ls Hugo/Features/Planner/Views/PlannedItemRow.swift` → "No such file or directory".
**Verify**: `Scripts/check-layout.sh` → exit 0, no output.

### Step 5: Use the card in the day sheet

In `PlannerDaySheet.swift`:

1. At the top of `body`, replace the `let bars = Dictionary(...)` line with:

   ```swift
           let planBars = plannerDay.bars.filter { $0.kind == .plan }
   ```

2. Change the call `plannedSection(bars: bars)` to `plannedSection(planBars: planBars)`.
3. Replace the whole `plannedSection(bars:)` function with:

   ```swift
       private func plannedSection(planBars: [PlannerBar]) -> some View {
           VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
               if planBars.isEmpty {
                   Text("planner.day.planned.empty")
                       .foregroundStyle(.secondary)
               }
               ForEach(planBars) { bar in
                   PlannedCategoryCard(
                       bar: bar,
                       showsProgress: canLog,
                       onEdit: { item in editingPlan = plans.first(where: { $0.id.uuidString == item.id }) },
                       onLog: canLog && !bar.isFull ? { loggingSeed = PlanLogSeed(bar: bar, day: day) } : nil
                   )
               }
           }
       }
   ```

4. Change the type's doc comment to:

   ```swift
   /// One day in the Planner: its plans first, one card per category, then, on
   /// days with logged entries, a smaller list of those entries. Logging a
   /// category's plans opens Add Entry filled from them.
   ```

Keep everything else (queries, `items`, `canLog`, `plannerDay`, the toolbar, all
four `.sheet` modifiers, `PlannerLoggedEntryList`).

**Verify**: `grep -n "PlannedItemRow\|bars\[" Hugo/Features/Planner/Screens/PlannerDaySheet.swift` → no output.
**Verify**: `grep -rn "PlannedItemRow" Hugo HugoTests` → no output.
**Verify**: Planner tests → `** TEST SUCCEEDED **`; `PlanMatcherTests` has 11 tests, `PlanLogSeedTests` has 5.

### Step 6: String

Add one key to `Hugo/Resources/Localizable.xcstrings` (Xcode JSON: 2-space
indent, `" : "` between key and value, keys in alphabetical order, so it goes
between `planner.plan.log.a11y` and `planner.plan.progress`; copy the shape of
the neighbouring entries):

| Key | English | Danish | Comment |
|---|---|---|---|
| `planner.plan.noStartTime` | No start time | Intet starttidspunkt | On a plan line in the Planner day sheet when the plan has no start time. |

Both localizations get `"state" : "translated"`. Do not change any other key.

**Verify**:
- JSON check → no output.
- `python3 -I -c "import json;d=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'];print(d['planner.plan.noStartTime']['localizations']['da']['stringUnit']['value'])"` → `Intet starttidspunkt`
- `git diff --numstat -- Hugo/Resources/Localizable.xcstrings` → about 18 lines added, 0 removed.

### Step 7: Glossary

In `CONTEXT.md`, under `## Planning`, replace the three entries **Covered time**,
**Unplanned time** and **Logging a plan** (shown in Current state) with:

```markdown
**Covered time**:
The part of a category's planned time on a day that logged time accounts for: first time in that category, then other time of the same kind (main or separate). Hugo matches per category, not per plan, and ignores start times, because an entry does not record whether its time was picked or guessed. The Planner draws each category's plans on a day as one bar, filled as far as the covered time goes. Time beyond the plans stays on that bar.

**Unplanned time**:
Logged time in a category that has no plan on that day and that no plan of the same kind took. It gets its own bar.

**Logging a plan**:
Opening Add Entry filled from a category's plans on a day: the category, the start time of the first plan not covered yet, and the planned time not covered yet. The user still saves the entry, and the plans stay.
```

Keep one blank line between entries.

**Verify**: `grep -c "ignores start times" CONTEXT.md` → `1`.

### Step 8: Full gate

**Verify**: `Scripts/verify.sh` → exit 0, and its output contains `** TEST SUCCEEDED **` and `** ANALYZE SUCCEEDED **`.

Commit 2 (stage by explicit path: `PlanMatcher.swift`, `PlannerMonth.swift`,
`PlanLogSeed.swift`, `PlannedCategoryCard.swift`, the deletion of
`PlannedItemRow.swift`, `PlannerDaySheet.swift`, the three test files,
`Localizable.xcstrings`, `CONTEXT.md`). Then `git status --short` must show only
`plans/` and `.claude/` entries.

## Test plan

- `PlanMatcherTests` (Step 2): one bar per category, extra time stays on the
  plan bar (regression for owner issue 2), start times do not change matching
  (the owner's two-plan example), bar order, extra time still fills another
  plan of the same kind first, an unplanned bar only for a category with no plan.
- `PlanLogSeedTests` (Step 3): whole, partial and rounded remaining time, and
  the start time of the first plan not covered yet, including a plan without one.
- `PlannerMonthTests.planBarsAgreeWithStillPlannedTimePerKind`: bars still agree
  with the header's still-planned time per kind.
- Manual (owner, simulator or device):
  1. Bars in the grid, the day sheet and the legend: the filled part has the
     same color as the outline.
  2. Plan 2 h Field Service today, log 4 h Field Service: the day shows one full
     bar; the card says "4 hours of 2 hours logged"; Log is hidden.
  3. Plan 2 h Field Service at 10:00 and 3 h at 14:00 for today: the grid shows
     one bar; the day sheet shows one card "5 hours / Field Service" with two
     lines. Tap each line: the right plan opens. Log 2 h 30 min at 14:00: the
     card says "2 hours, 30 minutes of 5 hours logged"; tap Log: Add Entry shows
     02:30 and 14:00.
  4. A day with one plan: the card looks as before and tapping it opens the plan.
  5. Log 1 h of a category with no plan that day: it gets its own full bar in
     the grid.
  6. VoiceOver: a multi-plan card's header reads the category, total and
     progress; each line reads its start time (or "No start time"), its
     duration and "Opens the plan".
  7. Danish: review "Intet starttidspunkt".

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `PlanMatcherTests` has 11 passing tests, `PlanLogSeedTests` 5
- [ ] `grep -rn "PlannedItemRow\|PlanLogSeed(item:" Hugo HugoTests` → no output
- [ ] `grep -n "opacity(0.55)" Hugo/Features/Planner/Views/PlannerBarView.swift` → no output
- [ ] `git diff --stat 4b01234..HEAD` lists only the in-scope files
- [ ] `git status --short` shows only `plans/` and `.claude/` entries
- [ ] `plans/README.md` status row updated (skip if a reviewer maintains it)

## STOP conditions

Stop and report back (do not improvise) if:

- The drift check lists a file and the live code no longer matches the
  "Current state" excerpts.
- `PlannerBar(` is constructed anywhere other than `PlanMatcher.swift`
  (`grep -rn "PlannerBar(" Hugo HugoTests`).
- `planBarsAgreeWithStillPlannedTimePerKind` fails after Step 2's change to it.
  Report the expected and actual numbers; do not change its expectations.
- Any test outside the three named test files fails.
- You find you need to change `PlannerDayCell`, `PlannedItem`, `AddEntryView`,
  `AddEntryFormModel` or anything under `Hugo/Persistence`.
- A step's verification fails twice after a reasonable fix attempt.

## Maintenance notes

- Bar ids are now `plan:<category key>`. Anything that keys on a bar id (for
  example a future scroll position or animation) must not assume it is a plan id.
- Repeating plans (README "Planner: next steps") produce more `PlannedItem`s per
  day; they join their category's bar without changes here.
- If time-based matching is ever wanted, it needs a stored "start time picked by
  the user" flag on `Entry` (schema change). Until then, keep start times out of
  `PlanMatcher`. The owner chose the simple rule on 2026-11-05.
- The suggestion pills idea (README) should offer one pill per category bar,
  built like `PlanLogSeed(bar:day:)`, not one per plan.
- `planner.plan.progress` and `planner.plan.log.a11y` keep their old comments
  and wording ("plan"); they read fine for a category's plans.
