# Plan 006: Refactor entry creation and editing into idiomatic SwiftUI features

> **Executor instructions**: Remove the empty namespace structs and split the
> 314-line add-entry file by responsibility. Preserve existing user-visible
> behavior except for explicitly listed correctness fixes. Update
> `plans/README.md` after all tests pass.
>
> **Drift check (run first)**:
> `git diff --stat c047d57..HEAD -- Hugo/Features/EntrySheet Hugo/Features/EntryList Hugo/Features/Categories Hugo/Features/Reports HugoTests`
> Stop if entry form behavior has changed since this plan was written.

## Status

* **Priority**: P1
* **Effort**: L
* **Risk**: MED
* **Depends on**: Plans 001, 003, and 005
* **Category**: tech-debt / correctness / tests
* **Planned at**: commit `c047d57`, July 27, 2026

## Why this matters

The entry feature currently uses empty `EntrySheet` and `EntryList` structs as
namespaces, producing React-like names such as `EntrySheet.Add` and
`EntryList.Content`. Add-entry view state, validation, date arithmetic,
persistence, selection repair, and a nested sheet all live in one 314-line
view. Explicit feature types and a small observable form model will make SwiftUI
data ownership clear without adding an app-wide MVVM layer.

## Current state

* `EntrySheet.swift` and `EntryList.swift` are empty namespace structs.
* `EntrySheetAdd.swift:18-40` declares nine state properties, including unused state removed by Plan 002.
* `EntrySheetAdd.swift:85-87` replaces selection with `new.first` whenever trackers change, while lines 156-171 separately prefer the default only when selection is nil.
* `submitForm()` force unwraps optional time/date/tracker values and dismisses even when no entry is inserted.
* `isDurationZero()` wraps a pure Boolean calculation in `withAnimation`.
* `SelectTimeSheet` is nested at lines 262-307.
* `EntryList.DetailSheet` edits a SwiftData model wrapped in `@State` and mixes duration conversion, category selection, deletion, and layout.
* `EntryList.DurationPicker` owns a derived Date state but has no contract for external duration changes.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan006DerivedData CODE_SIGNING_ALLOWED=NO` | Exit 0 and entry tests pass |
| Namespace check | `rg -n '\b(EntrySheet\|EntryList)\.' Hugo --glob '*.swift'` | No matches |
| Force check | `rg -n 'time!\|trackers\.first!\|calendar\.date\(from: components\)!' Hugo/Features/Entries` | No matches |

## Scope

**In scope**:

* Current `Hugo/Features/EntrySheet/` and `Hugo/Features/EntryList/` trees.
* New `Hugo/Features/Entries/` tree.
* Entry call sites in Overview, Reports, and Categories.
* Entry-specific preview fixtures.
* `HugoTests/Features/Entries/` tests.
* Existing duration-format tests only for renamed API usage.
* `plans/README.md` status update.

**Out of scope**:

* Changing current SwiftData `Entry` stored properties or adding a schema version.
* Adding notes, locations, timers, calendar integration, or other entry features.
* Report aggregation; Plan 004 owns it.
* Overview layout; Plan 007 owns it.
* A repository layer around `ModelContext`.

## Target layout and names

```text
Hugo/Features/Entries/
    AddEntry/
        AddEntryView.swift
        AddEntryFormModel.swift
        EntryTimePickerView.swift
    EntryListView.swift
    EntryRow.swift
    EntryDetailView.swift
    EntryDurationPicker.swift
```

Do not add `Views`, `ViewModels`, or `Structs` subfolders. The feature and names
already communicate those roles.

## Git workflow

* Branch: `advisor/006-refactor-entries`
* Commit form-model extraction separately from view moves/renames.
* Suggested messages: `Extracted add entry form state` and `Reorganized entry views`.

## Steps

### Step 1: Model entry form state and validation explicitly

Create `@MainActor @Observable final class AddEntryFormModel`. Import
`Observation` explicitly. It owns only workflow state:

* selected date
* optional selected time
* duration picker date/value
* Bible-study count
* selected persisted `Tracker?`
* presentation booleans if keeping them out of the view improves testability
* validation/error state

Expose pure computed values for `durationInSeconds`, `isSubmitDisabled`, and a
safe combined entry date. Inject a `Calendar` and `now` in the initializer for
tests; defaults may use `.current` and `.now`.

Selection reconciliation must preserve the current selection if it still exists.
When nil or deleted, prefer `isDefault`, then the first category. It must never
replace a valid user selection merely because the query array changed.

Provide increment/decrement methods that clamp Bible studies at zero. Return an
`EntryDraft` value or an optional validated payload; do not insert into
`ModelContext` inside pure date calculations.

**Verify**: Unit tests cover duration conversion, midnight/date combination,
optional time combination, non-negative Bible studies, empty-category
validation, default selection, preserving selection, and repairing deleted
selection.

### Step 2: Build `AddEntryView` around the form model

Rename `EntrySheet.Add` to top-level `AddEntryView`. Instantiate the form model
with `@State private var form = AddEntryFormModel()`, then use `@Bindable` in
`body` for bindings.

The view may access `@Query` and `@Environment(\.modelContext)` directly. Its
submit action must:

* request a validated payload from the form
* create and insert one `Entry`
* save the context and dismiss only on success
* show a localized error if validation or save fails

Use `.task` or `.onChange` to call the idempotent selection reconciliation. Do
not duplicate fallback logic in multiple lifecycle modifiers. Show the Bible
studies section only when the selected category permits it, resetting the count
only if that matches current product behavior; otherwise preserve it while
hidden.

**Verify**: The force check returns no matches and form-model tests pass.

### Step 3: Extract the optional time sheet

Move nested `SelectTimeSheet` to top-level `EntryTimePickerView`. Prefer
`@Environment(\.dismiss)` over a second Boolean binding when the sheet can
dismiss itself. Initialize its local picker value from the optional bound date
or `Date.now`. Preserve Done and Clear behaviors.

The component's public contract should be one optional date binding; avoid
passing presentation ownership into the child.

**Verify**: `rg -n 'struct SelectTimeSheet|showTimeSheet: Binding' Hugo` returns
no matches. Build succeeds.

### Step 4: Flatten the entry list types

Rename and move:

* `EntryList.Content` → `EntryListView`
* `EntryList.Row` → `EntryRow`
* `EntryList.DetailSheet` → `EntryDetailView`
* `EntryList.DurationPicker` → `EntryDurationPicker`

Delete the empty `EntryList.swift` and `EntrySheet.swift` namespaces after all
call sites compile. Keep selected-entry presentation state in `EntryListView`;
that is appropriate local SwiftUI state.

Use explicit access control and immutable inputs (`let`) where possible. A
simple row remains a pure View and does not receive a ViewModel.

**Verify**: Namespace check returns no matches, old namespace files are deleted,
and full tests pass.

### Step 5: Clarify SwiftData editing in `EntryDetailView`

Treat the passed `Entry` as a reference-type persistent model rather than
copy-like `@State`. Establish bindings with `@Bindable` at the view boundary.
Keep local `@State` only for presentation flags and any draft needed for
cancelable editing.

Choose and implement one explicit persistence policy:

* If edits remain live/autosaved, document that Cancel is not offered and save errors are surfaced when explicit save occurs.
* If Done/Cancel semantics are introduced, edit a form draft and apply it only on Done.

Do not leave an accidental hybrid where field edits persist immediately but the
UI implies cancellation. Preserve the existing immediate-edit behavior unless
product copy requires otherwise.

Make `EntryDurationPicker` synchronize if the bound duration changes from
outside. Put duration↔picker-date conversion in one tested helper rather than in
both detail and picker views.

**Verify**: Add tests for duration round-tripping at 0, 1 minute, 1:30, and 23:59.
Complete tests pass.

### Step 6: Update report and overview call sites

Replace all usages of namespace types with explicit names. Report detail entry
navigation should target `EntryDetailView`; overview should render
`EntryListView` and present `AddEntryView`. Do not change their layouts in this
plan.

**Verify**: `rg -n '\b(EntrySheet|EntryList)\b' Hugo --glob '*.swift'` returns
no obsolete namespace symbols. Full build and tests pass.

## Test plan

* Add pure tests for the form model with injected calendar and fixed date.
* Test selection reconciliation using in-memory `Tracker` models.
* Test date combination around a daylight-saving transition with a fixed calendar/time zone.
* Test duration conversion independently of SwiftUI.
* Retain integration coverage that a valid payload inserts an `Entry` into an in-memory context.

## Done criteria

* [ ] Entry source lives under `Features/Entries` with explicit top-level type names.
* [ ] Empty namespace structs are deleted.
* [ ] Add-entry workflow state and calculations are outside the 314-line View.
* [ ] No forced optional unwrap remains in add-entry submission.
* [ ] A valid selected category is not overwritten when query results change.
* [ ] Entry edit data ownership is explicit and uses `@Bindable` appropriately.
* [ ] Duration conversion has one tested implementation.
* [ ] Full tests pass.
* [ ] Plan 006 is marked DONE.

## STOP conditions

* Moving form state to `@Observable` changes DatePicker behavior or loses bindings.
* The existing product requires silent dismissal when no category exists.
* SwiftData autosave/cancel semantics are not clear enough to preserve without a product decision.
* A proposed fix requires changing the persisted Entry schema.

## Maintenance notes

* Add-entry state is one justified observable workflow model; do not extrapolate this into a ViewModel for every row.
* Keep persistence insertion in the feature boundary and deterministic calculations in the form model.
* Reviewers should test changing categories while the sheet is open and adding a new category from the picker.
