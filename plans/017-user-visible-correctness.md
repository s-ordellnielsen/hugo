# Plan 017: Fix four user-visible defects and unify error alerts

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for plan 017
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat d65afec..HEAD -- Hugo/Features/Overview Hugo/Features/Entries Hugo/Features/Categories/AddCategoryView.swift Hugo/Features/Categories/DefaultCategoryButton.swift Hugo/Features/Categories/CategoryDetailView.swift Hugo/Features/Reports/SubmitReportFormModel.swift Hugo/App/AppRootView.swift Hugo/Resources/Localizable.xcstrings`
> If any in-scope file changed, compare the "Current state" excerpts against
> the live code; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: plans/016-green-verification-gate.md
- **Category**: bug
- **Planned at**: commit `d65afec`, 2026-08-06

## Why this matters

Four defects reach the user:

1. The "Detailed Report" sheet, opened from the **monthly** progress card,
   shows **all-time** totals — its query has no date filter. The numbers
   contradict the card the user just tapped.
2. An error alert can display a **raw localization key** instead of a message.
3. The single most important write in the app — persisting a submitted monthly
   report — is `try?`. If it fails, the SMS has already been sent, the sheet
   dismisses, and nothing is recorded: the reminder recurs and carry-over
   minutes are silently lost.
4. `.sheet(item:)` is attached to a `ForEach`, so the presentation is
   distributed across every generated row rather than owned once by a stable
   container.

Fixes 2 lands cleanly only if the duplicated alert plumbing is unified first,
so that is Step 1.

## Current state

### A. The unfiltered breakdown

`Hugo/Features/Overview/CategoryProgressBreakdownView.swift:4-9`:

```swift
struct CategoryProgressBreakdownView: View {
    @Query private var entries: [Entry]
    @Query private var trackers: [Tracker]
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""

    private var rows: [CategoryProgressRow] { CategoryProgressAggregator.rows(entries: entries, trackers: trackers) }
```

`Hugo/Features/Overview/MonthlyProgressDetailView.swift:3-9` — the breakdown is
the entire body of the sheet titled `monthlyReport.detailView.title`
("Detailed Report" / "Detaljeret rapport"):

```swift
struct MonthlyProgressDetailView: View {
    var body: some View {
        NavigationStack {
            ScrollView { CategoryProgressBreakdownView().padding() }.navigationTitle("monthlyReport.detailView.title")
        }
    }
}
```

`Hugo/Features/Overview/OverviewView.swift:13-19` shows the correct pattern
already in use for a month-bounded query — copy it:

```swift
init() {
    let interval = CurrentMonthInterval.current(now: .now, calendar: .current)
    let start = interval.start
    let end = interval.end
    _entries = Query(
        filter: #Predicate<Entry> { $0.date >= start && $0.date < end }, sort: \Entry.date, order: .reverse)
}
```

`CurrentMonthInterval` lives in `Hugo/Features/Overview/OverviewMetrics.swift:3-12`.

### B. Raw keys in alerts

`Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift:70-77`:

```swift
func draft() -> EntryDraft? {
    guard let combinedDate, let selectedTracker, durationInSeconds > 0 else {
        validationMessage = "entry.add.validation.invalid"
        return nil
    }
```

`entry.add.validation.invalid` **does not exist** in
`Hugo/Resources/Localizable.xcstrings` (verified). And
`Hugo/Features/Entries/AddEntry/AddEntryView.swift:71-75` renders it with
`Text(_ : String)`, which does not localize:

```swift
.alert("common.error", isPresented: errorAlertBinding) {
    Button("common.dismiss", role: .cancel) { form.validationMessage = nil }
} message: {
    Text(form.validationMessage ?? String(localized: "common.error"))
}
```

The same `errorAlertBinding` + `.alert` block is duplicated four times with
only cosmetic differences:

- `Hugo/Features/Entries/AddEntry/AddEntryView.swift:71-85`
- `Hugo/Features/Categories/AddCategoryView.swift:77-90`
- `Hugo/Features/Categories/DefaultCategoryButton.swift:22-34`
- `Hugo/App/AppRootView.swift:35-39` (variant: has a Retry button)

Three of them use `Text(errorMessage ?? "common.error")`, where the `??`
forces the `Text(some StringProtocol)` overload — so the *nil* branch renders
the literal string `common.error` rather than the localized "Error".

### C. Swallowed saves

`Hugo/Features/Reports/SubmitReportFormModel.swift:160-214` — `persistSubmission(in:)`
ends both branches with `try? context.save()` (lines 190 and 212) and returns
the report regardless. Its caller,
`Hugo/Features/Reports/SubmitReportView.swift:152-171`, dismisses on success:

```swift
) { sent in
    isComposingMessage = false
    if sent {
        model.persistSubmission(in: context)
        dismiss()
    }
}
```

`Hugo/Features/Categories/CategoryDetailView.swift:89-93` has the same shape
for deletion.

### D. Sheet on a ForEach

`Hugo/Features/Entries/EntryListView.swift:10-23`:

```swift
struct EntryListView: View {
        var entries: [Entry]

        @State var selectedEntry: Entry? = nil

        var body: some View {
            ForEach(entries) { entry in
                EntryRow(entry: entry, selectedEntry: $selectedEntry)
            }
            .sheet(item: $selectedEntry) { entry in
                EntryDetailView(entry: entry)
                    .presentationDetents([.medium])
            }
        }
    }
```

(Indentation will already be 4-space after plan 016.)

### Conventions to match

- Localized user-facing text uses `LocalizedStringResource` / `LocalizedStringKey`,
  never a bare `String`. See `Hugo/Domain/RoundingRule.swift:10-16` for the
  house pattern.
- Errors are surfaced with an alert, never silently ignored.
- View modifiers live next to the feature that owns them; a genuinely shared
  one goes in a new `Hugo/App/` file (the repo has no `Shared/` folder — do not
  create one, `plans/README.md` fixes the folder set).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan017 CODE_SIGNING_ALLOWED=NO` | `TEST SUCCEEDED` |
| Full gate | `Scripts/verify.sh` | exit 0 |
| Key check | `python3 -c "import json;d=json.load(open('Hugo/Resources/Localizable.xcstrings'));print('entry.add.validation.invalid' in d['strings'])"` | `True` after Step 2 |

## Scope

**In scope**:
- `Hugo/App/ErrorAlert.swift` (create)
- `Hugo/Features/Overview/CategoryProgressBreakdownView.swift`
- `Hugo/Features/Overview/MonthlyProgressDetailView.swift`
- `Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift`
- `Hugo/Features/Entries/AddEntry/AddEntryView.swift`
- `Hugo/Features/Entries/EntryListView.swift`
- `Hugo/Features/Overview/OverviewView.swift`
- `Hugo/Features/Categories/AddCategoryView.swift`
- `Hugo/Features/Categories/DefaultCategoryButton.swift`
- `Hugo/Features/Categories/CategoryDetailView.swift`
- `Hugo/Features/Reports/SubmitReportFormModel.swift`
- `Hugo/Features/Reports/SubmitReportView.swift`
- `Hugo/App/AppRootView.swift`
- `Hugo/Resources/Localizable.xcstrings`
- `HugoTests/Features/Reports/SubmitReportFormModelTests.swift`
- `HugoTests/Features/Entries/AddEntryFormModelTests.swift`

**Out of scope** (do NOT touch):
- `Hugo/Persistence/**` — no schema or model change is required here.
- Danish translations for `common.*` keys — plan 024 owns catalog completeness.
- `Hugo/Features/Overview/OverviewMetrics.swift` — `CategoryProgressAggregator`
  is correct; only its *input* is wrong.
- The `.onTapGesture` on `MonthlyProgressCard` — plan 020 converts it to a
  Button. Leave it alone here or the two plans will conflict.

## Git workflow

- Branch: `advisor/017-user-visible-correctness`
- One commit per step, message style: `` `017` Step N — <summary> ``
- Do NOT push or open a PR.

## Steps

### Step 1: Add one shared error-alert modifier and adopt it in four places

Create `Hugo/App/ErrorAlert.swift`:

```swift
import SwiftUI

/// Presents a localized error alert driven by an optional message.
/// Binding-to-Bool plumbing lives here once instead of in every caller.
extension View {
    func errorAlert(
        message: Binding<String?>,
        retry: (() -> Void)? = nil
    ) -> some View {
        let isPresented = Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )
        return alert("common.error", isPresented: isPresented) {
            if let retry {
                Button("common.retry") { retry() }
            }
            Button("common.dismiss", role: .cancel) { message.wrappedValue = nil }
        } message: {
            // `Text(verbatim:)` is deliberate: the value is already a resolved,
            // localized sentence. The nil branch uses the key form so it is
            // localized, which the previous `Text(x ?? "common.error")` was not.
            if let text = message.wrappedValue {
                Text(verbatim: text)
            } else {
                Text("common.error")
            }
        }
    }
}
```

Then delete the private `errorAlertBinding` computed property and the inline
`.alert(...)` block from each of these, replacing with a single
`.errorAlert(message: $errorMessage)` call:

- `AddEntryView.swift` → `.errorAlert(message: $form.validationMessage)`
  (requires `@Bindable var form = form`, already present at line 17)
- `AddCategoryView.swift` → `.errorAlert(message: $errorMessage)`
- `DefaultCategoryButton.swift` → `.errorAlert(message: $errorMessage)`
- `AppRootView.swift` → `.errorAlert(message: $bootstrapErrorMessage, retry: …)`.
  `AppBootstrapper.errorMessage` is `private(set)`, so add a local
  `@State private var bootstrapErrorMessage: String?` and sync it with
  `.onChange(of: bootstrapper.errorMessage) { _, new in bootstrapErrorMessage = new }`.
  The retry closure is `{ Task { await bootstrapper.retry(context: context) } }`.

**Verify**: `grep -rn "errorAlertBinding" Hugo` → no matches.
`Scripts/verify.sh` → exit 0.

### Step 2: Make the validation message a real localized string

In `AddEntryFormModel.swift`, change `validationMessage` so it can never hold
an unresolved key. Replace the assignment at line 72 with:

```swift
validationMessage = String(localized: "entry.add.validation.invalid")
```

Then add the key to `Hugo/Resources/Localizable.xcstrings` with an English
value. Suggested `en`: `Add a duration and pick a category before saving.`
Leave `da` absent — plan 024 fills the catalog.

Audit the other two writers of this property: `AddEntryView.submit()` line 96
assigns `error.localizedDescription` (already a resolved sentence — fine), and
Step 1's modifier now renders both via `Text(verbatim:)`.

**Verify**: key-check command → `True`.
`grep -rn '"entry.add.validation.invalid"' Hugo` → exactly one match, inside a
`String(localized:)` call.

### Step 3: Bound the category breakdown to a month

Give `CategoryProgressBreakdownView` an explicit month and a filtered query,
mirroring `OverviewView.init`:

```swift
struct CategoryProgressBreakdownView: View {
    @Query private var entries: [Entry]
    @Query private var trackers: [Tracker]
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""

    init(month: YearMonth = Date().yearMonth()) {
        let start = month.date()
        let end = month.nextMonth().date()
        _entries = Query(filter: #Predicate<Entry> { $0.date >= start && $0.date < end })
    }
    …
```

`YearMonth.date(day:calendar:)` and `nextMonth(calendar:)` already exist in
`Hugo/Domain/YearMonth.swift:14-22,89-97`.

Then thread the month through the sheet: `MonthlyProgressDetailView` takes
`let month: YearMonth` and passes it down; `OverviewView` presents it as
`MonthlyProgressDetailView(month: now.yearMonth())`.

**Verify**: `grep -n "@Query private var entries" Hugo/Features/Overview/CategoryProgressBreakdownView.swift`
→ still one line, and the `init` below it contains `#Predicate`.
Manual: open the app, tap the progress card — the "Detailed Report" category
durations must sum to the number on the card.

### Step 4: Surface save failures instead of swallowing them

Change `SubmitReportFormModel.persistSubmission(in:)` to `throws` and replace
both `try? context.save()` with `try context.save()`. On the update branch,
capture the pre-mutation values so a failed save can be reported honestly — or,
simpler and preferred: call `context.rollback()` in the `catch` at the call
site before re-presenting.

Update the two call sites in `SubmitReportView.swift`:

```swift
private func persist() {
    do {
        try model.persistSubmission(in: context)
        dismiss()
    } catch {
        context.rollback()
        saveErrorMessage = error.localizedDescription
    }
}
```

with `@State private var saveErrorMessage: String?` and
`.errorAlert(message: $saveErrorMessage)` from Step 1. Wire both the
`MessageComposeView` completion (line 159-162) and the copied-notice alert
(line 167-170) through `persist()`.

Do the same for `CategoryDetailView.swift:89-93` (delete + save).

**Important**: on failure the sheet must **not** dismiss. That is the whole
point — the user needs to know the report was sent but not recorded.

**Verify**: `grep -rn "try? context.save()" Hugo` → no matches.
`Scripts/verify.sh` → exit 0.

### Step 5: Move the entry sheet to a stable container

`EntryListView` currently returns a bare `ForEach` with `.sheet` attached to
it. Wrap the rows so the presentation is owned once:

```swift
var body: some View {
    LazyVStack(spacing: 12) {
        ForEach(entries) { entry in
            EntryRow(entry: entry, selectedEntry: $selectedEntry)
        }
    }
    .sheet(item: $selectedEntry) { entry in
        EntryDetailView(entry: entry)
            .presentationDetents([.medium])
    }
}
```

`OverviewView.swift:39-50` already places `EntryListView(entries:)` inside a
`VStack` inside a `ScrollView`, so a `LazyVStack` here is safe and additionally
avoids building every row up front.

**Verify**: `Scripts/verify.sh` → exit 0. Manual: with 3+ entries, tap each row
in turn — every tap opens the correct entry, and no "Currently, only presenting
a single sheet is supported" warning appears in the console.

## Test plan

Add to `HugoTests/Features/Entries/AddEntryFormModelTests.swift` (model after
the existing tests in that file):

- `draftWithoutTrackerProducesLocalizedValidationMessage` — assert
  `form.validationMessage != "entry.add.validation.invalid"` (i.e. the key was
  resolved, not stored raw) and that it is non-empty.

Add to `HugoTests/Features/Reports/SubmitReportFormModelTests.swift`:

- `persistSubmissionThrowsWhenContextCannotSave` — if a failing `ModelContext`
  is impractical to construct, instead assert the signature change compiles by
  calling `try model.persistSubmission(in: context)` inside a `#expect(throws: Never.self)`
  on the happy path. Document why in a comment.
- Keep every existing test in the file passing — the signature change to
  `throws` will require adding `try` at existing call sites.

Verification: test command → `TEST SUCCEEDED`, with 2 more tests than before.

## Done criteria

ALL must hold:

- [ ] `grep -rn "errorAlertBinding" Hugo` → no matches
- [ ] `grep -rn "try? context.save()" Hugo` → no matches
- [ ] `grep -rn 'Text(errorMessage ?? ' Hugo` → no matches
- [ ] `python3 -c "import json;d=json.load(open('Hugo/Resources/Localizable.xcstrings'));print('entry.add.validation.invalid' in d['strings'])"` → `True`
- [ ] `CategoryProgressBreakdownView` contains a `#Predicate` bounding `Entry.date`
- [ ] `Scripts/verify.sh` exits 0
- [ ] Test count increased by 2; all pass
- [ ] `git status` shows no files outside the in-scope list
- [ ] `plans/README.md` row for 017 updated

## STOP conditions

Stop and report if:

- `AppBootstrapper.errorMessage` is no longer `private(set)` or the type
  changed — the Step 1 sync shim assumes it.
- Making `persistSubmission` `throws` cascades into more than the two call
  sites named in Step 4 plus the test file.
- The `#Predicate` in Step 3 fails to compile against `Entry.date`. SwiftData
  predicates are fussy about captured values; if hoisting `start`/`end` into
  local `let`s (as `OverviewView.init` does) does not fix it, stop.
- Any change appears to require editing `Hugo/Persistence/**`.

## Maintenance notes

- `errorAlert(message:retry:)` is now the single error-presentation entry point.
  New features must use it rather than re-rolling the binding.
- `Text(verbatim:)` inside it is load-bearing: callers pass **already-resolved**
  strings. If a future caller wants to pass a key, add a separate overload
  taking `LocalizedStringResource?` — do not change this one.
- Step 3 introduces a `month` parameter with a `Date().yearMonth()` default so
  the existing preview and call site keep working. When plan 026 or a future
  backfill feature adds month navigation, that parameter is the hook.
- Reviewer should scrutinize: Step 4's rollback semantics. A failed save after
  a *sent* SMS is the worst state in the app; the alert copy should make clear
  the message went out but was not recorded.
