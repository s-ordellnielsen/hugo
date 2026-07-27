# Plan 002: Remove confirmed dead code and stale project artifacts

> **Executor instructions**: Follow each step in order and run every verification
> gate. Do not delete historical SwiftData schema declarations merely because
> current UI does not call them. Update this plan's row in `plans/README.md` when
> complete.
>
> **Drift check (run first)**:
> `git diff --stat c047d57..HEAD -- Hugo Hugo.xcodeproj README.md AGENTS.md`
> Stop if a listed deletion has acquired a live non-preview caller.

## Status

* **Priority**: P1
* **Effort**: M
* **Risk**: MED
* **Depends on**: `plans/001-establish-refactor-safety-net.md`
* **Category**: tech-debt
* **Planned at**: commit `c047d57`, July 27, 2026

## Why this matters

The compiler currently builds disconnected prototypes, empty views, unused
helpers, and commented feature blocks. These files inflate the apparent
architecture and make later moves preserve concepts the product has already
abandoned. Removing only high-confidence dead code first gives subsequent plans
a smaller and more truthful project.

## Current state

Confirmed declaration-only or preview-only files:

* `Hugo/Screens/PlannerView.swift:10-35` — the tab is commented out in `ContentView.swift:21-23`.
* `Hugo/Screens/Account/SettingsView.swift:10-20` — an empty list; its navigation link is commented out.
* `Hugo/Features/AddReportSheet/AddReportSheet.swift:11-145` — submit is a TODO and the only production presentation is commented out.
* `Hugo/Views/DynamicSheet.swift:10-58` — no production caller.
* `Hugo/View Modifiers/GaugeStyle.swift:10-26` — no `.circularLarge` use.
* `Hugo/Features/TrackerSettings/Views/TrackerSettingsDetailsEntryList.swift:12-27` — empty body and preview only.
* `Hugo/Features/SymbolPicker/Views/SymbolPickerAttributeToggle.swift:11-49` — the picker uses a single optional attribute instead.
* `Hugo/Data/Extensions/Calendar.swift:10-26` — `days(from:to:)` has no caller.

Confirmed unused members include:

* `EntrySheet.Add.includeTime`, `isDateAtMidnight()`, and `setBibleStudies(_:)`.
* `OverviewView.showAddItemSheet`.
* `ReportView.addReportSheetIsPresented`.
* `MonthlyReportListView.Row.showCopyAlert`.
* `AppInitializer.trackerRecordType`.
* Unused environment/query properties in report details, entry content,
  duration picker, tracker detail, current progress, and entry detail.

The app bundle also contains `README.md`, `AGENTS.md`, and both `.xcconfig`
files. The verified build log copied them into `Hugo.app`, although they are not
runtime resources.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Reference check | `rg -n '\b(PlannerView\|AddReportSheet\|DynamicSheet\|CircularLarge\|DetailsEntryList\|AttributeToggle)\b' Hugo --glob '*.swift'` | Only files/comments scheduled for deletion before Step 1; no matches after cleanup |
| Tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan002DerivedData CODE_SIGNING_ALLOWED=NO` | Exit 0 and `TEST SUCCEEDED` |
| Bundle inspection | `find /tmp/HugoPlan002DerivedData/Build/Products/Debug-iphonesimulator/Hugo.app -maxdepth 1 -type f -print \| sort` | No README, AGENTS, or xcconfig files |

## Scope

**In scope**:

* The eight confirmed dead Swift files/directories listed above.
* `Hugo/ContentView.swift`
* `Hugo/Screens/AccountView.swift`
* `Hugo/Screens/OverviewView.swift`
* `Hugo/Screens/Report/ReportView.swift`
* `Hugo/Screens/Report/Features/MonthlyReportDetail/MonthlyReportDetailView.swift`
* `Hugo/Screens/Report/Features/MonthlyReportList/Views/MonthlyReportListRow.swift`
* Active entry, tracker-settings, current-progress, symbol-picker, and bootstrap files solely for removing confirmed unused declarations/imports/comments.
* `Hugo.xcodeproj/project.pbxproj` solely for resource membership cleanup.
* `Hugo/Resources/Markdown/da.lproj/getting-started.md` and `en.lproj/getting-started.md` if a final source search confirms no runtime loader.
* `plans/README.md` status update.

**Out of scope**:

* Any file under `Hugo/Models/**/Versions/` except dead methods explicitly handled by Plan 003.
* Renaming active types or moving active files.
* Replacing `Tracker` terminology; Plan 005 owns UI vocabulary.
* Changing runtime behavior or completing commented features.
* Deleting `SchemaV8.Report`, `DailyPoint`, or `TrackerSummary`.

## Git workflow

* Branch: `advisor/002-remove-dead-code`
* Commit: `Removed unused prototypes and stale project artifacts`
* Preserve deletions as deletions; do not leave forwarding shims.

## Steps

### Step 1: Delete disconnected prototypes and helpers

Run the reference command and distinguish declarations/previews from live
callers. Delete the eight files listed under Current state. Delete the two
localized `getting-started.md` files only after `rg -n 'getting-started|Resources/Markdown' Hugo --glob '*.swift'`
returns no matches.

Do not delete `EntrySheet.swift` or `EntryList.swift` yet; despite being empty
namespace structs, active code refers to their nested types. Plan 006 removes
them atomically with call-site renames.

**Verify**: The reference command returns no matches in active Swift source and
the test command succeeds.

### Step 2: Remove commented implementation blocks

Delete commented-out feature blocks from:

* `ContentView.swift:21-33`
* `AccountView.swift:32-123`
* `ReportView.swift:46-59`
* `SymbolPicker.swift:35-55`

Keep explanatory comments that document a non-obvious invariant. Do not convert
commented product ideas into TODOs; product intent belongs in an issue or plan,
not executable source.

**Verify**: `rg -n '^\s*//\s*(Tab|NavigationLink|Section|Button|\.task|\.toolbar|\.sheet|VStack|HStack)' Hugo --glob '*.swift'`
returns no commented implementation blocks.

### Step 3: Remove unused properties, methods, imports, and debug prints

Remove every confirmed member listed under Current state. Also remove:

* `@Environment(\.colorScheme)` and `@Query trackers` from `EntryList.DetailSheet`.
* `@Environment(\.modelContext)` from `EntryList.Content` and `EntryList.DurationPicker`.
* `@Query trackers` from `TrackerSettingsView.DetailView`.
* `@Environment(\.modelContext)` from `CurrentMonthProgressView`.
* `@Environment(\.dismiss)` and `@Environment(\.modelContext)` from `MonthlyReportDetailView`.
* The per-render `print` at `CurrentMonthProgressSegmentedProgressView.swift:66`.
* Imports that become unused after these removals.

Do not remove `print` calls from migrations or bootstrap yet; Plans 003 and 008
replace them with scoped logging while restructuring those systems.

**Verify**: Build and tests succeed with no Swift compiler warning for unused
locals in application source.

### Step 4: Stop bundling development metadata

In `Hugo.xcodeproj/project.pbxproj`, remove `README.md` and `AGENTS.md` from the
app target's `PBXResourcesBuildPhase` while retaining them as project navigator
references. Add `ConfigDebug.xcconfig` and `ConfigRelease.xcconfig` to the
file-system synchronized build-file exception set so they remain build
configuration inputs but are not copied into the app bundle.

Do not remove `PrivacyInfo.xcprivacy` from resources.

**Verify**: Clean `/tmp/HugoPlan002DerivedData`, run tests, and inspect the app
bundle. `README.md`, `AGENTS.md`, `ConfigDebug.xcconfig`, and
`ConfigRelease.xcconfig` must be absent; `PrivacyInfo.xcprivacy` must remain.

## Test plan

* Run all characterization tests from Plan 001 after each deletion batch.
* A successful compile is the reference proof for deleted internal declarations because the target uses a file-system synchronized root group.
* Inspect the built app bundle to verify resource membership rather than relying only on project-file text.

## Done criteria

* [ ] All eight confirmed dead Swift files are deleted.
* [ ] The unused localized Markdown resources are deleted or a live runtime loader is documented and the files are retained.
* [ ] Confirmed unused properties, functions, imports, and commented implementations are gone.
* [ ] `rg -n 'TODO: Handle adding report manually' Hugo` returns no match because the abandoned no-op feature is deleted.
* [ ] README, AGENTS, and xcconfig files are absent from the built app bundle.
* [ ] Tests pass.
* [ ] No historical schema model was deleted.
* [ ] Plan 002 is marked DONE in `plans/README.md`.

## STOP conditions

* Any scheduled deletion has a live non-preview caller.
* Removing a file changes a localization key or user-visible behavior rather than only unreachable code.
* Xcode file-system synchronization still bundles xcconfig files after adding correct exceptions.
* A historical model appears unused by UI but is referenced by `Schema.models` or `HugoMigrationPlan`.

## Maintenance notes

* Xcode's synchronized groups make newly added non-source files under `Hugo/` resources by default. Keep build configuration and documentation outside that root or add explicit membership exceptions.
* Future product ideas should be tracked outside source instead of as hundred-line commented blocks.
