# Plan 109: Keep text readable at the largest accessibility text sizes

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 3055ae6..HEAD -- Hugo/Features/Settings/Views/CurrentPublisherStatusView.swift Hugo/Features/Overview/Views/ReportReminderCard.swift Hugo/Features/Entries/Views/EntryRow.swift Hugo/Features/Reports/Views/MonthlyReportTotalsView.swift Hugo/Features/Planner/Views/PlannerStatusHeader.swift Hugo/DesignSystem/Components/EditorialNavigationTitle.swift Hugo/Features/Planner/Screens/PlannerView.swift Hugo/Features/ServiceYear/Screens/ServiceYearView.swift`
> Plan 108 (SLN-161, minutes for totals under one hour) runs before this plan
> and is expected to change how durations are formatted inside
> `MonthlyReportTotalsView.swift` and `PlannerStatusHeader.swift`. Changes to
> the duration *values* (the `ServiceDurationFormatter` calls and the text they
> produce) are expected and fine: keep whatever value expressions are there and
> change only the layout code this plan describes. Any other mismatch with the
> excerpts below is a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S + owner (check on a device at the largest text size)
- **Risk**: LOW. Layout only, no logic, no data, no new strings.
- **Depends on**: none. Run after plan 108, which touches two of the same files.
- **Category**: bug (accessibility)
- **Planned at**: commit `3055ae6`, 2026-11-13
- **Issue**: [SLN-188](https://linear.app/sebastianln/issue/SLN-188)

## Why this matters

Many of Hugo's users are older, and some use iOS's Larger Accessibility Sizes (Settings → Accessibility → Display & Text Size → Larger Text). At those sizes six places in Hugo break: a symbol stays small, an icon spills out of its fixed frame, two rows squeeze their text into narrow columns that wrap word by word, one view has an accessibility layout that does nothing, and the toolbar titles get cut off.

The issue was written in August 2026. The views have changed a lot since (plans 054–101), so this plan was checked against `3055ae6`. Some of the original claims no longer hold, and "Findings rejected" at the end says why.

## Current state

Spacing and size tokens live in `Hugo/DesignSystem/Theme/Theme.swift` (`HugoLayout`): `Spacing.tight` 4, `small` 6, `compact` 8, `regular` 12, `spacious` 16, `card` 24; `Size.entryIcon` 32, `Size.prominentSymbol` 64.

Patterns already in the codebase that this plan copies:

- **`@ScaledMetric` for fixed sizes**, for example `Hugo/Features/Categories/Screens/CategoryDetailView.swift:10`:
  `@ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = HugoLayout.Size.categoryIcon`
- **`ViewThatFits` for a label/value row**, `Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift:32-44`:

  ```swift
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        label
                        Spacer(minLength: HugoLayout.Spacing.regular)
                        actualTotal
                    }
                    VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                        label
                        actualTotal
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
  ```

- **Capping Dynamic Type**, `Hugo/Features/ServiceYear/Views/TheocraticYearPicker.swift:46`: `.dynamicTypeSize(...DynamicTypeSize.xxLarge)`.

### Problem 1: fixed-size symbol on the publisher status page

`Hugo/Features/Settings/Views/CurrentPublisherStatusView.swift:19-23`:

```swift
            Image(
                systemName: PublisherStatus.status(for: currentStatus) != nil
                    ? "person.crop.circle.badge.checkmark" : "person.crop.circle"
            )
            .font(.system(size: HugoLayout.Size.prominentSymbol))
```

The symbol is always 64 pt while the text under it grows.

### Problem 2: report reminder card on the Overview

`Hugo/Features/Overview/Views/ReportReminderCard.swift:19-45`. The badge circle is a fixed 64 pt, but the `.title2` symbol inside it grows past the circle. The badge and the text sit side by side in an `HStack`, so at accessibility sizes the text gets a narrow column:

```swift
            HStack(alignment: .top, spacing: HugoLayout.Spacing.spacious) {
                ZStack(alignment: .center) {
                    Circle()
                        .fill(.hugoAccent)
                        .frame(width: HugoLayout.Size.prominentSymbol, height: HugoLayout.Size.prominentSymbol)
                    Image(systemName: "doc.badge.clock.fill")
                        .foregroundStyle(.white)
                        .font(.title2)
                }

                VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
                    ...
                }
                .padding(.top, HugoLayout.Spacing.compact)
            }
```

### Problem 3: entry rows in the Overview list

`Hugo/Features/Entries/Views/EntryRow.swift:19-42` (used by `OverviewListView.swift:97`). The `.title2` icon grows, but both frames around it stay 32 pt. The duration ("23 hours, 15 min") and the category name sit side by side, so at accessibility sizes both wrap into narrow columns:

```swift
            HStack(spacing: HugoLayout.Spacing.spacious) {
                ZStack {
                    Image(systemName: category.iconName)
                        .font(.title2)
                        .fontWeight(.medium)
                        .frame(width: HugoLayout.Size.entryIcon, height: HugoLayout.Size.entryIcon)
                        .alignmentGuide(
                            ...
                        )
                }
                .frame(width: HugoLayout.Size.entryIcon, height: HugoLayout.Size.entryIcon)
                VStack(alignment: .leading) {
                    HStack(spacing: HugoLayout.Spacing.small) {
                        Text(ServiceDurationFormatter.string(from: entry.duration))
                            .fontWeight(.bold)
                        Text(category.name)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                    .font(.body)
```

### Problem 4: the month detail totals have an accessibility branch that does nothing

`Hugo/Features/Reports/Views/MonthlyReportTotalsView.swift:7-33`:

```swift
    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) { totals }
            } else {
                totals
            }
        }
        .padding(HugoLayout.Spacing.compact)
    }

    @ViewBuilder
    private var totals: some View {
        HStack(alignment: .bottom) {
            total(
                ServiceDurationFormatter.hoursString(from: summary.mainDuration),
                label: "monthlyReport.detail.largeTotal.main.label", alignment: .leading)
            Spacer()
            total(
                ServiceDurationFormatter.hoursString(from: summary.totalSeconds),
                label: "monthlyReport.detail.largeTotal.total.label", alignment: .center, prominent: true)
            Spacer()
            total(
                ServiceDurationFormatter.hoursString(from: summary.separateDuration),
                label: "monthlyReport.detail.largeTotal.separate.label", alignment: .trailing)
        }
    }
```

`totals` is one `HStack`, so wrapping it in a `VStack` changes nothing: the three totals stay side by side at every size. `total(...)` (lines 35-51) gives each value `.frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .bottom))`.

### Problem 5: the Planner header's "Projected / Target" row

`Hugo/Features/Planner/Views/PlannerStatusHeader.swift:18-31`:

```swift
                HStack(alignment: .firstTextBaseline) {
                    Text("planner.header.projected.label")
                    Spacer(minLength: HugoLayout.Spacing.regular)
                    if let targetSeconds = status.targetSeconds {
                        Text(
                            String(
                                localized: "planner.header.target",
                                defaultValue: "Target \(ServiceDurationFormatter.hoursString(from: targetSeconds))",
                                comment: "The monthly target. The argument is a duration such as 50 hours.")
                        )
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
```

The same file already uses `ViewThatFits` for its legend (lines 42-50). This row does not, so at accessibility sizes both labels wrap word by word.

### Problem 6: toolbar titles get cut off

Four custom titles sit in `ToolbarItem(placement: .principal)`. Each is `.headline` serif with `.lineLimit(1)` and `.minimumScaleFactor(0.75)`. At the largest sizes "November 2026" no longer fits even at 75 %, and it gets truncated. iOS's own navigation bar titles stop growing at a certain size and offer the Large Content Viewer (long-press shows the title enlarged in the middle of the screen). These titles should behave the same way.

- `Hugo/DesignSystem/Components/EditorialNavigationTitle.swift` (whole file), used by `MonthlyReportDetailView.swift:40` and `ServiceYearDetailView.swift:24`:

  ```swift
  struct EditorialNavigationTitle: View {
      let title: String

      var body: some View {
          Text(title)
              .font(.system(.headline, design: .serif, weight: .bold))
              .lineLimit(1)
              .minimumScaleFactor(0.75)
      }
  }
  ```

- `Hugo/Features/Planner/Screens/PlannerView.swift:107-112`, a copy of the same title written inline:

  ```swift
                ToolbarItem(placement: .principal) {
                    Text(activeMonth.monthYearString())
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
  ```

  `activeMonth` is a `YearMonth`; `monthYearString()` returns `String`.

- `Hugo/Features/ServiceYear/Screens/ServiceYearView.swift:45-66`, the year title (`activeYear` is a `TheocraticYear`, which has `displayName`, for example "2026/2027"):

  ```swift
      private var yearTitle: some View {
          HStack(spacing: 0) {
              Text(String(activeYear.startYear))
                  ...
          }
          .font(.system(.headline, design: .serif, weight: .bold))
          .lineLimit(1)
          .minimumScaleFactor(0.75)
          .monospacedDigit()
      }

      private var yearTitleChevron: some View {
          Image(systemName: "chevron.down")
              .font(.caption.weight(.bold))
              .foregroundStyle(.secondary)
      }
  ```

  Both are used in the principal toolbar item at lines 101-126 (inside a `Button` when there is more than one year, plain otherwise).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Full gate (before the commit) | `Scripts/verify.sh` | exit 0 |
| Whitespace | `git diff --check` | exit 0 |

Use 4-space indentation. Tabs fail the lint.

## Suggested executor toolkit

- If the `write-swift` skill is available, use it for the `AnyLayout` code in steps 2-4.

## Scope

**In scope** (the only files you may modify):

- `Hugo/Features/Settings/Views/CurrentPublisherStatusView.swift`
- `Hugo/Features/Overview/Views/ReportReminderCard.swift`
- `Hugo/Features/Entries/Views/EntryRow.swift`
- `Hugo/Features/Reports/Views/MonthlyReportTotalsView.swift`
- `Hugo/Features/Planner/Views/PlannerStatusHeader.swift`
- `Hugo/DesignSystem/Components/EditorialNavigationTitle.swift`
- `Hugo/Features/Planner/Screens/PlannerView.swift` (the principal toolbar item only)
- `Hugo/Features/ServiceYear/Screens/ServiceYearView.swift` (`yearTitle` and `yearTitleChevron` only)

**Out of scope**:

- The `.minimumScaleFactor` on the big numbers in `MonthlyProgressCard`, `PlannerStatusHeader` (line 13), `TheocraticYearTotalsView` and `MonthlyReportTotalsView` (line 45). See "Findings rejected".
- Any duration formatting (`ServiceDurationFormatter` and what it returns). That is plan 108's work.
- `HugoLayout` tokens. Add none, change none.
- `Localizable.xcstrings`. No new strings are needed.
- `Hugo.xcodeproj/project.pbxproj`, `.claude/`, `Changelog/` and `plans/` (except this plan's README row). Never stage them.

## Git workflow

- Work on `main`. No branch, no worktree, no push. Stage files by path.
- One commit after `Scripts/verify.sh` exits 0: `fix: keep text readable at the largest accessibility text sizes`.

## Steps

### Step 1: Scale the publisher status symbol

In `CurrentPublisherStatusView`, add next to `var currentStatus: String`:

```swift
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = HugoLayout.Size.prominentSymbol
```

and change `.font(.system(size: HugoLayout.Size.prominentSymbol))` to `.font(.system(size: symbolSize))`.

**Verify**: `grep -n "prominentSymbol" Hugo/Features/Settings/Views/CurrentPublisherStatusView.swift` → exactly one match, on the `@ScaledMetric` line.

### Step 2: Scale the reminder badge and stack the card at accessibility sizes

In `ReportReminderCard`:

1. Add two properties next to `@State private var isPresentingSubmitSheet`:

   ```swift
       @Environment(\.dynamicTypeSize) private var dynamicTypeSize
       @ScaledMetric(relativeTo: .title2) private var badgeSize: CGFloat = HugoLayout.Size.prominentSymbol
   ```

2. Add a computed property below `monthName`:

   ```swift
       /// Badge beside the text normally; badge above the text at accessibility
       /// sizes, so the text keeps the card's full width.
       private var cardLayout: AnyLayout {
           dynamicTypeSize.isAccessibilitySize
               ? AnyLayout(VStackLayout(alignment: .leading, spacing: HugoLayout.Spacing.regular))
               : AnyLayout(HStackLayout(alignment: .top, spacing: HugoLayout.Spacing.spacious))
       }
   ```

3. Replace `HStack(alignment: .top, spacing: HugoLayout.Spacing.spacious) {` with `cardLayout {`. Leave its contents as they are.
4. In the `Circle()`, change `.frame(width: HugoLayout.Size.prominentSymbol, height: HugoLayout.Size.prominentSymbol)` to `.frame(width: badgeSize, height: badgeSize)`.

**Verify**: `grep -n "HStack(alignment: .top\|HugoLayout.Size.prominentSymbol" Hugo/Features/Overview/Views/ReportReminderCard.swift` → matches only inside `cardLayout` and on the `@ScaledMetric` line.

### Step 3: Scale the entry icon and stack duration and category at accessibility sizes

In `EntryRow`:

1. Add next to `@Environment(\.colorScheme) var colorScheme`:

   ```swift
       @Environment(\.dynamicTypeSize) private var dynamicTypeSize
       @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = HugoLayout.Size.entryIcon
   ```

2. Add a computed property below `category`:

   ```swift
       /// Duration and category name on one line normally; on two lines at
       /// accessibility sizes, so neither wraps word by word.
       private var titleLayout: AnyLayout {
           dynamicTypeSize.isAccessibilitySize
               ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
               : AnyLayout(HStackLayout(spacing: HugoLayout.Spacing.small))
       }
   ```

3. Change both `.frame(width: HugoLayout.Size.entryIcon, height: HugoLayout.Size.entryIcon)` lines to `.frame(width: iconSize, height: iconSize)`.
4. Replace the inner `HStack(spacing: HugoLayout.Spacing.small) {` (the one holding the duration `Text` and `category.name`) with `titleLayout {`. Keep its modifiers (`.foregroundStyle(.primary)`, `.font(.body)`).

Leave the outer `HStack(spacing: HugoLayout.Spacing.spacious)`, the Bible studies column and the accessibility modifiers unchanged.

**Verify**: `grep -n "HugoLayout.Size.entryIcon\|HStack(spacing: HugoLayout.Spacing.small)" Hugo/Features/Entries/Views/EntryRow.swift` → only the `@ScaledMetric` line and the line inside `titleLayout`.

### Step 4: Make the month detail totals actually stack

In `MonthlyReportTotalsView`, replace `body` and `totals` (lines 7-33 at `3055ae6`) with one `body` that switches the layout itself. Keep the three `total(...)` calls' first arguments exactly as they are in the live file (plan 108 may have changed them); only the `alignment:` arguments and the surrounding layout change:

```swift
    var body: some View {
        // Side by side normally; one under the other at accessibility sizes.
        let isStacked = dynamicTypeSize.isAccessibilitySize
        let layout =
            isStacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: HugoLayout.Spacing.regular))
            : AnyLayout(HStackLayout(alignment: .bottom))
        layout {
            total(
                ServiceDurationFormatter.hoursString(from: summary.mainDuration),
                label: "monthlyReport.detail.largeTotal.main.label", alignment: .leading)
            if !isStacked { Spacer() }
            total(
                ServiceDurationFormatter.hoursString(from: summary.totalSeconds),
                label: "monthlyReport.detail.largeTotal.total.label", alignment: isStacked ? .leading : .center,
                prominent: true)
            if !isStacked { Spacer() }
            total(
                ServiceDurationFormatter.hoursString(from: summary.separateDuration),
                label: "monthlyReport.detail.largeTotal.separate.label", alignment: isStacked ? .leading : .trailing)
        }
        .padding(HugoLayout.Spacing.compact)
    }
```

The `Spacer`s are left out when stacked, because in a vertical stack they would push the totals apart vertically. Leave `total(_:label:alignment:prominent:)` unchanged. Let swift-format decide the line breaks (`xcrun swift-format format -i <file>` is allowed on this file if lint complains about line length).

**Verify**: `grep -n "Group {\|private var totals" Hugo/Features/Reports/Views/MonthlyReportTotalsView.swift` → no matches.

### Step 5: Let the Planner's "Projected / Target" row stack

In `PlannerStatusHeader`:

1. Replace the `HStack(alignment: .firstTextBaseline) { ... }` at lines 18-31 (find it by `planner.header.projected.label`), together with its `.font(.subheadline)` and `.foregroundStyle(.secondary)`, with:

   ```swift
                   // Side by side when both fit on one line; otherwise stacked.
                   ViewThatFits(in: .horizontal) {
                       HStack(alignment: .firstTextBaseline) {
                           projectedLabel
                           Spacer(minLength: HugoLayout.Spacing.regular)
                           targetLabel
                       }
                       VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                           projectedLabel
                           targetLabel
                       }
                   }
                   .font(.subheadline)
                   .foregroundStyle(.secondary)
   ```

2. Add two private properties to the struct (next to its other helpers, for example above `legendItems`). Move the target `Text` into `targetLabel` as it is in the live file, including its `String(localized:defaultValue:comment:)` call:

   ```swift
       private var projectedLabel: some View {
           Text("planner.header.projected.label")
       }

       @ViewBuilder
       private var targetLabel: some View {
           if let targetSeconds = status.targetSeconds {
               Text(
                   String(
                       localized: "planner.header.target",
                       defaultValue: "Target \(ServiceDurationFormatter.hoursString(from: targetSeconds))",
                       comment: "The monthly target. The argument is a duration such as 50 hours.")
               )
           }
       }
   ```

   The string key, default value and comment must stay byte-for-byte the same, or the string catalog will see a new string.

**Verify**: `grep -c "planner.header.target\"" Hugo/Features/Planner/Views/PlannerStatusHeader.swift` → `1`. `git diff --stat -- Hugo/Resources/Localizable.xcstrings` → no output after a build (Step 7 builds).

### Step 6: Cap the toolbar titles and offer the Large Content Viewer

1. `EditorialNavigationTitle`: add two modifiers after `.minimumScaleFactor(0.75)`:

   ```swift
               // Like the system navigation bar: stop growing at the largest
               // standard size, and show the title enlarged on long-press.
               .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
               .accessibilityShowsLargeContentViewer()
   ```

2. `PlannerView`: replace the principal item's `Text(activeMonth.monthYearString())` and its three modifiers with `EditorialNavigationTitle(title: activeMonth.monthYearString())`. Keep `.navigationTitle(activeMonth.monthYearString())` and everything else.
3. `ServiceYearView`:
   - In `yearTitle`, add after `.monospacedDigit()`:

     ```swift
             .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
             .accessibilityShowsLargeContentViewer {
                 Text(activeYear.displayName)
             }
     ```

   - In `yearTitleChevron`, add `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)` after `.foregroundStyle(.secondary)`.

   Do not change the `Button`, its accessibility label, value and hint, or the popover.

**Verify**: `grep -rn "minimumScaleFactor(0.75)" Hugo` → two matches (`EditorialNavigationTitle.swift` and `ServiceYearView.swift`). `grep -rn "accessibilityShowsLargeContentViewer" Hugo` → two matches (same two files).

### Step 7: Run the gate and commit

**Verify**: `Scripts/verify.sh` exits 0 (lint, all tests, analyze). `git diff --stat` lists only the eight in-scope files (plus the owner's untouched `Changelog/` changes, which you must not stage). `git diff --check` exits 0. Commit with the message from "Git workflow".

## Test plan

These are layout-only changes with no logic, so no unit test fits. The existing suite must stay green. The owner checks the result on a device (see Maintenance notes). Accessibility regression tests are a separate backlog issue (SLN-214).

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `git show --stat HEAD` lists only the eight in-scope files
- [ ] `grep -rn "\.system(size: HugoLayout" Hugo` returns no matches
- [ ] `grep -rn "accessibilityShowsLargeContentViewer" Hugo` returns two matches
- [ ] `grep -n "isAccessibilitySize" Hugo/Features/Overview/Views/ReportReminderCard.swift Hugo/Features/Entries/Views/EntryRow.swift Hugo/Features/Reports/Views/MonthlyReportTotalsView.swift` returns one match per file
- [ ] `git diff HEAD~1 -- Hugo/Resources/Localizable.xcstrings` is empty
- [ ] `plans/README.md` row for 109 updated

## STOP conditions

- The drift check shows changes other than plan 108's duration formatting, and the excerpts no longer match.
- A build adds, removes or marks stale any key in `Localizable.xcstrings`.
- `AnyLayout` with an `if` inside its content (Step 4) does not compile, and wrapping the conditional `Spacer` in a `Group` does not fix it.
- `accessibilityShowsLargeContentViewer` does not compile on `yearTitle`. Report it; do not swap in a different accessibility API.
- The change seems to need a file outside the in-scope list.

## Maintenance notes

- **Owner device check.** Turn on Settings → Accessibility → Display & Text Size → Larger Text and drag the slider to the largest size (AX5). Then check, in English and Danish:
  - Overview, list sorted by entry: the icons fit, and duration and category name sit on two lines.
  - Overview with a report due: the reminder card shows its badge above the text, and the symbol fits inside the badge.
  - Planner: the header shows "Projected" and "Target" on two lines, and the month title isn't cut off. Long-press the title: the Large Content Viewer shows it enlarged.
  - Year tab: the year title isn't cut off, and long-pressing it shows the enlarged year. Tapping it still opens the year picker.
  - Year tab → a month's menu → details: the three totals are listed one under the other, and the title fits.
  - Year tab → tap the header: the detail screen's title fits.
  - Settings → Publisher status: the symbol at the top grows with the text.
  - Then set the slider back to the default size and confirm nothing changed there.
- **Quick check without a device**: in Xcode's canvas, switch to Variants → Dynamic Type Variants on any of these views' previews, or use Environment Overrides → Text in the debug bar while running.
- Other toolbar titles added later should use `EditorialNavigationTitle`, so they get the cap and the Large Content Viewer for free.

## Findings rejected

- **"The hero number shrinks as text gets bigger"** (`MonthlyProgressCard.swift:23-26`, and the same pattern in `PlannerStatusHeader.swift:10-14`, `TheocraticYearTotalsView.swift:17-21` and `MonthlyReportTotalsView.swift:40-45`). Each number uses a font that grows with Dynamic Type (`@ScaledMetric` or a text style). `minimumScaleFactor` only shrinks the text when it would not fit on its one line, so the number never gets smaller as the text size goes up. It is a safety net against truncation. Keep it. After plan 108, the Overview circle may show "45 min" instead of a bare number, which is longer; the factor is what keeps that readable inside the circle.
- **"`MonthlyReportTotalsView` and `TheocraticYearTotalsView` are the only views that branch on accessibility size"**: no longer true. `SelectableOptionRow`, `PlannerStatusHeader` (legend), `TheocraticYearTotalsView` and `ReportingLineCard` handle it, and `MonthlyReportTotalsView`'s branch was broken (Problem 4).
- **"Card layouts don't adapt"**: `ServiceYearMonthRow` and the Year header stack their content vertically already. The cards that did not adapt are the reminder card (Problem 2) and the entry row (Problem 3).
