# Plan 073: Move the Planner to the middle tab and simplify its calendar

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 34423ef..HEAD -- Hugo/App/AppRootView.swift Hugo/DesignSystem/Theme/Theme.swift Hugo/Features/Planner Hugo/Features/ServiceYear/Screens/ServiceYearView.swift Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift HugoTests/Features/Planner`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding. On a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1 (run before plan 070)
- **Effort**: S
- **Risk**: LOW (layout and drawing only; no data or math changes)
- **Depends on**: plans/069-planner-tab-and-calendar.md (DONE, merged as `34423ef`)
- **Category**: direction
- **Planned at**: commit `34423ef`, 2026-11-04

## Why this matters

The owner tested the first Planner build (plan 069) and asked for four changes
before the rest of the Planner is built on top of it. Doing them now means the
day sheet (plan 070) and the status header (plan 071) start from the final look
instead of being reworked later.

## Product rules (decided with the owner, do not change)

1. **Tab order**: Overview, Planner, Year (and Settings last in the iPad sidebar).
   The Planner is the middle tab.
2. **Title bar background**: like the Year tab, the navigation bar shows no
   background (scroll edge effect) while the visible month is scrolled to the
   top, and shows it once that month's page is scrolled.
3. **Day numbers line up across a row**: today's number, inside its filled
   circle, must sit at the same height as the other numbers in its week row.
4. **Bars carry no text or icons**: a calendar bar is a thin rounded strip,
   6 pt tall, outlined in the category color, with a translucent tint, filled
   from the left as time is logged. The details (category, hours) are in the
   day sheet that plan 070 adds. The "+N" line for days with more than three
   bars stays.

## Current state

- `Hugo/App/AppRootView.swift`, `AppTab` (the case order is the tab order, because
  the tabs come from `AppTab.allCases`):

  ```swift
  enum AppTab: String, CaseIterable, Identifiable, Hashable {
      case overview
      case year
      case planner
      case settings
  ```

- The Year tab's scroll-edge pattern to copy:
  - `Hugo/Features/ServiceYear/Screens/ServiceYearView.swift`:

    ```swift
    @State private var scrolledPages: [TheocraticYear.ID: Bool] = [:]
    ...
    private var isScrolledFromTop: Bool {
        scrolledPages[activeYear.id] ?? false
    }
    ...
    ServiceYearPageView(
        year: year,
        onScrolledFromTopChange: { newValue in
            scrolledPages[year.id] = newValue
        }
    )
    ...
    .navigationBarTitleDisplayMode(.inline)
    .scrollEdgeEffectHidden(!isScrolledFromTop, for: .top)
    ```

  - `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift`:

    ```swift
    var onScrolledFromTopChange: ((Bool) -> Void)? = nil
    ...
    init(year: TheocraticYear, onScrolledFromTopChange: ((Bool) -> Void)? = nil) {
        self.year = year
        self.onScrolledFromTopChange = onScrolledFromTopChange
        ...
    }
    ...
    ScrollView { ... }
    .frame(maxWidth: .infinity)
    .onScrollGeometryChange(for: Bool.self) { geometry in
        geometry.contentOffset.y + geometry.contentInsets.top > 0
    } action: { _, isScrolledFromTop in
        onScrolledFromTopChange?(isScrolledFromTop)
    }
    ```

- `Hugo/Features/Planner/Screens/PlannerView.swift`, `private struct PlannerPager`:
  `@State private var scrollPosition: YearMonth?`, `@State private var displayedMonth: YearMonth?`,
  `private var activeMonth: YearMonth { displayedMonth ?? currentMonth }`, and in `body`:

  ```swift
  ForEach(months, id: \.self) { month in
      PlannerMonthPage(month: month, today: today)
          .containerRelativeFrame(.horizontal)
  }
  ...
  .navigationTitle(activeMonth.monthYearString())
  .navigationSubtitle("tab.planner")
  .navigationBarTitleDisplayMode(.inline)
  .toolbar {
  ```

- `Hugo/Features/Planner/Views/PlannerMonthPage.swift`: `let month: YearMonth`,
  `let today: Date`, `init(month: YearMonth, today: Date)`, and a body of
  `ScrollView { VStack(spacing: HugoLayout.Spacing.card) { ... }.padding() }.frame(maxWidth: .infinity)`.
- `Hugo/Features/Planner/Views/PlannerCalendarGrid.swift`:

  ```swift
  private let columns = Array(
      repeating: GridItem(.flexible(), spacing: HugoLayout.Spacing.tight), count: 7)
  ```

  `GridItem`'s default alignment is `.center`, so a cell that is shorter than
  the tallest cell in its row is centered vertically. Cells have different
  heights when days have different numbers of bars, which moves their day
  numbers up or down. (The circle behind today's number is a `.background` and
  does not move the number.)
- `Hugo/Features/Planner/Views/PlannerDayCell.swift`: a `VStack(spacing: HugoLayout.Spacing.tight)`
  of the number (fixed `numberDiameter` frame, circle in `.background` for today),
  `ForEach(visibleBars) { bar in PlannerBarView(bar: bar) }`, and the "+N" text;
  `.frame(maxWidth: .infinity, minHeight: minHeight, alignment: .top)`. No change needed here.
- `Hugo/Features/Planner/Views/PlannerBarView.swift`:

  ```swift
  /// One plan, or unplanned logged time, in a calendar day.
  struct PlannerBarView: View {
      let bar: PlannerBar

      @ScaledMetric(relativeTo: .caption2) private var height = HugoLayout.Size.calendarBarHeight

      private var color: Color {
          guard let color = bar.color else { return .hugoAccent }
          return Color(hue: color.hue, saturation: color.saturation, brightness: color.brightness)
      }

      var body: some View {
          let hours = Text(PlannerHoursText.short(bar.seconds)).monospacedDigit()
          let icon = Image(systemName: bar.categoryIconName)
          ViewThatFits(in: .horizontal) {
              HStack(spacing: 2) {
                  icon
                  hours
              }
              hours
              icon
          }
          .font(.caption2)
          .fontWeight(.semibold)
          .lineLimit(1)
          .foregroundStyle(.primary)
          .padding(.horizontal, 3)
          .frame(maxWidth: .infinity, minHeight: height)
          .background { PlannerBarShape(fraction: bar.fraction, color: color) }
      }
  }
  ```

  `PlannerBarShape` (same file, above it) draws the outline, tint and fill; keep it unchanged.
- `Hugo/Features/Planner/Views/PlannerLegend.swift` draws each sample with
  `PlannerBarShape(fraction: fraction, color: .hugoAccent).frame(width: 24, height: 12)`.
- `Hugo/DesignSystem/Theme/Theme.swift`, `HugoLayout.Size`:
  `static let calendarBarHeight: CGFloat = 16`.
- `Hugo/Features/Planner/Domain/PlannerHoursText.swift` and
  `HugoTests/Features/Planner/Domain/PlannerHoursTextTests.swift`: the short hours
  text used only by `PlannerBarView`. After Step 4 nothing uses it.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Layout | `Scripts/check-layout.sh` | exit 0, no output |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:
- `Hugo/App/AppRootView.swift`
- `Hugo/DesignSystem/Theme/Theme.swift`
- `Hugo/Features/Planner/Screens/PlannerView.swift`
- `Hugo/Features/Planner/Views/PlannerMonthPage.swift`
- `Hugo/Features/Planner/Views/PlannerCalendarGrid.swift`
- `Hugo/Features/Planner/Views/PlannerBarView.swift`
- `Hugo/Features/Planner/Views/PlannerLegend.swift`
- Delete: `Hugo/Features/Planner/Domain/PlannerHoursText.swift`,
  `HugoTests/Features/Planner/Domain/PlannerHoursTextTests.swift`

**Out of scope**:
- `PlannerDayCell.swift` (its layout is fine once the grid aligns rows to the top),
  `PlannerBarShape` (keep as is), every Domain type, `Localizable.xcstrings`.
- `ServiceYearView`, `ServiceYearPageView`: patterns to copy, not files to change.
- Tapping days (plan 070), the status header (plan 071).

## Git workflow

- Branch: `advisor/073-planner-calendar-polish`
- Conventional Commits, for example `fix: align planner days and show bars without text`
  and `feat: make the planner the middle tab`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Make the Planner the middle tab

In `AppTab`, move `case planner` above `case year`, so the cases read
`overview`, `planner`, `year`, `settings`. Do not reorder the `switch` cases
in the computed properties unless swift-format asks for it (order inside a
`switch` does not matter).

**Verify**: `grep -n "^    case " Hugo/App/AppRootView.swift` → `overview`, `planner`, `year`, `settings` in that order.

### Step 2: Hide the title bar background until the month is scrolled

`PlannerMonthPage`:
1. Add `var onScrolledFromTopChange: ((Bool) -> Void)? = nil` after `let today: Date`.
2. Change the init to `init(month: YearMonth, today: Date, onScrolledFromTopChange: ((Bool) -> Void)? = nil)`
   and assign the new property.
3. After `.frame(maxWidth: .infinity)` on the `ScrollView`, add the same
   `.onScrollGeometryChange(for: Bool.self) { ... } action: { ... }` as
   `ServiceYearPageView` (see "Current state").

`PlannerPager` (in `PlannerView.swift`):
1. Add `@State private var scrolledPages: [YearMonth: Bool] = [:]`.
2. Add `private var isScrolledFromTop: Bool { scrolledPages[activeMonth] ?? false }`.
3. Build each page as
   `PlannerMonthPage(month: month, today: today, onScrolledFromTopChange: { scrolledPages[month] = $0 })`.
4. Add `.scrollEdgeEffectHidden(!isScrolledFromTop, for: .top)` directly after
   `.navigationBarTitleDisplayMode(.inline)`.

**Verify**: `grep -n "scrollEdgeEffectHidden" Hugo/Features/Planner/Screens/PlannerView.swift` → one match;
`grep -n "onScrollGeometryChange" Hugo/Features/Planner/Views/PlannerMonthPage.swift` → one match.

### Step 3: Align day cells to the top of their row

In `PlannerCalendarGrid`, give the grid items top alignment:

```swift
private let columns = Array(
    repeating: GridItem(.flexible(), spacing: HugoLayout.Spacing.tight, alignment: .top), count: 7)
```

**Verify**: `grep -n "alignment: .top" Hugo/Features/Planner/Views/PlannerCalendarGrid.swift` → one match.

### Step 4: Bars without text or icons

1. `HugoLayout.Size.calendarBarHeight`: change `16` to `6`.
2. Replace `PlannerBarView` (keep `PlannerBarShape` above it untouched) with:

   ```swift
   /// One plan, or unplanned logged time, in a calendar day: a thin bar that
   /// fills from the left. The day sheet shows the category and hours.
   struct PlannerBarView: View {
       let bar: PlannerBar

       @ScaledMetric(relativeTo: .caption2) private var height = HugoLayout.Size.calendarBarHeight

       private var color: Color {
           guard let color = bar.color else { return .hugoAccent }
           return Color(hue: color.hue, saturation: color.saturation, brightness: color.brightness)
       }

       var body: some View {
           PlannerBarShape(fraction: bar.fraction, color: color)
               .frame(maxWidth: .infinity)
               .frame(height: height)
       }
   }
   ```

3. `PlannerLegend`: change the sample frame from `height: 12` to `height: 6`.
4. Delete `Hugo/Features/Planner/Domain/PlannerHoursText.swift` and
   `HugoTests/Features/Planner/Domain/PlannerHoursTextTests.swift` with `git rm`.

**Verify**: `grep -rn "PlannerHoursText" Hugo HugoTests` → no matches;
`grep -n "calendarBarHeight: CGFloat = 6" Hugo/DesignSystem/Theme/Theme.swift` → one match.

### Step 5: Full gate

**Verify**: `Scripts/check-layout.sh` → exit 0; lint → exit 0; `Scripts/verify.sh` → exit 0.

## Test plan

- No new automated tests: nothing in the Domain changes, and the removed suite
  tested only the deleted formatter.
- Manual (owner, simulator or device):
  - The tab bar reads Overview, Planner, Year.
  - On the Planner, the title bar has no background at rest; scrolling a month
    down shows it; swiping to another month that is at the top hides it again.
  - In the week row that contains today, today's number lines up with its
    neighbors, also when today has more or fewer bars than they do.
  - Bars are thin strips with no text or icon; a partly logged plan is partly filled;
    a day with four bars shows two and "+2".

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -rn "PlannerHoursText" Hugo HugoTests` → no matches
- [ ] The four grep checks in Steps 1-4 return what they say
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The excerpts in "Current state" do not match the live code.
- `scrollEdgeEffectHidden` or `onScrollGeometryChange` does not compile here
  (they compile in `ServiceYearView`; a failure means something else is wrong).
- Something other than `PlannerBarView` uses `PlannerHoursText` (then keep the
  file and report).
- You feel a need to change `PlannerDayCell` or `PlannerBarShape`.

## Maintenance notes

- Plans 070 and 071 were refreshed for this plan: 070 wraps the cells in
  buttons and adds the day sheet; 071 adds parameters to `PlannerMonthPage`
  and must keep passing `onScrolledFromTopChange`.
- If the owner later wants hours back in the calendar, add them below the bars
  as one day total, not inside each bar.
- If today's number still looks misaligned after this plan, ask the owner for a
  screenshot; the remaining suspect would be the font's line height inside the
  fixed number frame.
