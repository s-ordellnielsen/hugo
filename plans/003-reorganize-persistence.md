# Plan 003: Reorganize and harden SwiftData persistence

> **Executor instructions**: Treat persisted type names and migration stages as
> compatibility API. Move and simplify code only as specified, and run migration
> fixtures before changing migration behavior. Update `plans/README.md` after
> completion.
>
> **Drift check (run first)**:
> `git diff --stat c047d57..HEAD -- Hugo/Models Hugo/HugoApp.swift 'Hugo/Preview Content' HugoTests`
> Stop if a new schema version or migration stage has appeared.

## Status

* **Priority**: P1
* **Effort**: L
* **Risk**: HIGH
* **Depends on**: Plans 001 and 002
* **Category**: tech-debt / tests / correctness
* **Planned at**: commit `c047d57`, July 27, 2026

## Why this matters

Persistence is currently organized entity-first (`Models/Entry/Versions`,
`Models/Tracker/Versions`, `Models/Report/Versions`), which makes one schema
version difficult to inspect and encourages current UI code to share a folder
with migration-only types. The V7→V8 stage also constructs replacement entries
without inserting them, and no migration fixture would detect data loss. This
plan creates a version-first persistence boundary, removes only methods that are
provably irrelevant to stored shape, and establishes migration tests before
future feature renames.

## Current state

* `Hugo/Models/Schema.swift:11-81` declares `SchemaV1` through `SchemaV8`; `CurrentSchema` is V8.
* `Hugo/Models/Migration.swift:12-24` registers all eight schemas and migration stages.
* `Hugo/Models/Migration.swift:119-152` reads V7 reports, constructs `SchemaV7.Entry` values at lines 144-148, never calls `context.insert(entry)`, and then deletes each report.
* `Hugo/Models/Migration.swift:156-169` fills `storedTracker` after migration.
* `SchemaV8.Report` is empty but remains in `SchemaV8.models` after the report-to-entry transition.
* `ReportV3`–`ReportV7` contain 184–199 lines each, mostly unused report-generation methods. Their persisted properties and initializers are migration-relevant; the generation methods are not.
* `EntryV1`, `EntryV2`, and `EntryV2_1` contain migration-era `delete` and sample-data methods with no caller.
* `Hugo/Models/Schema.swift:87` exposes a current `Report` alias even though current feature code does not use it.

The schema chain must continue to use the exact nested names `SchemaV*.Entry`,
`SchemaV*.Tracker`, and `SchemaV*.Report`. File paths do not affect persistent
identity; type renames do.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan003DerivedData CODE_SIGNING_ALLOWED=NO` | Exit 0 and migration fixtures pass |
| Build | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project Hugo.xcodeproj -scheme Hugo -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/HugoPlan003Release CODE_SIGNING_ALLOWED=NO` | Exit 0 and `BUILD SUCCEEDED` |
| Schema inventory | `rg -n 'enum SchemaV\|static var versionIdentifier\|static var models' Hugo/Persistence` | Exactly V1, V2, V2_1, V3, V4, V5, V6, V7, V8 |

## Scope

**In scope**:

* All current files under `Hugo/Models/`.
* `Hugo/Persistence/` — create as replacement.
* `Hugo/Preview Content/SampleData.swift` → `Hugo/PreviewSupport/PreviewModelContainer.swift`.
* `Hugo/HugoApp.swift` only for renamed persistence symbols/import paths if required.
* `HugoTests/Persistence/SchemaMigrationTests.swift` — create.
* `HugoTests/TestSupport/TemporaryStore.swift` — create if useful.
* Existing tests whose paths/names must follow moved symbols.
* `plans/README.md` status update.

**Out of scope**:

* Renaming persisted `Tracker` to `Category`.
* Adding `SchemaV9` or deleting `SchemaV8.Report`.
* Changing CloudKit container identifiers or entitlements.
* Refactoring app bootstrap or CloudKit querying; Plan 008 owns it.
* Changing current `Entry` or `Tracker` persisted properties.

## Target layout

```text
Hugo/Persistence/
    AppSchema.swift
    HugoMigrationPlan.swift
    Legacy/
        LegacyReportTypes.swift
    SchemaVersions/
        V1/Entry.swift
        V2/Entry.swift
        V2/Tracker.swift
        V2_1/Entry.swift
        V2_1/Tracker.swift
        V3/Entry.swift
        V3/Tracker.swift
        V3/Report.swift
        ...
        V8/Entry.swift
        V8/Tracker.swift
        V8/Report.swift
Hugo/PreviewSupport/
    PreviewModelContainer.swift
```

Use version-first folders. Keep one persisted model per file because the older
report files remain substantial even after method removal. Avoid technical
subfolders named `Enums`, `Structs`, and `Versions`.

## Git workflow

* Branch: `advisor/003-reorganize-persistence`
* Commit in two logical units: migration tests/fix, then path-only persistence organization.
* Suggested messages: `Added SwiftData migration fixtures` and `Reorganized versioned persistence models`.

## Steps

### Step 1: Add migration fixture infrastructure before moving files

Create a temporary-directory helper that returns a unique SQLite store URL and
removes its directory during cleanup. Never write fixtures into the repository.
CloudKit must be disabled for tests.

Create at least these Swift Testing cases:

* V7 store with one tracker and one report containing two tracker summaries migrates to V8 with two entries and no V8 reports carrying old data.
* Migrated entries have the report's first-of-month date and expected durations.
* A migrated entry linked to a tracker has a non-`nil` `storedTracker` snapshot matching name, icon, and type.
* A V7 store with no reports migrates without creating entries.
* A current V8 in-memory store can insert, fetch, and delete a tracker while nullifying `Entry.tracker` and preserving `Entry.storedTracker`.

Create the source store using `Schema(versionedSchema: SchemaV7.self)` and open
the same URL with `CurrentSchema` plus `MigrationPlan.self`. Ensure all V7
contexts/containers are released before opening the V8 container.

**Verify**: Run only migration tests. The report-conversion test should fail
against the current missing insertion; all fixture setup must otherwise work.
If it does not fail for that reason, stop and inspect the actual store contents.

### Step 2: Correct the V7→V8 entry conversion

At the existing construction site, insert each constructed `SchemaV7.Entry`
into the migration context before deleting the report. Preserve the existing
stage direction and `didMigrate` snapshot fill. Replace force unwraps in the
snapshot fill with one `if let tracker = entry.tracker` binding.

Do not change report matching by tracker name in this plan unless a fixture
proves a separate defect; that would alter deployed migration semantics.

Replace migration `print` statements with one private `Logger` scoped to
`Hugo.Persistence` and category `Migration`. Do not log report contents or user
names.

**Verify**: All migration fixtures and the complete test suite pass.

### Step 3: Move schema files into the version-first hierarchy

Move every model file with `git mv` into the target layout. Rename
`Schema.swift` to `AppSchema.swift` and `Migration.swift` to
`HugoMigrationPlan.swift`; keep the Swift type names `CurrentSchema` and
`MigrationPlan` for now to minimize call-site churn.

Move `DailyPoint` and `TrackerSummary` into
`Persistence/Legacy/LegacyReportTypes.swift`. They remain required because
historical report schemas persist arrays of these Codable values.

Move preview support to `PreviewSupport/PreviewModelContainer.swift`. Do not
change its behavior yet beyond updated paths; Plan 008 makes fixture creation
deterministic.

**Verify**: Schema inventory shows all eight versions, Debug and Release builds
pass, and all tests pass.

### Step 4: Remove migration-only executable dead code without changing shape

From `SchemaV3.Report` through `SchemaV7.Report`, remove static report-generation
methods, `makePure`, and computed values that have no caller. Retain:

* every persisted property with its exact name and type
* `@Model`
* an initializer sufficient for migration fixtures and persisted-model creation

Delete `RoundingPolicy.swift` once its only callers are removed. Remove the
unused sample-data and convenience-delete methods from V1, V2, and V2_1 entries.
Do not remove model initializers used by a migration stage.

**Verify**:

* `rg -n 'makePure|RoundingPolicy|makeSampleData|public func delete' Hugo/Persistence` returns no matches.
* Migration fixtures and complete tests pass.

### Step 5: Clarify the current compatibility surface

Remove the top-level `typealias Report = CurrentSchema.Report` because no
current application code should treat reports as an active domain model. Keep
`SchemaV8.Report` in `SchemaV8.models` and add a short comment in
`AppSchema.swift` explaining that it remains migration compatibility ballast
until a tested future schema version removes it.

Keep `typealias Entry` and `typealias Tracker` unchanged for now; Plans 004–007
consume them.

**Verify**: `rg -n '\bReport\b' Hugo --glob '*.swift'` finds Report only inside
versioned persistence and migration code. Full tests pass.

## Test plan

* Migration tests must use disk-backed temporary stores; an in-memory store cannot prove reopening and migration.
* Assert resulting values, not merely that container construction succeeds.
* Include `#expect` counts before and after migration.
* Never use the production CloudKit container in tests.
* Keep Plan 001 characterization tests passing after every path move.

## Done criteria

* [ ] Persistence source is under `Hugo/Persistence` and organized by schema version.
* [ ] Every schema from V1 through V8 remains registered in the same order.
* [ ] V7 report conversion inserts and verifies replacement entries.
* [ ] Historical executable helpers with no migration use are removed.
* [ ] `RoundingPolicy` is removed; legacy serialized report value types remain.
* [ ] The active `Report` typealias is removed while `SchemaV8.Report` remains documented.
* [ ] Disk-backed migration fixtures pass.
* [ ] Debug tests and Release simulator build pass.
* [ ] Plan 003 is marked DONE.

## STOP conditions

* Opening a V7 fixture with the current container does not exercise the declared migration plan.
* A path move changes SwiftData's model identity or generated schema hash.
* Removing a historical method changes a persisted property, relationship, default, or model initializer required by migration.
* Migration tests reveal existing shipped data cannot be represented by V8.
* A fix appears to require SchemaV9 or CloudKit dashboard changes.

## Maintenance notes

* Never “clean up” historical model properties. Once shipped, they are compatibility definitions, not ordinary domain models.
* Future schema changes should add one `SchemaVersions/VN/` folder and a disk-backed fixture from the previous version.
* Reviewers should focus on migration counts, insertion/deletion ordering, and accidental type renames.
