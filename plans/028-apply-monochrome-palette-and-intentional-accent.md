# Plan 028: Apply the monochrome palette and intentional teal accents

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving on. If anything in the STOP conditions section occurs, stop and report it rather than improvising. When complete, update Plan 028 in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat f15e122..HEAD -- Hugo/Views/Checkmark.swift Hugo/Features/Overview/MonthlyProgressCircle.swift Hugo/Features/Overview/ReportReminderCard.swift Hugo/Features/Onboarding/OnboardingView.swift Hugo/Features/Reports/SubmitReportView.swift Hugo/Features/Reports/MonthSubmissionStatusView.swift Hugo/Features/Reports/MonthlyReportDetailView.swift Hugo/Features/Reports/MonthlyReportEntryListView.swift Hugo/Features/Settings/Views/CurrentPublisherStatusView.swift Hugo/Features/Categories/DefaultCategoryButton.swift Hugo/Features/Categories/CategoryListView.swift Hugo/Features/Categories/AddCategoryView.swift Hugo/Features/Categories/CategoryDetailView.swift Hugo/Features/SymbolPicker/SymbolPicker.swift Hugo/Features/Entries/EntryDetailView.swift Hugo/Features/Settings/SettingsView.swift Hugo/Features/ServiceYear/MonthlyReportRow.swift plans/README.md`
>
> If an in-scope file changed since this plan was written, compare it with the current-state excerpts and mapping table below. Treat a material mismatch as a STOP condition.

## Status

* **Priority**: P1
* **Effort**: M
* **Risk**: MED
* **Depends on**: `plans/027-establish-safe-hugo-theme-tokens-and-monochrome-root-tint.md`
* **Category**: tech-debt
* **Planned at**: commit `f15e122`, August 10, 2026

## Why this matters

The current interface mixes Orange, Yellow, Green, Red, a generated hue ramp, an asset accent, and feature-local `.primary` tints. This creates visual competition with future category-defined colors and makes the app’s color meaning inconsistent. After this plan, neutral system backgrounds and label hierarchy will form the default interface, while System Teal appears only when it communicates a priority action, active completion/status, or progress.

Color removal must not erase meaning. Destructive behavior remains signaled through `ButtonRole.destructive`; warnings retain explicit SF Symbols and localized wording; completion state gets the teal brand accent. This plan intentionally avoids treating every selected control as a branded surface.

## Current state

* Plan 027 introduces `.hugoAccent` and applies inherited `.tint(.primary)` at the app root. This plan must not redefine either behavior.
* `Hugo/Features/Overview/MonthlyProgressCircle.swift:16-25` fills the gauge with an Orange-to-Yellow gradient:

    Circle()
        .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground))
    Rectangle()
        .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .bottom, endPoint: .top))

* `Hugo/Features/Reports/SubmitReportView.swift:135-147` uses `.buttonStyle(.borderedProminent)` and `.tint(.orange)` for the submit CTA.
* `Hugo/Features/Onboarding/OnboardingView.swift:40-57` draws the completion CTA manually with `Color.orange` and white foreground text.
* `Hugo/Features/Overview/ReportReminderCard.swift:18-30` uses Orange for the report-reminder icon disc and title.
* `Hugo/Features/Reports/MonthSubmissionStatusView.swift:16-30` uses Green for submitted and Orange for the unreported warning.
* `Hugo/Views/Checkmark.swift:14-22` and `Hugo/Features/Settings/Views/CurrentPublisherStatusView.swift:19-26` currently inherit `.tint`.
* `Hugo/Features/Categories/DefaultCategoryButton.swift:18-21` and `Hugo/Features/Categories/CategoryListView.swift:27-31` use Yellow stars for an active default category.
* `Hugo/Features/SymbolPicker/SymbolPicker.swift:89-101` uses `Color.accent` for selected symbol cells. This is a generic selector, so it must become monochrome rather than a new teal use.
* `Hugo/Features/Entries/EntryDetailView.swift`, `Hugo/Features/Settings/SettingsView.swift`, `Hugo/Features/Categories/CategoryListView.swift`, `Hugo/Features/SymbolPicker/SymbolPicker.swift`, and `Hugo/Features/ServiceYear/MonthlyReportRow.swift` contain redundant `.tint(.primary)` modifiers that Plan 027 makes unnecessary.
* `Hugo/Features/Overview/CategoryProgressBreakdownView.swift` still uses `Color(hue:)`. It is explicitly owned by Plan 029 and must not be changed in this plan.

## Required color mapping

| Location | Current treatment | Target treatment | Reason |
|---|---|---|---|
| `MonthlyProgressCircle` | Orange/Yellow gradient | Solid `.hugoAccent` progress fill | Main progress gauge is an approved branded surface |
| `SubmitReportView` | Orange prominent submit CTA | `.tint(.hugoAccent)` | Primary report-submission CTA |
| `OnboardingView` | Orange completion CTA | `.background(.hugoAccent)` with white inverse label | Primary completion CTA |
| `ReportReminderCard` | Orange icon disc and title | `.hugoAccent` | Prominent path to report submission |
| `MonthSubmissionStatusView` | Green success label | `.hugoAccent` | Active completion/status marker |
| Warning labels/banners | Orange | Default label color or `.secondary`, retaining icon and text | No arbitrary warning chrome; semantics remain textual |
| `Checkmark` and current publisher badge | Inherited tint | `.hugoAccent` only when checked/active | Approved active status indication |
| Default-category stars | Yellow | `.hugoAccent` when active, `.primary` otherwise | Approved active-status badge |
| Symbol picker selection | `Color.accent` fill | Neutral primary-opacity fill and primary outline | Generic selection stays monochrome |
| Destructive/debug decoration | Explicit Red | Native destructive role or normal label hierarchy | Remove non-data color while preserving role semantics |
| Month metadata | Red | `.secondary` | Metadata, not a priority status |

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | Exit 0 with no lint diagnostics |
| Unit tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPaletteDerivedData CODE_SIGNING_ALLOWED=NO` | Exit 0; all tests pass |
| Full verification | `DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' DERIVED_DATA=/tmp/HugoPaletteVerifyDerivedData Scripts/verify.sh` | Exit 0; formatter, tests, and analyzer pass |
| Detect retired hard-coded accents | `rg -n --glob '*.swift' '\.(orange|yellow|green|red)\b|Color\.(orange|accent)' Hugo` | No output; command exits 1 because no matches remain |

## Scope

**In scope**:

* `Hugo/Views/Checkmark.swift`
* `Hugo/Features/Overview/MonthlyProgressCircle.swift`
* `Hugo/Features/Overview/ReportReminderCard.swift`
* `Hugo/Features/Onboarding/OnboardingView.swift`
* `Hugo/Features/Reports/SubmitReportView.swift`
* `Hugo/Features/Reports/MonthSubmissionStatusView.swift`
* `Hugo/Features/Reports/MonthlyReportDetailView.swift`
* `Hugo/Features/Reports/MonthlyReportEntryListView.swift`
* `Hugo/Features/Settings/Views/CurrentPublisherStatusView.swift`
* `Hugo/Features/Categories/DefaultCategoryButton.swift`
* `Hugo/Features/Categories/CategoryListView.swift`
* `Hugo/Features/Categories/AddCategoryView.swift`
* `Hugo/Features/Categories/CategoryDetailView.swift`
* `Hugo/Features/SymbolPicker/SymbolPicker.swift`
* `Hugo/Features/Entries/EntryDetailView.swift`
* `Hugo/Features/Settings/SettingsView.swift`
* `Hugo/Features/ServiceYear/MonthlyReportRow.swift`
* Update the Plan 028 status row in `plans/README.md` when complete.

**Out of scope**:

* `Hugo/Features/Overview/CategoryProgressBreakdownView.swift` and `Hugo/Features/Overview/OverviewMetrics.swift`; Plan 029 owns data-driven category colors and fallback behavior.
* New category color controls, custom `ColorPicker` UI, or SwiftData migrations.
* Replacing dynamic system background colors such as `Color(.systemGroupedBackground)` and `Color(.secondarySystemGroupedBackground)`.
* Typography, layout, copy, gestures, accessibility-label wording, and animation changes.
* Any new semantic color token beyond `.hugoAccent`.

## Git workflow

* Create branch `advisor/028-monochrome-palette` unless the operator supplies a branch.
* Make one logical commit after all verification gates pass. Match current commit subjects, for example: `Apply monochrome color palette`.
* Do not push, create a pull request, or modify unrelated working-tree changes.

## Steps

### Step 1: Apply teal only to approved primary and completion surfaces

Make the following focused replacements:

* In `MonthlyProgressCircle`, replace the Orange-to-Yellow gradient with `.fill(.hugoAccent)`. Preserve the existing dynamic circle background, geometry, clipping, and `Motion.progress` behavior.
* In `SubmitReportView`, replace only the bottom CTA’s `.tint(.orange)` with `.tint(.hugoAccent)`. Keep `.buttonStyle(.borderedProminent)`, disabled logic, and safe-area inset unchanged.
* In `OnboardingView`, replace the manual `Color.orange` background with `.hugoAccent`; retain the white foreground for the inverse label on the opaque teal surface.
* In `ReportReminderCard`, replace both Orange uses with `.hugoAccent`; retain the white icon inside the teal circle.
* In `MonthSubmissionStatusView`, render the real submitted state with `.hugoAccent`. For the unreported-entry warning, remove Orange and use `.secondary` while retaining its warning symbol and localized label.
* In `Checkmark`, use `.foregroundStyle(checked ? .hugoAccent : .clear)` rather than inherited `.tint`, while retaining opacity, blur, scale, and animation behavior.
* In `CurrentPublisherStatusView`, replace `.foregroundStyle(.tint)` with `.foregroundStyle(selectedStatus == nil ? .secondary : .hugoAccent)`. An empty state is neutral; an active configured status is teal.
* In `DefaultCategoryButton` and `CategoryListView`, replace Yellow active-star styling with `.hugoAccent`; leave inactive stars and all regular row content `.primary` or default.

Do not use raw `.teal` in feature views. All teal uses must resolve through `.hugoAccent`.

**Verify**: `rg -n --glob '*.swift' 'hugoAccent' Hugo` → results appear only in `Theme.swift` and the approved accent surfaces named above.

### Step 2: Convert generic selection and metadata back to monochrome

In `SymbolPicker.symbolButton(_:)`, replace `Color.accent` selection fill with a light, dynamic monochrome treatment that works in both appearances:

* Keep the normal cell background as `Color(.secondarySystemGroupedBackground)`.
* For a selected cell, use `Color.primary.opacity(0.12)` as the background, keep the symbol `.primary`, and add a one-point `RoundedRectangle` continuous outline in `.primary`.
* Do not use white inverse glyphs or `.hugoAccent` for this generic icon choice.

Then make these neutralization changes:

* Remove explicit Orange foreground styling from the unreported banner in `MonthlyReportDetailView` and warning icon in `MonthlyReportEntryListView`; default label hierarchy plus the warning symbol remains sufficient.
* In `MonthlyReportRow`, change the red uppercase month metadata to `.secondary` and remove its local `.tint(.primary)`.
* In `SettingsView`, remove the explicit red debug-link foreground style and its local root `.tint(.primary)`.
* In `EntryDetailView`, remove `.tint(.red)` from the destructive menu item and remove the outer `.tint(.primary)`. Keep `role: .destructive`, which preserves native destructive semantics.
* Remove redundant `.tint(.primary)` modifiers from `CategoryListView` and `SymbolPicker`.
* In `AddCategoryView` and `CategoryDetailView`, replace image-only `.tint(.primary)` with `.foregroundStyle(.primary)` so icon previews are explicitly label-colored rather than relying on a control tint.

Do not change navigation destinations, button actions, roles, disabled conditions, sheets, or accessibility traits.

**Verify**: `if rg -n --glob '*.swift' '\.(orange|yellow|green|red)\b|Color\.(orange|accent)' Hugo; then exit 1; fi` → exit 0 with no matching output.

### Step 3: Preserve dynamic-system surfaces and inspect both appearances

Do not replace existing `Color(.systemGroupedBackground)`, `Color(.secondarySystemGroupedBackground)`, `Color(.systemBackground)`, `.primary`, `.secondary`, or `.tertiary` uses merely for cosmetic consistency. They are already dynamic Apple system colors and are the required neutral baseline.

Run the app in Light and Dark Mode and manually inspect:

* Overview’s progress circle and report reminder.
* Onboarding completion action.
* Submit Monthly Report CTA in enabled and disabled states.
* Submitted versus unreported report statuses.
* Default-category stars, rounding/status checkmarks, and publisher-status badge.
* Symbol picker selected and unselected cells.
* Destructive entry action and Debug Settings navigation row.

Confirm teal is limited to priority/active state, text remains legible at increased Dynamic Type, and no custom Orange, Yellow, Green, or Red chrome remains.

**Verify**: `DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' DERIVED_DATA=/tmp/HugoPaletteVerifyDerivedData Scripts/verify.sh` → exit 0.

## Test plan

This is a presentation-only migration. Do not add brittle color-equality unit tests or snapshot infrastructure that the repository does not currently use.

* Run all existing unit tests to ensure actions, report state, and model workflows are untouched.
* Use the static retired-accent search after Step 2 to prove raw decorative Orange, Yellow, Green, Red, and `Color.accent` paths are gone.
* Perform the Light/Dark and larger-text manual matrix in Step 3, including enabled and disabled CTA states.

## Done criteria

* [ ] All approved branded surfaces use `.hugoAccent`, never raw `.teal`.
* [ ] `MonthlyProgressCircle` has no Orange/Yellow gradient.
* [ ] Report submission and onboarding CTAs use `.hugoAccent`.
* [ ] Active completion/default-status indicators use `.hugoAccent`; warnings and metadata use system label hierarchy rather than arbitrary semantic chrome.
* [ ] Symbol selection is monochrome and legible in Light and Dark Mode.
* [ ] No in-scope view retains a redundant local `.tint(.primary)`.
* [ ] `if rg -n --glob '*.swift' '\.(orange|yellow|green|red)\b|Color\.(orange|accent)' Hugo; then exit 1; fi` exits 0.
* [ ] `xcrun swift-format lint --strict --recursive Hugo HugoTests` exits 0.
* [ ] The designated `xcodebuild test` command and `Scripts/verify.sh` both exit 0.
* [ ] No files outside the in-scope list are modified, except the required `plans/README.md` status update.

## STOP conditions

Stop and report rather than improvising if:

* Plan 027 is not complete or `.hugoAccent` does not compile in `ShapeStyle` contexts.
* A target view has been structurally redesigned so the mapping table no longer identifies its intended control.
* Removing a local tint changes a control that does not inherit from `HugoApp`’s `.tint(.primary)`.
* A warning or destructive control loses its visible icon, text, `ButtonRole`, or accessibility semantics as part of color removal.
* A requested change requires editing `CategoryProgressBreakdownView`, adding a category color picker, or changing persisted Tracker data.

## Maintenance notes

* New feature work should begin neutral. Add `.hugoAccent` only when the element is a primary CTA, core progress gauge, active completion/status indicator, or category-color fallback.
* Preserve system semantic roles such as `.destructive`; do not reintroduce explicit Red just to duplicate native behavior.
* If a future generic selector needs stronger affordance, prefer monochrome border/background hierarchy before adding teal.
