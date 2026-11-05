# Plan 053: Restructure the project into DesignSystem and feature role folders

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git status --porcelain` must print nothing, and `git log --oneline -1` must show a commit that contains plan 050's AGENTS.md section "7. Project structure" (`grep -c '^## 7. Project structure' AGENTS.md` prints `1`). Then confirm every source path in the move list below exists: the `mv_to` commands in Step 2 stop at the first missing file (`set -e`). If any file was added since this plan was written (compare `find Hugo HugoTests -name '*.swift'` with the lists below), STOP and report it.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW (file moves only; the app is one Swift module, so no import changes are needed)
- **Depends on**: plans/050-refresh-agent-docs-and-small-hygiene.md (it writes the folder rules into AGENTS.md; this plan makes the repository match them). Run it after plans 037–052 so that their paths are already in place.
- **Category**: tech-debt
- **Planned at**: commit `359d37e`, 2026-11-03
- **Issue**: [SLN-256](https://linear.app/sebastianln/issue/SLN-256)
- **Owner decisions (2026-11-03)**: generic UI gets a `Hugo/DesignSystem` folder. Every feature file lives in a role folder (`Screens`, `Views`, `State`, `Domain`, `Services`), even when it is the only file in that role. State classes go in `State`. The refactor is done in one pass.

## Why this matters

AGENTS.md used to ban catch-all folders outright, but the project grew two anyway: `Hugo/Views` (one generic view) and `Hugo/App`, which holds generic styles and tokens next to the app entry point. Features are organized three different ways: `Overview` and `Settings` have partial subfolders, `Reports` has only `Domain`, and `Categories` has ten loose files. Tests do not mirror the source either. A new contributor (or agent) cannot tell where a file belongs. After this plan the layout follows the rules in AGENTS.md section 7 and `Scripts/check-layout.sh` keeps it that way.

## Current state

### Rules to implement (written into AGENTS.md by plan 050; quoted here so this plan stands alone)

- Top level of `Hugo/`: `App`, `DesignSystem`, `Domain`, `Features`, `Persistence`, `PreviewSupport`, `Resources`, plus the existing `Assets.xcassets` (asset catalog), `Info.plist` and `InfoPlist.xcstrings` (files). No other folders.
- `App` is composition only: `HugoApp`, `AppRootView`, `AppBootstrapper`, `CloudTrackerLookup`.
- `DesignSystem` holds generic UI in role folders: `Components`, `Styles`, `Modifiers`, `Motion`, `Theme`. A file belongs there only if it names no feature type and either several features use it or it is generic on purpose.
- Every Swift file in `Hugo/Features/<Feature>/` is inside exactly one role folder: `Screens` (destinations: tab roots, pushed screens, sheets), `Views` (embedded components and UIKit bridges), `State` (`@Observable` classes), `Domain` (value types and logic, no views, no `ModelContext`), `Services` (types that use the SwiftData context or the system). No nested folders inside a role folder.
- Tests mirror the source path under `HugoTests`. `HugoTests/TestSupport` holds shared helpers.

### Project facts

- The project uses filesystem-synchronized groups (`PBXFileSystemSynchronizedRootGroup` for `Hugo` and `HugoTests` in `Hugo.xcodeproj/project.pbxproj`). The only exception is `Info.plist`, which stays where it is. Moving a Swift file needs no project-file edit.
- `Hugo` is a single module. No `import` statement changes when a file moves.
- Files that already sit in a correct role folder stay where they are: everything under `Hugo/Features/Help/Screens`, `Hugo/Features/PublisherStatus/*`, `Hugo/Features/Settings/Screens`, `Hugo/Features/Settings/Views`, `Hugo/Features/Overview/Domain`, `Hugo/Features/Overview/Views`, `Hugo/Features/Reports/Domain`, `Hugo/Features/ServiceYear/Views`, plus `Hugo/App/{AppBootstrapper,AppRootView,CloudTrackerLookup,HugoApp}.swift`, `Hugo/Domain`, `Hugo/Persistence`, `Hugo/PreviewSupport`.
- Judgment calls already made, do not revisit: `ServiceYearPageView` is a `Views` component embedded in the paged `ServiceYearView`; `EntryTimePickerView` and `CategoryPicker` are `Screens` (they are sheets with their own navigation); the UIKit bridges in `OverseerPicker.swift` are `Views`; `AddEntryFormModel.swift` (which also defines `EntryDraft`) is `State`; `SymbolSet` stays in `Domain` although it imports SwiftUI.
- `HugoLayout.Size` in the Theme file contains a few feature-specific numbers (`monthlyProgressDiameter`, `categoryProgressHeight`, `symbolPickerMinimumCellWidth`, `durationPicker*`, `addEntryCompactSheetHeight`). They are plain numbers, not feature types, so they do not break the admission rule. Leave them. (Maintenance note below.)

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Layout check | `Scripts/check-layout.sh` | exit 0, no output |
| Full gate | `Scripts/verify.sh` | exit 0, `** TEST SUCCEEDED **`, `** ANALYZE SUCCEEDED **` |

## Scope

**In scope**:

- Every file in the two move lists in Step 2 (moved with `git mv`, content unchanged)
- `Scripts/check-layout.sh` (create)
- `Scripts/verify.sh` (add one line)
- `AGENTS.md` (only if the layout text from plan 050 disagrees with Step 2; see Step 5)
- `plans/README.md` (status row)

**Out of scope**:

- Any change to a Swift file's contents. If a moved file needs an edit to compile, STOP.
- `Hugo/Persistence/**` layout, `Hugo/PreviewSupport`, `Hugo/Resources`, `Hugo/Assets.xcassets`.
- Splitting feature-specific constants out of `HugoLayout.Size`, renaming types, or splitting big files.
- Anything in `Hugo.xcodeproj`.

## Git workflow

- Branch: only if the operator tells you to. In this repo the operator has been working directly on `main`.
- Use `git mv` for every move so history follows the files. Do not commit unless told to. The operator will commit with a semantic message such as `refactor: restructure the project into DesignSystem and feature role folders`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Record the baseline

```sh
Scripts/verify.sh > /tmp/053-before.log 2>&1; echo $?
grep 'Test run with' /tmp/053-before.log
```

**Verify**: exit `0`. Write down the test count (for example `Test run with N tests`); it must be identical after the moves.

### Step 2: Move the files

Run this script from the repository root. It creates each target folder, moves the file with `git mv`, and stops at the first error.

```sh
set -eu
mv_to() { mkdir -p "$(dirname "$2")"; git mv "$1" "$2"; }

# --- Hugo/ sources (54 moves) ---
mv_to "Hugo/Views/Checkmark.swift" "Hugo/DesignSystem/Components/Checkmark.swift"
mv_to "Hugo/App/EditorialNavigationTitle.swift" "Hugo/DesignSystem/Components/EditorialNavigationTitle.swift"
mv_to "Hugo/App/CardButtonStyle.swift" "Hugo/DesignSystem/Styles/CardButtonStyle.swift"
mv_to "Hugo/App/ErrorAlert.swift" "Hugo/DesignSystem/Modifiers/ErrorAlert.swift"
mv_to "Hugo/App/Motion.swift" "Hugo/DesignSystem/Motion/Motion.swift"
mv_to "Hugo/App/Theme.swift" "Hugo/DesignSystem/Theme/Theme.swift"
mv_to "Hugo/Features/Categories/AddCategoryView.swift" "Hugo/Features/Categories/Screens/AddCategoryView.swift"
mv_to "Hugo/Features/Categories/CategoryDetailView.swift" "Hugo/Features/Categories/Screens/CategoryDetailView.swift"
mv_to "Hugo/Features/Categories/CategoryListView.swift" "Hugo/Features/Categories/Screens/CategoryListView.swift"
mv_to "Hugo/Features/Categories/CategoryPicker.swift" "Hugo/Features/Categories/Screens/CategoryPicker.swift"
mv_to "Hugo/Features/Categories/CategoryAdvancedOptionsView.swift" "Hugo/Features/Categories/Views/CategoryAdvancedOptionsView.swift"
mv_to "Hugo/Features/Categories/DefaultCategoryButton.swift" "Hugo/Features/Categories/Views/DefaultCategoryButton.swift"
mv_to "Hugo/Features/Categories/CategoryName.swift" "Hugo/Features/Categories/Domain/CategoryName.swift"
mv_to "Hugo/Features/Categories/DefaultCategoryDefinition.swift" "Hugo/Features/Categories/Domain/DefaultCategoryDefinition.swift"
mv_to "Hugo/Features/Categories/CategoryDeletionService.swift" "Hugo/Features/Categories/Services/CategoryDeletionService.swift"
mv_to "Hugo/Features/Categories/DefaultCategoryService.swift" "Hugo/Features/Categories/Services/DefaultCategoryService.swift"
mv_to "Hugo/Features/Entries/AddEntry/AddEntryView.swift" "Hugo/Features/Entries/Screens/AddEntryView.swift"
mv_to "Hugo/Features/Entries/AddEntry/EntryTimePickerView.swift" "Hugo/Features/Entries/Screens/EntryTimePickerView.swift"
mv_to "Hugo/Features/Entries/EntryDetailView.swift" "Hugo/Features/Entries/Screens/EntryDetailView.swift"
mv_to "Hugo/Features/Entries/EntryRow.swift" "Hugo/Features/Entries/Views/EntryRow.swift"
mv_to "Hugo/Features/Entries/DurationWheelPicker.swift" "Hugo/Features/Entries/Views/DurationWheelPicker.swift"
mv_to "Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift" "Hugo/Features/Entries/State/AddEntryFormModel.swift"
mv_to "Hugo/Features/Entries/EntryCategory.swift" "Hugo/Features/Entries/Domain/EntryCategory.swift"
mv_to "Hugo/Features/Onboarding/OnboardingView.swift" "Hugo/Features/Onboarding/Screens/OnboardingView.swift"
mv_to "Hugo/Features/Overview/OverviewView.swift" "Hugo/Features/Overview/Screens/OverviewView.swift"
mv_to "Hugo/Features/Overview/MonthlyProgressDetailView.swift" "Hugo/Features/Overview/Screens/MonthlyProgressDetailView.swift"
mv_to "Hugo/Features/Overview/CategoryProgressBreakdownView.swift" "Hugo/Features/Overview/Views/CategoryProgressBreakdownView.swift"
mv_to "Hugo/Features/Overview/MonthlyProgressCard.swift" "Hugo/Features/Overview/Views/MonthlyProgressCard.swift"
mv_to "Hugo/Features/Overview/MonthlyProgressCircle.swift" "Hugo/Features/Overview/Views/MonthlyProgressCircle.swift"
mv_to "Hugo/Features/Overview/MonthlyProgressStatusView.swift" "Hugo/Features/Overview/Views/MonthlyProgressStatusView.swift"
mv_to "Hugo/Features/Overview/ReportReminderCard.swift" "Hugo/Features/Overview/Views/ReportReminderCard.swift"
mv_to "Hugo/Features/Overview/MonthlyProgressStatus.swift" "Hugo/Features/Overview/Domain/MonthlyProgressStatus.swift"
mv_to "Hugo/Features/Overview/OverviewMetrics.swift" "Hugo/Features/Overview/Domain/OverviewMetrics.swift"
mv_to "Hugo/Features/Reports/SubmitReportView.swift" "Hugo/Features/Reports/Screens/SubmitReportView.swift"
mv_to "Hugo/Features/Reports/MonthlyReportDetailView.swift" "Hugo/Features/Reports/Screens/MonthlyReportDetailView.swift"
mv_to "Hugo/Features/Reports/MonthlyReportEntryListView.swift" "Hugo/Features/Reports/Views/MonthlyReportEntryListView.swift"
mv_to "Hugo/Features/Reports/MonthlyReportTotalsView.swift" "Hugo/Features/Reports/Views/MonthlyReportTotalsView.swift"
mv_to "Hugo/Features/Reports/ReportingLineCard.swift" "Hugo/Features/Reports/Views/ReportingLineCard.swift"
mv_to "Hugo/Features/Reports/OverseerPicker.swift" "Hugo/Features/Reports/Views/OverseerPicker.swift"
mv_to "Hugo/Features/Reports/SubmitReportFormModel.swift" "Hugo/Features/Reports/State/SubmitReportFormModel.swift"
mv_to "Hugo/Features/ServiceYear/ServiceYearView.swift" "Hugo/Features/ServiceYear/Screens/ServiceYearView.swift"
mv_to "Hugo/Features/ServiceYear/ServiceYearPageView.swift" "Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift"
mv_to "Hugo/Features/ServiceYear/TheocraticYearTotalsView.swift" "Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift"
mv_to "Hugo/Features/ServiceYear/TheocraticYear.swift" "Hugo/Features/ServiceYear/Domain/TheocraticYear.swift"
mv_to "Hugo/Features/ServiceYear/TheocraticYearReport.swift" "Hugo/Features/ServiceYear/Domain/TheocraticYearReport.swift"
mv_to "Hugo/Features/ServiceYear/TheocraticYearReportBuilder.swift" "Hugo/Features/ServiceYear/Domain/TheocraticYearReportBuilder.swift"
mv_to "Hugo/Features/Settings/SettingsView.swift" "Hugo/Features/Settings/Screens/SettingsView.swift"
mv_to "Hugo/Features/Settings/DebugSettingsView.swift" "Hugo/Features/Settings/Screens/DebugSettingsView.swift"
mv_to "Hugo/Features/Settings/GreetingTemplateView.swift" "Hugo/Features/Settings/Screens/GreetingTemplateView.swift"
mv_to "Hugo/Features/Settings/SettingsButton.swift" "Hugo/Features/Settings/Views/SettingsButton.swift"
mv_to "Hugo/Features/SymbolPicker/SymbolPicker.swift" "Hugo/Features/SymbolPicker/Screens/SymbolPicker.swift"
mv_to "Hugo/Features/SymbolPicker/SymbolAttribute.swift" "Hugo/Features/SymbolPicker/Domain/SymbolAttribute.swift"
mv_to "Hugo/Features/SymbolPicker/SymbolDefinition.swift" "Hugo/Features/SymbolPicker/Domain/SymbolDefinition.swift"
mv_to "Hugo/Features/SymbolPicker/SymbolSet.swift" "Hugo/Features/SymbolPicker/Domain/SymbolSet.swift"

# --- HugoTests/ (19 moves) ---
mv_to "HugoTests/Domain/PublisherStatusTests.swift" "HugoTests/Features/PublisherStatus/Domain/PublisherStatusTests.swift"
mv_to "HugoTests/Domain/ServiceDurationFormatterTests.swift" "HugoTests/Features/Reports/Domain/ServiceDurationFormatterTests.swift"
mv_to "HugoTests/Features/Bootstrap/AppBootstrapperTests.swift" "HugoTests/App/AppBootstrapperTests.swift"
mv_to "HugoTests/Features/Categories/CategoryNameTests.swift" "HugoTests/Features/Categories/Domain/CategoryNameTests.swift"
mv_to "HugoTests/Features/Entries/AddEntryFormModelTests.swift" "HugoTests/Features/Entries/State/AddEntryFormModelTests.swift"
mv_to "HugoTests/Features/Entries/EntryCategoryTests.swift" "HugoTests/Features/Entries/Domain/EntryCategoryTests.swift"
mv_to "HugoTests/Features/Overview/MonthlyProgressStatusTests.swift" "HugoTests/Features/Overview/Domain/MonthlyProgressStatusTests.swift"
mv_to "HugoTests/Features/Overview/OverviewMetricsTests.swift" "HugoTests/Features/Overview/Domain/OverviewMetricsTests.swift"
mv_to "HugoTests/Features/Reports/MonthlyReportBuilderTests.swift" "HugoTests/Features/Reports/Domain/MonthlyReportBuilderTests.swift"
mv_to "HugoTests/Features/Reports/ReportComposerTests.swift" "HugoTests/Features/Reports/Domain/ReportComposerTests.swift"
mv_to "HugoTests/Features/Reports/ReportingLineCalculatorTests.swift" "HugoTests/Features/Reports/Domain/ReportingLineCalculatorTests.swift"
mv_to "HugoTests/Features/Reports/ReportReminderScheduleTests.swift" "HugoTests/Features/Reports/Domain/ReportReminderScheduleTests.swift"
mv_to "HugoTests/Features/Reports/SubmitReportFormModelTests.swift" "HugoTests/Features/Reports/State/SubmitReportFormModelTests.swift"
mv_to "HugoTests/Features/Reports/YearMonthTests.swift" "HugoTests/Domain/YearMonthTests.swift"
mv_to "HugoTests/Features/SymbolDefinitionTests.swift" "HugoTests/Features/SymbolPicker/Domain/SymbolDefinitionTests.swift"
mv_to "HugoTests/Features/TheocraticYear/TheocraticYearReportBuilderTests.swift" "HugoTests/Features/ServiceYear/Domain/TheocraticYearReportBuilderTests.swift"
mv_to "HugoTests/Features/TheocraticYear/TheocraticYearTests.swift" "HugoTests/Features/ServiceYear/Domain/TheocraticYearTests.swift"
mv_to "HugoTests/Persistence/CategoryDeletionServiceTests.swift" "HugoTests/Features/Categories/Services/CategoryDeletionServiceTests.swift"
mv_to "HugoTests/Persistence/DefaultCategoryServiceTests.swift" "HugoTests/Features/Categories/Services/DefaultCategoryServiceTests.swift"

# Remove folders that are now empty (git does not track them, but Xcode's
# synchronized groups would still show them).
for d in Hugo/Views Hugo/Features/Entries/AddEntry HugoTests/Features/Bootstrap HugoTests/Features/TheocraticYear; do
    rm -f "$d/.DS_Store"
    rmdir "$d"
done
```

**Verify**:

- `git status --porcelain | grep -vc '^R'` prints `0` (every change is a rename).
- `git diff --cached -M --name-status | awk '$1 != "R100"' | wc -l` prints `0` (all renames are 100% identical, so no file content changed).
- `test -d Hugo/Views && echo exists` prints nothing, and `ls Hugo` shows exactly: `App Assets.xcassets DesignSystem Domain Features Info.plist InfoPlist.xcstrings Persistence PreviewSupport Resources`.

### Step 3: Build and test

```sh
Scripts/verify.sh > /tmp/053-after.log 2>&1; echo $?
grep 'Test run with' /tmp/053-after.log
```

**Verify**: exit `0`, and the test count equals the baseline from Step 1. If the build fails with a missing file or duplicate symbol, STOP (see STOP conditions). If the simulator fails with "Busy", wait about 25 seconds and run again.

### Step 4: Add the layout check

1. Create `Scripts/check-layout.sh` and make it executable (`chmod +x`). It enforces AGENTS.md section 7 with plain shell:

   ```sh
   #!/bin/sh
   # Checks the folder layout described in AGENTS.md section 7.
   set -eu
   cd "$(dirname "$0")/.."

   status=0
   fail() {
       echo "layout: $1" >&2
       status=1
   }

   # Top level of Hugo/
   for d in Hugo/*/; do
       case "$(basename "$d")" in
       App | Assets.xcassets | DesignSystem | Domain | Features | Persistence | PreviewSupport | Resources) ;;
       *) fail "unexpected top-level folder $d" ;;
       esac
   done

   # DesignSystem role folders
   for d in Hugo/DesignSystem/*/; do
       [ -d "$d" ] || continue
       case "$(basename "$d")" in
       Components | Styles | Modifiers | Motion | Theme) ;;
       *) fail "unexpected DesignSystem folder $d" ;;
       esac
   done
   for f in Hugo/DesignSystem/*.swift; do
       [ -e "$f" ] && fail "$f must be inside a DesignSystem role folder"
   done

   # Feature role folders
   for f in Hugo/Features/*/*.swift; do
       [ -e "$f" ] && fail "$f must be inside a role folder (Screens, Views, State, Domain or Services)"
   done
   for d in Hugo/Features/*/*/; do
       [ -d "$d" ] || continue
       case "$(basename "$d")" in
       Screens | Views | State | Domain | Services) ;;
       *) fail "unexpected feature folder $d" ;;
       esac
   done
   for d in Hugo/Features/*/*/*/; do
       [ -d "$d" ] && fail "nested folder $d (role folders must not contain folders)"
   done

   # DesignSystem and Domain must not name feature types
   if grep -rwnE 'Entry|Tracker|SubmittedReport|TheocraticYear|PublisherStatus' Hugo/DesignSystem Hugo/Domain; then
       fail "DesignSystem and Domain must not reference feature types"
   fi

   exit "$status"
   ```

2. In `Scripts/verify.sh`, add the line `Scripts/check-layout.sh` directly before the `xcrun swift-format lint ...` line. The gate then runs the layout check first.

**Verify**: `Scripts/check-layout.sh` → exit 0, no output. Then prove the check can fail: `touch Hugo/Features/Entries/Stray.swift && Scripts/check-layout.sh; echo $?; rm Hugo/Features/Entries/Stray.swift` → prints a `layout:` message and `1`; afterwards `git status --porcelain | grep Stray` prints nothing.

### Step 5: Check the docs match

**Verify**:

- `grep -n 'DesignSystem' AGENTS.md README.md` → both files mention it (plan 050 wrote them).
- Read the "Project structure" section of AGENTS.md once. The role names (`Screens`, `Views`, `State`, `Domain`, `Services`) and the `DesignSystem` subfolders (`Components`, `Styles`, `Modifiers`, `Motion`, `Theme`) must equal the lists in `Scripts/check-layout.sh`. If they differ, change AGENTS.md (not the script) to match the script, and say so in your report.
- If `AGENTS.md` still contains the old sentence about catch-all `Views`, `Managers` or `Utilities` folders in "Final repository conventions", plan 050 did not land: STOP.

Then run `Scripts/verify.sh` once more → exit 0.

## Test plan

No new unit tests. A refactor that only moves files is proven by the unchanged test count, the all-`R100` rename check, a green build, and the layout script (including the failing-case check in Step 4).

## Done criteria

- [ ] `git diff --cached -M --name-status | awk '$1 != "R100" && $1 != "A" && $1 != "M"' | wc -l` prints `0`, and the only `A` or `M` entries are `Scripts/check-layout.sh`, `Scripts/verify.sh` (and `AGENTS.md` only if Step 5 changed it)
- [ ] `ls Hugo` prints exactly `App Assets.xcassets DesignSystem Domain Features Info.plist InfoPlist.xcstrings Persistence PreviewSupport Resources`
- [ ] `ls Hugo/App` prints exactly `AppBootstrapper.swift AppRootView.swift CloudTrackerLookup.swift HugoApp.swift`
- [ ] `Scripts/check-layout.sh` exits 0
- [ ] `Scripts/verify.sh` exits 0 with the same test count as Step 1
- [ ] `plans/README.md` row for 053 updated

## STOP conditions

Stop and report back if:

- `git status --porcelain` is not empty at the start, or plan 050's AGENTS.md section is missing.
- A source path in the move list does not exist, or a Swift file exists that is not in either list and not in a correct role folder already (someone added a file).
- The build fails after the moves for any reason other than the simulator "Busy" flake. Do not edit Swift files to fix it; report the error.
- The test count after the moves differs from the baseline.
- `Scripts/check-layout.sh` reports a violation you cannot explain from the move list.

## Maintenance notes

- New files must go into a role folder from the first commit; `Scripts/check-layout.sh` fails the gate otherwise. When a feature needs a role folder that does not exist yet (for example its first `State` class), create it with the file.
- The role vocabulary and the `DesignSystem` folders live in two places: AGENTS.md section 7 and `Scripts/check-layout.sh`. Change both together.
- Follow-up that was left out on purpose: `HugoLayout.Size` still holds numbers used by a single feature (`monthlyProgressDiameter`, `categoryProgressHeight`, `symbolPickerMinimumCellWidth`, `durationPicker*`, `addEntryCompactSheetHeight`). They could move next to the views that use them, so `DesignSystem` stays free of feature knowledge. That is a content change, so it is a separate plan.
- The dependency rules (features may use `DesignSystem` and `Domain`; those two never use a feature; avoid circular feature dependencies) are checked only for the five type names in the script. Reviewers should look for new violations by eye.
