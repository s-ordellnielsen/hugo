# Plan 111: Explain carried-in time on the Overview and keep carried-in entries out of the month's entry list

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 3055ae6..HEAD -- Hugo/Features/Overview/Views/OverviewListView.swift Hugo/Features/Reports/Views/MonthlyReportEntryListView.swift Hugo/Features/Reports/Domain Hugo/Resources/Localizable.xcstrings HugoTests/Features/Reports/Domain`
> Expected: no output. If a file is listed, compare the "Current state"
> excerpts below with the live code. A mismatch is a STOP condition. Changes
> to `Localizable.xcstrings` from other plans are fine as long as the three
> keys named in this plan are unchanged.

## Status

- **Priority**: P2
- **Effort**: S + owner (look at it on a device, review the Danish)
- **Risk**: LOW. Views and one small value type. No schema change, no change to how time is counted or reported.
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `3055ae6`, 2026-11-13
- **Issue**: [SLN-237](https://linear.app/sebastianln/issue/SLN-237)
- **Revision 1** (2026-11-14, after Steps 1-4 landed as `f0a397f` and `b0ac48c`): the owner looked at it on their iPhone. Tapping the Overview line should not open the Rounding help. It should open a small sheet that lists which categories the carried-in time belongs to and how much each has. The line's text should be centered, as the old pill was. Everything else stays. **Execute only Step 5**; Steps 1-4 are done.
- **Revision 2** (2026-11-14, after Step 5 landed as `2424ba2`): the owner looked at the sheet on their iPhone. The "… transferred from …" sentence should be larger and serif, and sit at the top of the sheet: no navigation title and no Done button. The list gets a section header ("Breakdown"), and the footer goes. **Execute only Step 6**; Steps 1-5 are done.

## Why this matters

When a user transfers a line's remainder while submitting a report, Hugo creates a **carried-in entry** on the 1st of the next month. Two places still handle that poorly:

1. **The Overview** shows a gray pill, "Carried in from previous month: 30m". It doesn't say which month the time came from, and nothing explains what it is. Many of Hugo's users are older and need the app to explain itself.
2. **The month detail** (Year tab → a month's "…" menu → Details) lists carried-in entries as if they were ordinary entries. They can be tapped and edited there, even though Hugo manages them: the next submission of the source month overwrites or deletes them.

After this plan, every place shows carried-in time as one non-editable line in the same words the Submit Report screen already uses: "30 minutes transferred from October" (Danish: "30 minutter overført fra oktober"). On the Overview, tapping the line opens the existing Rounding help, which explains transfers.

## Current state

Glossary terms from `CONTEXT.md` to use in names and comments:

- **Carried-in entry**: "An entry Hugo creates on the 1st of the next month to hold minutes that were transferred." _Avoid_: generated entry, carry entry.
- **Transfer**: "The rounding rule that moves a reporting line's remainder into the next month."
- **Remainder**: "The minutes on a reporting line beyond its whole hours."

How a carried-in entry is recognized: `Entry.isCarriedIn` in `Hugo/Persistence/SchemaVersions/V13/EntryV13.swift:55-57`:

```swift
        var isCarriedIn: Bool {
            sourceReportYear != nil && sourceReportMonth != nil
        }
```

`sourceReportYear` and `sourceReportMonth` (both `Int?`) name the month whose report transferred the time.

### Overview

`Hugo/Features/Overview/Views/OverviewListView.swift`. The list already splits carried-in entries off (lines 20 and 47-54):

```swift
        let groups = OverviewEntryGroups(entries)
...
                if listStyle == .byEntry {
                    OverviewEntryList(entries: groups.regular, selectedEntry: $selectedEntry)
                } else if listStyle == .byDate {
                    OverviewDateList(entries: groups.regular, selectedEntry: $selectedEntry)
                }
                if !groups.carried.isEmpty {
                    OverviewCarriedEntriesView(entries: groups.carried)
                }
```

The pill (lines 234-259):

```swift
struct OverviewCarriedEntriesView: View {
    var entries: [Entry]

    private var totalDuration: Duration {
        entries.reduce(into: .zero) { total, entry in
            total += .seconds(entry.duration)
        }
    }

    var body: some View {
        HStack(spacing: HugoLayout.Spacing.tight) {
            Text(
                "overview.carried.summary.label"
            )
            Text(totalDuration.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                .fontWeight(.semibold)
        }
        .font(.caption)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray5))
        .foregroundStyle(.secondary)
        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
        .accessibilityElement(children: .combine)
    }
}
```

`overview.carried.summary.label` is "Carried in from previous month:" / "Overført fra forrige måned:". `OverviewCarriedEntriesView` and that key are used nowhere else (`grep -rn "OverviewCarriedEntriesView\|overview.carried" Hugo` finds only this file and the catalog).

### Month detail

`Hugo/Features/Reports/Views/MonthlyReportEntryListView.swift` (whole file). It is shown by `MonthlyReportDetailView`, which the Year tab's month card opens:

```swift
import SwiftUI

struct MonthlyReportEntryListView: View {
    let month: ServiceMonth

    var body: some View {
        Section {
            ForEach(month.summary?.entries ?? []) { entry in
                NavigationLink(destination: EntryDetailView(entry: entry)) {
                    Label {
                        HStack {
                            Text(entry.date, format: Date.FormatStyle(date: .abbreviated, time: .none))
                            Spacer()
                            if month.isUnreported(entry) {
                                Image(systemName: "exclamationmark.triangle.fill")

                                    .font(.caption)
                            }
                            Text(ServiceDurationFormatter.string(from: entry.duration))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: entry.resolvedCategory().iconName)
                    }
                }
            }
        }
    }
}
```

### Wording and glyph to reuse

The Submit Report screen already says this, in `Hugo/Features/Reports/Views/ReportingLineCard.swift:63-80`:

```swift
    @ViewBuilder
    private var carriedInRow: some View {
        if result.line.carriedInSeconds > 0, !result.line.carriedInFrom.isEmpty {
            let duration = ServiceDurationFormatter.accessibilityString(from: result.line.carriedInSeconds)
            let months = result.line.carriedInFrom.map(monthName).joined(separator: ", ")
            let label = Text("report.line.carried-in.\(duration).\(months)")

            HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.compact) {
                Text(verbatim: "↘")
                    .accessibilityHidden(true)
                label
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
        }
    }
```

The catalog key `report.line.carried-in.%@.%@` is "%1$@ transferred from %2$@" / "%1$@ overført fra %2$@". The Submit screen passes `{ $0.monthName() }` as `monthName`. `YearMonth.monthName(locale:calendar:)` is in `Hugo/Domain/YearMonth.swift:90`. `ServiceDurationFormatter` (`Hugo/Domain/ServiceDurationFormatter.swift`) is `nonisolated`; `accessibilityString(from:locale:)` gives "30 minutes" / "1 hour, 30 minutes".

### Help to open

`HelpView(for: "RoundingRule")` (`Hugo/Features/Help/Screens/HelpView.swift`) shows `Hugo/Resources/Markdown/Help/{Base,da}.lproj/RoundingRule.md`. It brings its own `NavigationStack` and is already opened as a sheet from `ReportSettingsView` and `SubmitReportView`:

```swift
        .sheet(isPresented: $showingHelp) { HelpView(for: "RoundingRule") }
```

Its last paragraph already says: "When you transfer minutes, Hugo adds them to the next month as an entry dated the 1st. You will see it on the Overview as time carried in from the previous month." Do not edit it.

### Conventions

- Pure value types live in a feature's `Domain` folder and are `nonisolated` (see `Hugo/Features/Reports/Domain/ReportingLineCalculator.swift`, which reads `[Entry]` the same way). The project builds with MainActor default isolation and Swift 6 strict concurrency.
- The Xcode project uses synchronized folders: a new `.swift` file under `Hugo/` or `HugoTests/` is picked up without editing `project.pbxproj`.
- Strings live in `Hugo/Resources/Localizable.xcstrings`, with English (`en`) and Danish (`da`) values. Edit it as JSON and keep its formatting (two-space indentation, keys sorted the way Xcode writes them). Look at an existing entry such as `overview.carried.summary.label` and copy its shape.
- Tests use Swift Testing. Model after `HugoTests/Features/Overview/Domain/OverviewMetricsTests.swift:36-40`, which makes a carried-in entry in memory like this:

```swift
        let carried = Entry(date: date(2026, 1, 1), duration: 1_800, tracker: nil)
        carried.sourceReportYear = 2025
        carried.sourceReportMonth = 12
```

## Owner decisions (recommended defaults, change before executing if wanted)

1. ~~**Tapping the Overview line opens the Rounding help.**~~ Changed in Revision 1 (owner, 2026-11-14): tapping the line opens a small sheet with the carried-in time per category. The line keeps its `info.circle` icon and its text is centered.
2. **Wording**: reuse "30 minutes transferred from October" everywhere (the Submit screen's existing string) instead of keeping "Carried in from previous month:".
3. **Month detail**: carried-in entries leave the tappable list and appear as one non-editable line at the top of the entries section.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| One test suite | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/CarriedInTimeTests` | `** TEST SUCCEEDED **` |
| Full gate (before each commit) | `Scripts/verify.sh` | exit 0 |
| Whitespace | `git diff --check` | exit 0 |

If `Scripts/verify.sh` or the scheme name has changed (plan 102 renames the `Hugo` scheme to `Debug`), use whatever `Scripts/verify.sh` runs now.

## Scope

**In scope** (the only files you may modify or create):

- `Hugo/Features/Reports/Domain/CarriedInTime.swift` (create)
- `HugoTests/Features/Reports/Domain/CarriedInTimeTests.swift` (create)
- `Hugo/Features/Overview/Views/OverviewListView.swift`
- `Hugo/Features/Reports/Views/MonthlyReportEntryListView.swift`
- `Hugo/Resources/Localizable.xcstrings` (add one key, remove one key)

**Out of scope**:

- `ReportingLineCard.swift`, `SubmitReportView.swift` and the rest of the Submit Report flow. They already explain carried-in time.
- `RoundingRule.md` in either language.
- `EntryDetailView.swift`. Do not add edit guards there. After this plan no list opens a carried-in entry.
- `MonthlyReportTotalsView.swift`. The totals keep including carried-in time, as the report does.
- `ServiceYearMonthRow.swift`. Plan 112 shows carried-in time on the Year cards.
- `ReportSubmissionService.swift`, every SwiftData model and schema version.
- `Hugo.xcodeproj/project.pbxproj`, `.claude/`, `plans/` (except your status row) and the owner's `Changelog/` changes. Never stage them.

## Git workflow

- Work on `main`. No branch, no worktree, no push. Stage files by path.
- Two commits, each after `Scripts/verify.sh` exits 0:
  1. `feat: add CarriedInTime for a month's carried-in entries` (Step 1)
  2. `feat: explain carried-in time on the Overview and in the month detail` (Steps 2-4)

## Steps

### Step 1: Add `CarriedInTime` and its tests

Create `Hugo/Features/Reports/Domain/CarriedInTime.swift`:

```swift
import Foundation

/// The time a month holds in carried-in entries: minutes transferred from
/// earlier months' reports. Nil when the month has none.
nonisolated struct CarriedInTime: Equatable, Sendable {
    let seconds: TimeInterval
    /// The months whose reports transferred the time, oldest first.
    let sourceMonths: [YearMonth]

    init?(entries: [Entry]) {
        var seconds: TimeInterval = 0
        var months: Set<YearMonth> = []
        for entry in entries where entry.isCarriedIn && entry.duration > 0 {
            seconds += entry.duration
            if let year = entry.sourceReportYear, let month = entry.sourceReportMonth {
                months.insert(YearMonth(year: year, month: month))
            }
        }
        guard seconds > 0 else { return nil }
        self.seconds = seconds
        self.sourceMonths = months.sorted()
    }

    /// "30 minutes transferred from October" (Danish "30 minutter overført
    /// fra oktober"), the same words the Submit Report screen uses.
    func label(locale: Locale = .current, calendar: Calendar = .current) -> LocalizedStringResource {
        let duration = ServiceDurationFormatter.accessibilityString(from: seconds, locale: locale)
        let months = sourceMonths.map { $0.monthName(locale: locale, calendar: calendar) }
            .joined(separator: ", ")
        return LocalizedStringResource("report.line.carried-in.\(duration).\(months)")
    }
}
```

`YearMonth` is `Hashable, Comparable` (`Hugo/Domain/YearMonth.swift:3`), so the `Set` and `sorted()` work as written.

Create `HugoTests/Features/Reports/Domain/CarriedInTimeTests.swift` with a `@MainActor struct CarriedInTimeTests` and these `@Test`s (build entries in memory as in the excerpt above, with a fixed Gregorian UTC calendar for dates like `ServiceMonthTests` does):

1. `nilWithoutCarriedInEntries`: two ordinary entries → `CarriedInTime(entries:)` is `nil`.
2. `nilForAnEmptyMonth`: `[]` → `nil`.
3. `sumsCarriedInEntriesOnly`: one ordinary entry of 3 600 s plus carried-in entries of 1 800 s (from 2026-10) and 900 s (from 2026-10) → `seconds == 2_700`, `sourceMonths == [YearMonth(year: 2026, month: 10)]`.
4. `listsSourceMonthsOldestFirstWithoutDuplicates`: carried-in entries from 2026-10, 2026-09 and 2026-10 → `sourceMonths == [2026-09, 2026-10]`.
5. `ignoresZeroLengthCarriedInEntries`: one carried-in entry with `duration: 0` → `nil`.

Do not test the text of `label()`; it resolves through the string catalog.

**Verify**: the one-suite test command above → `** TEST SUCCEEDED **` with 5 tests. Then `Scripts/verify.sh` exits 0. Commit 1.

### Step 2: Rebuild the Overview line

In `OverviewListView.swift`:

1. Change the call site (lines 52-54) to:

```swift
                if let carriedIn = CarriedInTime(entries: groups.carried) {
                    OverviewCarriedEntriesView(carriedIn: carriedIn)
                }
```

2. Replace the whole `OverviewCarriedEntriesView` struct with:

```swift
/// The month's carried-in time as one line. Tapping it opens the Rounding
/// help, which explains transfers.
struct OverviewCarriedEntriesView: View {
    let carriedIn: CarriedInTime

    @State private var showingHelp = false

    var body: some View {
        let label = Text(carriedIn.label())
        Button {
            showingHelp = true
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.compact) {
                Text(verbatim: "↘")
                    .accessibilityHidden(true)
                label
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "info.circle")
                    .accessibilityHidden(true)
            }
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray5))
            .foregroundStyle(.secondary)
            .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityHint(Text("overview.carried.hint"))
        .accessibilityAddTraits(.isButton)
        .sheet(isPresented: $showingHelp) { HelpView(for: "RoundingRule") }
    }
}
```

`OverviewEntryGroups` stays as it is.

**Verify**: `xcrun swift-format lint --strict --recursive Hugo HugoTests` exits 0, and `grep -n "overview.carried.summary.label" Hugo/Features` returns nothing.

### Step 3: Show carried-in time as one line in the month detail

Replace the body of `MonthlyReportEntryListView` so carried-in entries leave the tappable list:

```swift
struct MonthlyReportEntryListView: View {
    let month: ServiceMonth

    private var entries: [Entry] { month.summary?.entries ?? [] }

    var body: some View {
        Section {
            if let carriedIn = CarriedInTime(entries: entries) {
                carriedInRow(carriedIn)
            }
            ForEach(entries.filter { !$0.isCarriedIn }) { entry in
                // keep the existing NavigationLink { Label { ... } icon: { ... } } exactly as it is
            }
        }
    }

    /// Carried-in entries are managed by the source month's report, so they
    /// show as one line that can't be opened or edited.
    private func carriedInRow(_ carriedIn: CarriedInTime) -> some View {
        let label = Text(carriedIn.label())
        return HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.compact) {
            Text(verbatim: "↘")
                .accessibilityHidden(true)
            label
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}
```

Copy the existing `NavigationLink` block unchanged into the `ForEach`. Remove the stray empty line inside it (between `Image(systemName: "exclamationmark.triangle.fill")` and `.font(.caption)`) only if the linter asks for it; otherwise leave it.

**Verify**: lint exits 0.

### Step 4: Strings

In `Hugo/Resources/Localizable.xcstrings`:

1. Add `overview.carried.hint`: English "Shows how transferred minutes work", Danish "Viser, hvordan overførte minutter fungerer". Copy the JSON shape of an existing key with both `en` and `da` `stringUnit`s and `"state" : "translated"`.
2. Remove the key `overview.carried.summary.label`, which nothing uses any more.
3. Do not touch `report.line.carried-in.%@.%@`.

**Verify**:
- `python3 -I -c "import json; d=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings']; print('overview.carried.hint' in d, 'overview.carried.summary.label' in d)"` prints `True False`.
- `Scripts/verify.sh` exits 0.
- `git diff --stat` lists only the in-scope files (plus the owner's untouched `Changelog/` changes, which you must not stage). `git diff --check` exits 0.

Commit 2.

### Step 5 (Revision 1): open a category breakdown instead of the Rounding help, and center the line

Steps 1-4 are done. Read "Current state" for background only; the live code now looks like the end of Step 2 and Step 4.

**Why.** The owner wants the Overview line to answer "where did this time come from?" A short list of categories with their carried-in time does that. The Rounding help stays reachable from Report Settings and Submit Report, where users choose Transfer.

**How the categories are found.** Use `CategoryTotals.rows(entries:trackers:locale:)` (`Hugo/Features/Entries/Domain/CategoryTotals.swift`). It already groups entries by category the way every other screen does. Carried-in main time joins the user's default main category whatever its name, and carried-in separate time joins the live category with the same name and type, or keeps its own row if that category was deleted. Its tests are in `HugoTests/Features/Entries/Domain/CategoryTotalsTests.swift` (`carriedMainTimeJoinsTheDefaultCategoryWhateverItsName` and others). Do not change `CategoryTotals`.

**Pattern for the sheet.** Copy the shape of `Hugo/Features/Overview/Screens/PlanPaceSheet.swift` (a small sheet opened from the Overview): `NavigationStack` > `List` with sections, inline title, a Done button in `.confirmationAction` using `"navigation.done"`. It is shown with `.presentationDetents([.medium])` from `OverviewView`.

**Scope for this step** (the only files you may change or create):

- `Hugo/Features/Overview/Screens/CarriedInBreakdownSheet.swift` (create)
- `Hugo/Features/Overview/Views/OverviewListView.swift`
- `Hugo/Resources/Localizable.xcstrings` (change one value, add two keys)

Out of scope: `CarriedInTime.swift`, `CategoryTotals.swift`, `MonthlyReportEntryListView.swift`, `HelpView.swift`, `RoundingRule.md`, and everything listed as out of scope above.

1. Create `Hugo/Features/Overview/Screens/CarriedInBreakdownSheet.swift`:

```swift
import SwiftData
import SwiftUI

/// The month's carried-in time split by category. Opened from the
/// carried-in line on the Overview.
struct CarriedInBreakdownSheet: View {
    let carriedIn: CarriedInTime
    /// The month's carried-in entries.
    let entries: [Entry]

    @Environment(\.dismiss) private var dismiss
    @Query private var trackers: [Tracker]

    var body: some View {
        let rows = CategoryTotals.rows(entries: entries, trackers: trackers)
        NavigationStack {
            List {
                Section {
                    Text(carriedIn.label())
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(rows) { row in
                        LabeledContent {
                            Text(ServiceDurationFormatter.hoursString(from: row.duration))
                        } label: {
                            Label(row.name, systemImage: row.iconName)
                        }
                    }
                } footer: {
                    Text("overview.carried.breakdown.footer")
                }
            }
            .navigationTitle("overview.carried.breakdown.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("navigation.done") { dismiss() }
                }
            }
        }
    }
}
```

   No preview is needed. `row.name` is a `String`, so `Label(row.name, systemImage:)` shows it as is (it is already localized for the untracked row).

2. In `OverviewListView.swift`:
   - Change the call site to pass the entries too:

     ```swift
                     if let carriedIn = CarriedInTime(entries: groups.carried) {
                         OverviewCarriedEntriesView(carriedIn: carriedIn, entries: groups.carried)
                     }
     ```

   - In `OverviewCarriedEntriesView`:
     - Update the doc comment to: `/// The month's carried-in time as one line. Tapping it opens a breakdown by category.`
     - Add `let entries: [Entry]` below `let carriedIn: CarriedInTime`.
     - Rename `showingHelp` to `showingBreakdown`.
     - Center the line: in the `HStack`, delete `Spacer(minLength: 0)`, change `.multilineTextAlignment(.leading)` to `.multilineTextAlignment(.center)`, and change `.frame(maxWidth: .infinity, alignment: .leading)` to `.frame(maxWidth: .infinity)`. Keep the `↘`, the label and the `info.circle` image in that order.
     - Replace `.sheet(isPresented: $showingHelp) { HelpView(for: "RoundingRule") }` with:

       ```swift
               .sheet(isPresented: $showingBreakdown) {
                   CarriedInBreakdownSheet(carriedIn: carriedIn, entries: entries)
                       .presentationDetents([.medium])
               }
       ```

     Leave every other modifier (button style, accessibility label, hint, traits, background, padding, clip shape) as it is.

3. In `Hugo/Resources/Localizable.xcstrings` (keep the file's formatting, insert new keys in sorted position, `"state" : "translated"` for both languages):
   - Change `overview.carried.hint`: English "Shows the categories the time came from", Danish "Viser, hvilke kategorier tiden kom fra". Set its comment to "VoiceOver hint for the line that shows carried-in time on the Overview. Opens a breakdown by category."
   - Add `overview.carried.breakdown.title`: English "Transferred time", Danish "Overført tid". Comment: "Title of the sheet that shows carried-in time per category."
   - Add `overview.carried.breakdown.footer`: English "You transferred these minutes when you submitted your report. They count toward this month.", Danish "Du overførte disse minutter, da du indsendte din rapport. De tæller med i denne måned." Comment: "Footer under the list of carried-in time per category."

**Verify**:
- `xcrun swift-format lint --strict --recursive Hugo HugoTests` exits 0.
- `grep -n "HelpView\|showingHelp\|Spacer(minLength: 0)\|alignment: .leading)" Hugo/Features/Overview/Views/OverviewListView.swift` prints nothing inside `OverviewCarriedEntriesView` (matches elsewhere in the file are fine; check the line numbers against the struct).
- `python3 -I -c "import json; d=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings']; print(all(k in d for k in ['overview.carried.hint','overview.carried.breakdown.title','overview.carried.breakdown.footer']))"` prints `True`.
- `Scripts/verify.sh` exits 0. After it, `git diff -- Hugo/Resources/Localizable.xcstrings` shows only the changed hint and the two added keys.
- `git status --short` lists only the three files of this step (plus files the owner changed, which you must not stage). `git diff --check` exits 0.

Commit: `feat: show carried-in time per category on the Overview`.

**STOP conditions for this step**: `CategoryTotals.rows` or `CarriedInTime` would need a change; `@Query` in the sheet doesn't compile; the change seems to need a file outside this step's scope.

### Step 6 (Revision 2): make the sentence the sheet's heading, drop the title bar and footer, add a section header

Steps 1-5 are done. The live `CarriedInBreakdownSheet.swift` is exactly the code in Step 5.1.

**Why.** Without a navigation bar, the sentence moves to the top of the sheet and becomes its heading. The serif bold style matches the heading in `PlanPaceSheet` (`.font(.system(.title2, design: .serif, weight: .bold))`). The sheet has a medium detent and closes with a swipe down; a visible drag indicator shows that, since there is no Done button any more.

**Scope for this step** (the only files you may change):

- `Hugo/Features/Overview/Screens/CarriedInBreakdownSheet.swift`
- `Hugo/Features/Overview/Views/OverviewListView.swift` (the `.sheet` modifier in `OverviewCarriedEntriesView` only)
- `Hugo/Resources/Localizable.xcstrings` (remove two keys, add one)

1. Replace the whole `CarriedInBreakdownSheet` struct with:

```swift
/// The month's carried-in time split by category. Opened from the
/// carried-in line on the Overview.
struct CarriedInBreakdownSheet: View {
    let carriedIn: CarriedInTime
    /// The month's carried-in entries.
    let entries: [Entry]

    @Query private var trackers: [Tracker]

    var body: some View {
        let rows = CategoryTotals.rows(entries: entries, trackers: trackers)
        List {
            Section {
                Text(carriedIn.label())
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                    .listRowBackground(Color.clear)
            }
            Section {
                ForEach(rows) { row in
                    LabeledContent {
                        Text(ServiceDurationFormatter.hoursString(from: row.duration))
                    } label: {
                        Label(row.name, systemImage: row.iconName)
                    }
                }
            } header: {
                Text("overview.carried.breakdown.header")
            }
        }
    }
}
```

   Keep the two imports (`SwiftData`, `SwiftUI`). The `NavigationStack`, navigation title, toolbar, `dismiss` and footer are gone.

2. In `OverviewListView.swift`, in `OverviewCarriedEntriesView`'s `.sheet`, add `.presentationDragIndicator(.visible)` after `.presentationDetents([.medium])`. Change nothing else in that file.

3. In `Hugo/Resources/Localizable.xcstrings` (keep the file's formatting; `"state" : "translated"` for both languages):
   - Remove `overview.carried.breakdown.title` and `overview.carried.breakdown.footer`.
   - Add `overview.carried.breakdown.header` in sorted position: English "Breakdown", Danish "Fordeling". Comment: "Section header above the list of carried-in time per category."

**Verify**:
- `xcrun swift-format lint --strict --recursive Hugo HugoTests` exits 0.
- `grep -n "NavigationStack\|navigationTitle\|navigation.done\|footer" Hugo/Features/Overview/Screens/CarriedInBreakdownSheet.swift` prints nothing.
- `grep -rn "overview.carried.breakdown.title\|overview.carried.breakdown.footer" Hugo` prints nothing.
- `python3 -I -c "import json; d=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings']; print('overview.carried.breakdown.header' in d, 'overview.carried.breakdown.title' in d, 'overview.carried.breakdown.footer' in d)"` prints `True False False`.
- `Scripts/verify.sh` exits 0. After it, `git diff -- Hugo/Resources/Localizable.xcstrings` shows only the two removed keys and the one added key.
- `git status --short` lists only this step's three files (plus files the owner changed, which you must not stage). `git diff --check` exits 0.

Commit: `feat: make the carried-in sentence the heading of its breakdown sheet`.

**STOP conditions for this step**: the live sheet differs from Step 5.1's code; the change seems to need a file outside this step's scope.

## Test plan

- `CarriedInTimeTests` (5 tests, Step 1) cover the sum, the source months and the empty cases.
- The views have no logic beyond `CarriedInTime` and a filter. The full suite must stay green.
- Owner device checks are listed under Maintenance notes.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `HugoTests/Features/Reports/Domain/CarriedInTimeTests.swift` exists with 5 passing tests
- [ ] `grep -rn "overview.carried.summary.label" Hugo` returns nothing
- [ ] `grep -n "CarriedInTime" Hugo/Features/Overview/Views/OverviewListView.swift Hugo/Features/Reports/Views/MonthlyReportEntryListView.swift` shows both files using it
- [ ] `git show --stat HEAD~1 HEAD` lists only in-scope files
- [ ] `plans/README.md` row for 111 updated

## STOP conditions

- The drift check shows changes and the excerpts no longer match.
- `LocalizedStringResource("report.line.carried-in.\(duration).\(months)")` does not compile, or on the simulator the line shows the raw key instead of "… transferred from …". Report it; do not invent a new key.
- `HelpView(for: "RoundingRule")` fails to open from the Overview (for example a nested `NavigationStack` warning that breaks the sheet).
- Any step seems to need an out-of-scope file.

## Maintenance notes

- Owner device check, in English and Danish:
  - Submit a month with **Transfer** on a line that has minutes. In the next month the Overview shows "↘ 30 minutes transferred from October" with an info icon, centered. Tapping it opens a small sheet headed by the same sentence in large serif type, with a "Breakdown" list of each category and its carried-in time, and a drag indicator to close it (Revisions 1 and 2).
  - VoiceOver on that line reads the sentence and the hint "Shows the categories the time came from".
  - Year tab → that month → Details: the carried-in time is one gray line at the top and can't be tapped. Ordinary entries still open.
  - Check the Danish hint text.
- Plan 112 uses `CarriedInTime` on the Year page cards. If the wording changes, change it in `CarriedInTime.label()` so all three places stay the same.
- `ReportingLineCard` still builds the same sentence itself from `ReportingLine.carriedInSeconds`. It could call a shared helper later; it was left alone to keep this plan small.
