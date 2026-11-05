# Plan 041: Seed the default category once per install and merge categories duplicated by sync

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 3f8d48b..HEAD -- Hugo/App Hugo/Domain/UserDefaultsKeys.swift Hugo/Features/Categories/DefaultCategoryDefinition.swift Hugo/Persistence`
> Only whitespace changes from plan 037 are expected under `Hugo/Persistence`.
> Any other change to an in-scope file is a mismatch: compare against the
> excerpts below and STOP if they differ.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/040-resolve-entry-category-in-one-place.md (uses `Entry.refreshStoredTracker()`)
- **Category**: bug
- **Planned at**: commit `3f8d48b`, 2026-10-12
- **Issue**: [SLN-168](https://linear.app/sebastianln/issue/SLN-168)

## Why this matters

On first launch Hugo creates a default "Field Service" category, unless CloudKit already holds the user's data. That check never works:

1. `CloudKitTrackerLookup` queries record type `CD_Tracker` in the private database's default zone. SwiftData's CloudKit sync (built on `NSPersistentCloudKitContainer`) stores every record in the custom zone `com.apple.coredata.cloudkit.zone`, so the query finds nothing. Every error is also turned into "nothing found".
2. The flag `hasRunInitialSetup` is written on every launch but never read. The original Oct 2025 code (commit `722c81e`, `AppInitializer.checkAndSeedIfNeeded`) returned early when the flag was set. The plan-008 refactor dropped that read.

As a result, every new device and every reinstall seeds another "Field Service". The copies share one fixed UUID (`DefaultCategoryDefinition.swift:14`) and all have `isDefault = true`, and sync spreads them to every device. A user who deletes all categories also gets "Field Service" back on the next launch. Nothing in the app merges duplicates: there is no dedupe code and no handler for CloudKit imports. Duplicates double the Overview category breakdown (rows are keyed by `tracker.id`) and give SwiftUI duplicate `ForEach` IDs in the category lists.

After this plan: the app seeds at most once per install, skips seeding when the user's synced data already exists, and merges categories that share an `id` whenever sync could have produced them.

## Current state

- `Hugo/App/AppBootstrapper.swift:16-46`:

  ```swift
  private(set) var state: State = .idle
  private(set) var errorMessage: String?
  private let lookup: any CloudTrackerLookup
  private let logger = Logger(subsystem: "com.ordellnielsen.Hugo", category: "Bootstrap")

  init(lookup: any CloudTrackerLookup = CloudKitTrackerLookup()) {
      self.lookup = lookup
  }

  func start(context: ModelContext) async {
      guard state != .checking else { return }
      state = .checking
      errorMessage = nil

      do {
          let descriptor = FetchDescriptor<Tracker>()
          if try context.fetch(descriptor).isEmpty {
              if try await lookup.hasAnyTracker() == false {
                  try seedDefaults(in: context)
              }
          }
          UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasRunInitialSetup)
          state = .ready
      } catch is CancellationError {
          state = .idle
      } catch {
          logger.error("Bootstrap failed: \(error.localizedDescription, privacy: .public)")
          errorMessage = error.localizedDescription
          state = .failed
      }
  }
  ```

  `seedDefaults(in:)` (lines 53-68) inserts one `Tracker` per `DefaultCategoryDefinition.all` and saves.

- `Hugo/App/CloudTrackerLookup.swift` (whole file):

  ```swift
  import CloudKit
  import Foundation

  protocol CloudTrackerLookup: Sendable {
      func hasAnyTracker() async throws -> Bool
  }

  struct CloudKitTrackerLookup: CloudTrackerLookup, Sendable {
      func hasAnyTracker() async throws -> Bool {
          // `CKContainer.default()` throws an *Objective-C* exception (not a
          // Swift error) when no iCloud account is present ... Never touch CloudKit from the test
          // runner; treat the cloud as empty there.
          if Self.isRunningTests { return false }

          let database = CKContainer.default().privateCloudDatabase
          let query = CKQuery(recordType: "CD_Tracker", predicate: NSPredicate(value: true))
          do {
              let (results, _) = try await database.records(matching: query)
              return results.contains { (_, result) in
                  if case .success = result { return true }
                  return false
              }
          } catch {
              // A signed-out or offline device must not break first-run seeding;
              // fall back to local defaults instead of failing the bootstrap.
              return false
          }
      }

      private static var isRunningTests: Bool { ... }
  }
  ```

- `Hugo/App/AppRootView.swift:35-47` (the only caller):

  ```swift
  var body: some View {
      Group {
          if isCompact {
              compactLayout
          } else {
              regularLayout
          }
      }
      .task { await bootstrapper.start(context: context) }
      .sheet(isPresented: $needsOnboarding) { OnboardingView { needsOnboarding = false } }
      .onChange(of: bootstrapper.errorMessage) { _, newValue in bootstrapErrorMessage = newValue }
      .errorAlert(message: $bootstrapErrorMessage, retry: { Task { await bootstrapper.retry(context: context) } })
  }
  ```

- `Hugo/Domain/UserDefaultsKeys.swift:2`: `static let hasRunInitialSetup = "hasRunInitialSetup"`.
- `Hugo/Features/Categories/DefaultCategoryDefinition.swift:12-22`: one definition, fixed `id` `A5B8A6FE-0DA4-4F7F-A9F3-2E2ACB5AA001`, `isDefault: true`.
- `Hugo/Persistence/SchemaVersions/V11/TrackerV11.swift`: `Tracker` has `id: UUID`, `name`, `type`, `isDefault`, `iconName`, `hue`, `sat`, `bri`, `createdAt: Date = Date()`, and `entries: [Entry]?` (inverse of `Entry.tracker`, delete rule `.nullify`). CloudKit sync forbids unique constraints, so two rows can share an `id`.
- After plan 040: `Entry.refreshStoredTracker()` exists in `Hugo/Features/Entries/EntryCategory.swift`. It copies the live tracker's name, icon and type into `entry.storedTracker`.
- Logging convention: `Logger(subsystem: "com.ordellnielsen.Hugo", category: "<Area>")` with `privacy: .public` only on error descriptions (see `ModelContainerFactory.swift:7,21`).
- Service convention: `@MainActor struct` taking a `ModelContext`. Exemplar: `Hugo/Features/Categories/DefaultCategoryService.swift`.
- Tests: Swift Testing; `InMemoryModelContainer.make()` plus `ModelContext(container)`; isolated defaults via `UserDefaults(suiteName: "<Suite>-\(UUID().uuidString)")!` (see `HugoTests/Features/Reports/SubmitReportFormModelTests.swift:38-41`). The directory `HugoTests/Features/Bootstrap/` exists and is empty.
- The operator has deferred any change to the CloudKit container configuration. Keep using `CKContainer.default()`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/AppBootstrapperTests -only-testing:HugoTests/SyncDeduplicatorTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:

- `Hugo/App/AppBootstrapper.swift`
- `Hugo/App/CloudTrackerLookup.swift`
- `Hugo/App/AppRootView.swift`
- `Hugo/Persistence/SyncDeduplicator.swift` (create)
- `HugoTests/Features/Bootstrap/AppBootstrapperTests.swift` (create)
- `HugoTests/Persistence/SyncDeduplicatorTests.swift` (create)
- `plans/README.md` (status row)

**Out of scope**:

- `Configuration/Hugo.entitlements`, the xcconfig files, and the container identifier. The operator deferred container configuration.
- Any `Hugo/Persistence/SchemaVersions/**` file or `HugoMigrationPlan.swift`. No schema change.
- Merging duplicate `SubmittedReport` rows or generated carry entries. That is plan 044, which extends `SyncDeduplicator`.
- Merging categories that have different `id`s but the same name. Old installs seeded with random UUIDs; merging by name could join two categories the user meant to keep apart.
- `DefaultCategoryService.swift`. Keep it unchanged.

## Git workflow

- Branch: `advisor/041-seed-once-merge-categories`
- Commit message style: short imperative sentence, for example `Seed default categories once per install`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Seed at most once per install

In `AppBootstrapper`:

1. Add `private let userDefaults: UserDefaults` and change the initializer to `init(lookup: any CloudTrackerLookup = CloudKitTrackerLookup(), userDefaults: UserDefaults = .standard)`.
2. Change the `do` block in `start(context:)` to:

   ```swift
   do {
       if !userDefaults.bool(forKey: UserDefaultsKeys.hasRunInitialSetup) {
           if try context.fetch(FetchDescriptor<Tracker>()).isEmpty,
               try await lookup.hasAnyTracker() == false
           {
               try seedDefaults(in: context)
           }
           userDefaults.set(true, forKey: UserDefaultsKeys.hasRunInitialSetup)
       }
       state = .ready
   }
   ```

   Keep both `catch` blocks unchanged. Existing users already have the flag set to `true` (it was written on every launch), so they skip the whole block.

**Verify**: `grep -n 'UserDefaults.standard' Hugo/App/AppBootstrapper.swift` → only the default argument in `init`.

### Step 2: Write bootstrap tests

Create `HugoTests/Features/Bootstrap/AppBootstrapperTests.swift`:

```swift
import Foundation
import SwiftData
import Testing

@testable import Hugo

private struct StubCloudLookup: CloudTrackerLookup {
    let hasData: Bool
    func hasAnyTracker() async throws -> Bool { hasData }
}

private struct FailingCloudLookup: CloudTrackerLookup {
    struct Unexpected: Error {}
    func hasAnyTracker() async throws -> Bool { throw Unexpected() }
}

@MainActor
struct AppBootstrapperTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "AppBootstrapperTests-\(UUID().uuidString)")!
    }
    // tests below
}
```

Tests (each makes its own in-memory container and `ModelContext`):

1. `seedsDefaultCategoryOnFirstLaunchWithoutCloudData`: `StubCloudLookup(hasData: false)`, empty store. After `await bootstrapper.start(context:)`: exactly one `Tracker`, its `id == DefaultCategoryDefinition.all[0].id`, `isDefault == true`, the defaults flag is `true`, and `bootstrapper.state == .ready`.
2. `doesNotSeedWhenCloudHasData`: `StubCloudLookup(hasData: true)`. Zero trackers, flag `true`, state `.ready`.
3. `neverSeedsOrAsksCloudAfterFirstLaunch`: set the flag to `true` first, empty store, `FailingCloudLookup()`. Zero trackers, state `.ready`. (If the lookup were consulted, the state would be `.failed`.)
4. `doesNotSeedWhenStoreAlreadyHasCategories`: insert and save one `Tracker(name: "Bethel")`, `StubCloudLookup(hasData: false)`. Still exactly one tracker.

**Verify**: focused-tests command → `** TEST SUCCEEDED **` for `AppBootstrapperTests` (4 tests).

Commit steps 1-2: `Seed default categories once per install`.

### Step 3: Check the zone SwiftData actually syncs to

In `CloudKitTrackerLookup.hasAnyTracker()`, keep the test-runner guard and replace the query with a zone lookup:

```swift
/// True when the user's private database already holds the zone that
/// SwiftData's CloudKit sync creates, meaning another device or an earlier
/// install has synced Hugo data that will arrive shortly.
func hasAnyTracker() async throws -> Bool {
    if Self.isRunningTests { return false }

    let database = CKContainer.default().privateCloudDatabase
    let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
    do {
        _ = try await database.recordZone(for: zoneID)
        return true
    } catch {
        // No zone (a new iCloud user), no account, or offline: seed locally.
        // SyncDeduplicator merges any copy that sync brings in later.
        return false
    }
}
```

Keep the existing comment about `CKContainer.default()` and the test runner.

**Verify**: `grep -n 'CKQuery\|CD_Tracker' Hugo/App/CloudTrackerLookup.swift` → no matches. Lint exits 0.

Commit: `Check the SwiftData CloudKit zone before seeding`.

### Step 4: Add the category merge

Create `Hugo/Persistence/SyncDeduplicator.swift`:

```swift
import Foundation
import OSLog
import SwiftData

/// Merges rows that CloudKit sync duplicated. CloudKit cannot enforce unique
/// values, so two devices that each created the same logical row (for example
/// the seeded default category) end up with two copies after sync.
///
/// Every device runs this independently, so each rule must pick the same
/// survivor on every device using synced attributes only.
@MainActor
struct SyncDeduplicator {
    private static let logger = Logger(subsystem: "com.ordellnielsen.Hugo", category: "Sync")
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Runs every merge and logs failures. Safe to call often.
    func run() {
        do {
            let removed = try mergeDuplicateCategories()
            if removed > 0 {
                Self.logger.info("Merged \(removed) duplicate categories")
            }
        } catch {
            Self.logger.error("Deduplication failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Returns the number of deleted duplicates.
    @discardableResult
    func mergeDuplicateCategories() throws -> Int { ... }
}
```

Implement `mergeDuplicateCategories()`:

1. Fetch all trackers: `try context.fetch(FetchDescriptor<Tracker>())`.
2. Group them by `id` (`Dictionary(grouping:by:)`). Skip groups with one member.
3. Sort each group with `survivorPrecedes(_:_:)` (below). If `survivorPrecedes(sorted[0], sorted[1])` is `false`, the first two are indistinguishable on every synced attribute. Skip the group, because two devices could each keep a different copy and together delete both.
4. The survivor is `sorted[0]`. For each other copy:
   - For each entry in `Array(loser.entries ?? [])`: set `entry.tracker = survivor` and call `entry.refreshStoredTracker()`.
   - If `loser.isDefault`, set `survivor.isDefault = true`.
   - `context.delete(loser)` and count it.
5. Among the remaining (non-deleted) trackers with `isDefault == true`, if there is more than one, keep `isDefault` only on the first by `survivorPrecedes` and set it to `false` on the rest.
6. If anything changed, `try context.save()`. Return the count.

Ordering helper (deterministic on every device, synced attributes only):

```swift
/// Earliest `createdAt` wins; ties fall back to the remaining synced fields.
private static func survivorPrecedes(_ a: Tracker, _ b: Tracker) -> Bool {
    if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
    if a.name != b.name { return a.name < b.name }
    if a.iconName != b.iconName { return a.iconName < b.iconName }
    if a.type.rawValue != b.type.rawValue { return a.type.rawValue < b.type.rawValue }
    if a.hue != b.hue { return a.hue < b.hue }
    if a.sat != b.sat { return a.sat < b.sat }
    return a.bri < b.bri
}
```

Earliest `createdAt` keeps the copy the user has had longest. That copy carries any rename the user made.

**Verify**: lint exits 0 and the project builds (focused-tests command compiles).

### Step 5: Write merge tests

Create `HugoTests/Persistence/SyncDeduplicatorTests.swift` (`@MainActor struct SyncDeduplicatorTests`, in-memory container). Set `createdAt` explicitly on each tracker, for example `Date(timeIntervalSince1970: 1_000)` and `2_000`. Tests:

1. `mergesCategoriesSharingAnID`: two `Tracker(id: sharedID, name: "Field Service", isDefault: true)` with createdAt 1 000 and 2 000, one entry on each. After `mergeDuplicateCategories()`: it returns 1, one tracker remains with createdAt 1 000, both entries point to it, and it is still the default.
2. `earliestCopyKeepsTheUsersRename`: earliest copy named "Tjeneste", later copy "Field Service", same id. The survivor is named "Tjeneste".
3. `movedEntriesGetFreshSnapshots`: after merging, each moved entry's `storedTracker?.name` equals the survivor's name.
4. `distinctCategoriesAreUntouched`: two trackers with different ids. Returns 0; both remain.
5. `indistinguishableCopiesAreKept`: same id and identical attributes including `createdAt`. Returns 0; both remain.
6. `onlyOneDefaultRemains`: two trackers with different ids, both `isDefault`. Afterwards exactly one has `isDefault == true`: the one with the earlier `createdAt`.
7. `isIdempotent`: run the setup of test 1, call `mergeDuplicateCategories()` twice. The second call returns 0.

**Verify**: focused-tests command → `** TEST SUCCEEDED **` (11 tests across both suites).

Commit steps 4-5: `Merge categories duplicated by CloudKit sync`.

### Step 6: Run the merge at launch, on foreground, and after each CloudKit import

In `AppRootView.swift`:

1. Add `import Combine` and `import CoreData` (the target enables `MemberImportVisibility`, so these imports are required for `NotificationCenter.publisher` and `NSPersistentCloudKitContainer`).
2. Add `@Environment(\.scenePhase) private var scenePhase`.
3. Change the `.task` to run the merge after bootstrap: `.task { await bootstrapper.start(context: context); SyncDeduplicator(context: context).run() }`.
4. Add:

   ```swift
   .onChange(of: scenePhase) { _, phase in
       if phase == .active { SyncDeduplicator(context: context).run() }
   }
   .onReceive(
       NotificationCenter.default
           .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
           .receive(on: RunLoop.main)
   ) { notification in
       guard
           let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
               as? NSPersistentCloudKitContainer.Event,
           event.type == .import, event.endDate != nil
       else { return }
       SyncDeduplicator(context: context).run()
   }
   ```

   Do not use `DispatchQueue`. AGENTS.md forbids it; `RunLoop.main` is the main-thread scheduler.

**Verify**: `Scripts/verify.sh` → exit 0.

Commit: `Merge sync duplicates at launch, on foreground and after imports`.

### Step 7 [owner]: Verify on devices

1. On a device signed into iCloud with existing Hugo data, delete the app, reinstall from Xcode, and launch. Expected: no second "Field Service" appears after sync finishes. Console (subsystem `com.ordellnielsen.Hugo`, category `Sync`) shows no merge, or a merge that leaves one copy.
2. On a device with two "Field Service" categories from earlier builds that share the fixed id, launch the new build. Expected: one remains after launch, and the Overview breakdown no longer doubles.
3. Background and foreground the app while another device adds an entry. Confirm the import notification reaches `onReceive` (add a temporary breakpoint; do not commit logging changes).

## Test plan

- `AppBootstrapperTests` (4 tests, Step 2): first launch seeds; cloud data prevents seeding; the flag prevents seeding and the cloud call; existing categories prevent seeding.
- `SyncDeduplicatorTests` (7 tests, Step 5): merge, rename survival, snapshot refresh, distinct rows, tie safety, single default, idempotence.
- The zone lookup itself cannot be unit-tested (CloudKit is skipped in the test runner). Step 7 covers it.

## Done criteria

- [ ] `grep -rn 'CKQuery' Hugo` prints nothing
- [ ] `grep -n 'hasRunInitialSetup' Hugo/App/AppBootstrapper.swift` shows both a read (`bool(forKey:`) and a write
- [ ] `grep -rn 'DispatchQueue' Hugo` prints nothing
- [ ] `Scripts/verify.sh` exits 0, with 11 more tests than before this plan
- [ ] `git status --porcelain` lists only files from the Scope list
- [ ] `plans/README.md` row for 041 updated (DONE, or DONE pending owner Step 7)

## STOP conditions

Stop and report back if:

- `Entry.refreshStoredTracker()` does not exist (plan 040 has not landed).
- The stub lookups in the test target fail to conform to `CloudTrackerLookup` because of actor isolation and marking the stubs `@MainActor` does not fix it. Report the compiler error.
- The `onReceive` block produces Swift 6 concurrency errors you cannot fix within two attempts. Then remove only the `onReceive` block (keep the launch and `scenePhase` triggers) and report.
- SwiftData rejects two `Tracker` rows with the same `id` in the in-memory test store. That would mean a uniqueness constraint exists that this plan did not expect.

## Maintenance notes

- Plan 044 extends `SyncDeduplicator.run()` with merges for duplicate monthly reports and generated carry entries. Keep `run()` as the single entry point that the app calls.
- Every merge rule must choose its survivor from synced attributes only, and must skip groups it cannot order. Choosing by store-local identity (for example `persistentModelID`) lets two devices keep different copies and delete both.
- Installs from before the fixed UUID (Oct 2025 code used `UUID()`) can still have two "Field Service" categories with different ids. Users can delete one by hand. Merging by name is deliberately not done.
- If the zone name changes in a future SwiftData release, seeding falls back to creating a copy, and the merge removes it after sync.
