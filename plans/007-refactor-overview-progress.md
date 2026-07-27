# Plan 007: Refactor overview and monthly progress presentation

> **Executor instructions**: Separate current-month calculation and progress
> state from SwiftUI layout, remove the generic sheet-content abstraction, and
> reuse existing report/category aggregation where appropriate. Update
> `plans/README.md` after verification.
>
> **Drift check (run first)**:
> `git diff --stat c047d57..HEAD -- Hugo/Screens/OverviewView.swift Hugo/Features/CurrentMonthProgress Hugo/Features/Entries Hugo/Features/Reports Hugo/Domain HugoTests`
> Stop if Plans 004 or 006 did not establish their target APIs.

## Status

* **Priority**: P2
* **Effort**: L
* **Risk**: MED
* **Depends on**: Plans 001, 004, and 006
* **Category**: tech-debt / performance / tests
* **Planned at**: commit `c047d57`, July 27, 2026

## Why this matters

Overview currently owns a static predicate, duration aggregation, date
formatting, and entry presentation. The progress card is generic only to inject
one add-entry sheet, stores derived goal/value text in state, and force unwraps
a calendar range. The detail breakdown filters and reduces all entries twice
per category on every render. This plan preserves the UI while making data flow
predictable and calculations testable.

## Current state

* `OverviewView:12-23` creates a current-month predicate; the segmented progress view declares a duplicate predicate but accidentally queries `OverviewView.currentMonthPredicate`.
* `OverviewView:33-46` performs current total and month formatting in the View.
* `CurrentMonthProgressView<SheetContent>` uses a generic solely for `EntrySheet.Add`.
* `CurrentMonthProgressView:19-20` stores `valueText` and `monthlyGoal`, both derived from inputs/AppStorage.
* `marker` force unwraps `calendar.range(of:in:for:)`.
* `SegmentedProgressView:56-85` filters and reduces entries twice for each tracker, and colors are indexed from a generated array.
* The whole progress card has an `onTapGesture` while also containing an add button, leaving presentation gestures coupled.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan007DerivedData CODE_SIGNING_ALLOWED=NO` | Exit 0 and overview tests pass |
| Old-name check | `rg -n '\bCurrentMonthProgressView\|ProgressCircle\|SegmentedProgressView\|StatusText\|DetailSheet\b' Hugo/Features/Overview --glob '*.swift'` | No obsolete generic/nested names |
| Repeated scan check | `rg -n 'entries\.filter\|ForEach\(trackers\.enumerated' Hugo/Features/Overview --glob '*.swift'` | No per-category repeated scans |

## Scope

**In scope**:

* `Hugo/Screens/OverviewView.swift`
* Current `Hugo/Features/CurrentMonthProgress/` tree
* New `Hugo/Features/Overview/` tree
* Shared monthly/category aggregation helpers from Plan 004 only when a small extension prevents duplication.
* Overview/progress tests.
* Relevant root call sites.
* `plans/README.md` status update.

**Out of scope**:

* Redesigning the circle, animations, colors, typography, or layout.
* Changing publisher goal values.
* Adding yearly/theocratic-year progress.
* Changing Entry or Tracker persistence.
* Motion accessibility work beyond preserving existing behavior; audit it separately.

## Target layout and names

```text
Hugo/Features/Overview/
    OverviewView.swift
    OverviewMetrics.swift
    MonthlyProgressCard.swift
    MonthlyProgressCircle.swift
    MonthlyProgressStatus.swift
    MonthlyProgressStatusView.swift
    MonthlyProgressDetailView.swift
    CategoryProgressBreakdownView.swift
```

Use top-level names. `MonthlyProgressStatus` is a pure enum; only the suffixed
presentation type conforms to `View`.

## Git workflow

* Branch: `advisor/007-overview-progress`
* Suggested commits: `Extracted overview metrics` and `Reorganized monthly progress views`.

## Steps

### Step 1: Centralize the current-month interval and query construction

Create a pure helper that returns the half-open current month interval for an
injected date/calendar. Use it to initialize the overview `@Query` and any
detail query. There must be exactly one implementation of the date range.

Prefer a custom `OverviewView.init(now:calendar:)` that initializes `_entries`
with captured interval bounds. Do not put a repository between `@Query` and the
view.

Test normal months, December→January, and a daylight-saving month with a fixed
time zone. Use half-open `[start, nextMonthStart)` semantics.

**Verify**: `rg -n 'dateInterval\(of: \.month|date\(byAdding: \.month' Hugo/Features/Overview`
finds only the helper implementation. Tests pass.

### Step 2: Extract pure overview metrics

Create `OverviewMetrics` or equivalent pure value logic that computes:

* current total hours from entries
* monthly goal from `PublisherStatus`
* expected goal at the injected date
* clamped progress fractions used by the circle

Avoid storing `monthlyGoal` or rendered numeric text in `@State`. Derive them
from current inputs and let `.contentTransition(.numericText())` animate the
numeric value directly. Handle missing status, zero goal, and unavailable
calendar ranges without force unwraps.

**Verify**: Tests cover zero goal, missing status, month start/end, progress over
goal, and negative input clamping where applicable.

### Step 3: Extract and test monthly progress status

Move nested `MonthStatus` to top-level `MonthlyProgressStatus` with a pure
factory taking expected and current progress. Preserve current thresholds:

* above 5 → way above
* above 2 → above
* within -2...2 → on target
* below -5 → way below
* otherwise below

Move localized labels/icons into computed properties on the enum or a
presentation adapter. Test every boundary value, especially exactly 2, -2, 5,
and -5.

**Verify**: Status tests pass without instantiating a SwiftUI view.

### Step 4: Replace the generic progress view with explicit presentation actions

Rename `CurrentMonthProgressView<SheetContent>` to `MonthlyProgressCard` and
remove its generic parameter. Pass explicit actions such as `onAddEntry` and
`onShowDetails`, or let `OverviewView` own clearly named sheet state. The parent
should present `AddEntryView` and `MonthlyProgressDetailView`.

Ensure tapping the add button does not also trigger detail presentation. Keep
local presentation state at the nearest feature owner; do not create a
coordinator.

Rename nested views to the target names and move them next to the feature.

**Verify**: `rg -n 'SheetContent|@ViewBuilder var addItemSheet|CurrentMonthProgressView<' Hugo`
returns no matches. Build succeeds.

### Step 5: Aggregate category progress once

Replace per-category filter/reduce calls with one aggregation pass. Reuse a
small category-duration aggregator from reports if its semantics match current
month progress; otherwise create one pure overview helper, not a ViewModel.

The resulting rows should have stable category identity, display metadata,
duration, and color. Prefer persisted tracker hue/saturation/brightness when
that is the intended category color; if current generated colors are product
behavior, preserve them but derive the palette safely for zero categories and
never index beyond its count.

Render both the bar and legend from the same precomputed rows.

**Verify**: Repeated scan check returns no matches. Tests assert duration
conservation and stable ordering. Full tests pass.

### Step 6: Move the complete feature and clean access control

Move `OverviewView` and all monthly-progress files under `Features/Overview`.
Remove obsolete `Screens/OverviewView.swift` and
`Features/CurrentMonthProgress`. Mark environment/state properties private and
immutable inputs `let`. Remove imports no longer needed.

**Verify**: The old directories are absent, tests pass, and a Debug build
succeeds.

## Test plan

* Use fixed calendars, time zones, dates, and publisher statuses.
* Test every status threshold boundary.
* Test category aggregation with zero, one, and multiple categories, including a deleted category snapshot if shared aggregation supports it.
* Retain a simple in-memory integration test that the overview predicate excludes next-month entries.
* Do not snapshot animation frames in this refactor.

## Done criteria

* [ ] Overview and monthly progress live in one feature folder.
* [ ] Current-month interval logic has one tested implementation.
* [ ] Derived goal and numeric text are not mirrored in mutable state.
* [ ] Progress status is a tested pure enum.
* [ ] The generic sheet-content view and empty abstraction are gone.
* [ ] Category breakdown aggregates once and renders from stable rows.
* [ ] No calendar force unwrap remains in overview.
* [ ] Full tests pass.
* [ ] Plan 007 is marked DONE.

## STOP conditions

* Plans 004/006 APIs differ enough that this plan would need to reimplement their responsibilities.
* Removing mirrored numeric text state changes required animation behavior.
* Tracker color fields do not represent user-facing category color and changing palette requires design approval.
* Current-month query initialization cannot accept injected bounds without a persistence change.

## Maintenance notes

* Future theocratic-year progress should add a separate domain period type rather than overloading current-month helpers.
* Keep progress geometry in presentation types and business thresholds in pure domain values.
* Reviewers should manually test add-button versus card-tap gesture behavior.
