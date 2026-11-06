# Plan 084: Explain Monthly Target with a live goal marker, adjusted target, and Buffer

> **Executor instructions**: This plan is an implementation handoff. Do not
> start until the owner requests implementation and prerequisites pass. Read
> the whole plan, run every verification gate, and stop on the named conflicts.
> Update the index and Linear as work progresses. Device acceptance, not a
> successful build alone, is required before Done.
>
> **Drift check**: written against `9be5c03`, revised 2026-11-06.
> Run `git diff --stat 9be5c03..HEAD -- Hugo/Features/Planner HugoTests/Features/Planner Hugo/DesignSystem/Components Hugo/Resources/Localizable.xcstrings CONTEXT.md`.
> Expected prerequisite differences: 091 changes the Planner bar and adds
> `MarkedProgressBar`; 083 adds `SelectableOptionRow`,
> `PlannerTarget.settingSummary`, its tests, and catalog entries. Other changes
> require checking the excerpts below. Do not overwrite unrelated work.

## Status

* **Status**: TODO
* **Priority**: P2
* **Effort**: M + owner device check
* **Risk**: MED — shared target-input extraction, query-driven presentation, and visual explanation; no persistence migration.
* **Depends on**: plan 083 (General hierarchy, selectable row, settings summary); plan 091 through 083 (shared bar); plan 081 already completed (no Planner-header sheet caller).
* **Category**: direction
* **Planned at**: commit `9be5c03`, revised 2026-11-06
* **Issue**: [SLN-298](https://linear.app/sebastianln/issue/SLN-298)

## Why this matters

A user should be able to see what a target setting changes before leaving Settings. The page will compare the chosen base target with the factual monthly goal, show Buffer as a faded extension, and use real credited time to explain the yearly-adjusted option. It must agree with the Planner because both use the same credited-time input and target calculator.

## Accepted design

Location: **Settings → General → Planner → Monthly Target**. Plan 083 owns that hierarchy; do not add shortcuts back at the root or in the Planner header.

Visible names:

* Existing regular option remains **Monthly goal** / **Månedligt mål**.
* Yearly-share option becomes **Adjusted to yearly goal** / **Tilpasset årsmålet**. Do not introduce “Dynamic”.
* **Extra Hours** becomes **Buffer** / **Buffer** for a status with a goal.
* Without a goal, call the stepper **Monthly Target** / **Mål for måneden**, because the selected duration is the target itself, not a buffer on an existing goal.
* Preserve `PlannerTargetBase.yearlyGoalShare`, all enum raw values, `plannerExtraHours`, and the existing `extraHours` parameters. Renaming UI and glossary does not justify a preference migration.

Visual first, options below:

1. Current month label and total target, expressed as a localized duration, above the bar. A nil total is “Not set”, not an invented goal.
2. A solid accent fill ending at the chosen base target before Buffer.
3. A faded accent extension ending at the total, using the same opacity as the Planner's planned segment. Never fade the whole target or draw Buffer from the baseline on top of the solid segment.
4. A vertical marker fixed at the status's factual monthly goal, with a readable “Monthly goal: 50 hours” label. It stays at the goal when the option changes; it is not the computed target.
5. Short labels/text identify base, Buffer, and total. Users must not need color or animation to distinguish them.
6. For yearly-goal statuses, two full-width selectable option rows, each showing its **base target without Buffer**. The adjusted option explains the real remaining credited hours and remaining number of months; rounding up to whole hours is explained once.
7. The existing 0...30-hour stepper, renamed as above. Do not change bounds or increment.

The bar is comparative, not “percentage of target achieved”. Selecting Monthly goal aligns the solid fill with the goal marker; selecting the adjusted option goes beyond the marker when behind, below it when ahead, and matches it when on pace. Adding Buffer grows only the faded part. No fake progress, red/green judgment, pulsing marker, replay button, or entrance animation.

### Stable comparison scale

Derive both candidate base targets before selecting one. Let `goalSeconds` be the factual monthly goal; `monthlyBaseSeconds` and `adjustedBaseSeconds` come from the existing calculator with zero additional hours; `bufferSeconds` is the nonnegative additional duration.

```text
largestBase = max(goalSeconds, monthlyBaseSeconds, adjustedBaseSeconds)
scaleSeconds = max(1.25 * largestBase, largestBase + bufferSeconds)
solidFraction = selectedBaseSeconds / scaleSeconds
extendedFraction = totalSeconds / scaleSeconds
markerFraction = goalSeconds / scaleSeconds
```

Only render this bar when the status has a positive monthly goal; that makes the denominator positive. A candidate nil because its computed base is zero is **0**, not the factual monthly goal. Do not change the calculator's nil semantics. The scale is independent of the chosen option, so switching options never moves the marker. Buffer uses the reserved headroom first; once it exceeds that headroom the track may rescale, identically for either option. Do not replace this with a scale based only on the selected base.

No-goal statuses get the truthful numeric total and explanation, not a fabricated goal marker or a self-normalizing bar that always looks full. Auxiliary pioneers get the 30-hour goal/bar and Buffer but no yearly option. If an old yearly-share preference is stored for an auxiliary pioneer, the existing calculator's monthly-goal fallback still applies; do not reset that preference.

## Current state

* `Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift` currently owns three AppStorage values, a yearly-only inline picker, and a stepper. It has `showsDone` and an optional dismissal toolbar, although plan 081 removed the last outside caller. This plan removes the obsolete sheet-only API after checking references.
* `Hugo/Features/Planner/Screens/PlannerView.swift:71–79` computes credited time in a private `PlannerPager` property:

```swift
private var creditedBeforeCurrentMonth: TimeInterval {
    guard targetBase == .yearlyGoalShare, let rule = status?.yearlyGoalRule else { return 0 }
    let report = TheocraticYearReportBuilder.report(
        for: TheocraticYear.containing(today), entries: yearEntries, submissions: submissions,
        trackers: trackers, now: today)
    return PlannerTarget.creditedSeconds(before: today.yearMonth(), in: report, rule: rule)
}
```

* That pager queries the current theocratic year's entries using a half-open date range, plus `SubmittedReport` and `Tracker` collections. It builds the report only when the selected base needs it. Preserve that optimization.
* `Hugo/Features/Planner/Domain/PlannerTarget.swift` is a nonisolated enum. Its calculator is authoritative:

```swift
static func seconds(
    for month: YearMonth,
    base: PlannerTargetBase,
    extraHours: Int,
    status: PublisherStatus?,
    creditedBeforeCurrentMonth: TimeInterval,
    now: Date = .now,
    calendar: Calendar = .current
) -> TimeInterval?
```

For yearly share in the current theocratic year, it subtracts credited time **before the current month**, divides what remains by the number of months left including the current one, and rounds up to whole hours. The existing epsilon prevents an exact 50 from rounding to 51. A nonpositive total returns nil; extra hours are clamped nonnegative. Do not rewrite this math.

* `PlannerTarget.creditedSeconds(before:in:rule:)` applies `YearlyGoalRule.creditedSeconds` to report months before the supplied month. It must not be replaced by raw entry durations: submitted snapshots, category resolution, separate allowances, and carry-ins matter.
* `PlannerTargetTests.swift` has fixed Gregorian UTC/calendar and locale, regular/auxiliary/publisher status fixtures, main/separate trackers, and a November 3, 2026 reference date. Its credited fixture is September main 40 h; October main 30 h plus separate 30 h; November main 10 h. Credit before November is **95 h**, not raw 100 h. Existing tests expect adjusted November targets of 51 h with 95 h credited, 49 h with 110 h credited, and nil when the yearly goal is already exceeded with no additions.
* Plan 083 adds `settingSummary(base:extraHours:status:locale:)`, `planner.target.none`, and `SelectableOptionRow(title:description:value:isSelected:action:)`. Its General row uses the base's catalog label, so the rename here automatically appears in that row.
* Plan 091 provides the generic `MarkedProgressBar`, solid/extended/marker fractions, optional marker label, clipping and selection-driven animation.
* `Hugo/PreviewSupport/PreviewModelContainer.swift` provides `.modelContainer(.preview)`. Persistence tests use `InMemoryModelContainer.make()`. Use isolated UserDefaults for previews and fixed now/calendar/locale for test values.

### Repository constraints

`AGENTS.md` requires pure target/presentation calculations in `Planner/Domain`, not report building or option mapping inside SwiftUI `body`. A pure value needs no ViewModel. Keep new visual composition in `Planner/Views`. SwiftData queries belong at the screen boundary, injected through the environment/model container, not a singleton. Swift 6 strict concurrency remains enabled; do not move SwiftData models across actors or add detached work. Use `TheocraticYear` and `YearMonth` with the supplied calendar, `ServiceDurationFormatter`, `HugoLayout`, and the shared motion handling. No schema/default-key changes or UIKit wrapper.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Prerequisites | `test -f Hugo/DesignSystem/Components/MarkedProgressBar.swift && test -f Hugo/DesignSystem/Components/SelectableOptionRow.swift` | Exit 0; 083 and 091 completion records also checked |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/PlannerTargetTests -only-testing:HugoTests/PlannerTargetPreviewTests -only-testing:HugoTests/PlannerMonthStatusTests` | `** TEST SUCCEEDED **`; new suite appears |
| Layout | `Scripts/check-layout.sh` | Exit 0 |
| Catalog syntax | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | Exit 0 |
| Full gate, before every implementation commit | `Scripts/verify.sh` | Exit 0 |
| Whitespace | `git diff --check` | Exit 0 |

## Scope

**In scope**:

* `Hugo/Features/Planner/Domain/PlannerTarget.swift` (add shared credited-input helper; update comments for Buffer, not target behavior)
* `Hugo/Features/Planner/Domain/PlannerTargetPreview.swift` (new pure presentation value)
* `Hugo/Features/Planner/Views/PlannerTargetPreviewView.swift` (new visual)
* `Hugo/Features/Planner/Screens/PlannerView.swift` (credited property delegation only)
* `Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift` (redesign)
* `HugoTests/Features/Planner/Domain/PlannerTargetTests.swift` (shared-helper tests)
* `HugoTests/Features/Planner/Domain/PlannerTargetPreviewTests.swift` (new)
* `Hugo/Resources/Localizable.xcstrings` (listed target keys only)
* `CONTEXT.md` (Monthly target, Adjusted target, Buffer terminology)
* This plan's index status and SLN-298 workflow state.

**Out of scope**:

* Changes to `PlannerTarget.seconds`, credit math, report building semantics, schema, stored keys/raw values, or the stepper range.
* Settings hierarchy and General implementation (083); shared drawing/row component behavior (091/083).
* Planner header design, calendar bars, Year-page visuals, or duration formatter behavior.

## Git workflow

Work on `main`; no branch/worktree/push or co-authorship trailer. Preserve pre-existing owner files and stage explicit paths only. Run `Scripts/verify.sh` before each implementation commit. Suggested implementation message: `feat: explain monthly targets with a live goal bar and buffer`. Commit completion documentation separately. Set SLN-298 In Progress when implementation starts, In Testing after verification, and Done only after owner acceptance.

## Steps

### Step 0: Confirm prior plans and callers

Check prerequisite files and recorded owner acceptance. Confirm `settingSummary` exists and both settings pages are reached through General. Run `rg 'showsDone' Hugo`; every match must be inside `PlannerTargetSettingsView.swift`. Record the working tree so existing owner planning edits cannot accidentally enter the implementation commit.

**Verify**: prerequisite command exits 0; no outside `showsDone` caller; 083/091 owner checks recorded. Otherwise stop.

### Step 1: Move the credited-input computation, unchanged

Add this helper to `PlannerTarget` after `creditedSeconds(before:in:rule:)`:

```swift
static func creditedBeforeCurrentMonth(
    entries: [Entry],
    submissions: [SubmittedReport],
    trackers: [Tracker],
    status: PublisherStatus?,
    now: Date = .now,
    calendar: Calendar = .current,
    locale: Locale = .current
) -> TimeInterval {
    guard let rule = status?.yearlyGoalRule else { return 0 }
    let report = TheocraticYearReportBuilder.report(
        for: TheocraticYear.containing(now, calendar: calendar),
        entries: entries, submissions: submissions, trackers: trackers,
        now: now, calendar: calendar, locale: locale)
    return creditedSeconds(before: now.yearMonth(using: calendar), in: report, rule: rule)
}
```

Replace only `PlannerPager.creditedBeforeCurrentMonth`'s body with:

```swift
guard targetBase == .yearlyGoalShare else { return 0 }
return PlannerTarget.creditedBeforeCurrentMonth(
    entries: yearEntries, submissions: submissions, trackers: trackers,
    status: status, now: today)
```

Keep the property and its lazy guard. The Settings page must compute the credit even with Monthly goal selected, because it displays both candidates.

Add tests reusing the existing fixture → 95 h; adding current-month entries does not change that input; auxiliary/nil status → 0. Add a submission regression modeled on `YearlyGoalProgressTests.submittedMonthsUseSubmittedHoursNotRawSeconds`: a September snapshot with main 4 h and separate 2 h takes precedence over a raw 30 h September entry. With no other past month data, the helper must return 6 h. Use the report builder rather than hand-selecting snapshots in this helper.

**Verify**: focused tests pass. `rg 'TheocraticYearReportBuilder' Hugo/Features/Planner/Screens/PlannerView.swift` has no match. The two domain functions remain the only source of target credit and target arithmetic.

### Step 2: Define and test target presentation values

Create nonisolated `PlannerTargetPreview` in `Planner/Domain`, with a factory taking the existing domain inputs:

```swift
static func make(
    base: PlannerTargetBase,
    extraHours: Int,
    status: PublisherStatus?,
    creditedBeforeCurrentMonth: TimeInterval,
    now: Date = .now,
    calendar: Calendar = .current,
    locale: Locale = .current
) -> PlannerTargetPreview
```

It stores the goal, both candidate bases, selected base, Buffer, optional total target, optional bar fractions, and localized presentation text. Use `PlannerTarget.seconds` for **both zero-Buffer candidates and the selected total**. Nil candidates are zero for geometry, but a nil total stays nil for the “Not set” label. Apply the stable scale specified above only when a factual monthly goal exists.

For the adjusted option's real explanation, compute remaining credited hours from `max(0, yearlyGoalSeconds - creditedBeforeCurrentMonth)` and months left from the current `TheocraticYear.months`, including the current month. These are explanation inputs; do not replace the existing rounded-target function. Show one shared rounding sentence rather than claiming the unrounded quotient is the final target. Number-format the month count using the injected locale; display remaining time with the existing duration formatter. Make the description valid for one remaining month without hand-written English plurals (the template below uses “Months remaining: N”).

The page's computed presentation property may build credit through the shared helper once, then call this factory. `body` must not build the report, reduce arrays, or format alternate totals. Keep the pure presentation independent of SwiftData and UserDefaults. If data changes while the screen remains open, new query inputs must recompute it; do not cache by `entries.count`, because edits/submissions can change values without changing counts.

Add `PlannerTargetPreviewTests`, copying the fixed calendar/locale from `PlannerTargetTests`. Assert:

* Monthly base equals the goal marker; adjusted base crosses above/below with the existing 95/110-hour fixtures.
* Selecting a different base with identical other inputs leaves scale and marker unchanged.
* Buffer is included only in extended/total, never solid. Test 0, a value within headroom, and 30; fractions stay bounded and the total fits.
* Yearly goal already met: adjusted base zero, no Buffer → nil target/empty fill but factual marker remains; positive Buffer → faded-only fill and real positive total.
* Auxiliary: no yearly options, goal 30 h, effective monthly base despite a stale yearly-share choice.
* Publisher/nil: no bar or goal marker, numeric target from additions alone, or Not set at zero. Negative additions cannot produce negative geometry.
* September/last month/September boundary use `TheocraticYear` consistently, and remaining-month count includes the current month.
* All displayed base/total values equal `PlannerTarget.seconds` with matching inputs; unit assertions are seconds, not a manually reimplemented rounding formula.

**Verify**: focused tests pass and `PlannerTargetPreviewTests` appears. `rg 'SwiftData|SwiftUI|ModelContext|UserDefaults' Hugo/Features/Planner/Domain/PlannerTargetPreview.swift` has no match.

### Step 3: Rebuild the visual-first screen

Create `PlannerTargetPreviewView` in `Planner/Views`. It accepts presentation values, displays month and total first, then the bar when available:

```swift
MarkedProgressBar(
    filled: bar.solidFraction,
    extended: bar.extendedFraction,
    marker: bar.markerFraction
) {
    Text(preview.goalLabel)
}
```

The marker label states the factual monthly goal; a nearby textual breakdown identifies the selected base and Buffer with actual amounts. Allow vertical stacking when space is constrained. Do not place large labels in a fixed-height chart area or assume 50 h is the only goal. Use the shared bar's clipped drawing and animation. Animate only after a setting changes, using the existing progress motion for associated numeric transitions. Under Reduce Motion, update the bar without spatial interpolation and remove numeric rolling; the selection/text still provides immediate feedback.

Represent the same information to VoiceOver: current month, monthly goal, selected base/amount, Buffer, total. Hide duplicate shape/legend elements only after supplying this semantic text. No-goal mode omits the nonexistent goal and Buffer semantics.

Rebuild `PlannerTargetSettingsView`:

* Add `import SwiftData` and current-theocratic-year `@Query` entries, submissions, trackers, matching `PlannerPager`'s query semantics.
* Inject `now: Date = .now`, `calendar: Calendar = .current`, and `locale: Locale = .current` in its initializer and use the same values for query bounds, credit, factory, and date labels. Query bounds come from `TheocraticYear.containing(now, calendar: calendar).dateRange(calendar: calendar)` and use `>= start && < end`.
* Keep all existing AppStorage keys and types. The first section holds `PlannerTargetPreviewView`, then the yearly-only options built with `SelectableOptionRow`, then the Buffer/Monthly Target stepper and explanation. Candidate values are base-only, not base plus Buffer. The visual's total already serves the old plan's “This Month” result; do not add a redundant total row below the stepper.
* Remove `showsDone`, dismissal environment, and toolbar after Step 0 confirms no caller depends on them. Keep the inline navigation title.
* Without a yearly goal, hide both option rows; without any goal, hide the bar but keep the numeric result and stepper. Status changes update the presentation without resetting stored choices.
* Changes to entries, submitted reports, or category data while open must refresh candidate targets through the existing queries. No async database singleton or detached task.

For previews, use an in-memory model container and isolated preview defaults. Include a fixed November with actual fixture entries producing a shortfall, a second fixture producing an ahead-of-goal result, a met-yearly-goal fixture, auxiliary, and no goal. Fixtures are preview-only and must not be used as a production fallback. Never mutate standard defaults. Use the repository's `.modelContainer(.preview)` pattern where appropriate, with deterministic custom fixtures for shortfall/ahead scenarios.

**Verify**: focused tests and layout check pass. `rg 'showsDone' Hugo` has no match. Preview switching keeps the goal marker fixed and the number equals the Planner target with the same inputs.

### Step 4: Rename and localize without migrating preferences

Change only the following catalog entries. Preserve JSON format, translated English/Danish units, comments, placeholder order/types, and neighboring keys.

| Action | Key | English | Danish |
|---|---|---|---|
| Update | `planner.target.base.yearlyGoalShare` | Adjusted to yearly goal | Tilpasset årsmålet |
| Update | `planner.target.base.footer` | The adjusted target spreads the remaining yearly goal over the remaining months, rounded up to whole hours. | Det tilpassede mål fordeler resten af årsmålet over de resterende måneder, rundet op til hele timer. |
| Update | `planner.target.extra` | Buffer | Buffer |
| Update | `planner.target.extra.footer` | Added to your base target every month. The faded part of the bar shows your buffer. | Lægges til dit udgangspunkt hver måned. Den nedtonede del af bjælken viser din buffer. |
| Update | `planner.target.extra.footer.noGoal` | Your publisher status has no goal. Choose the monthly target you want the Planner to use. | Din forkynderstatus har intet mål. Vælg det mål for måneden, som planlæggeren skal bruge. |
| Add | `planner.target.thisMonth` | This month | Nuværende måned |
| Add | `planner.target.preview.goal` | Monthly goal: %1$@ | Månedligt mål: %1$@ |
| Add | `planner.target.preview.base` | Base target: %1$@ | Udgangspunkt: %1$@ |
| Add | `planner.target.preview.buffer` | Buffer: %1$@ | Buffer: %1$@ |
| Add | `planner.target.base.monthlyGoal.description` | Uses the monthly goal for your publisher status. | Bruger det månedlige mål for din forkynderstatus. |
| Add | `planner.target.base.yearlyGoalShare.description` | Remaining yearly goal: %1$@. Months remaining: %2$@. | Tilbage af årsmålet: %1$@. Resterende måneder: %2$@. |
| Add | `planner.target.preview.accessibility` | %1$@. Monthly goal: %2$@. %3$@: %4$@. Buffer: %5$@. Target: %6$@. | %1$@. Månedligt mål: %2$@. %3$@: %4$@. Buffer: %5$@. Mål: %6$@. |
| Add | `planner.target.preview.accessibility.noGoal` | %1$@. Monthly target: %2$@. | %1$@. Mål for måneden: %2$@. |

Use existing `planner.target.title` for the no-goal stepper label; existing `planner.target.none` for nil totals. Keep `planner.target.base.monthlyGoal`, `.base`, and `.summary.withExtra` keys. The old `.extra` identifier remains intentionally, just like the stored preference. No “Dynamic”, “Margin”, or “Extra Hours” remains in the changed page's visible text.

Accessibility arguments are localized month, spoken goal duration, selected base label, spoken base duration, spoken Buffer duration, spoken total. “Not set” is acceptable for nil total. Use `ServiceDurationFormatter.accessibilityString` for spoken amounts and `hoursString` for visible amounts. Avoid text stitching that forces English word order.

Update `CONTEXT.md` in the same implementation:

* Monthly target = monthly goal or adjusted yearly-goal base, plus Buffer.
* Add **Adjusted target**: the remaining yearly goal divided over months left including the current month, rounded up to whole hours, based on credited time before the current month. UI name “Adjusted to yearly goal” / “Tilpasset årsmålet”; persisted case `yearlyGoalShare` remains.
* Replace the **Extra hours** entry with **Buffer**: the nonnegative hours added to the base target each month. Without a goal the same preference defines the whole personal monthly target and is labeled Monthly Target. Historical storage/API names remain `plannerExtraHours`/`extraHours` for compatibility.
* Leave the Current month calculation entry from 083 alone; it controls expected time on the Year page, not this target.

**Verify**: catalog JSON check and focused tests pass. Check the two renamed values exactly in English/Danish, and confirm `UserDefaultsKeys.swift` plus enum cases/raw values have no diff. `settingSummary` in General uses the new adjusted label automatically.

### Step 5: Gate, commit, and request owner acceptance

Run `Scripts/verify.sh` and `git diff --check`. Inspect the staged files for accidental catalog reformatting and out-of-scope edits. Commit the implementation, then put SLN-298 In Testing with the commit and verification record. Record pending owner checks in the index; complete only after the owner confirms them.

**Verify**: full gate and whitespace checks exit 0; staged diff is scoped; Linear records In Testing rather than Done.

## Test plan

* Shared-helper tests prove submitted snapshots and credit rules still win over raw time; current-month data is excluded.
* Pure presentation tests prove the bar and all labels agree with the authoritative target math, both choices share a scale, Buffer is separate, and nil/no-goal states are truthful.
* Existing target rounding, later-year fallback, credited-time, and month-status tests remain green.
* Owner checks regular pioneer behind/ahead/on target, Buffer 0 and 30, yearly goal already met, auxiliary, publisher and unset status. Compare page total with the Planner header using the same preferences and data.
* Check both English and Danish, narrow iPhone, iPad, largest Dynamic Type, light/dark, Reduce Motion and VoiceOver. The option titles, marker label, and totals must remain readable without relying on hue/opacity.
* Modify an existing past entry or submitted report without changing collection counts and confirm the open page updates. Reopening the page uses the current date. All previews/test defaults remain isolated from real preferences.

## Done criteria

* [ ] Credited inputs come from the shared helper; target behavior and stored identifiers are unchanged.
* [ ] Monthly Target uses the shared bar with factual goal marker, base fill, and separate Buffer extension.
* [ ] Switching base leaves marker/scale fixed for the same data/Buffer.
* [ ] Exact accepted labels are localized; no-goal mode shows a personal target without a fabricated bar.
* [ ] New/existing focused tests and `Scripts/verify.sh` pass.
* [ ] Owner device/accessibility/localization checks recorded before SLN-298 and plan 084 become Done.

## STOP conditions

* Prerequisites have not landed or another caller still needs the sheet-only API.
* Existing 95-hour credit fixture or target rounding expectations change.
* Getting real inputs appears to require bypassing the report builder, category resolution, or submission precedence.
* A shared component cannot represent this design without a second custom bar; report the capability gap instead.
* A storage migration, new rounding rule, changed stepper range, or out-of-scope file change seems necessary.
* A verification gate fails twice after a targeted fix.

## Maintenance notes

The same bar has different meaning at each call site: logged/planned in Planner, base/Buffer here, a month fraction on the current-month page. Keep those labels and calculations feature-owned. Do not cache credited inputs by array count; edits, submission replacement, sync, and category changes can alter their meaning without changing counts. The explanatory month count and remaining hours do not replace the existing rounded-target calculation.
