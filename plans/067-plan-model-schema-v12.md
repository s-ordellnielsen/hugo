# Plan 067: Add a synced `Plan` model in schema V12

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 2e8a451..HEAD -- Hugo/Persistence Hugo/Features/Categories/Services/CategoryDeletionService.swift HugoTests/Persistence/SchemaMigrationTests.swift HugoTests/Features/Categories/Services/CategoryDeletionServiceTests.swift CONTEXT.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding. On a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1 (first of the Planner plans 067-072)
- **Effort**: S
- **Risk**: MED (schema change on a CloudKit-synced store; needs an owner CloudKit deploy before release)
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `2e8a451`, 2026-11-04
- **Issue**: [SLN-270](https://linear.app/sebastianln/issue/SLN-270)

## Why this matters

Hugo is getting a Planner: a new tab where the user plans how much time they
want to spend in service on each day of a month and compares the plan with
the time they actually log. Plans must sync between the user's devices like
entries do, so they need their own SwiftData model in a new schema version.
This plan adds only the model, the migration stage, the glossary term and the
category-deletion hook. No UI. Plans 068-072 build the rest.

## Product rules (decided with the owner, do not change)

1. A **plan** is: one day, a duration, a category, and an optional start time
   (shown only, never used in any calculation). Several plans per day are allowed.
2. A plan **never** counts as logged time. It is never turned into an entry
   automatically. (Plan 070 adds a "Log" button that opens the normal Add Entry
   form pre-filled; the user saves the entry themselves.)
3. A plan stores the category's `Tracker.id` plus a snapshot of the category's
   name, icon and type. It does **not** use a SwiftData relationship to
   `Tracker`. Reason: CloudKit requires every relationship to have an inverse,
   so a relationship would need a new `Tracker` class in V12, which would force
   new copies of `Entry` and `SubmittedReport` too. With an id, V12 adds one
   model and migrates lightweight.
4. The plan's date is stored as **12:00 on the planned day**, the same rule
   Hugo already uses for carried-in entries (`YearMonth.middayOnFirst`), so a
   time-zone change cannot move a plan to another day. The start time is stored
   separately as minutes after midnight.
5. Future repeating plans ("every Monday, 2 hours") will be computed when read,
   not stored as one row per occurrence. Do not add any recurrence fields now.

## Current state

- `Hugo/Persistence/AppSchema.swift` lists every `VersionedSchema`. The newest
  is V11 (lines 107-123):

  ```swift
  enum SchemaV11: VersionedSchema {
      static let versionIdentifier = Schema.Version(8, 0, 0)

      typealias Report = SchemaV10.Report

      static var models: [any PersistentModel.Type] {
          [Entry.self, Tracker.self, Report.self, SubmittedReport.self]
      }
  }

  typealias CurrentSchema = SchemaV11

  // SchemaV8/V9.Report remains as migration compatibility ballast until a tested
  // future schema version can remove it safely.
  typealias Entry = CurrentSchema.Entry
  typealias Tracker = CurrentSchema.Tracker
  typealias SubmittedReport = CurrentSchema.SubmittedReport
  ```

  `SchemaV11.Entry`, `SchemaV11.Tracker` and `SchemaV11.SubmittedReport` are
  classes defined in `Hugo/Persistence/SchemaVersions/V11/*.swift`. Earlier
  versions reuse unchanged classes through `typealias` (see `SchemaV9` and
  `SchemaV10` at lines 83-105). V12 follows that pattern.

- `Hugo/Persistence/HugoMigrationPlan.swift` lines 15-29:

  ```swift
  static var schemas: [any VersionedSchema.Type] {
      [
          SchemaV1.self, SchemaV2.self, SchemaV2_1.self, SchemaV3.self,
          SchemaV4.self, SchemaV5.self, SchemaV6.self, SchemaV7.self,
          SchemaV8.self, SchemaV9.self, SchemaV10.self, SchemaV11.self,
      ]
  }

  static var stages: [MigrationStage] {
      [
          migrateV1toV2, migrateV2ToV21, migrateV21ToV3, migrateV3toV4,
          migrateV4toV5, migrateV5toV6, migrateV6toV7, migrateV7toV8,
          migrateV8toV9, migrateV9toV10, migrateV10toV11,
      ]
  }
  ```

  A lightweight stage looks like this (same file):

  ```swift
  static let migrateV9toV10: MigrationStage = .lightweight(
      fromVersion: SchemaV9.self,
      toVersion: SchemaV10.self
  )
  ```

- `Hugo/Persistence/SchemaVersions/V11/TrackerV11.swift` is the model style to
  match: every stored property has a default value (CloudKit requires it), no
  `@Attribute(.unique)`, the class lives in `extension SchemaV11 { @Model final class ... }`.
  `Tracker` has `var id: UUID = UUID()`, `name`, `type: TrackerType`, `iconName`.
  `TrackerType` (`Hugo/Persistence/Legacy/TrackerType.swift`) is a `String`
  `Codable` enum with cases `main` and `separate`; `Tracker` stores it directly
  as `var type: TrackerType = TrackerType.main`.

- `Hugo/Features/Categories/Services/CategoryDeletionService.swift` (whole file):

  ```swift
  @MainActor
  struct CategoryDeletionService {
      private let context: ModelContext

      init(context: ModelContext) {
          self.context = context
      }

      /// Deletes a category. Each entry's snapshot is refreshed first, so the
      /// entry keeps counting toward the category's latest name and type.
      func delete(_ tracker: Tracker) throws {
          for entry in tracker.entries ?? [] {
              entry.refreshStoredTracker()
          }
          context.delete(tracker)
          try context.save()
      }
  }
  ```

- `HugoTests/Persistence/SchemaMigrationTests.swift` has private store builders
  (`makeV7Store`, `makeV8Store`, `makeV9Store`, `makeV10Store` at line 1097,
  `makeCurrentStore` at the end). Each builds a `ModelContainer` for one
  schema at a file URL with `cloudKitDatabase: .none`, inserts rows and saves.
  `TemporaryStore` (in `HugoTests/TestSupport`) gives a throwaway `storeURL`.
  Tests are `@MainActor @Suite(.serialized) struct SchemaMigrationTests`.

- `CONTEXT.md` is the domain glossary. Sections: `## Time`, `## Reports`,
  `## Goals` (ends with the **Pacing** term at line 117), `## Sync` (line 120),
  `## Flagged ambiguities`. Terms use this format:

  ```markdown
  **Credited time**:
  The part of a month's time that counts toward the yearly goal: ...
  _Avoid_: Counted time
  ```

- Project settings: Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, the
  Xcode project uses file-system synchronized groups, so new files on disk are
  compiled without editing `project.pbxproj`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Layout | `Scripts/check-layout.sh` | exit 0, no output |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/SchemaMigrationTests -only-testing:HugoTests/CategoryDeletionServiceTests -only-testing:HugoTests/SyncDeduplicatorTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 |

Use 4-space indentation. Tabs fail the lint.

## Scope

**In scope** (the only files you should modify or create):
- `Hugo/Persistence/SchemaVersions/V12/PlanV12.swift` (create)
- `Hugo/Persistence/AppSchema.swift`
- `Hugo/Persistence/HugoMigrationPlan.swift`
- `Hugo/Features/Categories/Services/CategoryDeletionService.swift`
- `HugoTests/Persistence/SchemaMigrationTests.swift`
- `HugoTests/Features/Categories/Services/CategoryDeletionServiceTests.swift`
- `CONTEXT.md`

**Out of scope** (do NOT touch):
- Every file under `Hugo/Persistence/SchemaVersions/V1` ... `V11`. Shipped schema
  versions must never be edited (AGENTS.md section 8).
- `Hugo/Persistence/SyncDeduplicator.swift`. Plans are created only by a user
  action on one device, so sync cannot duplicate them. No merge rule is needed.
- Any UI, `Hugo/PreviewSupport`, `Localizable.xcstrings`. Plans 069-072 do that.

## Git workflow

- Branch: `advisor/067-plan-model-schema-v12`
- Conventional Commits, as in `git log`, for example `feat: add the Plan model in schema V12`.
- End each commit message with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` if your operator uses that attribution.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Create the `Plan` model

Create `Hugo/Persistence/SchemaVersions/V12/PlanV12.swift`:

```swift
//
//  PlanV12.swift
//  Hugo
//

import Foundation
import SwiftData

extension SchemaV12 {
    /// Time the user intends to spend in service on one day. A plan never
    /// counts as logged time; the Planner compares the two.
    @Model
    final class Plan {
        var id: UUID = UUID()
        /// 12:00 on the planned day, so a time-zone change cannot move the
        /// plan to another day. The start time, if any, is `startMinute`.
        var date: Date = Date()
        var duration: TimeInterval = 0
        /// Minutes after midnight, or nil when the plan has no start time.
        var startMinute: Int?

        /// `Tracker.id` of the plan's category. Plans keep the id and a
        /// snapshot instead of a relationship, so V12 needed no new `Tracker`,
        /// `Entry` or `SubmittedReport` classes.
        var categoryID: UUID?
        var categoryName: String = ""
        var categoryIconName: String = "questionmark.circle"
        var categoryType: TrackerType = TrackerType.main

        var createdAt: Date = Date()

        init(date: Date, duration: TimeInterval, startMinute: Int? = nil, tracker: Tracker?) {
            self.date = date
            self.duration = duration
            self.startMinute = startMinute
            self.categoryID = tracker?.id
            self.categoryName = tracker?.name ?? ""
            self.categoryIconName = tracker?.iconName ?? "questionmark.circle"
            self.categoryType = tracker?.type ?? .main
        }

        /// Points the plan at `tracker` and copies its name, icon and type, so
        /// the plan keeps its category if the category is deleted later.
        func setCategory(_ tracker: Tracker?) {
            categoryID = tracker?.id
            categoryName = tracker?.name ?? ""
            categoryIconName = tracker?.iconName ?? "questionmark.circle"
            categoryType = tracker?.type ?? .main
        }
    }
}
```

This does not compile yet, because `SchemaV12` does not exist. That is Step 2.

### Step 2: Add `SchemaV12` and make it current

In `Hugo/Persistence/AppSchema.swift`, insert after the closing brace of `SchemaV11`:

```swift
enum SchemaV12: VersionedSchema {
    static let versionIdentifier = Schema.Version(9, 0, 0)

    typealias Entry = SchemaV11.Entry
    typealias Tracker = SchemaV11.Tracker
    typealias Report = SchemaV11.Report
    typealias SubmittedReport = SchemaV11.SubmittedReport

    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self, SubmittedReport.self, Plan.self]
    }
}
```

Then change `typealias CurrentSchema = SchemaV11` to `typealias CurrentSchema = SchemaV12`
and add `typealias Plan = CurrentSchema.Plan` after the `SubmittedReport` typealias.

In `Hugo/Persistence/HugoMigrationPlan.swift`:
- append `SchemaV12.self` to `schemas` (after `SchemaV11.self`),
- append `migrateV11toV12` to `stages` (after `migrateV10toV11`),
- add the stage, directly after the closing of `migrateV10toV11`'s definition
  (before `private static func inferredRoundingRaw`):

```swift
    /// Adds the `Plan` model. No existing data changes.
    static let migrateV11toV12: MigrationStage = .lightweight(
        fromVersion: SchemaV11.self,
        toVersion: SchemaV12.self
    )
```

**Verify**: Focused tests → `** TEST SUCCEEDED **` (existing tests only; this
proves V1-V11 stores still migrate to the new current schema).

### Step 3: Keep plan snapshots current when a category is deleted

In `CategoryDeletionService.delete(_:)`, refresh the snapshot of every plan that
points at the tracker before deleting it. Fetch all plans and filter in memory
(the number of plans is small, and this avoids an optional-UUID `#Predicate`):

```swift
    /// Deletes a category. Each entry's and plan's snapshot is refreshed first,
    /// so they keep the category's latest name and type.
    func delete(_ tracker: Tracker) throws {
        for entry in tracker.entries ?? [] {
            entry.refreshStoredTracker()
        }
        let trackerID = tracker.id
        for plan in try context.fetch(FetchDescriptor<Plan>()) where plan.categoryID == trackerID {
            plan.setCategory(tracker)
        }
        context.delete(tracker)
        try context.save()
    }
```

Keep `categoryID` pointing at the deleted id (that is what `setCategory`
does). The Planner falls back to the snapshot when no live category has that id.

### Step 4: Tests

In `HugoTests/Persistence/SchemaMigrationTests.swift`:

1. Add a store builder next to `makeV10Store`, following the same shape:

   ```swift
   private func makeV11Store(
       at url: URL,
       trackers: [SchemaV11.Tracker] = [],
       entries: [SchemaV11.Entry] = []
   ) throws {
       let schema = Schema(versionedSchema: SchemaV11.self)
       let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
       let container = try ModelContainer(for: schema, configurations: [configuration])
       let context = container.mainContext
       trackers.forEach(context.insert)
       entries.forEach(context.insert)
       try context.save()
   }
   ```

2. Add `migratingV11StoreKeepsEntriesAndStartsWithoutPlans`: build a V11 store
   with one tracker (`name: "Field Service", type: .main, isDefault: true, iconName: "figure.walk"`)
   and one entry of 3_600 seconds on that tracker. Open it with `makeCurrentStore`.
   Expect one `Entry` whose `tracker?.name == "Field Service"`, and
   `try context.fetch(FetchDescriptor<Plan>()).isEmpty`.

3. Add `currentStoreRoundTripsPlanWithCategorySnapshot` next to
   `currentStoreRoundTripsSubmittedReportWithCategorySnapshots`: in
   `InMemoryModelContainer.make()`, insert `Tracker(name: "LDC", type: .separate, iconName: "hammer")`
   and `Plan(date: <any date>, duration: 5_400, startMinute: 600, tracker: tracker)`,
   save, fetch the plan, and expect `categoryID == tracker.id`,
   `categoryName == "LDC"`, `categoryIconName == "hammer"`, `categoryType == .separate`,
   `startMinute == 600`, `duration == 5_400`.

In `HugoTests/Features/Categories/Services/CategoryDeletionServiceTests.swift`,
add `deletingCategoryKeepsItsLatestNameOnPlans`, modeled on
`deletingRenamedCategoryKeepsLatestSnapshot` (first test in the file): insert a
tracker "LDC" (`.separate`, icon "hammer") and a plan for it; save; rename the
tracker to "Building" and set `type = .main`; call
`CategoryDeletionService(context:).delete(tracker)`. Expect the fetched plan's
`categoryName == "Building"`, `categoryType == .main`, and `categoryID` equal to
the deleted tracker's id (read the id into a local before deleting).

**Verify**: Focused tests → `** TEST SUCCEEDED **`, including the three new tests.

### Step 5: Glossary

In `CONTEXT.md`, add a new section between `## Goals` and `## Sync`:

```markdown
## Planning

**Planner**:
The tab where the user plans each month on a calendar and compares the plan with the time they log.

**Plan**:
Time the user intends to spend in service on one day: a duration, a category and optionally a start time. A plan never counts as logged time; logging stays a separate step.
_Avoid_: Planned entry, schedule, appointment
```

**Verify**: `grep -n "^## Planning" CONTEXT.md` → one match.

### Step 6: Full gate

**Verify**: `Scripts/verify.sh` → exit 0.

## Test plan

- `SchemaMigrationTests.migratingV11StoreKeepsEntriesAndStartsWithoutPlans` (upgrade path).
- `SchemaMigrationTests.currentStoreRoundTripsPlanWithCategorySnapshot` (fields persist, snapshot copied).
- `CategoryDeletionServiceTests.deletingCategoryKeepsItsLatestNameOnPlans`.
- Every existing migration test must still pass: they now migrate into V12.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -n "typealias CurrentSchema = SchemaV12" Hugo/Persistence/AppSchema.swift` → one match
- [ ] `grep -n "migrateV11toV12" Hugo/Persistence/HugoMigrationPlan.swift` → two matches (list and definition)
- [ ] `git diff --stat 2e8a451..HEAD -- Hugo/Persistence/SchemaVersions/V11 Hugo/Persistence/SchemaVersions/V10` → empty
- [ ] `grep -c "@Attribute(.unique)" Hugo/Persistence/SchemaVersions/V12/PlanV12.swift` → 0
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The excerpts in "Current state" do not match the live code.
- Any existing `SchemaMigrationTests` test fails after Step 2. Do not "fix" it by
  editing an old schema file. Report the failing test and its message.
- SwiftData reports a duplicate version checksum or "Cannot use staged migration
  with an unknown model version". Report it; do not change version identifiers
  of existing schemas.
- The compiler rejects the `Plan` class because of the property named `id`
  (it should not: `SchemaV11.Tracker` has the same property).
- You feel a need to add a relationship between `Plan` and `Tracker` or `Entry`.
  Rule 3 forbids it.

## Maintenance notes

- **Owner step before any TestFlight or App Store build that contains V12**:
  run a Debug build that saves at least one plan (after plan 070 lands), confirm
  in CloudKit Console (container `iCloud.com.ordellnielsen.Hugo`, Development)
  that record type `CD_Plan` exists with all fields, then choose
  **Deploy Schema Changes** to Production. Production rejects unknown record
  types, so without this step plans silently fail to sync for testers (same
  procedure as plan 036, step 5).
- Adding fields to `Plan` later (for example a `repeatingPlanID` for exceptions
  to repeating plans) needs a V13 with a new `Plan` class and a lightweight stage.
  Optional attributes with defaults migrate lightweight and are CloudKit-safe.
- `categoryID` intentionally survives category deletion. If a deleted category
  is restored by sync with the same id, the plan reattaches automatically.
- `SyncDeduplicator.mergeDuplicateCategories` keeps the `Tracker.id` of the
  survivor, so plan category ids stay valid after a category merge.
