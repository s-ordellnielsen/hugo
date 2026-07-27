# Plan 005: Refactor settings and tracker UI around category vocabulary

> **Executor instructions**: Rename user-interface concepts to Category while
> preserving SwiftData and CloudKit model identity as Tracker. Do not perform a
> persisted model rename. Run the default-category tests after each mutation
> change and update `plans/README.md` when complete.
>
> **Drift check (run first)**:
> `git diff --stat c047d57..HEAD -- Hugo/Screens/AccountView.swift Hugo/Features/TrackerSettings Hugo/Views/AddTrackerSheet.swift Hugo/Views/TrackerPicker.swift Hugo/Managers/TrackerManager.swift Hugo/Features/Settings Hugo/Data`
> Stop if persisted `Tracker` properties or category UX have changed.

## Status

* **Priority**: P1
* **Effort**: L
* **Risk**: MED
* **Depends on**: Plans 001, 002, and 003
* **Category**: tech-debt / correctness
* **Planned at**: commit `c047d57`, July 27, 2026

## Why this matters

The product already presents trackers as “Categories,” but source names still
mix `Account`, `Settings`, `TrackerSettings`, generic root `Views`, and a
`TrackerManager`. Creation can also insert a second default tracker because it
does not reuse the manager logic used by the star button. This plan gives the
settings flow one feature-first home, uses product vocabulary at the UI
boundary, and centralizes the default-category invariant with observable error
handling.

## Current state

* `AccountView` is actually the app's settings sheet; it contains publisher status, tracker/category settings, and debug controls.
* `SettingsView` was empty and is removed by Plan 002.
* `AccountViewButton` is defined in the same 164-line file as the sheet.
* `TrackerSettingsView` nests generic child names `DetailView`, `OptionView`, and `FavoriteSwitch` across a `Views` subfolder.
* `AddTrackerSheet` and `TrackerPicker` live in root `Hugo/Views` despite being category feature UI.
* `TrackerManager.setAsDefault` catches and discards fetch/save errors.
* `AddTrackerSheet:64-72` binds `tracker.isDefault` directly and only shows a warning; inserting it can leave multiple defaults.
* `PublisherStatusConfig` is an immutable domain value, not configuration infrastructure.
* `UserDefaults.hasCompletedOnboardingKey` is unused, while onboarding uses a raw `"isOnboarding"` string.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan005DerivedData CODE_SIGNING_ALLOWED=NO` | Exit 0 and category invariant tests pass |
| UI old-name check | `rg -n '\b(AccountView\|AccountViewButton\|TrackerSettingsView\|AddTrackerSheet\|TrackerPicker\|TrackerManager\|PublisherStatusConfig\|PublisherStatusGoalType)\b' Hugo --glob '*.swift'` | Matches only persisted/migration terminology explicitly exempted, or no matches for UI types |
| Persistence guard | `rg -n 'final class Tracker\|var tracker: Tracker\|typealias Tracker' Hugo/Persistence` | Persisted Tracker declarations remain unchanged |

## Scope

**In scope**:

* `Hugo/Screens/AccountView.swift`
* `Hugo/Screens/Account/DebuggingView.swift`
* `Hugo/Features/TrackerSettings/`
* `Hugo/Views/AddTrackerSheet.swift`
* `Hugo/Views/TrackerPicker.swift`
* `Hugo/Managers/TrackerManager.swift`
* `Hugo/Features/Settings/PublisherStatusSelectionView.swift`
* `Hugo/Data/PublisherStatusConfig.swift`
* `Hugo/Data/Enums.swift`
* `Hugo/Data/Extensions/UserDefaultsKeys.swift`
* Relevant call sites in overview/report root toolbars and onboarding.
* Category/settings/domain tests.
* `plans/README.md` status update.

**Out of scope**:

* Any `SchemaV*.Tracker` class, `Entry.tracker`, migration, CloudKit record type, or persistent property.
* Entry feature implementation beyond updating category picker call sites; Plan 006 owns it.
* App bootstrap seeding; Plan 008 owns it.
* Adding account authentication or new settings.

## Target layout and names

```text
Hugo/Domain/
    PublisherStatus.swift
    PublisherGoalPeriod.swift
    UserDefaultsKeys.swift
Hugo/Features/Settings/
    SettingsView.swift
    SettingsButton.swift
    DebugSettingsView.swift
    PublisherStatusSelectionView.swift
Hugo/Features/Categories/
    CategoryListView.swift
    CategoryDetailView.swift
    CategoryAdvancedOptionsView.swift
    AddCategoryView.swift
    CategoryPicker.swift
    DefaultCategoryButton.swift
    DefaultCategoryService.swift
```

Use `Tracker` only when a signature directly touches the persisted model. View
and service names use Category. This deliberate boundary avoids a dangerous
CloudKit migration while aligning code users navigate daily.

## Git workflow

* Branch: `advisor/005-settings-categories`
* Commit domain renames, default invariant, and view moves as separate logical commits.
* Suggested messages: `Aligned settings with category vocabulary` and `Enforced a single default category`.

## Steps

### Step 1: Rename the publisher status domain values

Move the immutable status types to `Hugo/Domain`. Rename:

* `PublisherStatusConfig` → `PublisherStatus`
* `PublisherStatusGoalType` → `PublisherGoalPeriod`
* `defaults` → `all`
* `current(_:)` → `status(for:)`
* `monthlyGoal()` and `yearlyGoal()` → computed properties `monthlyGoal` and `yearlyGoal`

Keep stored identifiers such as `regular-pioneer` unchanged. Update onboarding,
settings, overview, and tests. Use internal access; remove unnecessary `public`.

Move user-default key constants into a named `UserDefaultsKeys` namespace or
enum rather than extending `UserDefaults` with domain-specific static values.
Preserve existing raw key strings to avoid resetting user choices. Remove the
unused completed-onboarding key.

**Verify**: Publisher status characterization tests pass under new names and old
configuration type names have no matches.

### Step 2: Replace `TrackerManager` with a throwing default-category service

Create `@MainActor struct DefaultCategoryService` taking a `ModelContext`. Its
mutation API must:

* fetch all currently default `Tracker` models
* clear them
* set the requested tracker as default when non-`nil`
* save the context
* propagate fetch/save errors

Provide a clear-default operation if the UI still supports deselecting the
current default. Do not silently swallow errors.

Expand tests to assert:

* selecting a new default leaves exactly one
* selecting the same default is idempotent
* clearing leaves none
* creating a category marked default clears the previous default before save

**Verify**: Category service tests pass and `try? context.save()` no longer
exists in category mutation code.

### Step 3: Refactor category creation away from a mutable uninserted model

Rename `AddTrackerSheet` to `AddCategoryView`. Use local primitive form state or
an `@Observable @MainActor` `AddCategoryFormModel`; do not bind the form directly
to a newly allocated SwiftData `Tracker` for the entire presentation.

On submit:

* trim and validate the name
* construct the `Tracker` once
* insert it
* invoke `DefaultCategoryService` if it should become default
* save and dismiss only on success
* expose a localized error alert on failure

Share the icon/type/advanced controls with edit UI only when a concrete,
readable component reduces duplication. Do not create a generic dynamic-form
system.

**Verify**: Tests prove the default invariant and the view builds without force
unwraps.

### Step 4: Rename and flatten category views

Move files into `Features/Categories` and rename:

* `TrackerSettingsView` → `CategoryListView`
* `TrackerSettingsView.DetailView` → `CategoryDetailView`
* `TrackerSettingsView.OptionView` → `CategoryAdvancedOptionsView`
* `TrackerSettingsView.FavoriteSwitch` → `DefaultCategoryButton`
* `TrackerPicker` → `CategoryPicker`

Remove extension-based namespace nesting. Each SwiftUI type is top-level and
matches its filename. In edit views, a SwiftData `@Model` already supplies
observation; use `@Bindable` for bindings rather than wrapping the model in
`@State` as if it were value state.

For deletion, keep the `.nullify` relationship behavior and rely on Plan 004's
stored snapshot fallback. Surface save errors instead of dismissing
unconditionally.

**Verify**: Old UI type names have no matches; all views compile and tests pass.

### Step 5: Rename Account to Settings and split its toolbar button

Move and rename:

* `AccountView` → `SettingsView`
* `AccountViewButton` → `SettingsButton`
* `DebuggingView` → `DebugSettingsView`

Put `SettingsButton` in its own file. Update all toolbars. Keep the debug section
inside `#if DEBUG` unless there is a documented production support requirement.
Remove the empty help button from publisher status selection because it has no
action.

Apply `private` to local environment and state properties. Keep simple private
subviews in the same file when they are used only once.

**Verify**: Settings navigation reaches publisher status, category list, and
debug settings in Debug builds. Full tests pass.

## Test plan

* Migrate Plan 001 publisher and manager tests to new names before deleting old symbols.
* Add an in-memory integration test for category creation marked as default.
* Add a test for two pre-existing defaults being repaired to one by selecting a category.
* Do not test SwiftUI pixel output; mutation services and form validation provide the useful seams.

## Done criteria

* [ ] Settings and categories use the target feature-first layout.
* [ ] UI types use Category terminology and explicit top-level names.
* [ ] Persisted Tracker types and properties are unchanged.
* [ ] Default category mutations are centralized, throwing, and tested.
* [ ] Adding a default category cannot leave multiple defaults.
* [ ] SwiftData models passed into edit views are not incorrectly owned via `@State`.
* [ ] Empty-action controls and unused user-default keys are removed.
* [ ] Full tests pass.
* [ ] Plan 005 is marked DONE.

## STOP conditions

* A requested rename requires changing a persisted type or CloudKit record name.
* SwiftData does not observe `@Bindable` model changes as expected on iOS 26.
* Save error handling requires a product decision about retry/discard behavior.
* Existing users depend on Debug settings in Release and no requirement documents why.

## Maintenance notes

* “Category” is a UI/domain boundary term; persistence remains “Tracker” until a separately planned schema migration.
* New category mutations must route through the same invariant service when they affect default status.
* Avoid reviving a generic `Managers` folder; name services by the invariant or external system they own.
