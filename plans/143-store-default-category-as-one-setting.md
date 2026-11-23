# Plan 143: Store the default category as one synced setting

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 07d4c61..HEAD -- Hugo/App/AppBootstrapper.swift Hugo/Domain/UserDefaultsKeys.swift Hugo/Features/Settings/Domain/SyncedSettings.swift Hugo/Features/Categories Hugo/Features/Entries/State/AddEntryFormModel.swift Hugo/Features/Entries/Domain/CategoryTotals.swift Hugo/Features/Planner/State/PlanFormModel.swift Hugo/Persistence/SyncDeduplicator.swift`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). Never touch, stage or commit it.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MEDIUM. It changes where the default category lives and touches `SyncDeduplicator`, but the merge of duplicate categories is unchanged. A wrong migration would leave the user without a default until they pick one.
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `07d4c61`, 2026-11-23
- **Issue**: [SLN-324](https://linear.app/sebastianln/issue/SLN-324)

## Why this matters

The default category is `Tracker.isDefault`, a Bool on every category. Nothing
stops two rows from being true, especially after sync on two devices.
`DefaultCategoryService` clears the others and `SyncDeduplicator` has two
branches to repair it afterwards. One setting that holds the default
category's id cannot be set twice, and it syncs through the same iCloud
key-value path as the other settings. The name "Default category" stays in code
and in `CONTEXT.md`.

After this plan the id is stored under `UserDefaultsKeys.defaultCategoryID`
and listed in `SyncedSettings.keys`. When the id is unset or points at a
category that no longer exists, the first Field Service category is the
default. `Tracker.isDefault` stays in the shipped schemas (never edit a shipped
`VersionedSchema`, and no new schema version is added for this) but nothing
reads or writes it any more, except the one-time migration.

## Current state

`Hugo/Persistence/SchemaVersions/V11/TrackerV11.swift:20` has
`var isDefault: Bool = false`. This is the current schema. Leave it.

`Hugo/Features/Categories/Services/DefaultCategoryService.swift` (whole body):

```swift
func setDefault(_ tracker: Tracker?) throws {
    let defaults = try context.fetch(FetchDescriptor<Tracker>(predicate: #Predicate { $0.isDefault }))
    for category in defaults {
        category.isDefault = false
    }
    tracker?.isDefault = true
    try context.save()
}

func clearDefault() throws {
    try setDefault(nil)
}
```

`Hugo/Features/Categories/Domain/DefaultCategoryDefinition.swift` has `let isDefault: Bool`, set to `true` for the one seeded category (id `A5B8A6FE-0DA4-4F7F-A9F3-2E2ACB5AA001`).

`Hugo/App/AppBootstrapper.swift` (plan 041). `start(context:)` seeds once per
install, guarded by `UserDefaultsKeys.hasRunInitialSetup`, and `seedDefaults(in:)` calls
`Tracker(id: definition.id, name: ..., type: .main, isDefault: definition.isDefault, iconName: ...)`.
It already takes `userDefaults: UserDefaults = .standard`.

`Hugo/Persistence/SyncDeduplicator.swift`, `mergeDuplicateCategories()`:

```swift
                if loser.isDefault { survivor.isDefault = true }      // line 68
...
        let defaults =                                                // lines 76-83
            trackers
            .filter { !deletedIDs.contains($0.persistentModelID) && $0.isDefault }
            .sorted(by: Self.survivorPrecedes)
        for extra in defaults.dropFirst() {
            extra.isDefault = false
            changed = true
        }
```

and `private static func survivorPrecedes(_ a: Tracker, _ b: Tracker) -> Bool`
(line 273) orders by `createdAt`, `name`, `iconName`, `type.rawValue`,
`colorHue`, `colorTone`. All are synced attributes.

Readers of `isDefault`:

- `Hugo/Features/Categories/Views/DefaultCategoryButton.swift`: `tracker.isDefault` in the label symbol, `.foregroundStyle`, `.motion` value, `.accessibilityAddTraits`, and `setDefault(tracker.isDefault ? nil : tracker)`.
- `Hugo/Features/Categories/Screens/AddCategoryView.swift`: `@State private var isDefault = false` (line 15), `Toggle("tracker.options.use-as-default", isOn: $isDefault)` (69), `isDefault: false` in the `Tracker` init (104), `if isDefault { try DefaultCategoryService(context: context).setDefault(tracker) }` (111).
- `Hugo/Features/Categories/Screens/CategoryListView.swift:28`: `if tracker.isDefault { Image(systemName: "star.fill") ... }`.
- `Hugo/Features/Entries/State/AddEntryFormModel.swift:85-92` and `Hugo/Features/Planner/State/PlanFormModel.swift:38-45`: `reconcileSelection(with:)` ends with `?? trackers.first(where: \.isDefault) ?? trackers.first`.
- `Hugo/Features/Entries/Domain/CategoryTotals.swift`: `let defaultMain = candidates.first { $0.isDefault && $0.type == .main }` (line 29), and `liveCandidates` sorts `if $0.isDefault != $1.isDefault { return $0.isDefault }` (line 77). `rows(entries:trackers:locale:)` is called from `Hugo/Features/Overview/Screens/CarriedInBreakdownSheet.swift:14` and `Hugo/Features/Reports/Domain/MonthlyReportBuilder.swift:31` (`summaries(from:calendar:locale:trackers:)`, itself called from `ServiceMonth.swift:110`, `SubmitReportFormModel.swift:60`, `ReportPreviewFixtures.swift:15`).
- Previews: `Hugo/PreviewSupport/ReportPreviewFixtures.swift:6` and `PreviewModelContainer.swift:10` pass `isDefault: true`.

Settings sync. `Hugo/Features/Settings/Domain/SyncedSettings.swift` has
`static let keys: [String]` and a doc comment that says every other key stays
on the device. `SettingsSyncService` (`Hugo/Features/Settings/Services/`) pulls
and pushes exactly `SyncedSettings.keys`, so adding a key there is enough.
`AppRootView` calls `settingsSync?.start()` before `bootstrapper.start`, then
pushes on every `UserDefaults.didChangeNotification`. Important: `pushToCloud`
only sends keys that exist locally. Removing a key never syncs. To clear the
default so it syncs, store an empty string. The tests in
`HugoTests/Features/Settings/Services/SettingsSyncServiceTests.swift` pass
their own `keys` or check single keys (for example `theBufferSwitchesAreSyncedSettings`),
they do not enumerate all of `SyncedSettings.keys`. Add one test beside them.

Rules from `AGENTS.md` that apply: new files go in `Hugo/Features/Categories/Domain`
(value logic, no `ModelContext`) or `Services`; Swift Testing; `InMemoryModelContainer.make()`;
time and `UserDefaults` are initializer parameters; no catch-all folders; never
use `@Published` or `ObservableObject`; never edit a shipped schema. Do not
declare `@AppStorage` for the same key in a parent and a pushed child (it froze
the app before). Here the star button, the list and the forms are siblings, not
pushed settings pages, so one `@AppStorage` per view is fine. Pass the value down to
state and domain types as a parameter.

## Meaning of the stored value

`UserDefaultsKeys.defaultCategoryID` holds a `String`:

| Stored | Meaning |
|---|---|
| key absent | unset: use the first Field Service category |
| `""` | the user cleared it: no default |
| a UUID string of an existing category | that category |
| anything else (stale id, malformed) | use the first Field Service category |

"First Field Service category" is the category with `type == .main` that has the
oldest `createdAt`, ties broken by `id.uuidString`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Find leftovers | `grep -rn "isDefault" Hugo --include='*.swift' \| grep -v "Persistence/SchemaVersions"` | see Done criteria |

## Scope

**In scope**:

- `Hugo/Domain/UserDefaultsKeys.swift`
- `Hugo/Features/Settings/Domain/SyncedSettings.swift`
- `Hugo/Features/Categories/Domain/DefaultCategory.swift` (create)
- `Hugo/Features/Categories/Domain/DefaultCategoryDefinition.swift`
- `Hugo/Features/Categories/Services/DefaultCategoryService.swift`
- `Hugo/Features/Categories/Views/DefaultCategoryButton.swift`
- `Hugo/Features/Categories/Screens/AddCategoryView.swift`, `CategoryListView.swift`
- `Hugo/Features/Entries/State/AddEntryFormModel.swift`, `Hugo/Features/Entries/Screens/AddEntryView.swift`
- `Hugo/Features/Entries/Domain/CategoryTotals.swift`
- `Hugo/Features/Overview/Screens/CarriedInBreakdownSheet.swift`
- `Hugo/Features/Reports/Domain/MonthlyReportBuilder.swift` and its callers, only to pass the stored id
- `Hugo/Features/Planner/State/PlanFormModel.swift`, `Hugo/Features/Planner/Screens/PlanFormView.swift`
- `Hugo/App/AppBootstrapper.swift`
- `Hugo/Persistence/SyncDeduplicator.swift`
- `Hugo/PreviewSupport/ReportPreviewFixtures.swift`, `PreviewModelContainer.swift`
- the matching tests under `HugoTests/`
- `CONTEXT.md` (one sentence on the Default category term, see Step 8)

**Out of scope**:

- Any `SchemaVersions` file, `HugoMigrationPlan`, and `Tracker.isDefault` itself. No new schema version.
- The merge rules for duplicate categories other than the two `isDefault` branches.
- `SettingsSyncService` code (adding the key is enough).
- `Hugo/Resources/Localizable.xcstrings`. The existing string `tracker.options.use-as-default` stays.

## Git workflow

- Work on `main`. Commit per step. Conventional Commits, for example `refactor(categories): store the default category as one synced setting`.
- Do not push. Never stage `Hugo/Resources/Localizable.xcstrings`.

## Steps

### Step 1: Add the keys

In `UserDefaultsKeys` add:

```swift
/// The UUID string of the default category. "" means the user cleared it.
/// Synced. See `DefaultCategory`.
static let defaultCategoryID = "defaultCategoryID"

/// Whether this device has copied the old `Tracker.isDefault` row into
/// `defaultCategoryID`. Device-only.
static let hasMigratedDefaultCategory = "hasMigratedDefaultCategory"
```

Add `UserDefaultsKeys.defaultCategoryID` to `SyncedSettings.keys`. Update the
doc comment of `SyncedSettings` so the list of device-only keys also names the
migration flag.

**Verify**: `swift-format lint --strict Hugo/Domain/UserDefaultsKeys.swift Hugo/Features/Settings/Domain/SyncedSettings.swift` exits 0.

### Step 2: Add `DefaultCategory`

Create `Hugo/Features/Categories/Domain/DefaultCategory.swift`:

```swift
import Foundation

/// Decides which category is the default, from the stored id.
enum DefaultCategory {
    /// `storedID` is the raw value of `UserDefaultsKeys.defaultCategoryID`.
    static func resolve(storedID: String?, in categories: [Tracker]) -> Tracker? {
        if storedID == "" { return nil }
        if let storedID, let id = UUID(uuidString: storedID),
            let match = categories.first(where: { $0.id == id })
        {
            return match
        }
        return categories
            .filter { $0.type == .main }
            .min {
                if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
                return $0.id.uuidString < $1.id.uuidString
            }
    }
}
```

If `Tracker` is `@MainActor` by default isolation and the file does not compile
as written, mark the enum `@MainActor`. Do not use `nonisolated(unsafe)`.

**Verify**: build passes (`Scripts/verify.sh` is run at Step 9, a quick `swift-format lint --strict` on the file is enough here).

### Step 3: Rewrite `DefaultCategoryService`

It no longer needs a `ModelContext` for writes. Replace the body with:

```swift
struct DefaultCategoryService {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) { self.userDefaults = userDefaults }

    /// Makes `tracker` the default. `nil` clears the default.
    func setDefault(_ tracker: Tracker?) {
        userDefaults.set(tracker?.id.uuidString ?? "", forKey: UserDefaultsKeys.defaultCategoryID)
    }

    /// Runs once per device. Copies the old `isDefault` row into the setting
    /// unless the setting already has a value (for example from another device).
    func migrateLegacyDefault(context: ModelContext) throws {
        guard !userDefaults.bool(forKey: UserDefaultsKeys.hasMigratedDefaultCategory) else { return }
        if userDefaults.object(forKey: UserDefaultsKeys.defaultCategoryID) == nil {
            let legacy = try context.fetch(FetchDescriptor<Tracker>(predicate: #Predicate { $0.isDefault }))
            if let survivor = legacy.min(by: SyncDeduplicator.survivorPrecedes) {
                userDefaults.set(survivor.id.uuidString, forKey: UserDefaultsKeys.defaultCategoryID)
            }
        }
        userDefaults.set(true, forKey: UserDefaultsKeys.hasMigratedDefaultCategory)
    }
}
```

Keep `import SwiftData`. Remove `clearDefault()` (callers: only tests). In
`SyncDeduplicator.swift` change `private static func survivorPrecedes` to
`static func survivorPrecedes` (internal), and nothing else about it. This
reuses the rule that picks the same survivor on every device from synced
attributes.

Edge: on a brand-new device the CloudKit rows may not have arrived at the first launch. Then the migration
finds nothing and marks itself done, and the fallback (first Field Service
category) applies. That is accepted. The settings sync still delivers the
real value from another device that has already migrated.

**Verify**: `swift-format lint --strict Hugo/Features/Categories/Services/DefaultCategoryService.swift` exits 0.

### Step 4: Bootstrapper and seed

In `AppBootstrapper.swift`:

1. In `seedDefaults(in:)` remove `isDefault: definition.isDefault`. After `context.save()` add
   `if userDefaults.object(forKey: UserDefaultsKeys.defaultCategoryID) == nil { userDefaults.set(DefaultCategoryDefinition.all[0].id.uuidString, forKey: UserDefaultsKeys.defaultCategoryID) }`.
   (`DefaultCategoryDefinition.all` has one entry. Use the entry that was the default, which is `all[0]`.)
2. In `start(context:)`, after the `if !userDefaults.bool(forKey: UserDefaultsKeys.hasRunInitialSetup) { ... }` block and before `state = .ready`, add
   `try DefaultCategoryService(userDefaults: userDefaults).migrateLegacyDefault(context: context)`.
   The migration runs on every install and every upgrade, once, because of its own flag. Seeding keeps its own once-per-install guard.
3. In `DefaultCategoryDefinition.swift` delete `isDefault` from the struct and from the one instance.

**Verify**: `grep -n "isDefault" Hugo/App/AppBootstrapper.swift Hugo/Features/Categories/Domain/DefaultCategoryDefinition.swift` returns nothing.

### Step 5: Remove the `SyncDeduplicator` branches

In `mergeDuplicateCategories()` delete the line `if loser.isDefault { survivor.isDefault = true }`,
the whole `let defaults = ... for extra in defaults.dropFirst() { ... }` block,
and `deletedIDs` if nothing else uses it afterwards (check with a build). Leave the
rest of the function exactly as it is.

**Verify**: `grep -n "isDefault" Hugo/Persistence/SyncDeduplicator.swift` returns nothing.

### Step 6: Update the readers

Read the stored id with `@AppStorage(UserDefaultsKeys.defaultCategoryID) private var defaultCategoryID: String?` in views. Pass it down as a plain `String?` parameter.

- `DefaultCategoryButton`: add the `@AppStorage` above and `@Query private var trackers: [Tracker]` (to resolve a stale id). Define `private var isDefault: Bool { DefaultCategory.resolve(storedID: defaultCategoryID, in: trackers)?.id == tracker.id }`. Replace every `tracker.isDefault` with `isDefault`. Call `DefaultCategoryService().setDefault(isDefault ? nil : tracker)` (no `try`, so remove the `do/catch`, the `errorMessage` state and the `.errorAlert` if nothing else uses them). Keep `.accessibilityAddTraits(isDefault ? .isSelected : [])`. Leave the symbol and color exactly as they are (plan 144 changes the color).
- `AddCategoryView`: the toggle writes the setting after the category is saved. Replace line 111's body with `DefaultCategoryService().setDefault(tracker)` (drop the `try` if the surrounding `do` has no other throwing call; check). Remove `isDefault: false` from the `Tracker` init at line 104 only if the init default is `false` (it is, `Tracker(name:)` is used without it elsewhere).
- `CategoryListView`: add the `@AppStorage` and replace `tracker.isDefault` with `DefaultCategory.resolve(storedID: defaultCategoryID, in: trackers)?.id == tracker.id`. Compute that id once above the `List` (`let defaultID = ...`), not per row.
- `AddEntryFormModel.reconcileSelection(with:)` and `PlanFormModel.reconcileSelection(with:)`: add a parameter `defaultCategoryID: String?` and replace `trackers.first(where: \.isDefault)` with `DefaultCategory.resolve(storedID: defaultCategoryID, in: trackers)`. Update the two call sites in `AddEntryView.swift` (lines 87 and 89) and `PlanFormView.swift` (lines 96 and 98), where the view gets the value from `@AppStorage`. The `.onChange` handlers that pass `newTrackers` pass the same stored id.
- `CategoryTotals.rows(entries:trackers:locale:)`: add `defaultCategoryID: String? = nil` before `locale`. Compute `defaultMain` as `DefaultCategory.resolve(storedID: defaultCategoryID, in: candidates).flatMap { $0.type == .main ? $0 : nil }`. In `liveCandidates` add the same parameter and replace the `isDefault` comparison with `($0.id == defaultID) != ($1.id == defaultID)` returning `$0.id == defaultID`, where `defaultID` is the resolved default's id (compute it in `rows` and pass it as `UUID?`). Update the doc comment ("default first" stays true).
- Callers: `CarriedInBreakdownSheet` reads `@AppStorage` and passes it. `MonthlyReportBuilder.summaries` gets `defaultCategoryID: String? = nil` and passes it on. `ServiceMonth.swift:110` and `SubmitReportFormModel.swift:60` pass `UserDefaults.standard.string(forKey: UserDefaultsKeys.defaultCategoryID)` (a `UserDefaults` initializer parameter with that default if the type already takes one). If threading this needs more than these callers, STOP.
- Previews: remove `isDefault: true` from `ReportPreviewFixtures.swift:6` and `PreviewModelContainer.swift:10`. The first Field Service category is then the default.

**Verify**: `grep -rn "isDefault" Hugo --include='*.swift' | grep -v "Persistence/SchemaVersions"` shows only `Tracker.swift` or the model file that declares the property and its init (no readers), and `Scripts/verify.sh` compiles (tests may still fail until Step 7).

### Step 7: Tests

Swift Testing, `@MainActor struct`, mirror the source layout.

1. `HugoTests/Features/Categories/Domain/DefaultCategoryTests.swift` (create): storedID of an existing category returns it; `nil` returns the oldest `.main` category; a stale UUID returns the oldest `.main`; a malformed string returns the oldest `.main`; `""` returns `nil`; with only `.separate` categories and `nil`, returns `nil`.
2. Rewrite `HugoTests/Features/Categories/Services/DefaultCategoryServiceTests.swift`. Use `UserDefaults(suiteName: "DefaultCategoryServiceTests-\(UUID().uuidString)")!`. Tests: `setDefaultStoresTheId`; `setDefaultNilStoresAnEmptyString`; `migrationCopiesTheLegacyDefault` (one `Tracker(name: "A", isDefault: true)`, expect the key is its id string and `hasMigratedDefaultCategory` is true); `migrationPicksTheSurvivorWhenSeveralAreDefault` (two `isDefault: true` rows with different `createdAt`, expect the older one); `migrationKeepsAnExistingSetting` (key preset, rows flagged, expect the key unchanged); `migrationRunsOnce` (migrate, change the key, add a flagged row, migrate again, expect the key unchanged); `migrationWithoutLegacyRowsStillMarksDone`.
3. `HugoTests/App/AppBootstrapperTests.swift`: replace `#expect(trackers.first?.isDefault == true)` with `#expect(defaults.string(forKey: UserDefaultsKeys.defaultCategoryID) == DefaultCategoryDefinition.all[0].id.uuidString)`. Add a test that a launch with an existing flagged `Tracker` and no seeding (`hasRunInitialSetup` already true) migrates it.
4. `HugoTests/Persistence/SyncDeduplicatorTests.swift`: remove `isDefault` from `makeTracker`, remove `onlyOneDefaultRemains`, and drop the `isDefault == true` expectation at line 55 and the `isDefault: true` arguments at lines 35, 36.
5. `AddEntryFormModelTests.swift` (lines 131, 145, 161) and `PlanFormModelTests.swift` (lines 28, 42): replace `isDefault: true` with a call that passes `defaultCategoryID: tracker.id.uuidString` to `reconcileSelection`. Keep the assertions (selection prefers the default and keeps an existing selection; an unknown preferred category falls back to the default). Add one test per model: `defaultCategoryID: nil` selects the oldest Field Service category, and `""` selects `trackers.first`.
6. `CategoryTotalsTests.swift` (lines 52, 77) and `MonthlyReportBuilderTests.swift` (line 140): pass `defaultCategoryID: field.id.uuidString` instead of `isDefault: true`. Keep the assertions.
7. `HugoTests/Features/Settings/Services/SettingsSyncServiceTests.swift`: add `theDefaultCategoryIsASyncedSetting`, `#expect(SyncedSettings.keys.contains(UserDefaultsKeys.defaultCategoryID))`, and a `hasMigratedDefaultCategory` entry beside `deviceOnlySettingsNeverSync` (it must not sync).
8. `SchemaMigrationTests.swift` keeps its `isDefault: true` lines. They test shipped schemas. Do not change them.

**Verify**: `Scripts/verify.sh` exits 0.

### Step 8: Update `CONTEXT.md`

In the **Default category** entry add one sentence: "There is only one. The app stores its id as a synced setting, and when that id is unset or its category is gone, the first Field Service category is the default." Keep the entry's other words.

**Verify**: `git diff CONTEXT.md` shows only that sentence.

### Step 9: Final gate

Run `Scripts/verify.sh`.

**Verify**: exit 0.

## Test plan

- `DefaultCategoryTests`: stored, unset, stale, malformed, cleared, no Field Service category.
- `DefaultCategoryServiceTests`: set, clear, migration (single, several, existing value, once, none).
- `AppBootstrapperTests`: seed stores the key, upgrade migrates.
- Form model, `CategoryTotals` and `MonthlyReportBuilder` tests keep their intent with the id passed in.
- `SettingsSyncServiceTests`: new key syncs, migration flag does not.
- `SyncDeduplicatorTests` still pass without the default branches.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -rn "isDefault" Hugo --include='*.swift' | grep -v "Persistence/SchemaVersions"` shows no reader. Only the `Tracker` model declaration and its init parameter remain
- [ ] `grep -n "defaultCategoryID" Hugo/Features/Settings/Domain/SyncedSettings.swift` has one match
- [ ] No file under `Hugo/Persistence/SchemaVersions` changed, and `HugoMigrationPlan` is unchanged
- [ ] `git status --short` shows only in-scope files (plus the owner's `Localizable.xcstrings`, unstaged)
- [ ] `plans/README.md` row updated

Owner check on two devices on one iCloud account, both with this build: set
the default on device A, and confirm device B shows the same star within a
minute. Set it on B, then on A, and confirm the last writer wins on both. On a
device that had a default before the update, confirm the same category is
still the default after the first launch. Clear the default (tap the filled
star) and confirm new entries start with no category preselected on both
devices.

## STOP conditions

Stop and report if:

- A file in "Current state" no longer matches.
- Any change to a `VersionedSchema` or `HugoMigrationPlan` seems needed.
- `@AppStorage` with `String?` does not compile or does not refresh the view after `DefaultCategoryService` writes (then switch the views to a non-optional `String` with a documented unset marker and ask first).
- Passing the stored id into `MonthlyReportBuilder` needs changes outside the files listed in Scope.
- A `SyncDeduplicatorTests` test about merging categories (not about `isDefault`) fails.

## Maintenance notes

- Older app versions still write `Tracker.isDefault` and read it. During a mixed-version rollout the two stores can disagree. Once every build reads the setting, a later plan can stop declaring the property, in a new schema version.
- `pushToCloud` never sends a removed key, so always store `""` to clear. Do not call `removeObject` on `defaultCategoryID`.
- `DefaultCategory.resolve` is the only place that knows the fallback rule. New readers call it instead of comparing ids.
- Two devices that set different defaults at nearly the same time end with whichever write iCloud applies last. This is accepted.
