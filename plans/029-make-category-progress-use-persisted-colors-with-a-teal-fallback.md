# Plan 029: Make category progress use persisted colors with a teal fallback

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving on. If anything in the STOP conditions section occurs, stop and report it rather than improvising. When complete, update Plan 029 in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat f15e122..HEAD -- Hugo/Features/Overview/OverviewMetrics.swift Hugo/Features/Overview/CategoryProgressBreakdownView.swift HugoTests/Features/Overview/OverviewMetricsTests.swift plans/README.md`
>
> If an in-scope file changed since this plan was written, compare it with the current-state excerpts below. Treat a material mismatch as a STOP condition.

## Status

* **Priority**: P1
* **Effort**: M
* **Risk**: MED
* **Depends on**: `plans/027-establish-safe-hugo-theme-tokens-and-monochrome-root-tint.md`, `plans/028-apply-monochrome-palette-and-intentional-accent.md`
* **Category**: correctness
* **Planned at**: commit `f15e122`, August 10, 2026

## Why this matters

The category breakdown currently assigns colors from tracker enumeration position:

    Color(hue: Double(row.colorIndex) * 0.05, saturation: 0.75, brightness: 1)

That means a category’s visible color changes when query order changes, categories are added, or a device receives data in a different order. It also ignores the Tracker’s existing persisted `hue`, `sat`, and `bri` values and omits untracked hours even though the Overview total includes them. This violates the intended rule that content/data provides color and makes the breakdown less trustworthy.

This plan creates a small pure-data color descriptor for category progress. A valid stored category color remains data-driven; missing, invalid, black-default, or untracked categories intentionally resolve to `.hugoAccent`. No color picker, new field, or SwiftData migration is introduced.

## Current state

* `Hugo/Features/Overview/OverviewMetrics.swift:31-50` currently models a row with a positional `colorIndex` and aggregates only entries that have a Tracker:

    struct CategoryProgressRow: Identifiable {
        let id: String
        let name: String
        let iconName: String
        let duration: TimeInterval
        let colorIndex: Int
    }

    enum CategoryProgressAggregator {
        static func rows(entries: [Entry], trackers: [Tracker]) -> [CategoryProgressRow] {
            var totals: [UUID: TimeInterval] = [:]
            for entry in entries {
                if let tracker = entry.tracker { totals[tracker.id, default: 0] += entry.duration }
            }
            return trackers.enumerated().compactMap { index, tracker in
                guard totals[tracker.id, default: 0] > 0 else { return nil }
                return CategoryProgressRow(
                    id: tracker.id.uuidString, name: tracker.name, iconName: tracker.iconName,
                    duration: totals[tracker.id, default: 0], colorIndex: index)
            }
        }
    }

* `Hugo/Features/Overview/CategoryProgressBreakdownView.swift:21-36` turns that transient index into an arbitrary hue. It renders neither an untracked row nor a persisted Tracker color.
* The current Tracker model is the V8-compatible type alias. `Hugo/Persistence/SchemaVersions/V8/TrackerV8.swift:22-25` already persists `hue`, `sat`, and `bri`, all defaulting to `0`, `1`, and `0` respectively. The bootstrap default also uses brightness `0`, so `bri == 0` must mean “no assigned display color” in this plan.
* `Hugo/Features/Reports/Domain/MonthlyReportBuilder.swift` already gives untracked entries a localized `entry.untracked` category in report summaries. The Overview breakdown should provide equivalent accounting.
* `HugoTests/Features/Overview/OverviewMetricsTests.swift:44-54` currently verifies only total-duration conservation for two tracked categories.
* The app’s design decision is: custom category color is a data exception; `.hugoAccent` is the fallback for categories with no valid assigned display color.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | Exit 0 with no lint diagnostics |
| Focused tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoCategoryColorDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/OverviewMetricsTests` | Exit 0; Overview metrics tests pass |
| Full verification | `DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' DERIVED_DATA=/tmp/HugoCategoryColorVerifyDerivedData Scripts/verify.sh` | Exit 0; formatter, tests, and analyzer pass |
| Detect positional colors | `rg -n 'colorIndex|Color\(hue: Double\(row\.colorIndex\)' Hugo HugoTests` | No output; command exits 1 because no matches remain |

## Scope

**In scope**:

* `Hugo/Features/Overview/OverviewMetrics.swift`
* `Hugo/Features/Overview/CategoryProgressBreakdownView.swift`
* `HugoTests/Features/Overview/OverviewMetricsTests.swift`
* Update the Plan 029 status row in `plans/README.md` when complete.

**Out of scope**:

* All `Hugo/Persistence/SchemaVersions/*` model definitions and `Hugo/Persistence/HugoMigrationPlan.swift`.
* A category color picker, category edit UI, new localization keys, or a color-import feature.
* Changes to `Tracker.hue`, `Tracker.sat`, or `Tracker.bri` persistence values.
* Global palette changes already owned by Plan 028.
* Report summary behavior outside the Overview category-progress breakdown.

## Git workflow

* Create branch `advisor/029-category-progress-colors` unless the operator supplies a branch.
* Make one logical commit after all verification gates pass. Match current repository style, for example: `Use category colors in progress breakdown`.
* Do not push, create a pull request, or modify unrelated working-tree changes.

## Steps

### Step 1: Replace positional color with a pure, validated color descriptor

In `Hugo/Features/Overview/OverviewMetrics.swift`, remove `colorIndex` from `CategoryProgressRow`. Add a small `nonisolated`, `Equatable`, `Sendable` value type in the same file, for example `CategoryProgressColor`, containing `hue`, `saturation`, and `brightness`.

Its failable initializer must accept persisted numeric inputs only when all three values are within `0...1` and brightness is strictly greater than `0`. A zero brightness is Hugo’s existing “unassigned color” sentinel and must resolve to `nil`, not a black custom segment. Invalid persisted values must also resolve to `nil` rather than be passed into `SwiftUI.Color`.

Add an optional `color: CategoryProgressColor?` to `CategoryProgressRow`. Keep this type Foundation-only; do not import SwiftUI into `OverviewMetrics.swift`.

For each tracked row, construct its optional color from `tracker.hue`, `tracker.sat`, and `tracker.bri`. The row continues to get its identity, name, icon, and duration from the Tracker.

**Verify**: `if rg -n 'colorIndex' Hugo/Features/Overview/OverviewMetrics.swift HugoTests/Features/Overview/OverviewMetricsTests.swift; then exit 1; fi` → exit 0.

### Step 2: Account for untracked hours as an explicit fallback category

While aggregating entries, accumulate entries with `tracker == nil` separately instead of silently discarding them. When the accumulated untracked duration is positive, append one row with:

* Stable ID `untracked`.
* Name `String(localized: "entry.untracked", locale: locale)`.
* Icon `questionmark.circle`.
* The accumulated duration.
* `color: nil` so it deliberately resolves to the Hugo accent fallback.

Add a `locale: Locale = .current` parameter to `CategoryProgressAggregator.rows` only if needed to obtain the localized untracked name. Preserve the existing tracker-row ordering, append the untracked row after tracked rows, and preserve the existing rule that non-positive total rows are not shown.

Do not clamp, re-round, or otherwise alter durations in this plan; the task is to report the same positive category data the breakdown already works with, plus previously omitted untracked entries.

**Verify**: `xcrun swift-format lint --strict Hugo/Features/Overview/OverviewMetrics.swift` → exit 0.

### Step 3: Resolve visual color at the SwiftUI boundary

In `Hugo/Features/Overview/CategoryProgressBreakdownView.swift`, add one private resolver that turns a row’s optional pure-data color into a `SwiftUI.Color`:

    private func displayColor(for row: CategoryProgressRow) -> Color {
        guard let color = row.color else { return .hugoAccent }
        return Color(hue: color.hue, saturation: color.saturation, brightness: color.brightness)
    }

Use this resolver for every progress segment. If a legend marker is added while implementing the existing rows, it must use the same resolver; do not duplicate the fallback condition. Preserve the existing system grouped background, dimensions, clipping, and duration text hierarchy.

The only remaining `Color(hue:saturation:brightness:)` use must consume a validated `CategoryProgressColor`, never a list index or raw Tracker property. The `.hugoAccent` fallback is intentional: it applies to no-color Tracker records and the explicit untracked row.

**Verify**: `rg -n -C 2 'displayColor|CategoryProgressColor|hugoAccent' Hugo/Features/Overview` → output shows a single fallback resolver and no positional hue generation.

### Step 4: Add characterization tests for color assignment and omitted hours

Extend `HugoTests/Features/Overview/OverviewMetricsTests.swift`, matching the existing `@MainActor` and Swift Testing style.

Add tests covering all of these cases:

* A Tracker with valid nonzero `hue`, `sat`, and `bri` produces a row whose `color` matches those values.
* A Tracker with the default brightness `0` produces a row whose `color` is `nil`, proving it will receive the teal fallback in the view.
* A Tracker with an out-of-range persisted channel produces `color == nil` rather than an invalid custom color.
* A positive untracked Entry produces one `untracked` row with `color == nil`, its expected duration, and no Tracker dependency.
* The sum of returned row durations includes tracked and untracked positive entries, preserving the relationship to the Overview total.

Do not unit-test SwiftUI’s exact teal rendering. The pure data contract is the correct test boundary; Plan 027’s token compilation and the resolver’s use of `.hugoAccent` provide the UI integration guarantee.

**Verify**: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoCategoryColorDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/OverviewMetricsTests` → exit 0; all existing and new Overview metrics tests pass.

### Step 5: Perform visual data-state validation

Use previews or simulator seed data to inspect at least three states:

* A default Tracker with brightness `0`: its segment is teal.
* A Tracker with a valid nonzero persisted color: its segment uses that data color.
* An untracked Entry: the breakdown includes an Untracked row and teal fallback segment.

Inspect both Light and Dark Mode. Confirm system grouped backgrounds remain neutral and only the progress data segments carry content color.

**Verify**: `DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' DERIVED_DATA=/tmp/HugoCategoryColorVerifyDerivedData Scripts/verify.sh` → exit 0.

## Test plan

* Extend `HugoTests/Features/Overview/OverviewMetricsTests.swift`; use its existing calendar and Swift Testing conventions.
* Cover valid assigned color, default/unassigned color, malformed persisted color, untracked fallback, and aggregate-duration conservation.
* Run the focused Overview metrics target after Step 4, then the full verification script after Step 5.
* Manually validate Light/Dark appearance because SwiftUI `Color` rendering is environment-dependent.

## Done criteria

* [ ] `CategoryProgressRow` no longer exposes `colorIndex`.
* [ ] A valid persisted Tracker color is represented by a pure Foundation value, not a SwiftUI type.
* [ ] Default brightness `0`, malformed color channels, and untracked entries resolve to `nil` at the data layer and `.hugoAccent` at the view boundary.
* [ ] The Overview breakdown includes positive untracked hours.
* [ ] The only `Color(hue:saturation:brightness:)` path consumes validated data, never an enumeration index.
* [ ] New focused tests cover all five cases in Step 4.
* [ ] `if rg -n 'colorIndex|Color\(hue: Double\(row\.colorIndex\)' Hugo HugoTests; then exit 1; fi` exits 0.
* [ ] `xcrun swift-format lint --strict --recursive Hugo HugoTests` and `Scripts/verify.sh` exit 0.
* [ ] No files outside the in-scope list are modified, except the required `plans/README.md` status update.

## STOP conditions

Stop and report rather than improvising if:

* Plan 027 or Plan 028 is incomplete, or `.hugoAccent` is unavailable to the progress view.
* The current Tracker type no longer exposes `hue`, `sat`, and `bri` as V8-compatible persisted values.
* Correct behavior requires storing a new optional color field, modifying a historical schema, or adding a migration stage.
* The team decides brightness `0` must be a selectable black category color rather than the existing unassigned sentinel; that requires an explicit persisted-assignment contract outside this plan.
* The category breakdown has changed into a different feature shape that no longer consumes `CategoryProgressRow`.

## Maintenance notes

* A future color-picker feature should populate and validate the existing Tracker color channels only after its UX and black/clear semantics are formally specified.
* Keep `CategoryProgressColor` free of SwiftUI so aggregation remains deterministic and unit-testable under strict concurrency.
* Any future category-colored legend, chart, or row must use the single display resolver so fallback behavior cannot drift.
