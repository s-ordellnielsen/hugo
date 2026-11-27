# Plan 174: Move the SwiftData store into an App Group container, copy first, delete later

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 5bdce20..HEAD -- Hugo/Persistence Hugo/App Configuration Hugo/Info.plist HugoTests/Persistence HugoTests/TestSupport`
> Expected: no output. Any output: compare the "Current state" excerpts with
> the live code and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). This plan adds no strings. Never stage that file.

## Status

- **Priority**: P2
- **Effort**: L + owner
- **Risk**: HIGH. A mistake can hide or lose the user's data. Every design choice below favors keeping the old store.
- **Depends on**: none
- **Category**: migration
- **Planned at**: commit `5bdce20`, 2026-11-27
- **Issue**: [SLN-350](https://linear.app/sebastianln/issue/SLN-350)

**Tier**: Large, because it changes where the CloudKit-mirrored SwiftData store lives and adds an entitlement (AGENTS.md section 9).

## Why this matters

A future widget extension can only read Hugo's data if the store sits in an App
Group container. Hugo is in beta with about ten testers, so moving the store now
is cheap. Doing it after the public release would put every user's data at risk.
This plan is ONLY the move. No widget target, no widget code, no schema change
(no new `VersionedSchema`, no CloudKit schema change, models untouched). It
ships to TestFlight before any widget work.

Decisions already made with the owner (do not reopen):

- Copy first, never move. Copy the SQLite store with its `-wal` and `-shm` companions, verify it, and leave the old store in place. Delete the old store only on a LATER launch, after that launch confirmed the new store opened and works.
- If the copy fails, the app keeps using the old location and must not crash.
- CloudKit mirroring stays on, same container as today.
- `ModelContainerLoader` keeps never deleting anything and keeps showing `StoreLoadFailureView` on failure.
- `SyncDeduplicator` must not be relied on to clean up migration mistakes.
- A future widget will open the store read-only with CloudKit off. That is out of scope. Do not make location or configuration choices that would block it.

## Current state

- `Hugo/Persistence/ModelContainerFactory.swift` is the only place that creates the production container. It uses a default `ModelConfiguration` with no URL, so the store sits at SwiftData's default location (`Application Support/default.store`):

```swift
static func makeProductionContainer() throws -> ModelContainer {
    let schema = Schema(versionedSchema: CurrentSchema.self)
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    return try ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: [configuration])
}
```

- `Hugo/App/HugoApp.swift` calls `ModelContainerFactory.makeProductionContainer()` from `ModelContainerLoader`. Tests and previews use `makeInMemoryContainer()` and never touch the production path. Leave `HugoApp.swift` unchanged.
- `Hugo/App/ModelContainerLoader.swift` turns a thrown error into `.failed` and `retry()` calls the factory again. Unchanged by this plan.
- Launch order today: `HugoApp` creates `ModelContainerLoader`, which calls the factory (container opens). Only when the state is `.loaded` does `AppRootView` run its `.task`: `settingsSync.start()`, then `AppBootstrapper.start(context:)`, then `deduplication.request(context:)`.
- `AppBootstrapper.start` seeds the Default category only when `hasRunInitialSetup` is false, `context.fetch(FetchDescriptor<Tracker>())` is empty AND `CloudKitTrackerLookup.hasAnyTracker()` is false. `hasRunInitialSetup` lives in `UserDefaults.standard` and is not moved by this plan.
- `Configuration/Hugo.entitlements` has the iCloud container `iCloud.com.ordellnielsen.Hugo`, CloudKit, push and the key-value store. It has no App Group. The entitlements file is already wired to the app target (`CODE_SIGN_ENTITLEMENTS = Configuration/Hugo.entitlements`), so no `project.pbxproj` edit is needed.
- `Hugo/Info.plist` is merged with generated keys (`GENERATE_INFOPLIST_FILE = YES`) and already uses build settings (`$(SUPPORT_EMAIL)`).
- `Configuration/Debug.xcconfig`, `TestFlight.xcconfig`, `Production.xcconfig` set per-build values (for example `BUNDLE_IDENTIFIER`). Debug uses the bundle ID `com.ordellnielsen.Hugo.dev`, TestFlight and Production share the App Store bundle ID.
- Test helpers: `HugoTests/TestSupport/TemporaryStore.swift` (a temp directory plus `storeURL`, `remove()`), `InMemoryModelContainer.make()`. A pattern for opening a SwiftData store at a URL in a test is `corruptStoreFileFailsToOpenInsteadOfCrashing` in `HugoTests/App/ModelContainerLoaderTests.swift`. A pattern for a stub `CloudTrackerLookup` is `StubCloudLookup` in `HugoTests/App/AppBootstrapperTests.swift` (it is `private`, so copy it into the new test file).
- Project settings: Swift 6 strict concurrency and MainActor default isolation are intentional. New types are `@MainActor` by default, which is fine here. Use 4-space indentation.
- AGENTS.md section 8: types that depend on time or the filesystem take their dependencies as initializer parameters with production defaults.

## Design

Two new files in `Hugo/Persistence/` (flat folder, no role folders there):

1. `StoreCopier.swift`: a protocol `StoreCopying` and the production type `FileStoreCopier`.
   - `func copyStore(from source: URL, to destination: URL) throws` copies, when they exist: the store file, `<store>-wal`, `<store>-shm`, and the hidden support directory `.<storename without extension>_SUPPORT` (for `default.store` that is `.default_SUPPORT`). Use `FileManager.copyItem`. A missing companion is not an error. A missing main store file is.
   - `func verifyCopy(of source: URL, at destination: URL) throws` checks that each file that exists at the source exists at the destination with the same byte size and the same SHA-256 (CryptoKit, read in 1 MB chunks through `FileHandle`). A missing or different file throws.
2. `StoreRelocator.swift`: decides where the store lives.

```swift
struct StoreRelocator {
    enum Location: Equatable { case legacy, appGroup }

    struct Resolution: Equatable {
        var storeURL: URL        // the URL to open
        var location: Location
        var isFreshCopy: Bool    // copied and verified in THIS launch
        var legacyCleanupPending: Bool  // marker said "copied" at launch start
    }

    init(
        legacyStoreURL: URL,
        groupDirectory: URL?,    // nil when the App Group is unavailable
        copier: any StoreCopying = FileStoreCopier(),
        fileManager: FileManager = .default
    )

    func resolve() -> Resolution
    func markCopied()            // writes the marker file "copied"
    func abandonCopy()           // removes the new store files and the marker
    func confirmAndDeleteLegacyStore()   // deletes legacy files, marker becomes "confirmed"

    static func productionGroupDirectory(bundle: Bundle = .main, fileManager: FileManager = .default) -> URL?
    static func productionLegacyStoreURL() -> URL
}
```

- The new store is `<groupDirectory>/default.store` (same file name, so the support directory name stays the same). `groupDirectory` is `containerURL(forSecurityApplicationGroupIdentifier:)` plus `Library/Application Support`, created if missing. The identifier comes from the Info.plist key `HugoAppGroupIdentifier`. Return nil when the key is empty, the container is nil or the directory cannot be created.
- `productionLegacyStoreURL()` returns `ModelConfiguration(schema: Schema(versionedSchema: CurrentSchema.self), isStoredInMemoryOnly: false).url`. Do not hardcode the path. This is what SwiftData uses today, so it is the true legacy path.
- The marker is a small file `store-move-state` in `groupDirectory` whose text is `copied` or `confirmed`. **The marker is the only authority for "the app group store is the real store".** Files in the group directory without a marker are never trusted.

`resolve()` rules, in order:

1. `groupDirectory == nil` (or any `FileManager` call in this method throws): return `.legacy` at `legacyStoreURL`. Touch nothing.
2. Marker is `confirmed`: return `.appGroup`, `isFreshCopy` false, `legacyCleanupPending` false.
3. Marker is `copied`: if the new store file exists, return `.appGroup` with `legacyCleanupPending` true. If it is missing: remove the marker and continue with rule 4 as if there were no marker.
4. No marker and the legacy store file exists: remove any stray files at the new location (`abandonCopy`), then `copyStore` and `verifyCopy`. Success returns `.appGroup` with `isFreshCopy` true. Any thrown error: run `abandonCopy()` and return `.legacy`. Never leave a partial copy, never throw out of `resolve()`.
5. No marker and no legacy store file (a fresh install, or both deleted): return `.appGroup`, `isFreshCopy` false, `legacyCleanupPending` false. Nothing is copied.

`ModelContainerFactory.makeProductionContainer` changes to take its dependencies and follow this flow (`relocator` default is built from the two `production…` functions; add `cloudKitDatabase: ModelConfiguration.CloudKitDatabase = .automatic` so tests can pass `.none`):

```
let resolution = relocator.resolve()
open(resolution.storeURL)                      // helper that builds the ModelConfiguration with url:
if resolution.location == .legacy -> return it // nothing else to do
probe: ModelContext(container).fetchCount(FetchDescriptor<Tracker>()) must not throw
if probe or open throws:
    if resolution.isFreshCopy:                 // first launch only
        relocator.abandonCopy()
        return try open(legacyStoreURL)        // if this throws too, throw that error
    else: throw the error                      // StoreLoadFailureView; never fall back to a stale legacy store
if resolution.isFreshCopy: relocator.markCopied()
else if resolution.legacyCleanupPending: relocator.confirmAndDeleteLegacyStore()
return container
```

Why: the copy is trusted only after it is byte-identical AND the real container (CloudKit on) opened and answered a fetch. The marker is written last. An interrupted launch leaves no marker, so the next launch copies again from the intact legacy store. The legacy files are deleted only in a launch that started with marker `copied`, so never in the launch that made the copy. In `copied`/`confirmed` states a failed open is a real fault and goes to `StoreLoadFailureView`, because falling back would show stale data and invite a second seed.

**Required launch order** (all of it already holds, because `AppRootView.task` starts only after the loader is `.loaded`; do not change `AppBootstrapper`, `AppRootView` or `CloudKitTrackerLookup`):

1. `ModelContainerLoader` calls the factory.
2. Factory: locate legacy store and marker, copy and verify if needed, open the container, probe it, write the marker or delete the legacy store.
3. Loader state `.loaded`; `AppRootView` runs `AppBootstrapper.start` (seeding), then deduplication.

Because step 2 puts the copied rows in the container before step 3, the seed check `Tracker` fetch is non-empty and no Default category is added. When the copy fails, step 2 returns the legacy container with its rows, so seeding is skipped for the same reason.

Not blocking a widget: the file name, the marker and the CloudKit setting are chosen so a read-only, CloudKit-off `ModelConfiguration(url:)` at the same URL works later. Files in the group container get the default protection class (available after first unlock), which a widget can read. Do not set a stricter class.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| One suite | `Scripts/test-quick.sh HugoTests/StoreRelocatorTests` | suite passes |
| Resolved build settings | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Hugo.xcodeproj -scheme Debug -configuration Debug -showBuildSettings \| grep -E "^\s*(APP_GROUP_IDENTIFIER\|PRODUCT_BUNDLE_IDENTIFIER) ="` | one line per setting |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:
- `Hugo/Persistence/StoreCopier.swift` (create)
- `Hugo/Persistence/StoreRelocator.swift` (create)
- `Hugo/Persistence/ModelContainerFactory.swift`
- `Configuration/Hugo.entitlements`, `Configuration/Debug.xcconfig`, `Configuration/TestFlight.xcconfig`, `Configuration/Production.xcconfig`, `Hugo/Info.plist`
- `HugoTests/Persistence/StoreRelocatorTests.swift` (create), `HugoTests/Persistence/ModelContainerFactoryTests.swift` (create)
- `CODEMAP.md`, `README.md` (one sentence under "Builds"), `plans/README.md`

**Out of scope** (do NOT touch):
- Any `VersionedSchema`, model, `HugoMigrationPlan`, `SyncDeduplicator`.
- `AppBootstrapper`, `CloudTrackerLookup`, `AppRootView`, `HugoApp`, `ModelContainerLoader`, `StoreLoadFailureView`.
- A widget target, App Group `UserDefaults`, moving `hasRunInitialSetup` or other settings.
- `Hugo.xcodeproj/project.pbxproj`, `CONTEXT.md` (a storage location is not a domain term).
- Any in-app banner or new string.

## Git workflow

- Work on `main`. Commit per step or logical unit with Conventional Commits, for example `feat(persistence): copy the store into an App Group container`. Do not push.
- Never stage `Hugo/Resources/Localizable.xcstrings`.

## Steps

### Step 1: App Group build settings and entitlement

- In each of `Debug.xcconfig`, `TestFlight.xcconfig`, `Production.xcconfig` add the line `APP_GROUP_IDENTIFIER = group.$(PRODUCT_BUNDLE_IDENTIFIER)`. This gives the Debug build its own group, so a dev build never shares a store with the beta install.
- In `Configuration/Hugo.entitlements` add:

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>$(APP_GROUP_IDENTIFIER)</string>
</array>
```

- In `Hugo/Info.plist` add key `HugoAppGroupIdentifier` with string `$(APP_GROUP_IDENTIFIER)`.
- Add one sentence to the "Builds" section of `README.md`: each build has its own App Group named `group.` plus its bundle ID, and the store lives in it.

**Verify**: run the "Resolved build settings" command for the Debug scheme, then again with `-scheme TestFlight -configuration TestFlight`. Expected: `APP_GROUP_IDENTIFIER` equals `group.` plus the printed `PRODUCT_BUNDLE_IDENTIFIER` in both. Write both resolved values into your final report (the owner registers them in the developer portal). If `APP_GROUP_IDENTIFIER` prints empty, STOP.

### Step 2: `StoreCopier.swift`

Create `StoreCopying` and `FileStoreCopier` as designed above. Keep it under about 90 lines.

**Verify**: `Scripts/verify.sh` is not needed yet; build via `Scripts/test-quick.sh HugoTests/ModelContainerLoaderTests` → passes (proves the module still compiles).

### Step 3: `StoreRelocator.swift`

Create `StoreRelocator` with the exact API and `resolve()` rules above. Log with `Logger(subsystem: "com.ordellnielsen.Hugo", category: "Persistence")` (see `ModelContainerFactory`) when a copy fails or is abandoned. Never throw out of `resolve()`, `abandonCopy()` or `confirmAndDeleteLegacyStore()`: they use `try?` and log. `confirmAndDeleteLegacyStore()` removes the legacy store, its `-wal`, `-shm` and support directory, then writes `confirmed`. Write the marker atomically (`Data.write(to:options: .atomic)`).

**Verify**: `Scripts/test-quick.sh HugoTests/ModelContainerLoaderTests` → passes.

### Step 4: Wire `ModelContainerFactory`

Change `makeProductionContainer` to the flow in "Design". Signature:

```swift
static func makeProductionContainer(
    relocator: StoreRelocator = StoreRelocator(
        legacyStoreURL: StoreRelocator.productionLegacyStoreURL(),
        groupDirectory: StoreRelocator.productionGroupDirectory()),
    cloudKitDatabase: ModelConfiguration.CloudKitDatabase = .automatic
) throws -> ModelContainer
```

The relocator needs to expose its `legacyStoreURL` (make it a `let`). Use `ModelConfiguration(schema: schema, url: url, cloudKitDatabase: cloudKitDatabase)` when opening. `HugoApp.swift` still compiles unchanged.

**Verify**: `Scripts/test-quick.sh HugoTests/ModelContainerLoaderTests` → passes.

### Step 5: Tests

Create `HugoTests/Persistence/StoreRelocatorTests.swift` and `ModelContainerFactoryTests.swift` (Swift Testing, `@MainActor`, `TemporaryStore` for directories; make a second temp directory as the fake App Group; always `defer { remove() }`). Build real legacy stores by opening SwiftData at `legacyStoreURL` with `cloudKitDatabase: .none`, inserting rows, then letting the container go out of scope. Cases:

`StoreRelocatorTests`:
1. Copy succeeds: legacy store with rows, no marker. `resolve()` returns `.appGroup`, `isFreshCopy` true, the new store file exists, and opening it with `cloudKitDatabase: .none` returns the same row counts as the legacy store. Legacy files are still present.
2. Missing `-wal` and `-shm`: copy succeeds with only the main file. With fake companion bytes written next to a fake legacy file, they are copied too (use a fake copier-level test with plain byte files for this one).
3. Interrupted copy: a stub `StoreCopying` that writes the main file at the destination and then throws. `resolve()` returns `.legacy` with `legacyStoreURL`, the new location has no files and no marker, the legacy store still opens with its rows.
4. Corrupt copy: a stub whose `verifyCopy` throws. Same expectations as case 3.
5. Unavailable App Group (`groupDirectory == nil`): `.legacy`, nothing created. Unwritable group directory (a path under a regular file, so directory creation fails): `.legacy`, legacy untouched.
6. Second launch after a successful move: after `markCopied()`, a new relocator with the same URLs returns `.appGroup`, `isFreshCopy` false, `legacyCleanupPending` true, and does not copy again (a counting stub copier is not called).
7. Deletion only after a confirmed later launch: after the first `resolve()` and `markCopied()` the legacy files still exist. Only `confirmAndDeleteLegacyStore()` removes them, and a third relocator then reports `legacyCleanupPending` false.
8. Marker `copied` but the new store file was deleted, legacy still present: the next `resolve()` copies again.
9. Fresh install (no legacy, no marker): `.appGroup`, nothing copied, `isFreshCopy` false.

`ModelContainerFactoryTests` (pass `cloudKitDatabase: .none`):
10. First launch with data: container opens at the app group URL and holds the legacy rows; the marker says `copied`; legacy files still exist.
11. Second launch: marker `copied` at start, so the legacy files are deleted after the container opened; the rows are still there.
12. A new store at the group location that fails to open (write the text "not a database" over it after a marker of `copied`): `makeProductionContainer` throws and legacy files are NOT used or deleted.
13. First-launch copy that opens badly (stub copier that produces a garbage destination but a passing verify): the factory returns the legacy container with its rows, and `abandonCopy` removed the new files.
14. No seeding: legacy store holds one `Tracker` with the Default category id. After the factory returns (case 10) run `AppBootstrapper(lookup: <stub, hasData: false>, userDefaults: <fresh suite>)` `.start(context:)`: the `Tracker` count stays 1. Repeat with an unavailable group (legacy fallback): count stays 1.

Model the factory and bootstrapper tests on `ModelContainerLoaderTests` and `AppBootstrapperTests`.

**Verify**: `Scripts/test-quick.sh HugoTests/StoreRelocatorTests HugoTests/ModelContainerFactoryTests` → all pass.

### Step 6: Docs

- `CODEMAP.md`, Persistence section: add `StoreRelocator` (decides legacy vs App Group store, copies, marker file) and `StoreCopier` (`StoreCopying`, `FileStoreCopier`) to the "Container creation" line, and add `StoreRelocatorTests`, `ModelContainerFactoryTests` to the tests line. Add a row to the task table: "Change where the store lives" → `Hugo/Persistence/StoreRelocator.swift`, `Hugo/Persistence/ModelContainerFactory.swift`.
- `plans/README.md`: add the row below to the table after plan 173, and keep the status `TODO` until done.

`| 174 | Move the SwiftData store into an App Group container | P2 | L + owner | — | TODO | [SLN-350](https://linear.app/sebastianln/issue/SLN-350) |`

**Verify**: `grep -n "StoreRelocator" CODEMAP.md plans/README.md` → matches in `CODEMAP.md`; the plan row exists.

### Step 7: Full gate

**Verify**: `Scripts/verify.sh` → exit 0. Then `git status --short` shows only in-scope files (and the owner's `Localizable.xcstrings`, unstaged).

## Owner steps and checks (after the executor is done, not for the executor)

Before any build is installed:

1. **Developer portal**: register two App Groups (Certificates, Identifiers & Profiles, Identifiers, App Groups) with the exact two values the executor reported in step 1 (Debug and TestFlight/Production), and add the App Groups capability to the matching App IDs. With automatic signing, Xcode can do this when you open the target's Signing & Capabilities tab and are signed in with a team role that may create identifiers. The App Store distribution profile then regenerates when you archive.
2. **Backup**: in Xcode, Window, Devices and Simulators, select the iPhone (Mona), choose Hugo, "Download Container", and save it. Repeat on the iPad (Sean). Keep both until the legacy store has been deleted and the app has been used for some weeks.
3. **Simulator rehearsal**: install the old build in a signed Simulator, replace its container with a downloaded real container (Download Container, then Replace Container in the same window), install this build over it and launch twice. Check that entries, reports and plans are intact after the first launch, and after the second launch that the old `default.store` is gone from the app's Application Support folder and the data is still there.
4. **Devices**: install over the existing build on both devices. Check entries, reports, plans and the Settings sync status. Check again after a second launch.
5. Use it for a few days on both devices before sending it to TestFlight.
6. **Tester message** (plain message, not an in-app banner), to send with the TestFlight build:

> Hi, the next Hugo beta changes where the app keeps its data on your device. You do not need to do anything, and nothing is deleted. Before you update, please open Settings in Hugo and check that iCloud sync is on, so your data also has a copy in iCloud. After updating, open Hugo and check that your entries, reports and plans are all still there. If anything looks missing, please do not delete the app. Message me first and I will help you.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `Scripts/test-quick.sh HugoTests/StoreRelocatorTests HugoTests/ModelContainerFactoryTests` passes with 14 new tests (cases 1 to 14)
- [ ] `grep -n "application-groups" Configuration/Hugo.entitlements` matches, and `grep -n "HugoAppGroupIdentifier" Hugo/Info.plist` matches
- [ ] `grep -rn "APP_GROUP_IDENTIFIER" Configuration` shows all three xcconfig files
- [ ] `git diff --stat 5bdce20..HEAD -- Hugo/App Hugo/Persistence/SchemaVersions Hugo/Persistence/AppSchema.swift Hugo/Persistence/HugoMigrationPlan.swift Hugo/Persistence/SyncDeduplicator.swift` prints nothing
- [ ] No file outside the in-scope list is modified (`git status`)
- [ ] `plans/README.md` status row updated (DONE with the owner checks pending)

## STOP conditions

Stop and report (do not improvise) if:

- The drift check shows changes, or `makeProductionContainer` differs from the excerpt.
- `APP_GROUP_IDENTIFIER` resolves empty or the Debug and TestFlight values are identical.
- A SwiftData store at a `url:` inside a test cannot be opened with `cloudKitDatabase: .none` (then the test design needs rethinking).
- A step's verification fails twice after a reasonable fix attempt.
- You would need to edit a schema, a model, `AppBootstrapper` or any out-of-scope file.
- You find code that deletes, recreates or resets the store on failure. That must stay absent.

## Maintenance notes

- The widget plan must add its own target with the same App Group value (its bundle ID differs, so set `APP_GROUP_IDENTIFIER` explicitly there instead of deriving it) and open `<group>/Library/Application Support/default.store` read-only with `cloudKitDatabase: .none`.
- A reviewer should check that `confirmAndDeleteLegacyStore` can only run in a launch whose marker was already `copied` when `resolve()` started, and that no path falls back to the legacy store once the marker exists.
- Deferred: removing the `copied` versus `confirmed` states and the legacy cleanup code in a later release, once every tester has moved.
- Known limit: edits made between the first and second launch exist only in the new store. This is intended; the old store is stale after the first launch.
