# Plan 011: Let an empty month on the Year screen create a back-dated entry

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Prerequisite**: `plans/010-year-screen-theocratic-year.md` must be DONE.
> This plan modifies files that plan 010 creates. If
> `Hugo/Features/Reports/MonthlyReportEmptyRow.swift` does not exist, STOP.
>
> **Drift check (run first)**:
> `git diff --stat 4b647ce..HEAD -- Hugo/Features/Entries/AddEntry Hugo/Features/Reports/Domain/YearMonth.swift Hugo/Resources/Localizable.xcstrings`
> If `AddEntryView.swift`, `AddEntryFormModel.swift`, or `YearMonth.swift`
> changed since this plan was written, compare the "Current state" excerpts
> against the live code before proceeding; on a mismatch, treat it as a STOP
> condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/010-year-screen-theocratic-year.md
- **Category**: direction
- **Planned at**: commit `4b647ce`, 2026-07-27
- **Issue**: n/a

## Why this matters

Plan 010 turns the second tab into a full theocratic year: twelve month cards,
September through August, with empty months rendered as inert "No entries"
placeholders. The moment a user sees an empty November they have forgotten to
fill in, the natural gesture is to tap it — and today nothing happens. They have
to go back to the Overview tab, open Add Entry, and manually wheel the date
picker back several months.

After this plan, tapping an empty past month opens the existing Add Entry sheet
with the date already set inside that month and the date picker clamped to it,
so the entry cannot silently land in the wrong month. The year view becomes the
place you *fix* a year, not just read one.

## Current state

### Files that own the behavior today

- `Hugo/Features/Reports/MonthlyReportEmptyRow.swift` — **created by plan 010.** Non-interactive card for a month with no entries. Holds `let month: TheocraticYearMonth` and shows the month name plus `Text("year.month.empty")` when `month.isFuture == false`.
- `Hugo/Features/Reports/TheocraticYearPageView.swift` — **created by plan 010.** Renders `MonthlyReportRow` or `MonthlyReportEmptyRow` per month inside a vertical `ScrollView`. Receives `let report: TheocraticYearReport`.
- `Hugo/Features/Reports/YearView.swift` — **created by plan 010.** Owns the `@Query` for all entries and the paged `TabView` of years.
- `Hugo/Features/Reports/Domain/TheocraticYearReport.swift` — **created by plan 010.** Defines `TheocraticYearMonth { let id: YearMonth; let displayName: String; let summary: MonthlyReportSummary?; let isFuture: Bool }`.
- `Hugo/Features/Reports/Domain/YearMonth.swift` — the `YearMonth` value type.
- `Hugo/Features/Entries/AddEntry/AddEntryView.swift` — the Add Entry sheet, presented today only from `OverviewView` and `MonthlyProgressCard`.
- `Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift` — `@MainActor @Observable` form state plus the `EntryDraft` value type.
- `HugoTests/Features/Entries/AddEntryFormModelTests.swift` — existing coverage for the form model.
- `HugoTests/Features/Reports/YearMonthTests.swift` — existing coverage for `YearMonth`.

### Code as it exists today

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

`Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift:11-53`

```swift
@MainActor
@Observable
final class AddEntryFormModel {
    var date: Date
    var time: Date?
    var durationDate: Date
    var bibleStudies = 0
    var selectedTracker: Tracker?
    var isTimePickerPresented = false
    var isCategoryPickerPresented = false
    var validationMessage: String?

    private let calendar: Calendar
    private let now: Date

    init(calendar: Calendar = .current, now: Date = .now) {
        self.calendar = calendar
        self.now = now
        self.date = calendar.startOfDay(for: now)
        self.durationDate = calendar.startOfDay(for: now)
    }
    // …
    var combinedDate: Date? {
        guard var components = calendar.dateComponents([.year, .month, .day], from: date) as DateComponents? else { return nil }
        if let time {
            components.hour = calendar.component(.hour, from: time)
            components.minute = calendar.component(.minute, from: time)
            components.second = calendar.component(.second, from: time)
        } else {
            components.hour = 0
            components.minute = 0
            components.second = 0
        }
        return calendar.date(from: components)
    }
```

`Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift:70-77`

```swift
    func draft() -> EntryDraft? {
        guard let combinedDate, let selectedTracker, durationInSeconds > 0 else {
            validationMessage = "entry.add.validation.invalid"
            return nil
        }
        validationMessage = nil
        return EntryDraft(date: combinedDate, duration: durationInSeconds, tracker: selectedTracker, bibleStudies: bibleStudies)
    }
```

`Hugo/Features/Entries/AddEntry/AddEntryView.swift:4-8` and `:26-38`

```swift
struct AddEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var trackers: [Tracker]
    @State private var form = AddEntryFormModel()
    // …
                Section {
                    DatePicker("entry.date.label", selection: $form.date, in: ...Date.now, displayedComponents: .date)
                    Button {
                        form.isTimePickerPresented = true
                    } label: {
                        HStack {
                            Text("entry.time.label")
                            Spacer()
                            timeLabel
                                .foregroundStyle(.secondary)
                        }
                    }
                }
```

`Hugo/Features/Entries/AddEntry/AddEntryView.swift:65-69` — the alert that renders `validationMessage`:

```swift
            .alert("common.error", isPresented: errorAlertBinding) {
                Button("common.dismiss", role: .cancel) { form.validationMessage = nil }
            } message: {
                Text(form.validationMessage ?? String(localized: "common.error"))
            }
```

### Blocker found in the direct path of this change

`AddEntryFormModel.draft()` assigns the **raw key** `"entry.add.validation.invalid"`
to `validationMessage`, which is a plain `String`. `Text(_ : String)` does not
localize, and that key does not exist in `Hugo/Resources/Localizable.xcstrings`
at all — verified with:

```sh
python3 -c "import json;print('entry.add.validation.invalid' in json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'])"
```

which prints `False`. The alert therefore shows the literal string
`entry.add.validation.invalid` to the user. This plan adds a *second* validation
path through the same field, so the fix is in scope (Step 1). It is the only
pre-existing defect this plan touches; nothing else in `AddEntry` is changed
beyond what the feature requires.

### Repository conventions that apply here

Quoted from `AGENTS.md` — the executor has not read that file:

- "**Definition:** A theocratic year runs from **September 1st** of one year to **August 31st** of the following year."
- "Keep Views purely visual. Do not perform complex data mapping, computation, or database queries inside the View body."
- "Use `@Bindable` when you need to create bindings (`$`) to properties of an `@Observable` model object." — `AddEntryView` already does this with `@Bindable var form = form` at the top of its body.
- "Never use legacy property wrappers: `ObservableObject`, `@Published`, `@StateObject`, or `@ObservedObject`."
- "**Ease of use.** … the user base ranges from around 13 to 70 years." — a tap target that changes behavior must *look* like a button, not be a hidden gesture.
- "**Simplicity.** Always keep the app as simple as possible, do not add unnecessary features."
- `nonisolated` is applied explicitly to pure value types because the project builds with MainActor default isolation.

Formatting is enforced by `.swift-format`: 4-space indentation, 120-column line length, max 1 blank line.

Xcode uses `fileSystemSynchronizedGroups`, so **new files do not require `project.pbxproj` edits.**

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Format fix | `xcrun swift-format format --in-place --recursive Hugo HugoTests` | exit 0 |
| Full verification | `Scripts/verify.sh` | exit 0 (lint + test + analyze) |
| Tests only | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoDerivedData CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **` |
| Single suite | append `-only-testing:HugoTests/AddEntryFormModelTests` to the test command | `** TEST SUCCEEDED **` |
| String catalog is valid JSON | `python3 -m json.tool Hugo/Resources/Localizable.xcstrings > /dev/null` | exit 0, no output |

## Scope

**In scope** (the only files you may modify or create):

- `Hugo/Features/Reports/Domain/YearMonth.swift` (modify — add `Identifiable` and one date helper)
- `Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift` (modify — month seeding, clamped range, validation)
- `Hugo/Features/Entries/AddEntry/AddEntryView.swift` (modify — new initializer, clamped date picker)
- `Hugo/Features/Reports/MonthlyReportEmptyRow.swift` (modify — becomes a button for past months)
- `Hugo/Features/Reports/TheocraticYearPageView.swift` (modify — forward the tap upwards)
- `Hugo/Features/Reports/YearView.swift` (modify — own the sheet)
- `Hugo/Resources/Localizable.xcstrings` (modify — add keys)
- `HugoTests/Features/Reports/YearMonthTests.swift` (modify — cover the new helper)
- `HugoTests/Features/Entries/AddEntryFormModelTests.swift` (modify — cover seeding and clamping)
- `plans/README.md` (status row only)

**Out of scope** (do NOT touch, even though they look related):

- `Hugo/Features/Overview/OverviewView.swift` and `MonthlyProgressCard.swift` — they call `AddEntryView()` with no arguments; the new initializer parameter must be defaulted so these call sites compile unchanged. Do not "modernize" them.
- `Hugo/Features/Entries/EntryDetailView.swift` — editing an existing entry keeps its current unclamped date behavior. Making the *edit* flow month-aware is a different feature.
- `Hugo/Features/Reports/MonthlyReportRow.swift` — months that already have entries keep navigating to `MonthlyReportDetailView`. Do not add an inline add-button to the summary card.
- `Hugo/Features/Reports/Domain/TheocraticYearReportBuilder.swift`, `TheocraticYear.swift`, `MonthlyReportBuilder.swift` — aggregation is unaffected.
- Anything under `Hugo/Persistence/` — no schema change; `Entry` already stores an arbitrary `date`.
- Broadening the fix of the unlocalized `validationMessage` into a general "make all error strings `LocalizedStringResource`" refactor. Fix the two keys this plan uses and stop.

## Git workflow

- Branch: `advisor/011-add-entry-from-empty-month`
- Commit per step or per logical unit. Repo style for plan work (see `git log`): `` `011` – Add entries from an empty month ``.
- Do NOT push or open a PR unless the operator instructs it.

## Design decisions (already made — implement these, do not re-litigate)

1. **Only empty, non-future months are tappable.** A month with entries keeps its `NavigationLink` to the detail screen. A future month stays completely inert — you cannot log service you have not done.
2. **The affordance is visible.** The empty row grows a trailing `plus.circle.fill` and the text changes from "No entries" to "Add entry". A card that silently does something on tap fails the ease-of-use principle.
3. **The sheet is owned by `YearView`, not by the page.** A paged `TabView` keeps adjacent pages alive; presenting a sheet from a page that may scroll offscreen mid-presentation is a known source of dismissal glitches. `YearView` holds `@State private var addEntryMonth: YearMonth?` and uses `.sheet(item:)`.
4. **Seed date**: if the tapped month is the month containing "now", seed today; otherwise seed the **1st** of that month. The 1st is the conventional start-of-period default and the user adjusts the day anyway.
5. **The date picker is clamped to the tapped month** (and never past "now"). Without this, a user can open November and save into December, which contradicts the card they tapped.
6. **`draft()` validates month membership** as a second line of defence, comparing `YearMonth` values rather than raw dates — because `combinedDate` adds a time-of-day that can push the last day of a month past a raw upper bound.
7. **No new sheet, no duplicated form.** This is `AddEntryView` with one defaulted initializer parameter.

## Edge cases

These two are the reason this is not a five-line change. Both are date-dependent
failures that pass a casual manual test and break later, in production, on one
specific day. Each has a named regression test in Step 7. Neither may be dropped,
and the two fixes are coupled — "fixing" one the obvious way breaks the other.

### EC-1: the last day of the month, with a time of day

`AddEntryFormModel.combinedDate` folds the selected `time` into the selected
`date` (`AddEntryFormModel.swift:41-53`). A user who taps the November 2025 card,
picks the 30th, and sets the time to 23:30 produces `2025-11-30 23:30:00` — which
is **later than** `YearMonth.endDate`, because `endDate` is the start of the last
day (`2025-11-30 00:00:00`).

A guard written the obvious way, `combinedDate <= endDate`, therefore rejects a
perfectly valid entry on the last day of every month at any time after midnight.
It works for 29 days and fails on the 30th.

**Required behavior**: `draft()` compares `YearMonth` values, never raw dates.

```swift
if let month, combinedDate.yearMonth(using: calendar) != month { … }
```

`.yearMonth(using:)` discards the time of day, so the entire last day passes
while anything in a neighbouring month still fails.

**Do not** resolve this by moving `endDate` to the first instant of the next
month — that breaks EC-2.

| Input (target month = 2025/11) | `combinedDate` | `draft()` |
|---|---|---|
| 30 Nov, no time | 2025-11-30 00:00 | non-nil |
| 30 Nov, 23:30 | 2025-11-30 23:30 | non-nil |
| 1 Nov, no time | 2025-11-01 00:00 | non-nil |
| 1 Dec, no time | 2025-12-01 00:00 | `nil`, `validationMessage` set |
| 31 Oct, 23:59 | 2025-10-31 23:59 | `nil`, `validationMessage` set |

### EC-2: `endDate` is the start of the last day, not the end of the month

`DatePicker(… displayedComponents: .date)` treats its `ClosedRange<Date>` upper
bound as a concrete instant, and normalizes the days it offers to midnight. Two
tempting definitions of `endDate` both fail:

* First instant of the next month (`2025-12-01 00:00`) — December 1 becomes
  selectable from the November card, defeating the clamp.
* Last second of the month (`2025-11-30 23:59:59`) — correct for comparison, but
  it invites the `<=` guard that EC-1 forbids, and it makes the bound depend on
  second-level arithmetic no reader can verify at a glance.

**Required behavior**: `endDate` returns midnight on the last day of the month,
computed as `startDate` plus one month minus one day via
`calendar.date(byAdding:)`. Never hard-code 28/30/31, and never subtract a
literal `86_400` — that is wrong across a DST transition.

| `YearMonth` | `startDate` | `endDate` | Case |
|---|---|---|---|
| 2025/11 | 2025-11-01 00:00 | 2025-11-30 00:00 | 30-day month |
| 2025/12 | 2025-12-01 00:00 | 2025-12-31 00:00 | 31-day month, year boundary |
| 2026/02 | 2026-02-01 00:00 | 2026-02-28 00:00 | non-leap February |
| 2024/02 | 2024-02-01 00:00 | 2024-02-29 00:00 | leap February |

`endDate` is therefore an **inclusive day marker**, not an exclusive interval
bound. Any future code that filters entries with `entry.date < endDate` will
silently drop the last day of every month. This is restated in
"Maintenance notes" for whoever owns the file next.

## Steps

### Step 1: Add the missing validation strings and fix the raw-key bug

Edit `Hugo/Resources/Localizable.xcstrings`. It is JSON with 4-space
indentation and a space before each `:` (`"key" : {`). Insert new keys in
alphabetical order among the existing `"strings"` entries, matching the exact
shape used by `tab.overview`:

| Key | en | da | Comment |
|---|---|---|---|
| `entry.add.validation.invalid` | `Enter a duration and choose a category.` | `Angiv en varighed, og vælg en kategori.` | Shown when the entry form is submitted without a duration or a category. |
| `entry.add.validation.outsideMonth` | `The date must be in the month you selected.` | `Datoen skal ligge i den måned, du valgte. ` | Shown when a back-dated entry would land outside the month it was started from. |
| `year.month.add` | `Add entry` | `Tilføj registrering` | Action on a past month that contains no entries. |
| `year.month.add.hint` | `Adds an entry dated in this month.` | `Tilføjer en registrering i denne måned.` | VoiceOver hint for the add action on an empty month. |

Remove the trailing space from the Danish `outsideMonth` value if you copied it
from the table above.

Then, in `Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift`, change the
assignment in `draft()` from the raw key to a localized lookup:

```swift
validationMessage = String(localized: "entry.add.validation.invalid")
```

`validationMessage` stays a `String` — `AddEntryView` renders it with
`Text(form.validationMessage ?? …)` and also assigns
`error.localizedDescription` to it in `submit()`. Do not change its type.

**Verify**:

- `python3 -m json.tool Hugo/Resources/Localizable.xcstrings > /dev/null` → exit 0
- `grep -n 'validationMessage = "' Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift` → no matches

### Step 2: Extend `YearMonth` with identity and a default entry date

Edit `Hugo/Features/Reports/Domain/YearMonth.swift`:

- Add `Identifiable` to the declaration: `nonisolated struct YearMonth: Hashable, Comparable, Identifiable` with `var id: YearMonth { self }`. This is what lets `YearView` use `.sheet(item:)` without inventing a wrapper type.
- Add to the existing `extension YearMonth` block (the one holding `monthYearString`):

```swift
    func startDate(using calendar: Calendar = .current) -> Date?
    func endDate(using calendar: Calendar = .current) -> Date?
    func defaultEntryDate(now: Date, calendar: Calendar = .current) -> Date
```

Behavior:

- `startDate` — `calendar.date(from: DateComponents(year: year, month: month))`, i.e. midnight on the 1st.
- `endDate` — the **start of the last day** of the month, not the first instant of the next month. Compute it as `startDate` plus one month minus one day, via `calendar.date(byAdding:)`. Do not hard-code 28/30/31 and do not subtract a literal `86_400`. **Read "EC-2" in the Edge cases section before writing this — it has the exact expected values for 30-day, 31-day, non-leap-February and leap-February months, and explains why the two obvious alternatives are wrong.**
- `defaultEntryDate(now:calendar:)` — if `now.yearMonth(using: calendar) == self`, return `calendar.startOfDay(for: now)`; otherwise return `startDate(using: calendar)`, falling back to `calendar.startOfDay(for: now)` if the components cannot be resolved.

Keep everything `nonisolated` — these are pure calendar computations with no
`Entry` dependency.

**Verify**: `xcrun swift-format lint --strict --recursive Hugo` → exit 0, no output.

### Step 3: Teach `AddEntryFormModel` about a target month

Edit `Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift`.

Change the initializer to:

```swift
    init(calendar: Calendar = .current, now: Date = .now, month: YearMonth? = nil)
```

- Store `private let month: YearMonth?`.
- `self.date = month?.defaultEntryDate(now: now, calendar: calendar) ?? calendar.startOfDay(for: now)`
- `self.durationDate` stays `calendar.startOfDay(for: now)` — it only carries hours and minutes, so the day component is irrelevant.
- The existing two-argument call sites keep compiling because `month` is defaulted.

Add a computed range used by the view:

```swift
    var dateRange: ClosedRange<Date>
```

- Upper bound: `min(month?.endDate(using: calendar) ?? now, now)` — never the future, never past the month.
- Lower bound: `month?.startDate(using: calendar) ?? .distantPast`.
- If the computed lower bound is somehow greater than the upper bound (a month entirely in the future, which the UI must never allow), collapse the range to `upper...upper` so `DatePicker` cannot crash on an invalid range. This is a safety clamp, not a supported path.

Add month validation to `draft()`, after the existing `guard`:

```swift
        if let month, combinedDate.yearMonth(using: calendar) != month {
            validationMessage = String(localized: "entry.add.validation.outsideMonth")
            return nil
        }
```

Compare `YearMonth` values, not raw dates. **This is EC-1 in the Edge cases
section — read it before writing this guard.** `combinedDate` folds in a
time-of-day, so a `combinedDate <= endDate` comparison rejects every valid entry
made on the last day of a month after midnight. `.yearMonth(using:)` discards
the time and makes the whole last day pass.

Do not change `EntryDraft`, `durationInSeconds`, `isSubmitDisabled`,
`reconcileSelection`, or `EntryDurationConversion`.

**Verify**: `xcrun swift-format lint --strict --recursive Hugo` → exit 0.

### Step 4: Give `AddEntryView` a month-seeded initializer

Edit `Hugo/Features/Entries/AddEntry/AddEntryView.swift`.

Add an explicit initializer that seeds the `@State` form (the default-value
initializer must be replaced, since `@State` initial values cannot reference
parameters otherwise):

```swift
    init(month: YearMonth? = nil) {
        _form = State(initialValue: AddEntryFormModel(month: month))
    }
```

Change the date picker at line 27 from the hard-coded partial range to the
model's range:

```swift
    DatePicker("entry.date.label", selection: $form.date, in: form.dateRange, displayedComponents: .date)
```

Nothing else in the file changes. `OverviewView` and `MonthlyProgressCard` call
`AddEntryView()` and must continue to compile untouched.

Add a second preview alongside the existing one:

```swift
#Preview("Back-dated") {
    AddEntryView(month: YearMonth(year: 2025, month: 11)).modelContainer(.preview)
}
```

**Verify**:

- `grep -rn "AddEntryView()" Hugo` → still matches in `OverviewView.swift` and/or `MonthlyProgressCard.swift`, unchanged
- `xcrun swift-format lint --strict --recursive Hugo` → exit 0

### Step 5: Make the empty month row actionable

Edit `Hugo/Features/Reports/MonthlyReportEmptyRow.swift` (created by plan 010).

Add a second stored property:

```swift
    let month: TheocraticYearMonth
    let onAddEntry: (() -> Void)?
```

Behavior:

- When `month.isFuture == true` **or** `onAddEntry == nil`, render exactly the card plan 010 specified: month name, no trailing action, not tappable. Keep `.accessibilityElement(children: .combine)`.
- Otherwise wrap the card in a `Button(action:)` with `.buttonStyle(.plain)` so the card keeps its own background rather than taking on tint styling, and change the trailing content from `Text("year.month.empty")` to an `HStack(spacing: 6)` of `Text("year.month.add")` and `Image(systemName: "plus.circle.fill")`, both `.font(.caption)` with `.foregroundStyle(.secondary)` on the text and `.tint`/accent styling on the symbol so it reads as an action.
- On the button, add `.accessibilityHint("year.month.add.hint")`.

Keep the existing card treatment (`.padding(.horizontal, 24)`,
`.padding(.vertical, 20)`, `.frame(maxWidth: .infinity, alignment: .leading)`,
`.background(Color(.secondarySystemGroupedBackground))`, `.cornerRadius(24)`)
and the dimmed `.tertiary` month name for future months.

Update the previews to show all three states: future month, past month with an
action, past month without one.

**Verify**: `xcrun swift-format lint --strict --recursive Hugo` → exit 0.

### Step 6: Forward the tap from the page to `YearView`

Edit `Hugo/Features/Reports/TheocraticYearPageView.swift` (created by plan 010).

Add a stored callback:

```swift
    let onAddEntry: (YearMonth) -> Void
```

In the `ForEach` over `report.months`, pass it down for empty months only:

```swift
    MonthlyReportEmptyRow(
        month: month,
        onAddEntry: month.isFuture ? nil : { onAddEntry(month.id) }
    )
```

`MonthlyReportRow` (months with entries) is unchanged and keeps its
`NavigationLink`.

Update the page preview to pass `onAddEntry: { _ in }`.

Edit `Hugo/Features/Reports/YearView.swift` (created by plan 010):

- Add `@State private var addEntryMonth: YearMonth?`.
- Pass `onAddEntry: { addEntryMonth = $0 }` into `TheocraticYearPageView`.
- Attach the sheet to the `NavigationStack`'s content, **outside** the paged `TabView`, next to the existing `.navigationTitle` / `.toolbar` modifiers:

```swift
    .sheet(item: $addEntryMonth) { month in
        AddEntryView(month: month)
    }
```

No refresh plumbing is needed: `YearView` already holds a SwiftData `@Query`
for all entries, so saving in the sheet re-runs
`TheocraticYearReportBuilder.report(for:entries:)` and the placeholder card is
replaced by a real summary card automatically.

**Verify**: `Scripts/verify.sh` → exit 0.

### Step 7: Cover the new logic with tests

Extend `HugoTests/Features/Reports/YearMonthTests.swift` (Swift Testing,
`@MainActor struct`, `@Test`, `#expect`). It currently constructs no calendar,
so add the project-standard GMT calendar and `date(_:_:_:)` helper copied from
`HugoTests/Features/Entries/AddEntryFormModelTests.swift:7-11` and `:86-88`.

New cases:

- `startDate` of `YearMonth(year: 2025, month: 11)` is 2025-11-01 at midnight.
- **EC-2 regression**, one case per row of the EC-2 table: `endDate` of 2025/11 is 2025-11-30, of 2025/12 is 2025-12-31, of 2026/02 is 2026-02-28 (non-leap), of 2024/02 is 2024-02-29 (leap). Assert the full `Date`, not just the day component, so a wrong time-of-day fails too.
- `defaultEntryDate(now:)` for a month that is *not* the current month returns the 1st.
- `defaultEntryDate(now:)` for the month containing `now` returns `startOfDay(for: now)`, not the 1st.

Extend `HugoTests/Features/Entries/AddEntryFormModelTests.swift`:

- `seedsDateFromTargetMonth` — `AddEntryFormModel(calendar:now: date(2026, 1, 15), month: YearMonth(year: 2025, month: 11))` has `date` equal to 2025-11-01.
- `seedsTodayWhenTargetMonthIsCurrent` — same but `month: YearMonth(year: 2026, month: 1)` → `date` equals `startOfDay` of 2026-01-15.
- `unseededModelKeepsExistingBehavior` — `AddEntryFormModel(calendar:now:)` with no month still starts at `startOfDay(for: now)` (guards the Overview call sites).
- `clampsDateRangeToTargetMonth` — for a fully past month the range is 1st → last day of that month; for the current month the upper bound is `now`, not the end of the month.
- `unseededDateRangeEndsAtNow` — `dateRange.upperBound == now` and the lower bound is `.distantPast`.
- `rejectsDraftOutsideTargetMonth` — seed month November 2025, set `date` to 2025-12-05, a valid duration and a `Tracker`; `draft()` returns `nil` and `validationMessage` is non-nil.
- **EC-1 regression** — `acceptsDraftOnLastDayOfTargetMonthWithLateTime`: seed month November 2025, `date` = 2025-11-30, `time` = 23:30, a valid duration and a `Tracker`; `draft()` is non-nil and `validationMessage` is `nil`. Then extend it, or add a `@Test(arguments:)` case, covering every row of the EC-1 table so both the accepted and the rejected boundaries are pinned.

Construct trackers with `Tracker(name:)` as the existing tests do; no model
container is required for these cases.

**Verify**: the test command with
`-only-testing:HugoTests/YearMonthTests -only-testing:HugoTests/AddEntryFormModelTests`
→ `** TEST SUCCEEDED **`, 7 new form-model cases and 6 new `YearMonth` cases.

### Step 8: Update the plan index

In `plans/README.md`, add a row for plan 011 to the execution-order table with
status `DONE`, priority `P3`, effort `S`, depends-on `010`.

**Verify**: `git status --short` lists only files from the "In scope" list.

## Test plan

No new test files — both suites already exist and are extended in place:

- `HugoTests/Features/Reports/YearMonthTests.swift` — 6 new cases (month bounds incl. leap February, seeded default date).
- `HugoTests/Features/Entries/AddEntryFormModelTests.swift` — 7 new cases (seeding, unseeded regression, range clamping, month validation incl. the last-day-late-time edge case).

All existing cases in both files must keep passing unchanged; if
`unseededModelKeepsExistingBehavior` or any pre-existing case fails, the
defaulted initializer parameter was implemented wrong.

No UI tests — the project has none, and none should be introduced here.

Verification: `Scripts/verify.sh` → `** TEST SUCCEEDED **` with every
pre-existing suite still green.

## Done criteria

Machine-checkable — ALL must hold:

- [ ] `xcrun swift-format lint --strict --recursive Hugo HugoTests` exits 0
- [ ] `Scripts/verify.sh` exits 0 (lint, `** TEST SUCCEEDED **`, analyze clean)
- [ ] `python3 -m json.tool Hugo/Resources/Localizable.xcstrings > /dev/null` exits 0
- [ ] `python3 -c "import json;s=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'];print(all(k in s for k in ['entry.add.validation.invalid','entry.add.validation.outsideMonth','year.month.add','year.month.add.hint']))"` prints `True`
- [ ] `grep -n 'in: ...Date.now' Hugo/Features/Entries/AddEntry/AddEntryView.swift` returns no matches
- [ ] EC-1: `acceptsDraftOnLastDayOfTargetMonthWithLateTime` exists and passes, and `grep -n 'combinedDate <=\|combinedDate >=\|combinedDate <\|combinedDate >' Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift` returns no matches
- [ ] EC-2: `grep -n '86_400\|86400\|byAdding: .day, value: -1, to: nextMonth' Hugo/Features/Reports/Domain/YearMonth.swift` returns no `86_400`/`86400` matches, and the leap-February case 2024/02 → 2024-02-29 passes
- [ ] `git diff --name-only` does not list `Hugo/Features/Overview/OverviewView.swift` or `Hugo/Features/Overview/MonthlyProgressCard.swift`
- [ ] `git status --short` lists only files from the "In scope" list
- [ ] `plans/README.md` has a status row for plan 011

Manual checks in the simulator (both `en` and `da` — set the scheme's App
Language to Danish for the second pass):

- [ ] A past month with no entries shows "Add entry" / "Tilføj registrering" and a plus symbol, and looks pressable
- [ ] Tapping it opens Add Entry with the date already set to the 1st of that month
- [ ] The date picker in that sheet cannot be moved outside the tapped month, and **the last day of the month is selectable** (EC-2)
- [ ] EC-1 by hand: from an empty February card, pick the 28th (or 29th in a leap year), set a time of 23:30, and save — the entry is accepted and lands in February
- [ ] Saving dismisses the sheet and the placeholder card is immediately replaced by a real summary card, with the year totals updated
- [ ] The empty *current* month seeds today's date, and its picker upper bound is today
- [ ] A future month shows no action and does not respond to taps
- [ ] A month that already has entries still navigates to the detail screen
- [ ] Add Entry opened from the Overview tab still defaults to today and still allows any past date
- [ ] Submitting the Overview sheet with no category shows a readable message, not the literal text `entry.add.validation.invalid`

## STOP conditions

Stop and report back (do not improvise) if:

- `Hugo/Features/Reports/MonthlyReportEmptyRow.swift`, `TheocraticYearPageView.swift`, or `YearView.swift` do not exist — plan 010 has not landed, and this plan cannot be executed.
- The code at the locations in "Current state" does not match the excerpts (the codebase drifted since commit `4b647ce`).
- A step's verification fails twice after a reasonable fix attempt.
- Making `YearMonth` conform to `Identifiable` produces an ambiguity or conformance conflict with `MonthlyReportSummary` / `TheocraticYearMonth` (both use `YearMonth` as their `ID`). If so, do **not** unpick those types — instead introduce a local `nonisolated struct AddEntryMonthTarget: Identifiable { let month: YearMonth; var id: YearMonth { month } }` in `YearView.swift` and revert the `Identifiable` conformance. Report the switch.
- `DatePicker` rejects the computed `dateRange` at runtime (invalid range crash) for any month reachable through the UI.
- Either edge case cannot be satisfied without contradicting the other — that is, you cannot find a definition of `endDate` that both keeps the last day selectable in the picker (EC-2) and passes the EC-1 table. Report the conflict rather than relaxing the clamp or dropping a test.
- The fix appears to require touching an out-of-scope file — in particular `OverviewView.swift`, `MonthlyProgressCard.swift`, or anything in `Hugo/Persistence/`.

## Maintenance notes

- `AddEntryFormModel.month` is the single source of truth for both the picker
  clamp and the `draft()` guard. If a future feature needs an unclamped
  back-dated entry, add an explicit flag rather than passing `nil` for `month`
  and re-deriving the month elsewhere.
- `YearMonth.endDate` deliberately returns the **start of the last day**, not the
  first instant of the next month. Anything that starts using it as an exclusive
  upper bound for filtering entries will silently drop the last day of the month.
- A reviewer should scrutinize, in this order: the EC-1 guard in `draft()` (it
  must compare `YearMonth`, not `Date`), the EC-2 arithmetic in `endDate`
  (`byAdding:` month then day, no literal seconds, leap February correct), and
  that `AddEntryView()` with no arguments still behaves exactly as before for the
  Overview tab.
- If a future change makes `endDate` exclusive, EC-1's guard and EC-2's picker
  bound must be revisited **together**. They are two halves of one decision.
- Deliberately deferred: making `EntryDetailView`'s date picker month-aware,
  an add-entry affordance on months that already have entries, and converting
  `validationMessage` from `String` to `LocalizedStringResource` across the
  entry feature.

---

**Boundaries of this planning pass**

- No implementation was performed.
- Investigation was limited to the Add Entry flow, the `YearMonth` value type, the plan-010 Year screen files this feature attaches to, and the string catalog.
- No whole-codebase audit was performed.
- One pre-existing defect is included (the unlocalized, missing `entry.add.validation.invalid` key) solely because this plan adds a second code path through the same field; no other unrelated fixes, cleanup, or refactors are included.
