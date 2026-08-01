# Plan 015: SchemaV10 with eligible `SubmittedReport` + V9→V10 lightweight migration

> **Status**: DONE (verified against a byte-identical copy of the real
> simulator store). Supersedes plan 014, which is BLOCKED.
> **Planned at**: commit `f8b2cda`, 2026-08-01. **Branch**: `advisor/015-schema-v10-submittedreport`.

## Why this exists (root cause)

Plan 014 made `SchemaV9.SubmittedReport` CloudKit-eligible **in place** on the
assumption that property optionality does not affect Core Data's entity version
hash. That assumption is **wrong** for SwiftData CloudKit-enabled stores.
Making every stored property optional changed `SubmittedReport`'s version hash,
so every existing V9 store (the internal TestFlight iPhone, simulators) became
an "unknown model version" to the staged-migration manager:

```
NSCocoaErrorDomain 134504 — "Cannot use staged migration with an unknown model version."
→ SwiftDataError.loadIssueModelContainer
→ fatalError in HugoApp.init()
```

A fresh store with the 014 model opens fine; only pre-existing stores crash.
There is **no hash-preserving way** to make the model eligible (CloudKit
requires optional attributes), so any fix that keeps existing data requires a
new schema version. This also matches the repo's own freeze rule: V9 reached a
user-installed build (the iPhone), so V9 is immutable.

## What was done

1. **Revert `SchemaV9.SubmittedReport`** (`SchemaVersions/V9/SubmittedReportV9.swift`)
   to its deployed non-optional shape, restoring hash compatibility with
   existing stores.
2. **Add `SchemaV10`** (`AppSchema.swift`, version `7.0.0`) carrying the
   eligible all-optional `SubmittedReport` in
   `SchemaVersions/V10/SubmittedReportV10.swift`. `CurrentSchema = SchemaV10`;
   the shared `SubmittedReport` typealias now resolves to V10, so 014's
   read-site optional-chaining and in-place `persistSubmission` keep working.
3. **`migrateV9toV10` = `.lightweight`** stage (`HugoMigrationPlan.swift`).
   Optionality-only — on-disk columns are identical, so Core Data re-stamps the
   store hash with no data movement.
4. **Tests**: added `migratingV9StorePreservesSubmittedReportsAcrossTheEligibilityRepair`
   (builds a deployed-shape V9 store with a sentinel + a real submission,
   migrates, asserts all fields survive); reverted the `?.` on V9-typed
   assertions (V9 is non-optional again); kept them on the V10 round-trip.

## Verification (empirical)

* Build-for-testing: **succeeded** · Analyze: **succeeded**.
* Against a copy of the real simulator store (6 entries, 6 submittedReports,
  2 trackers, 72 queued CloudKit export events, version `6.0.0`, hash `252830fa…`):
  * App **opens cleanly** (no `loadIssueModelContainer`).
  * Store re-stamped to **`7.0.0`**, `SubmittedReport` hash now `c2a0de2b…`.
  * All rows preserved (6/6/2); `Entry`/`Report`/`Tracker` hashes unchanged.
  * Relaunch on the migrated store is **stable** (idempotent, no re-migration).
* Unit tests (`xcodebuild test`) remain blocked by the pre-existing local
  `xcode-select`/simctl environment failure (needs `sudo` to repoint
  `xcode-select` to `/Applications/Xcode.app`) — unrelated to this change;
  verified failing identically at the base commit.

## Operator runbook (iPhone)

1. Do **not** delete the iPhone app and do **not** install a plan-014 build on
   it (that build crashes on launch against the existing store).
2. Fresh Debug install on a signed-in simulator, submit a report → pushes the
   V10 schema to CloudKit **Development**.
3. CloudKit Console → `iCloud.com.ordellnielsen.Hugo` → Development → confirm
   `CD_SubmittedReport` → **Deploy to Production**.
4. Ship this branch as a TestFlight build; the iPhone's store migrates V9→V10
   in place (data preserved, verified above) and its queued exports flush.
