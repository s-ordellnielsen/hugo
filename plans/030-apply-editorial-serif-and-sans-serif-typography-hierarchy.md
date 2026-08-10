# Plan 030: Apply the editorial serif and sans-serif typography hierarchy

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving on. If anything in the STOP conditions section occurs, stop and report it rather than improvising. When complete, update Plan 030 in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat f15e122..HEAD -- Hugo/App/EditorialNavigationTitle.swift Hugo/Features/Overview/MonthlyProgressCard.swift Hugo/Features/Overview/MonthlyProgressDetailView.swift Hugo/Features/Overview/MonthlyProgressStatusView.swift Hugo/Features/ServiceYear/ServiceYearView.swift Hugo/Features/ServiceYear/ServiceYearPageView.swift Hugo/Features/ServiceYear/TheocraticYearTotalsView.swift Hugo/Features/ServiceYear/MonthlyReportRow.swift Hugo/Features/ServiceYear/MonthlyReportEmptyRow.swift Hugo/Features/Reports/MonthlyReportDetailView.swift Hugo/Features/Reports/MonthlyReportTotalsView.swift Hugo/Features/Reports/SubmitReportView.swift Hugo/Features/Settings/Views/CurrentPublisherStatusView.swift Hugo/Features/Onboarding/OnboardingView.swift Hugo/Features/Entries/EntryRow.swift plans/README.md`
>
> If an in-scope file changed since this plan was written, compare it with the current-state excerpts below. Treat a material mismatch as a STOP condition.

## Status

* **Priority**: P2
* **Effort**: M
* **Risk**: MED
* **Depends on**: `plans/027-establish-safe-hugo-theme-tokens-and-monochrome-root-tint.md`
* **Category**: tech-debt
* **Planned at**: commit `f15e122`, August 10, 2026

## Why this matters

Hugo already has warm, rounded containers, but it currently uses San Francisco Rounded inconsistently for hero metrics, report totals, status copy, and interface labels. The result is approachable but lacks the intended editorial hierarchy. This plan establishes a deliberate contrast: New York serif for high-value totals and month/year titles; default San Francisco for navigation controls, forms, metadata, and action text.

The app must not ship font assets. `Font.Design.serif` uses Apple’s built-in New York system design and semantic text styles preserve Dynamic Type. Precise duration data remains monospaced, because tabular time values are a data-legibility exception rather than interface prose.

## Current state

* `Hugo/Features/Overview/MonthlyProgressCard.swift:18-29` styles the main monthly total with a scaled 80-point rounded design:

    Text("\\(Int(value))")
        .font(.system(size: heroSize, weight: .heavy, design: .rounded))
        .minimumScaleFactor(0.5)
        .lineLimit(1)
        .fontWeight(.heavy)
        .fontDesign(.rounded)

* `Hugo/Features/ServiceYear/TheocraticYearTotalsView.swift:43-55` and `Hugo/Features/Reports/MonthlyReportTotalsView.swift:35-49` use the `prominent` flag for total cards but do not give the prominent total an editorial serif hierarchy.
* `Hugo/Features/ServiceYear/MonthlyReportRow.swift:49-57` presents the month’s large total with `.font(.title)` plus `.fontDesign(.rounded)`.
* Month/year screen titles currently use native `.navigationTitle` strings in `ServiceYearView`, `MonthlyProgressDetailView`, `MonthlyReportDetailView`, and `SubmitReportView`; no reusable editorial title component exists.
* Rounded font-design modifiers currently occur in:

    Hugo/Features/Onboarding/OnboardingView.swift
    Hugo/Features/Overview/MonthlyProgressCard.swift
    Hugo/Features/Overview/MonthlyProgressStatusView.swift
    Hugo/Features/Entries/EntryRow.swift
    Hugo/Features/ServiceYear/ServiceYearPageView.swift
    Hugo/Features/ServiceYear/TheocraticYearTotalsView.swift
    Hugo/Features/ServiceYear/MonthlyReportRow.swift
    Hugo/Features/ServiceYear/MonthlyReportEmptyRow.swift
    Hugo/Features/Settings/Views/CurrentPublisherStatusView.swift

* Existing `.fontDesign(.monospaced)` uses in report totals, duration rows, and numeric entries are intentional tabular-data styling. Do not replace them with serif.
* Existing card geometry uses continuous-looking rounded rectangles and dynamic system grouped backgrounds. Keep it unchanged; this plan changes type hierarchy, not card layout.

## Typography contract

| Role | Font treatment | Applies to | Must not apply to |
|---|---|---|---|
| Hero | `.system(size: heroSize, weight: .bold, design: .serif)` | Main Overview monthly total | General labels or buttons |
| Editorial title | `.system(.headline, design: .serif, weight: .bold)` | Month/year navigation-title presentation | Toolbar controls, menu labels, form labels |
| Milestone total | `.system(.title, design: .serif, weight: .bold)` | Prominent central report/year total and monthly report-card total | Supporting category totals |
| Interface | Default `.body`, `.subheadline`, `.headline`, `.caption`, or `.title` | Buttons, navigation controls, list labels, forms, metadata | Hero and milestone roles |
| Tabular data | `.fontDesign(.monospaced)` | Exact time/duration values and numeric report columns | Narrative copy and headings |

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | Exit 0 with no lint diagnostics |
| Unit tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoTypographyDerivedData CODE_SIGNING_ALLOWED=NO` | Exit 0; all tests pass |
| Full verification | `DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' DERIVED_DATA=/tmp/HugoTypographyVerifyDerivedData Scripts/verify.sh` | Exit 0; formatter, tests, and analyzer pass |
| Detect deprecated rounded typography | `rg -n --glob '*.swift' '\.fontDesign\(\.rounded\)|design: \.rounded' Hugo` | No output; command exits 1 because no matches remain |

## Scope

**In scope**:

* Create `Hugo/App/EditorialNavigationTitle.swift`.
* `Hugo/Features/Overview/MonthlyProgressCard.swift`
* `Hugo/Features/Overview/MonthlyProgressDetailView.swift`
* `Hugo/Features/Overview/MonthlyProgressStatusView.swift`
* `Hugo/Features/ServiceYear/ServiceYearView.swift`
* `Hugo/Features/ServiceYear/ServiceYearPageView.swift`
* `Hugo/Features/ServiceYear/TheocraticYearTotalsView.swift`
* `Hugo/Features/ServiceYear/MonthlyReportRow.swift`
* `Hugo/Features/ServiceYear/MonthlyReportEmptyRow.swift`
* `Hugo/Features/Reports/MonthlyReportDetailView.swift`
* `Hugo/Features/Reports/MonthlyReportTotalsView.swift`
* `Hugo/Features/Reports/SubmitReportView.swift`
* `Hugo/Features/Settings/Views/CurrentPublisherStatusView.swift`
* `Hugo/Features/Onboarding/OnboardingView.swift`
* `Hugo/Features/Entries/EntryRow.swift`
* Update the Plan 030 status row in `plans/README.md` when complete.

**Out of scope**:

* Changing the numeric report/hero formatting rule. Keep `Int(value)` in `MonthlyProgressCard`; fractional-hour display needs a separate product and localization decision.
* Adding font resources, downloadable fonts, `UIFont`, UIKit appearance proxies, or custom text-rendering code.
* Color, background, accent, animation, localization, accessibility-copy, or data-model changes.
* Card-corner-radius changes, shadows, scroll layout, and navigation architecture changes.
* Replacing `.fontDesign(.monospaced)` exact-duration values.

## Git workflow

* Create branch `advisor/030-editorial-typography` unless the operator supplies a branch.
* Make one logical commit after all verification gates pass. Match current repository style, for example: `Apply editorial typography hierarchy`.
* Do not push, create a pull request, or modify unrelated working-tree changes.

## Steps

### Step 1: Add a reusable editorial navigation-title presentation

Create `Hugo/App/EditorialNavigationTitle.swift`. It must be a small SwiftUI view with a `String` title input, use:

    .font(.system(.headline, design: .serif, weight: .bold))

It must also use a single line and a reasonable minimum scale factor so long localized month names remain usable in the toolbar. Do not set a fixed point size, hard-code a language, or install a custom font.

Use the component as the `.principal` toolbar item while retaining the existing `.navigationTitle` for system navigation semantics in these views:

* `ServiceYearView` for `year.displayName`.
* `MonthlyProgressDetailView` for its localized month-progress title, converted to `String(localized:)` where necessary.
* `MonthlyReportDetailView` for `summary.displayName`.
* `SubmitReportView` for its existing month-year title expression.

Merge the principal item into each view’s existing `.toolbar` block; do not remove cancel, add, or menu toolbar items. The custom presentation must not change destinations, sheet behavior, or title content.

**Verify**: `xcrun swift-format lint --strict Hugo/App/EditorialNavigationTitle.swift Hugo/Features/Overview/MonthlyProgressDetailView.swift Hugo/Features/ServiceYear/ServiceYearView.swift Hugo/Features/Reports/MonthlyReportDetailView.swift Hugo/Features/Reports/SubmitReportView.swift` → exit 0.

### Step 2: Apply New York to hero and milestone totals

Make the following typography changes while preserving each view’s value source, layout constraints, animations, and accessibility behavior:

* In `MonthlyProgressCard`, retain `@ScaledMetric` and the existing `heroSize`, but replace the rounded/heavy stack with one serif declaration equivalent to `.font(.system(size: heroSize, weight: .bold, design: .serif))`. Retain `minimumScaleFactor`, `lineLimit`, `numericText` transition, and `Motion.value`.
* In `TheocraticYearTotalsView.total(_:label:alignment:prominent:)`, render only the `prominent == true` value with `.system(.title, design: .serif, weight: .bold)`. Supporting side totals remain San Francisco callout values with their existing medium weight.
* In `MonthlyReportTotalsView.total(_:label:alignment:prominent:)`, give only the prominent central value the same serif milestone font. Keep supporting category/total values monospaced where they currently represent exact durations.
* In `MonthlyReportRow`, change the large `summary.totalSeconds` value to `.system(.title, design: .serif, weight: .bold)` and retain its secondary hours label as interface typography.
* In `CurrentPublisherStatusView`, treat the selected configured status as a milestone callout: use `.system(.title, design: .serif, weight: .bold)` for its name. Keep the supporting caption in default San Francisco.

Do not change the current whole-hour `Int(value)` conversion in the Overview hero. This is typography work, not a reporting/rounding change.

**Verify**: `rg -n -C 2 'design: \.serif' Hugo/App Hugo/Features` → results appear only in the editorial title and specified hero/milestone contexts.

### Step 3: Return all interface copy to default San Francisco

Remove every remaining `.fontDesign(.rounded)` and `design: .rounded` use in the in-scope files. Do not replace it with another explicit font design unless the text is one of the serif roles in Step 2.

This includes:

* Onboarding section and CTA label typography.
* `MonthlyProgressStatusView` status line.
* `EntryRow` interface metadata line.
* Service Year empty-card title.
* Monthly report card month metadata and empty-month metadata.
* Any remaining non-milestone text in `TheocraticYearTotalsView`, `MonthlyReportRow`, and `CurrentPublisherStatusView`.

Retain semantic text styles such as `.caption`, `.subheadline`, `.body`, `.headline`, `.title2`, and `.title`. Default SwiftUI font design supplies San Francisco and preserves Dynamic Type. Leave every `.fontDesign(.monospaced)` intact.

**Verify**: `if rg -n --glob '*.swift' '\.fontDesign\(\.rounded\)|design: \.rounded' Hugo; then exit 1; fi` → exit 0 with no matching output.

### Step 4: Validate layout and accessibility at real text sizes

Run the app in Light and Dark Mode at default text size, Extra Extra Extra Large, and at least one Accessibility Dynamic Type size. Inspect:

* Overview hero total and status.
* Service Year navigation title, year totals card, populated month card, and empty month card.
* Monthly detail and Submit Report navigation titles with a long month name.
* Publisher-status selection and Onboarding.
* Entry rows with duration and category labels.

Confirm the serif hierarchy is visually distinct but not decorative, navigation titles do not overlap toolbar controls, numbers do not clip, tabular durations remain aligned, and VoiceOver announces each navigation title once rather than duplicating it.

If the principal toolbar title creates duplicate VoiceOver output, preserve the system `navigationTitle` for accessibility and mark only the duplicate visual component accessibility-hidden. Do not remove the system navigation title.

**Verify**: `DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' DERIVED_DATA=/tmp/HugoTypographyVerifyDerivedData Scripts/verify.sh` → exit 0.

## Test plan

Typography selection is a rendering decision and this repository has no visual snapshot harness. Do not add brittle font-equality unit tests.

* Run the complete existing unit suite to ensure toolbar and navigation refactors do not disturb feature logic.
* Use the static rounded-design search to prove old rounded typography has been fully retired.
* Perform the Dynamic Type, long-title, Light/Dark, and VoiceOver manual matrix in Step 4.

## Done criteria

* [ ] `EditorialNavigationTitle` uses Dynamic-Type-aware New York serif at headline weight and is used for month/year view titles.
* [ ] Overview hero, central yearly/monthly report totals, monthly report-card total, and publisher-status callout use New York serif with bold weight.
* [ ] Standard controls, forms, navigation actions, metadata, and supporting labels use default San Francisco text styles.
* [ ] Exact duration/tabular values retain `.fontDesign(.monospaced)`.
* [ ] No `.fontDesign(.rounded)` or `design: .rounded` remains anywhere under `Hugo`.
* [ ] The current whole-hour Overview hero data formatting remains unchanged.
* [ ] Long localized titles and Accessibility Dynamic Type sizes do not clip or overlap controls; VoiceOver does not announce duplicate title content.
* [ ] `xcrun swift-format lint --strict --recursive Hugo HugoTests`, the designated `xcodebuild test` command, and `Scripts/verify.sh` all exit 0.
* [ ] No files outside the in-scope list are modified, except the required `plans/README.md` status update.

## STOP conditions

Stop and report rather than improvising if:

* Plan 027 is incomplete or the root tint/theme work has changed navigation composition materially.
* A screen no longer uses the stated navigation title or toolbar configuration.
* The `.principal` toolbar presentation overlaps system controls, fails at an Accessibility Dynamic Type size, or causes unresolved duplicate VoiceOver announcements.
* Implementing the requested hierarchy requires a bundled font, `UIFont`, a UIKit wrapper, or a layout rewrite outside scope.
* A stakeholder confirms that `14.5` means the hero must change from whole-hour to fractional formatting; that is a separate data-format requirement and should not be inferred here.

## Maintenance notes

* Use `Font.Design.serif` only for editorial hierarchy: hero values, milestone values, and month/year titles.
* New forms, buttons, list rows, menus, and descriptive copy should use default San Francisco semantic styles unless they meet a documented editorial role.
* Keep custom-size serif hero text paired with `@ScaledMetric`; avoid fixed pixel typography that bypasses Dynamic Type.
* Review visual changes with category data colors enabled after Plan 029 so typography, system labels, teal fallback, and custom category colors maintain sufficient contrast.
