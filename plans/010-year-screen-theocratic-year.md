# Plan 010: Replace the Report tab with a swipeable Year screen showing every month of a theocratic year

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 4b647ce..HEAD -- Hugo/Features/Reports Hugo/App/AppRootView.swift Hugo/Resources/Localizable.xcstrings Hugo/PreviewSupport`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: plans/004-extract-reporting-domain.md (DONE), plans/008-modernize-app-bootstrap-concurrency.md
- **Category**: direction
- **Planned at**: commit `4b647ce`, 2026-07-27
- **Issue**: n/a

## Why this matters

The second tab is currently called "Report"/"Rapport" and only lists the months
that happen to contain entries, newest first. A publisher thinks in *service
years* (September–August), not in "months that have data": a month with zero
hours is meaningful information, not something to hide. Today there is also no
way to look at an earlier theocratic year at all — the list simply grows
forever in one flat stack.

After this plan the tab is called "Year"/"År" and shows one full theocratic year
at a time: all twelve months from September to August, each either rendered as
the existing month summary card or as a compact "no entries" row, with a totals
card for the whole year. Earlier theocratic years are reachable by swiping the
page horizontally and, for discoverability and VoiceOver, from a year menu in
the toolbar.

## Current state

### Files that own the behavior today

- `Hugo/App/AppRootView.swift` — root `TabView`; declares the tab that hosts the screen.
- `Hugo/Features/Reports/ReportsView.swift` — the screen itself; queries every `Entry` and renders either an empty-state card or `MonthlyReportListView`.
- `Hugo/Features/Reports/MonthlyReportListView.swift` — maps entries to summaries and stacks `MonthlyReportRow`s. Only consumer is `ReportsView`.
- `Hugo/Features/Reports/MonthlyReportRow.swift` — the month card, wrapped in a `NavigationLink` to `MonthlyReportDetailView`. **Reused unchanged by this plan.**
- `Hugo/Features/Reports/MonthlyReportDetailView.swift`, `MonthlyReportTotalsView.swift`, `MonthlyReportEntryListView.swift` — month detail stack. **Unchanged.**
- `Hugo/Features/Reports/Domain/YearMonth.swift` — `YearMonth` value type, `Date.yearMonth(using:)`, `YearMonth.monthYearString(locale:calendar:)`.
- `Hugo/Features/Reports/Domain/MonthlyReportSummary.swift` — `MonthlyReportSummary` (`id: YearMonth`) and `MonthlyCategorySummary`.
- `Hugo/Features/Reports/Domain/MonthlyReportBuilder.swift` — `@MainActor enum` that groups `[Entry]` into `[MonthlyReportSummary]`, sorted descending. **Reused, not modified.**
- `Hugo/PreviewSupport/ReportPreviewFixtures.swift` — `@MainActor` fixtures for previews.
- `Hugo/Resources/Localizable.xcstrings` — the only string catalog (`sourceLanguage: en`, localizations `en` + `da`).

### Code as it exists today

`Hugo/App/AppRootView.swift:10-13`

```swift
TabView {
    Tab("tab.overview", systemImage: "house") { OverviewView() }
    Tab("tab.report", systemImage: "tray.full.fill") { ReportsView() }
}
```

`Hugo/Features/Reports/ReportsView.swift:4-37`

```swift
struct ReportsView: View {
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]

    var body: some View {
        NavigationStack {
            ScrollView {
                if entries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.green)
                        Text("report.pending.empty")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                            .padding(.leading, 8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(24)
                    .padding()
                } else {
                    MonthlyReportListView(entries: entries)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("reports.title")
        }
    }
}
```

`Hugo/Features/Reports/MonthlyReportListView.swift:3-16`

```swift
struct MonthlyReportListView: View {
    let entries: [Entry]

    var summaries: [MonthlyReportSummary] {
        MonthlyReportBuilder.summaries(from: entries)
    }

    var body: some View {
        VStack(spacing: 24) {
            ForEach(summaries) { summary in
                MonthlyReportRow(summary: summary)
            }
        }
    }
}
```

`Hugo/Features/Reports/Domain/YearMonth.swift:3-18`

```swift
nonisolated struct YearMonth: Hashable, Comparable {
    let year: Int
    let month: Int

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        return lhs.month < rhs.month
    }
}

extension Date {
    func yearMonth(using calendar: Calendar = .current) -> YearMonth {
        let components = calendar.dateComponents([.year, .month], from: self)
        return YearMonth(year: components.year ?? 0, month: components.month ?? 0)
    }
}
```

`Hugo/Features/Reports/Domain/MonthlyReportBuilder.swift:3-9` (signature only — do not change it)

```swift
@MainActor
enum MonthlyReportBuilder {
    static func summaries(
        from entries: [Entry],
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [MonthlyReportSummary]
}
```

`Hugo/PreviewSupport/ReportPreviewFixtures.swift:3-17`

```swift
@MainActor
enum ReportPreviewFixtures {
    static let entries: [Entry] = {
        let main = Tracker(name: "Field Service", type: .main, isDefault: true, iconName: "figure.walk")
        let separate = Tracker(name: "Bethel", type: .separate, iconName: "building")
        return [
            Entry(date: Date(), duration: 3_600, tracker: main, bibleStudies: 1),
            Entry(date: Date(), duration: 7_200, tracker: separate),
        ]
    }()

    static var summary: MonthlyReportSummary {
        MonthlyReportBuilder.summaries(from: entries).first!
    }
}
```

### Repository conventions that apply here

Quoted from `AGENTS.md` — the executor has not read that file:

- "**Definition:** A theocratic year runs from **September 1st** of one year to **August 31st** of the following year."
- "**Naming Convention:** It must always be formatted and referred to as `YYYY/YYYY` (e.g., September 1, 2026, to August 31, 2027, is designated as `2026/2027`)."
- "Keep Views purely visual. Do not perform complex data mapping, computation, or database queries inside the View body."
- "Never use legacy property wrappers: `ObservableObject`, `@Published`, `@StateObject`, or `@ObservedObject`." Use `@State` + `@Observable` only where mutable workflow state exists; **this feature needs no `@Observable` view model — a `@State` selection value and pure value types are enough.**
- "**Ease of use.** … the user base ranges from around 13 to 70 years. As there will be a lot of older users, the app should always explain itself and make good use of accessibility features." → the horizontal swipe must not be the *only* way to change year.
- "**Simplicity.** Always keep the app as simple as possible, do not add unnecessary features."
- Preview pattern: `#Preview { ReportsView().modelContainer(.preview) }`.
- "Persistence names remain `Tracker` even where the UI says Category."
- `nonisolated` is applied explicitly to pure value types (`YearMonth`, `ServiceDurationFormatter`) because the project builds with MainActor default isolation. Follow that: new pure value types get `nonisolated`; anything touching `Entry` stays `@MainActor`.

Formatting is enforced by `.swift-format`: 4-space indentation, 120-column line length, max 1 blank line.

Xcode uses `fileSystemSynchronizedGroups`, so **new and deleted files do not require `project.pbxproj` edits** — creating the file on disk in an existing group folder is enough.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Format fix | `xcrun swift-format format --in-place --recursive Hugo HugoTests` | exit 0 |
| Full verification | `Scripts/verify.sh` | exit 0 (lint + test + analyze) |
| Tests only | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoDerivedData CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **` |
| Single suite | append `-only-testing:HugoTests/TheocraticYearTests` to the test command | `** TEST SUCCEEDED **` |
| String catalog is valid JSON | `python3 -m json.tool Hugo/Resources/Localizable.xcstrings > /dev/null` | exit 0, no output |

If the simulator named `iPhone 17 Pro` / OS `26.5` does not exist locally, list
available destinations with `xcrun simctl list devices available` and override
`DESTINATION` for `Scripts/verify.sh`. Do not change the checked-in defaults.

## Suggested executor toolkit

- If an `apple-design` skill is available, invoke it when implementing the paging container and the year-switch affordance — the goal is Apple-native feel, not a custom carousel.
- Reference: `AGENTS.md` (section 5 defines the theocratic year), `README.md` (build/test entry points).

## Scope

**In scope** (the only files you may modify, create, or delete):

- `Hugo/Features/Reports/Domain/TheocraticYear.swift` (create)
- `Hugo/Features/Reports/Domain/TheocraticYearReport.swift` (create)
- `Hugo/Features/Reports/Domain/TheocraticYearReportBuilder.swift` (create)
- `Hugo/Features/Reports/YearView.swift` (create)
- `Hugo/Features/Reports/TheocraticYearPageView.swift` (create)
- `Hugo/Features/Reports/TheocraticYearTotalsView.swift` (create)
- `Hugo/Features/Reports/MonthlyReportEmptyRow.swift` (create)
- `Hugo/Features/Reports/ReportsView.swift` (delete)
- `Hugo/Features/Reports/MonthlyReportListView.swift` (delete)
- `Hugo/App/AppRootView.swift` (modify — tab declaration only)
- `Hugo/PreviewSupport/ReportPreviewFixtures.swift` (modify — add fixtures)
- `Hugo/Resources/Localizable.xcstrings` (modify — add keys)
- `HugoTests/Features/Reports/TheocraticYearTests.swift` (create)
- `HugoTests/Features/Reports/TheocraticYearReportBuilderTests.swift` (create)
- `plans/README.md` (status row only)

**Out of scope** (do NOT touch, even though they look related):

- `Hugo/Features/Reports/MonthlyReportBuilder.swift`, `MonthlyReportSummary.swift`, `YearMonth.swift`, `ServiceDurationFormatter.swift` — the month aggregation layer is already tested and correct; the new year layer composes it. Changing its sort order or signature breaks `HugoTests/Features/Reports/MonthlyReportBuilderTests.swift`.
- `MonthlyReportRow.swift`, `MonthlyReportDetailView.swift`, `MonthlyReportTotalsView.swift`, `MonthlyReportEntryListView.swift` — reused verbatim.
- Anything under `Hugo/Persistence/` — this is a presentation change; no schema version, no migration.
- `Hugo/Features/Overview/` — the Overview tab keeps its current-month behavior.
- Deleting stale keys from `Localizable.xcstrings` (`report.pending.empty`, `reports.title`, `tab.report`, …). Xcode manages `extractionState`; leave orphaned entries in place.
- Adding entries from an empty month, exporting/sharing a year, year-over-year charts.

## Git workflow

- Branch: `advisor/010-year-screen`
- Commit per step or per logical unit. Repo style for plan work (see `git log`): `` `010` – Replace the Report tab with a Year screen ``. Ordinary commits use a short imperative subject.
- Do NOT push or open a PR unless the operator instructs it.

## Design decisions (already made — implement these, do not re-litigate)

1. **Paging container**: `TabView(selection:)` + `.tabViewStyle(.page(indexDisplayMode: .never))`, one page per theocratic year, wrapped in a single `NavigationStack` that lives *outside* the paging `TabView`. Rationale: each page contains a long vertical `ScrollView`, and the page style gives correct nested-gesture arbitration for free. The alternative (`ScrollView(.horizontal)` + `.scrollTargetBehavior(.paging)`) is the documented fallback in "STOP conditions".
2. **Page order**: years ascending (oldest first), so the newest year is the last page and swiping *right* (backwards) reveals earlier years. Default selection is the current theocratic year.
3. **Month order within a year**: ascending September → August, for every year, matching the official service-year record card. Predictable ordering beats "newest first" here because the page represents a fixed 12-slot year.
4. **Available years**: a contiguous ascending range from the theocratic year of the oldest entry through the theocratic year of `.now` (extended forwards if an entry is dated in a future year). No entries at all → exactly one page, the current year. Contiguity matters so swiping never skips a year.
5. **No future pages beyond the current year** (except as described in 4).
6. **Second, non-gestural way to change year**: a toolbar `Menu` containing an inline `Picker` of the available years, newest first. Required by the ease-of-use principle in `AGENTS.md`.
7. **Titles**: `navigationTitle` is the year designation (`2025/2026`), `navigationSubtitle` is `"year.subtitle"` ("Service Year" / "Tjenesteår"). The tab label is `"tab.year"` ("Year" / "År").
8. **No `@Observable` view model.** The screen holds `@State private var selectedYear: TheocraticYear?` and derives everything else from pure value types.

## Steps

### Step 1: Add the `TheocraticYear` value type

Create `Hugo/Features/Reports/Domain/TheocraticYear.swift`.

Requirements — a pure, `nonisolated`, `Sendable` value type that takes no
dependency on `Entry` (so it is testable without a model container):

- `nonisolated struct TheocraticYear: Hashable, Comparable, Identifiable, Sendable`
- `let startYear: Int` — `2026` represents `2026/2027`.
- `var id: Int { startYear }`
- `var displayName: String { "\(startYear)/\(startYear + 1)" }` — plain interpolation; must not produce grouping separators.
- `var months: [YearMonth]` — exactly 12 values, `YearMonth(year: startYear, month: 9)` … `YearMonth(year: startYear, month: 8)`, i.e. Sep–Dec of `startYear` then Jan–Aug of `startYear + 1`, in that order.
- `func contains(_ month: YearMonth) -> Bool`
- `static func containing(_ date: Date, calendar: Calendar = .current) -> TheocraticYear` — month `>= 9` → `startYear = year`, else `startYear = year - 1`.
- `static func < (lhs:rhs:)` comparing `startYear`.
- `static func availableYears(entryDates: [Date], now: Date, calendar: Calendar = .current) -> [TheocraticYear]` — ascending, contiguous, from `min(oldest entry year, current year)` through `max(newest entry year, current year)`. With an empty `entryDates` array it returns `[containing(now)]`.
- `extension Date { func theocraticYear(using calendar: Calendar = .current) -> TheocraticYear }` — mirrors the existing `Date.yearMonth(using:)` in `YearMonth.swift`.

Do not add a `dateInterval` helper unless a later step needs one; entry
filtering is done through `YearMonth`, which avoids time-zone edge cases at the
September 1 boundary.

**Verify**: `xcrun swift-format lint --strict --recursive Hugo` → exit 0, no output.

### Step 2: Add the year report model and builder

Create `Hugo/Features/Reports/Domain/TheocraticYearReport.swift`:

```swift
struct TheocraticYearMonth: Identifiable {
    let id: YearMonth
    let displayName: String
    let summary: MonthlyReportSummary?
    let isFuture: Bool
}

struct TheocraticYearReport {
    let year: TheocraticYear
    let months: [TheocraticYearMonth]
    let totalSeconds: TimeInterval
    let totalBibleStudies: Int
    let mainDuration: TimeInterval
    let separateDuration: TimeInterval

    var hasEntries: Bool { months.contains { $0.summary != nil } }
}
```

These types reference `MonthlyReportSummary`, which holds `[Entry]`, so they
are MainActor-isolated by the project's default isolation — do **not** mark them
`nonisolated`.

Create `Hugo/Features/Reports/Domain/TheocraticYearReportBuilder.swift`,
mirroring the shape of the existing `MonthlyReportBuilder`:

```swift
@MainActor
enum TheocraticYearReportBuilder {
    static func report(
        for year: TheocraticYear,
        entries: [Entry],
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> TheocraticYearReport
}
```

Behavior:

1. Filter `entries` to those whose `date.yearMonth(using: calendar)` is contained in `year`.
2. Feed the filtered entries to `MonthlyReportBuilder.summaries(from:calendar:locale:)` and index the result by `\.id`.
3. Map `year.months` (all 12, in Sep→Aug order) to `TheocraticYearMonth`, using the indexed summary when present and `nil` otherwise. `displayName` comes from `MonthlyReportSummary.displayName` when a summary exists, otherwise from `month.monthYearString(locale: locale, calendar: calendar)` so both paths format identically.
4. `isFuture` is `month > now.yearMonth(using: calendar)`.
5. Totals are the sums of the present summaries' `totalSeconds`, `totalBibleStudies`, `mainDuration`, `separateDuration`.

**Verify**: `xcrun swift-format lint --strict --recursive Hugo` → exit 0.

### Step 3: Add the domain tests

Create `HugoTests/Features/Reports/TheocraticYearTests.swift`, modeled
structurally on the existing `HugoTests/Features/Reports/YearMonthTests.swift`
(Swift Testing, `@MainActor struct`, `@Test` functions, `#expect`).

Cover:

- `containing(_:)` at both boundaries: 2026-08-31 → `2025/2026` (`startYear == 2025`); 2026-09-01 → `2026/2027`.
- `displayName` of `TheocraticYear(startYear: 2026)` == `"2026/2027"`.
- `months.count == 12`, `months.first == YearMonth(year: 2026, month: 9)`, `months.last == YearMonth(year: 2027, month: 8)`, and `months == months.sorted()`.
- `contains(_:)` true for Sep of `startYear` and Aug of `startYear + 1`, false for Aug of `startYear` and Sep of `startYear + 1`.
- `availableYears(entryDates:now:)` with an empty array → one element, the current year.
- `availableYears(entryDates:now:)` with a date three theocratic years back → 4 ascending contiguous elements ending at the current year.
- `availableYears(entryDates:now:)` with an entry dated in the *next* theocratic year → range extends forwards.
- Ordering: `TheocraticYear(startYear: 2024) < TheocraticYear(startYear: 2025)`.

Use a fixed gregorian calendar pinned to GMT, exactly as
`HugoTests/Features/Reports/MonthlyReportBuilderTests.swift:8-12` does:

```swift
private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()
```

Build dates with a private `date(_ year: Int, _ month: Int, _ day: Int) -> Date`
helper using `DateComponents` and that calendar — copy the helper from the
bottom of `MonthlyReportBuilderTests.swift`. Never use `Date()` in assertions.

Create `HugoTests/Features/Reports/TheocraticYearReportBuilderTests.swift`
covering:

- An empty entry array still produces `months.count == 12` and `hasEntries == false`, and all totals are `0`.
- Entries dated outside the requested year are excluded (e.g. an entry in Aug of `startYear` when the year is `startYear/startYear+1`).
- A month with entries carries a non-nil `summary` whose `totalSeconds` matches, while the other 11 months are `nil`.
- Totals: two entries in different months of the same year sum into `totalSeconds`, `totalBibleStudies`, `mainDuration`, `separateDuration` (create `Tracker(name:type:iconName:)` values with `.main` and `.separate` as in `MonthlyReportBuilderTests.aggregatesCategoryAndBibleStudyTotals`).
- Month order is Sep→Aug: `report.months.map(\.id) == year.months`.
- `isFuture` is `true` for months after the injected `now` and `false` for the month containing `now`.

**Verify**: run the test command with
`-only-testing:HugoTests/TheocraticYearTests -only-testing:HugoTests/TheocraticYearReportBuilderTests`
→ `** TEST SUCCEEDED **`.

### Step 4: Add the localized strings

Edit `Hugo/Resources/Localizable.xcstrings`. It is JSON with 4-space
indentation and a space before each `:` (`"key" : {`). Insert new keys in
alphabetical order among the existing `"strings"` entries and match this exact
shape (this is the shape used by `tab.overview`, minus the auto-generated
comment flags):

```json
    "tab.year" : {
      "comment" : "The label for the Year tab in the app's tab bar.",
      "localizations" : {
        "da" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "År"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Year"
          }
        }
      }
    },
```

Keys to add:

| Key | en | da | Comment |
|---|---|---|---|
| `tab.year` | `Year` | `År` | The label for the Year tab in the app's tab bar. |
| `year.subtitle` | `Service Year` | `Tjenesteår` | Navigation subtitle below the theocratic year designation. |
| `year.picker.label` | `Choose Service Year` | `Vælg tjenesteår` | Label for the toolbar menu that switches between service years. |
| `year.month.empty` | `No entries` | `Ingen registreringer` | Shown on a month card in a past or current month that contains no entries. |
| `year.empty.title` | `No entries yet` | `Ingen registreringer endnu` | Title of the card shown when a whole service year contains no entries. |
| `year.empty.description` | `Months where you record service will show a summary here.` | `Måneder, hvor du registrerer tjeneste, vises her med et resumé.` | Explains what will appear once entries exist. |

Reuse the existing keys `monthlyReport.detail.largeTotal.main.label`,
`monthlyReport.detail.largeTotal.total.label`,
`monthlyReport.detail.largeTotal.separate.label` and `report.bible-studies` for
the year totals card — they already read "Field Service / Total / Other" and
"Bible Studies" in both languages. Do not duplicate them under `year.*`.

Do **not** delete `tab.report`, `reports.title`, or `report.pending.empty`.
Xcode will mark them stale on the next build.

**Verify**: `python3 -m json.tool Hugo/Resources/Localizable.xcstrings > /dev/null` → exit 0.

### Step 5: Build the year totals card and the empty-month row

Create `Hugo/Features/Reports/TheocraticYearTotalsView.swift`:

- `struct TheocraticYearTotalsView: View { let report: TheocraticYearReport }`.
- Copy the three-column layout of `Hugo/Features/Reports/MonthlyReportTotalsView.swift` verbatim in structure (`HStack(alignment: .bottom)`, a private `total(_:label:alignment:prominent:)` `@ViewBuilder`, `ServiceDurationFormatter.string(from:)`, the same three localized labels), fed by `report.mainDuration`, `report.totalSeconds`, `report.separateDuration`.
- Below it, a `Divider().padding(.vertical, 8)` and a bible-studies row identical in styling to `MonthlyReportRow.swift:41-47`: `Label("report.bible-studies", systemImage: "book")`, `Spacer()`, `Text(String(report.totalBibleStudies))` with `.fontDesign(.monospaced).foregroundStyle(.secondary)`.
- Wrap the whole thing in the card treatment used by `MonthlyReportRow`: `.padding(24)`, `.background(Color(.secondarySystemGroupedBackground))`, `.cornerRadius(32)`.

Create `Hugo/Features/Reports/MonthlyReportEmptyRow.swift`:

- `struct MonthlyReportEmptyRow: View { let month: TheocraticYearMonth }`.
- An `HStack` with the month name styled like the header in `MonthlyReportRow.swift:10-15` (`.font(.caption)`, `.textCase(.uppercase)`, `.tracking(1.5)`, `.fontWeight(.semibold)`) but `.foregroundStyle(month.isFuture ? .tertiary : .secondary)`, a `Spacer()`, and — only when `month.isFuture == false` — `Text("year.month.empty").font(.caption).foregroundStyle(.tertiary)`.
- Card treatment, visually lighter than a summary card: `.padding(.horizontal, 24)`, `.padding(.vertical, 20)`, `.frame(maxWidth: .infinity, alignment: .leading)`, `.background(Color(.secondarySystemGroupedBackground))`, `.cornerRadius(24)`.
- Not a `NavigationLink`, not tappable.
- `.accessibilityElement(children: .combine)` so VoiceOver reads "September 2025, no entries" as one element.

Add `#Preview` blocks for both, following the project pattern
(`#Preview { … .modelContainer(.preview) }`), fed by the fixtures added in
Step 6.

**Verify**: `xcrun swift-format lint --strict --recursive Hugo` → exit 0.

### Step 6: Extend the preview fixtures

Modify `Hugo/PreviewSupport/ReportPreviewFixtures.swift`. Keep `entries` and
`summary` exactly as they are (other previews may use them) and add:

- `static var currentYear: TheocraticYear { Date().theocraticYear() }`
- `static var yearReport: TheocraticYearReport { TheocraticYearReportBuilder.report(for: currentYear, entries: entries) }`
- `static var emptyMonth: TheocraticYearMonth` — the first month in `yearReport.months` whose `summary == nil`, falling back to `yearReport.months[0]`.

Everything stays inside the existing `@MainActor enum`.

**Verify**: `xcrun swift-format lint --strict --recursive Hugo` → exit 0.

### Step 7: Build the single-year page

Create `Hugo/Features/Reports/TheocraticYearPageView.swift`:

```swift
struct TheocraticYearPageView: View {
    let report: TheocraticYearReport
    // …
}
```

Body:

- A vertical `ScrollView` containing a `VStack(spacing: 24)`:
  - If `report.hasEntries` → `TheocraticYearTotalsView(report: report)`.
  - Else → an explanatory card: `VStack(alignment: .leading, spacing: 12)` with `Image(systemName: "calendar")` (`.font(.system(size: 40))`, `.symbolRenderingMode(.hierarchical)`, `.foregroundStyle(.secondary)`), `Text("year.empty.title")` (`.font(.title3).fontWeight(.semibold).fontDesign(.rounded)`) and `Text("year.empty.description")` (`.font(.subheadline).foregroundStyle(.secondary)`); same card treatment as the totals card, `.frame(maxWidth: .infinity, alignment: .leading)`.
  - `ForEach(report.months)` → `MonthlyReportRow(summary: summary)` when `month.summary` is non-nil, otherwise `MonthlyReportEmptyRow(month: month)`. Attach `.id(month.id)` to each row for Step 9.
- `.padding()` on the `VStack`, `.frame(maxWidth: .infinity)` and `.background(Color(.systemGroupedBackground))` on the `ScrollView` — this mirrors the current `ReportsView` chrome, and the background must be applied per page so the paged container does not show a white gap (see commit `0b6234a`).
- Add `#Preview` using `ReportPreviewFixtures.yearReport` inside a `NavigationStack` (`MonthlyReportRow` contains a `NavigationLink`) with `.modelContainer(.preview)`.

Do not compute the report here — it is passed in, per the "keep views purely
visual" rule.

**Verify**: `xcrun swift-format lint --strict --recursive Hugo` → exit 0.

### Step 8: Replace `ReportsView` with `YearView` and wire up the tab

Create `Hugo/Features/Reports/YearView.swift`:

```swift
struct YearView: View {
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @State private var selectedYear: TheocraticYear?
    // …
}
```

- One `@Query` for all entries — the dataset is a single publisher's service
  entries, so per-page predicates are not worth the complexity. Slicing happens
  in `TheocraticYearReportBuilder`.
- `private var years: [TheocraticYear]` → `TheocraticYear.availableYears(entryDates: entries.map(\.date), now: .now)`.
- `private var currentYear: TheocraticYear` → `Date().theocraticYear()`.
- `private var activeYear: TheocraticYear` → `selectedYear ?? currentYear`.
- Body:

```
NavigationStack {
    TabView(selection: <binding to activeYear>) {
        ForEach(years) { year in
            TheocraticYearPageView(report: TheocraticYearReportBuilder.report(for: year, entries: entries))
                .tag(year)
        }
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .background(Color(.systemGroupedBackground))
    .ignoresSafeArea(edges: .bottom)
    .navigationTitle(activeYear.displayName)
    .navigationSubtitle("year.subtitle")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar { … year menu … }
}
```

- The selection binding is `Binding(get: { activeYear }, set: { selectedYear = $0 })`.
- Toolbar item, `placement: .topBarTrailing`:

```swift
Menu {
    Picker("year.picker.label", selection: <same binding>) {
        ForEach(years.reversed()) { year in
            Text(year.displayName).tag(year)
        }
    }
    .pickerStyle(.inline)
} label: {
    Label("year.picker.label", systemImage: "calendar")
}
```

- If `years.count == 1`, still render the menu (it shows the single year); do
  not conditionally hide toolbar items.
- `#Preview { YearView().modelContainer(.preview) }`.

Then:

- Delete `Hugo/Features/Reports/ReportsView.swift` and `Hugo/Features/Reports/MonthlyReportListView.swift`.
- In `Hugo/App/AppRootView.swift`, replace the second tab with:
  `Tab("tab.year", systemImage: "calendar") { YearView() }`.

**Verify**:

- `grep -rn "ReportsView\|MonthlyReportListView" Hugo HugoTests` → no matches.
- `Scripts/verify.sh` → exit 0.

### Step 9: Open the current year on the current month

In `TheocraticYearPageView`, wrap the `VStack` in a `ScrollViewReader` and add:

```swift
@State private var didScrollToCurrentMonth = false
let initialMonth: YearMonth?   // passed in; nil for years that are not the current one
```

`YearView` passes `initialMonth: year == currentYear ? Date().yearMonth() : nil`.
On `.onAppear`, when `initialMonth` is non-nil and `didScrollToCurrentMonth` is
`false`, call `proxy.scrollTo(month, anchor: .top)` **without animation** and set
the flag. The guard matters because a paged `TabView` pre-renders adjacent
pages and re-triggers `onAppear` on swipe-back.

Past years always open at the top (September).

**Verify**: `Scripts/verify.sh` → exit 0, then in the simulator confirm the
manual checks in "Done criteria".

### Step 10: Update the plan index

In `plans/README.md`, add a row for plan 010 to the execution-order table with
status `DONE`, priority `P2`, effort `M`, depends-on `004`.

**Verify**: `git status --short` lists only files from the "In scope" list.

## Test plan

New test files (Swift Testing, matching the existing suites in
`HugoTests/Features/Reports/`):

- `HugoTests/Features/Reports/TheocraticYearTests.swift` — 8 cases, listed in Step 3. Structural model: `HugoTests/Features/Reports/YearMonthTests.swift`.
- `HugoTests/Features/Reports/TheocraticYearReportBuilderTests.swift` — 6 cases, listed in Step 3. Structural model: `HugoTests/Features/Reports/MonthlyReportBuilderTests.swift`, including its GMT calendar, `en_US_POSIX` locale, and `date(_:_:_:)` helper.

No UI tests — the project has none, and none should be introduced here.

Verification: the full test command → `** TEST SUCCEEDED **`, with all
pre-existing suites (`MonthlyReportBuilderTests`, `YearMonthTests`,
`OverviewMetricsTests`, `SchemaMigrationTests`, …) still passing.

## Done criteria

Machine-checkable — ALL must hold:

- [ ] `xcrun swift-format lint --strict --recursive Hugo HugoTests` exits 0
- [ ] `Scripts/verify.sh` exits 0 (lint, `** TEST SUCCEEDED **`, analyze clean)
- [ ] `grep -rn "ReportsView\|MonthlyReportListView" Hugo HugoTests` returns no matches
- [ ] `grep -rn "tab.report" Hugo/App` returns no matches
- [ ] `python3 -m json.tool Hugo/Resources/Localizable.xcstrings > /dev/null` exits 0
- [ ] `git status --short` lists only files from the "In scope" list
- [ ] `plans/README.md` has a status row for plan 010

Manual checks in the simulator (both `en` and `da` — set the scheme's App
Language to Danish for the second pass):

- [ ] Second tab reads "Year" / "År" with a calendar icon
- [ ] The screen opens on the current theocratic year; the title reads e.g. `2025/2026` with subtitle "Service Year" / "Tjenesteår"
- [ ] Exactly 12 month cards are present, September first and August last
- [ ] Months without entries render the compact "No entries" / "Ingen registreringer" card; months after the current month render dimmed with no trailing text
- [ ] Months with entries render the existing summary card and still push `MonthlyReportDetailView` when tapped
- [ ] Swiping horizontally moves between theocratic years and the navigation title updates
- [ ] The toolbar menu lists the available years newest-first and switching from it moves the page
- [ ] With an empty database only one page exists, the explanatory card is shown, and all 12 month cards are still listed

## STOP conditions

Stop and report back (do not improvise) if:

- The code at the locations in "Current state" does not match the excerpts (the codebase drifted since commit `4b647ce`).
- A step's verification fails twice after a reasonable fix attempt.
- The fix appears to require touching an out-of-scope file — in particular, if you conclude that `MonthlyReportBuilder.summaries` must change its sort order or signature.
- **Paging exception**: if the nested vertical `ScrollView` inside `.tabViewStyle(.page)` swallows the horizontal swipe, or the page style clips content under the root tab bar in a way `.ignoresSafeArea(edges: .bottom)` does not fix, you are pre-authorized to switch the container to `ScrollView(.horizontal)` + `LazyHStack` + `.containerRelativeFrame(.horizontal)` + `.scrollTargetBehavior(.paging)` + `.scrollPosition(id:)`, keeping every other decision identical. Note the switch in your report; do not invent a third approach.
- You discover that `Entry.date` can be `nil` or that entries exist outside any theocratic year (they cannot — `date` is non-optional with a default in `SchemaV8.Entry`).

## Maintenance notes

- `YearView` loads every `Entry` with one `@Query`. That is deliberate for a
  single-publisher dataset. If entry counts ever reach thousands, move to a
  per-page `@Query` with a `#Predicate` bounded by the year's September 1 /
  September 1 dates, and keep `TheocraticYearReportBuilder` unchanged.
- `TheocraticYearReportBuilder` intentionally filters by `YearMonth` rather than
  by a `DateInterval`, which keeps the September 1 boundary time-zone-agnostic.
  Preserve that if a date-range filter is added later.
- A reviewer should scrutinize: the September/August boundary in
  `TheocraticYear.containing(_:)`, the contiguity of
  `availableYears(entryDates:now:)`, and that the Danish strings use
  "tjenesteår" (the term already used in `reports.submitted.empty.description`).
- Deliberately deferred out of this plan: tapping an empty month to add an
  entry for that month, sharing/exporting a full year, year-over-year
  comparison charts, and renaming the `Hugo/Features/Reports` folder. The folder
  keeps its name because the month detail stack, the summary model, and the
  aggregation layer are all still "reports"; only the screen changed.

---

**Boundaries of this planning pass**

- No implementation was performed.
- Investigation was limited to the Report screen, the reporting domain it consumes, the root tab declaration, the preview fixtures, and the string catalog.
- No whole-codebase audit was performed.
- No unrelated fixes, cleanup, refactors, or roadmap work are included.
