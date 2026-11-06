# Plan 083: Put Planner and Service Year settings in General and explain the current-month calculation

> **Executor instructions**: This is an implementation handoff, not permission
> to implement before the owner starts this plan. Read it fully. Follow each
> step and its verification gate. Stop at the listed STOP conditions rather
> than changing the specification. Update the plan index and Linear status as
> work progresses; do not mark Done before the owner checks the interface.
>
> **Drift check**: planned against `9be5c03`, revised 2026-11-06.
> Run `git diff --stat 9be5c03..HEAD -- Hugo/Features/Settings Hugo/Features/ServiceYear/Domain/YearlyGoalPacing.swift Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift Hugo/Features/Planner/Domain/PlannerTarget.swift Hugo/DesignSystem/Components HugoTests/Features/ServiceYear/Domain HugoTests/Features/Planner/Domain/PlannerTargetTests.swift CONTEXT.md`.
> Plan 091's new bar is an expected difference. Catalog additions from other
> completed plans are also expected. Other differences require comparison
> with the current-state excerpts below; stop if their behavior changed.

## Status

* **Status**: DONE — `Scripts/verify.sh` passed, and owner device, English/Danish, and accessibility checks are complete.
* **Priority**: P2
* **Effort**: M + owner device check
* **Risk**: MED — settings navigation and an extraction from yearly expected-time math; no schema change.
* **Depends on**: `plans/091-shared-marked-progress-bar.md`, including its owner check. Plan 084 follows this plan.
* **Category**: direction
* **Planned at**: commit `9be5c03`, revised 2026-11-06
* **Issue**: [SLN-292](https://linear.app/sebastianln/issue/SLN-292)

## Why this matters

Planner and Service Year settings belong inside General, not in the Settings root. The current-month calculation is difficult to understand from a picker alone. A live month bar will show exactly how much of the current month each option adds to expected time, using the user's current date and actual monthly goal. This replaces the old plan's root-level goal section and text-only pacing page.

## Accepted design

```text
Settings
    Publisher Status                 (unchanged)
    Report                           (unchanged)
    Categories                       (opens the category list directly)
    General
        [Planner]
        Monthly Target               (current setting underneath)
        [Service Year]               (yearly-goal statuses only)
        Current Month Calculation    (current setting underneath)
        [unlabelled section]
        Minute Interval
```

* English title: **Current Month Calculation**.
* Danish title: **Beregning af nuværende måned**. Use this exact wording, without emphasis or an asterisk; do not substitute “denne måned” in the setting's title or generic explanations.
* Reuse `tab.planner` and `year.subtitle` for General's section headings. They currently read “Planner” / “Planlæg” and “Service Year” / “Tjenesteår”. Do not rename the tabs.
* The page is a native scrolling list: visual first, three selectable option rows below. No tutorial carousel, decorative illustration, custom card system, or looping demo.
* The visual represents **expected time**, never logged time. It needs real date/status inputs but no database entries: logged time does not determine expected time.
* The month track runs from zero current-month contribution to the full current-month contribution. Below it, show localized dates for the first and last day of the month (for example “November 1” and “November 30”, localized rather than manually concatenated).
* Place a fixed marker at today's inclusive day fraction, with today's localized date above it. The fill is `day / daysInMonth`, `0`, or `1` for the three options. On the first day, today's marker is at `1 / daysInMonth`, not zero; this matches the existing inclusive calculation.
* Above the bar, show the selected current-month contribution as “%1$@ of %2$@” (for example 5 hours of 50 hours). Label it “Current month” and explain that it contributes to the time expected by today, not to recorded hours.
* Each option retains its explanation and its **service-year expected total by today**, as the original plan required. A section caption must identify these numbers as “Expected by today”; they are not the current-month contribution shown above the bar.
* Selecting an option moves only the fill and selected checkmark. Today's marker and endpoint dates do not move. Use plan 091's bar and `Motion.progress`; no entrance sweep. Reduce Motion must remove the spring/spatial interpolation, not merely substitute another width animation.
* At large text sizes, allow labels and values to wrap or stack. Keep the full Danish title available in the row and accessibility label; do not shrink body text to make it fit.

## Current state

At `9be5c03`:

* `Hugo/Features/Settings/Screens/SettingsView.swift:55–68` links to Report, `CategorySettingsView`, General, then `PlannerTargetSettingsView` (“Planner”). Publisher Status has its own section. TestFlight, contact, Debug, and dismissal follow and must stay unchanged.
* `GeneralSettingsView.swift:10–43` owns `durationMinuteInterval`, `pacing`, and `statusID`. It puts Minute Interval first and a plain navigation-link pacing picker second, conditional on `yearlyGoalRule != nil`.
* `CategorySettingsView.swift` contains one link to `CategoryListView`. `CategoryListView` already owns its navigation title and add action.
* `Hugo/Features/ServiceYear/Domain/YearlyGoalPacing.swift` persists these raw values; keep them:

```swift
nonisolated enum YearlyGoalPacing: String, CaseIterable, Sendable {
    case proRated
    case completedMonths
    case includeCurrentMonth
}
```

* Its `label` property maps to `settings.yearlyGoal.pacing.proRated`, `.completedMonths`, and `.includeCurrentMonth`.
* `Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift:65–80` currently computes the current-month contribution inline:

```swift
if month.id < current {
    return total + rule.monthlyGoalSeconds
}
guard month.id == current else { return total }
switch pacing {
case .proRated:
    let day = calendar.component(.day, from: now)
    let lastDay = current.lastDay(calendar: calendar)
    return total + rule.monthlyGoalSeconds * TimeInterval(day) / TimeInterval(lastDay)
case .completedMonths:
    return total
case .includeCurrentMonth:
    return total + rule.monthlyGoalSeconds
}
```

* `YearlyGoalProgress.make(report:status:pacing:now:calendar:)` returns nil without a yearly goal and leaves `expectedSeconds` nil for a future year. Completed years expect the full yearly goal. Preserve all of these rules.
* `TheocraticYearReportBuilder.report(for:entries:submissions:trackers:now:calendar:locale:)` builds twelve months even with `entries: []`. That is sufficient for expected time, which does not read contributions.
* `Hugo/Features/Planner/Domain/PlannerTarget.swift` has `PlannerTargetBase.label`, `seconds(for:base:extraHours:status:creditedBeforeCurrentMonth:now:calendar:)`, and `creditedSeconds(before:in:rule:)`. This plan adds only the settings-summary helper, not the live target computation planned for 084.
* A regular pioneer has a 600-hour yearly goal and a 50-hour monthly goal; auxiliary pioneer has a 30-hour monthly goal but no yearly rule; publisher has no goal. `PublisherStatus.status(for:)` is authoritative.
* `Checkmark` in `Hugo/DesignSystem/Components/Checkmark.swift` already animates selection. Hide the image from accessibility inside the new row; expose selection through `.isSelected` instead.
* Plan 091 provides `MarkedProgressBar(filled:extended:marker:markerLabel:)` and a no-label overload. It accepts fractions, clips the fills, reserves marker height, handles motion, and hides its drawing from accessibility. Each caller must supply equivalent readable text.

### Repository constraints

* `AGENTS.md`: feature files live directly in `Screens`, `Views`, `State`, `Domain`, or `Services`. No new top-level folder. Generic components in `DesignSystem` cannot mention feature types, including in comments.
* Pure calculations belong in nonisolated domain value types. Do not build reports, map options, or format multiple examples inside `body`. No ViewModel is needed for deterministic presentation values.
* Swift 6 complete concurrency checking and MainActor default isolation remain enabled. Preserve storage keys and enum raw values. No migrations or UIKit wrappers.
* Use `HugoLayout` spacing and existing typography. `ServiceDurationFormatter.hoursString(from:locale:)` gives visible durations; `accessibilityString(from:locale:)` gives spoken durations.
* `CONTEXT.md` currently calls the rule **Pacing**: “How expected time is worked out for the current month: in proportion to the days passed, counting only completed months, or counting the whole current month.” Update the user-facing name in the glossary in the same implementation.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Prerequisite | `test -f Hugo/DesignSystem/Components/MarkedProgressBar.swift` | Exit 0; owner check for 091 also recorded |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/YearlyGoalPacingTests -only-testing:HugoTests/YearlyGoalProgressTests -only-testing:HugoTests/CurrentMonthCalculationTests -only-testing:HugoTests/PlannerTargetTests` | `** TEST SUCCEEDED **`; new suites must appear |
| Layout | `Scripts/check-layout.sh` | Exit 0 |
| Catalog syntax | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | Exit 0 |
| Full gate, before every implementation commit | `Scripts/verify.sh` | Exit 0: layout, strict format lint, serial tests, analyze |

## Scope

**In scope**:

* `Hugo/DesignSystem/Components/SelectableOptionRow.swift` (new)
* `Hugo/Features/ServiceYear/Domain/YearlyGoalPacing.swift`
* `Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift` (replace the current-month branch with the shared fraction; preserve behavior)
* `Hugo/Features/Planner/Domain/PlannerTarget.swift` (add `settingSummary` only)
* `Hugo/Features/Settings/Domain/CurrentMonthCalculation.swift` (new, pure presentation values)
* `Hugo/Features/Settings/Views/CurrentMonthCalculationPreview.swift` (new, visual composition)
* `Hugo/Features/Settings/Screens/YearlyGoalPacingSettingsView.swift` (new)
* `Hugo/Features/Settings/Screens/GeneralSettingsView.swift`
* `Hugo/Features/Settings/Screens/SettingsView.swift`
* `Hugo/Features/Settings/Screens/CategorySettingsView.swift` (delete after checking references)
* `HugoTests/Features/ServiceYear/Domain/YearlyGoalPacingTests.swift` (new)
* `HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift` (add extraction regression tests)
* `HugoTests/Features/Settings/Domain/CurrentMonthCalculationTests.swift` (new)
* `HugoTests/Features/Planner/Domain/PlannerTargetTests.swift` (summary tests)
* `Hugo/Resources/Localizable.xcstrings` (keys listed below only)
* `CONTEXT.md` (Pacing definition and naming only)
* This plan's status row in `plans/README.md` and SLN-292 workflow status.

**Out of scope**:

* `PlannerTargetSettingsView` and its current “Extra Hours” wording: 084 owns its redesign and Buffer rename.
* `MarkedProgressBar`: 091 owns its drawing. If it cannot meet this page's documented contract, stop and report the missing capability.
* Persistence, stored defaults, enum raw values, reporting/credit rules, and the Year header's design.
* Publisher Status, Report, Debug, TestFlight, support, dismissal behavior, and the category list itself.

## Git workflow

Work on `main`; no branch, worktree, push, or agent co-authorship trailer. Preserve all pre-existing owner changes, especially planning files. Stage explicit paths only; never use blanket staging or destructive cleanup. Run `Scripts/verify.sh` before the implementation commit, suggested message `feat: organize General settings and explain current-month calculation`. Keep implementation and completion-status documentation in separate commits, running the gate before each. Leave Linear In Testing until the owner confirms the device check; do not claim the planning revision is implemented.

## Steps

### Step 0: Confirm the shared bar is ready

Read plan 091's completion record and confirm its owner device check passed. Inspect the component interface and the excerpts above. Check that neither `CurrentMonthCalculation` nor the new row already exists under another name.

**Verify**: prerequisite command exits 0; `git status --short` recorded; plan 091 owner check documented. Otherwise stop.

### Step 1: Extract the exact current-month fraction

Add this instance function to `YearlyGoalPacing` without changing cases or labels:

```swift
func currentMonthFraction(now: Date = .now, calendar: Calendar = .current) -> Double {
    switch self {
    case .proRated:
        let current = now.yearMonth(using: calendar)
        let day = calendar.component(.day, from: now)
        return Double(day) / Double(current.lastDay(calendar: calendar))
    case .completedMonths:
        return 0
    case .includeCurrentMonth:
        return 1
    }
}
```

In `YearlyGoalProgress.make`, keep the past-month branch, the current-month guard, and future-year handling. Replace only the switch with `return total + rule.monthlyGoalSeconds * pacing.currentMonthFraction(now: now, calendar: calendar)`. Do not replace this rule with elapsed seconds, `(day - 1) / days`, or a fixed 30-day denominator.

Add `explanation: LocalizedStringResource`, keyed to the three `.description` entries listed below. Keep it separate from the numeric function.

Add fraction tests using a fixed Gregorian UTC calendar: November 3 gives `3 / 30`; the first gives `1 / days`; the last gives 1; February 2028 uses 29 days; February 2027 uses 28; the other options always give 0 and 1. Assert with tolerance where needed. Extend `YearlyGoalProgressTests` to compare each option's current-month increment with `monthlyGoalSeconds * fraction`; existing November 3 results must remain **105, 100, and 150 hours**.

**Verify**: focused tests pass, including all existing yearly-progress tests. `rg 'switch pacing' Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift` has no match.

### Step 2: Build the real-data presentation outside the view body

Create `Settings/Domain/CurrentMonthCalculation.swift`, a nonisolated value type. Its factory takes `status: PublisherStatus?`, `now: Date = .now`, `calendar: Calendar = .current`, and `locale: Locale = .current`; return nil without a yearly goal. Store:

* First-day date, last-day date, and today's date, with localized month/day labels generated using the supplied calendar, timezone, and locale. No hardcoded “November”, date order, English suffixes, or added year.
* `todayFraction`, always obtained from `.proRated.currentMonthFraction` regardless of selected option.
* `monthlyGoalSeconds` from the actual yearly goal rule.
* Three option values: pacing case, its current-month fraction, current-month contribution in seconds, and service-year expected seconds by today.

For the service-year totals, build **one** report for `TheocraticYear.containing(now, calendar: calendar)` with empty entries and pass it to `YearlyGoalProgress.make` for each option. Use `expectedSeconds` from that existing function; do not duplicate its past/future-month rules. This is intentionally not a database query: the quantity being explained is expectation, not actual achievement. Do not invent logged history to make the visual interesting.

Keep string interpolation localized. Pass the same date/calendar/locale to every helper. The screen may make one presentation value in a computed property; `body` only composes it. A pure value does not need an observable workflow object.

Test November 3, 2026, regular pioneer: marker 0.1; option fills 0.1/0/1; current-month contributions 5/0/50 hours; year expectations 105/100/150. Test publisher, auxiliary, and nil status → nil. Test both en_US and da_DK date output semantically against Foundation formatting with the supplied calendar rather than punctuation guessed in a test. Test February 29 and the last day.

**Verify**: focused tests pass and `CurrentMonthCalculationTests` appears in the test output. No `ModelContext`, `@Query`, or `SwiftUI` import in the new domain file.

### Step 3: Add the selectable row and visual page

Create the generic `SelectableOptionRow` with this interface:

```swift
struct SelectableOptionRow: View {
    let title: Text
    var description: Text? = nil
    var value: Text? = nil
    let isSelected: Bool
    let action: () -> Void
}
```

Use a plain Button with the entire row as the content shape, a minimum 44 pt hit target, primary title, secondary footnote description, optional monospaced value, and the existing `Checkmark`. Combine accessibility children, always hide the checkmark image, and add `.isSelected` to the chosen button. Let the description wrap. Move the value below the title/description at accessibility sizes or whenever a horizontal candidate does not fit; do not rely only on screen width or truncate values.

Create `CurrentMonthCalculationPreview` in `Settings/Views`. It takes the presentation and selected pacing, displays the current-month contribution and monthly goal, and uses:

```swift
MarkedProgressBar(
    filled: selected.fraction,
    marker: calculation.todayFraction
) {
    Text(calculation.todayLabel)
}
```

The illustration is not an interactive slider. Put the first/last date labels below the track. Keep the date marker fixed on selection. Expose an accessible summary containing today's date, the selected rule, current-month contribution, full monthly goal, and selected service-year expected total; hide only duplicate drawing elements, not all information. Use full spoken duration units for VoiceOver.

Create `YearlyGoalPacingSettingsView` in `Settings/Screens`. Keep `@AppStorage` bindings to existing pacing/status keys. Inject `now`, `calendar`, and `locale` with production defaults for deterministic previews/tests. Snapshot them consistently for the presentation; reopening the page takes a fresh current date. Show the visual as the first list section and the three option rows below. Write a selection straight to the existing AppStorage value. Do not animate on first appearance. If the status loses its yearly goal while the page is open, show the no-yearly-goal explanation instead of fabricated 50-hour values; hide irrelevant choices without resetting stored pacing.

Preview with a fixed November 3 date and isolated preview UserDefaults containing regular-pioneer status. Do not write to `UserDefaults.standard` from previews. Also preview November 1, November 30, the largest accessibility size, and Danish labels. Use `.modelContainer(.preview)` only where a parent requires it; this page itself has no database dependency.

**Verify**: focused tests build the app and pass; `Scripts/check-layout.sh` exits 0. Inspect previews: 0 is empty, the first day's sliver is contained, and all dates are readable. Record manual checks rather than claiming snapshots were tested automatically.

### Step 4: Put the navigation in General, not at the root

Add `PlannerTarget.settingSummary(base:extraHours:status:locale:) -> String`, defaulting locale to `.current`. This is a settings description, not a live database-derived target:

* With a yearly goal: chosen base label, optionally followed by ` + ` and the nonnegative additional duration.
* With a monthly goal but no yearly goal: monthly-goal label regardless of a previously stored yearly-share choice, optionally plus the duration.
* Without any goal: positive additional duration alone, otherwise localized `planner.target.none`.
* Format durations and localized interpolation using the supplied locale. Do not read UserDefaults inside the helper. Keep the old parameter and storage name `extraHours`; 084 changes its visible name to Buffer.

Add tests for both bases, auxiliary fallback, nonzero additions, negative additions treated as zero, and publisher/nil with and without a target. Compare localized results through the catalog, not device-language assumptions.

In `GeneralSettingsView`, keep the storage bindings for status, pacing and Minute Interval; add base and extra-hours bindings. Reorder its list:

1. Planner section: Monthly Target navigation link to the existing `PlannerTargetSettingsView`, with `settingSummary` as its secondary text.
2. Conditional Service Year section: Current Month Calculation link to the new page, with `pacing.label` as secondary text.
3. Unlabelled section: the existing Minute Interval picker unchanged, last.

Remove General's old pacing Picker and footer. In `SettingsView`, remove the standalone Planner link only; leave Publisher Status in its existing section, and Report/General and later sections in place. Change Categories to push `CategoryListView` directly. Check references before deleting the redundant `CategorySettingsView`.

**Verify**: `rg 'PlannerTargetSettingsView|YearlyGoalPacingSettingsView' Hugo/Features/Settings/Screens/GeneralSettingsView.swift` finds both destinations; neither destination occurs in `SettingsView.swift`. `rg 'CategorySettingsView' Hugo HugoTests` has no match. Focused tests pass. Check the hierarchy manually in both languages.

### Step 5: Localize the page and update the glossary

Edit only these catalog entries. Preserve neighboring entries and the catalog's existing format; all new entries need English and Danish translated string units and a translator comment. Placeholder order and types must agree across languages. Duration arguments are already localized strings, not bare hours that require a new plural rule.

| Action | Key | English | Danish |
|---|---|---|---|
| Update | `settings.yearlyGoal.pacing` | Current Month Calculation | Beregning af nuværende måned |
| Add | `settings.yearlyGoal.pacing.intro` | Choose how much of the current month's goal counts toward the time expected by today. This does not change your logged time or your yearly goal. | Vælg, hvor stor en del af målet for den nuværende måned der skal indgå i den tid, du forventes at have nået i dag. Det ændrer hverken din registrerede tid eller dit årsmål. |
| Add | `settings.yearlyGoal.pacing.currentMonth` | Current month | Nuværende måned |
| Add | `settings.yearlyGoal.pacing.monthContribution` | %1$@ of %2$@ | %1$@ af %2$@ |
| Add | `settings.yearlyGoal.pacing.expectedByToday` | Expected by today | Forventet frem til i dag |
| Add | `settings.yearlyGoal.pacing.options.caption` | The hours beside each option show the expected time for the service year by today. | Timerne ved hver valgmulighed viser, hvor meget tid du forventes at have nået i tjenesteåret frem til i dag. |
| Add | `settings.yearlyGoal.pacing.proRated.description` | The part of the monthly goal that counts grows each day. | Den del af månedens mål, der tæller med, vokser dag for dag. |
| Add | `settings.yearlyGoal.pacing.completedMonths.description` | The current month counts only once it is over. | Den nuværende måned tæller først med, når den er slut. |
| Add | `settings.yearlyGoal.pacing.includeCurrentMonth.description` | The whole monthly goal counts from the first day. | Hele månedens mål tæller med fra den første dag. |
| Add | `settings.yearlyGoal.pacing.noGoal` | Your publisher status has no yearly goal. | Din forkynderstatus har intet årsmål. |
| Add | `settings.yearlyGoal.pacing.accessibility` | %1$@. %2$@. Current month: %3$@ of %4$@. Expected by today: %5$@. | %1$@. %2$@. Nuværende måned: %3$@ af %4$@. Forventet frem til i dag: %5$@. |
| Add | `planner.target.none` | Not set | Ikke valgt |
| Add | `planner.target.summary.withExtra` | %1$@ + %2$@ | %1$@ + %2$@ |
| Remove after reference check | `settings.yearlyGoal.pacing.footer` | Superseded | Superseded |
| Remove after reference check | `settings.screens.categories.items.list` | Deleted wrapper page | Deleted wrapper page |

Keep existing three option labels. The accessibility template arguments are localized date, selected label, current contribution, monthly goal, and year expectation. Do not read a raw percentage as a substitute for this explanation. The option caption is sufficient explanation; do not add another tip paragraph.

In `CONTEXT.md`, rename the **Pacing** entry to **Current month calculation** and keep its definition, adding that it is called “Current Month Calculation” / “Beregning af nuværende måned” in Settings and determines expected time, not credited/logged time. State that persisted code names remain `YearlyGoalPacing`. Do not apply the Buffer glossary change yet; 084 owns it.

**Verify**: catalog JSON check and focused tests pass. Search Swift sources for removed keys: no matches. Confirm the title's `da` string is exactly `Beregning af nuværende måned`; no literal month names occur in production UI code.

### Step 6: Full gate and hand over for the owner check

Run `Scripts/verify.sh` and inspect `git diff --check`. Keep implementation and plan completion notes in separate commits. Record pending owner checks in the plan index; keep SLN-292 In Testing until the owner verifies the interface.

**Verify**: full gate and `git diff --check` exit 0. SLN-292 is In Testing until the owner device, localization, and accessibility checks pass.

## Test plan

* `YearlyGoalPacingTests`: fractions at first/last day, 28/29/30/31-day months, and all three cases.
* `YearlyGoalProgressTests`: existing 105/100/150-hour November expectations unchanged; future and completed years unchanged; explicit integration with the extracted fraction.
* `CurrentMonthCalculationTests`: real rule inputs, separate month and year quantities, fixed marker across options, localized dates and nil without a yearly goal.
* `PlannerTargetTests`: settings summary for each kind of status, negative/positive additions, and injected locale.
* Owner, English and Danish, narrow iPhone and iPad: exact hierarchy above, category add still works, selection persists when leaving/reopening, monthly target still opens its existing page, Minute Interval remains last.
* Owner, current-month page: first/middle/last-day previews; tapping the options changes fill and numbers but not today's marker. Match the selected service-year expected total to `YearlyGoalProgress` and the Year page's expected-time calculation.
* Owner, VoiceOver, Reduce Motion, largest text, light/dark: values remain understandable without color or movement; no duplicate checkmark announcement; dates do not clip. Record results rather than inferring accessibility from compilation.

## Done criteria

* [ ] Shared fraction is the only current-month fraction rule used by both the explanation and `YearlyGoalProgress`.
* [ ] New and existing focused suites pass; `Scripts/verify.sh` exits 0.
* [ ] Only General contains the Planner and Service Year settings links.
* [ ] Exact Danish title is in the catalog; stored keys/raw values are unchanged.
* [ ] Native visual-first page uses plan 091's bar and real date/status inputs, not demo history.
* [ ] Owner device/localization/accessibility check recorded before marking SLN-292 and this plan Done.

## STOP conditions

* Plan 091 is absent or has not passed its owner check.
* Existing yearly expected totals change, or the implementation requires changing goal/credit/report semantics.
* The shared bar cannot keep the marker label readable or contain tiny fills; report to 091 instead of forking drawing code.
* CategorySettingsView has another caller, an old string still has a live caller, or a storage-key/raw-value rename seems necessary.
* Verification fails twice after a targeted fix, or a required change falls outside scope.

## Maintenance notes

The current-month bar measures a fraction of a month; the target bar in 084 measures hours. Only drawing is shared. Never pass a duration directly as a fraction or use the Planner's monthly target (which includes Buffer) as the denominator of the yearly expectation. The summary row describes preferences and stays independent of database changes. Plan 084 will rename the yearly-share label and Extra Hours without changing their persisted identifiers.
