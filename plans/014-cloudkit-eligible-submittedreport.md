# Plan 014: Make `SubmittedReport` CloudKit-eligible so the V9 schema pushes and syncs — without a V10 migration

> **Executor instructions**: Follow this plan task by task, in order. Run every
> verification command and confirm the expected result before moving to the
> next task. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for plan 014
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 6a2b67a..HEAD -- Hugo/Persistence/SchemaVersions/V9/SubmittedReportV9.swift Hugo/Features/Reports/SubmitReportFormModel.swift Hugo/Features/ServiceYear/Structs/TheocraticYearReport.swift Hugo/Features/Overview/OverviewView.swift Hugo/Features/Reports/MonthSubmissionStatusView.swift Hugo/Features/Reports/MonthlyReportEntryListView.swift Hugo/Features/Reports/Domain/ReportReminderSchedule.swift Hugo/Features/ServiceYear/Structs/TheocraticYearReportBuilder.swift HugoTests/Features/Reports/SubmitReportFormModelTests.swift plans/README.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: MED
- **Depends on**: none (plan 012 is DONE; this fixes a defect introduced there)
- **Category**: bug
- **Planned at**: commit `6a2b67a`, 2026-08-01

## Why this matters

`SchemaV9.SubmittedReport` (added in plan 012, commit `2621ad0`) is not
CloudKit-eligible. The primary blocker is the non-optional Codable composite
`var categories: [SubmittedCategory]`, and every synced scalar is also stored
non-optional. Because of this, `ModelContainerFactory.makeProductionContainer()`
opens the store but **silently skips CloudKit schema initialization** — the
container does not throw. Consequences:

* `CD_SubmittedReport` never appears in the CloudKit **Development** console.
* "Deploy to Production" therefore shows no changes (Development and Production
  are still identical at the V8 shape).
* A production/TestFlight build's iCloud sync fails because the production
  schema lacks the record type the app writes.

V9 has never been pushed to CloudKit and never shipped beyond the author's own
internal TestFlight iPhone, so we repair V9 **in place** instead of cutting a
V10 migration. This is safe precisely because the fix is **optionality-only**:
Core Data's entity version hash (the store-compatibility check) is computed
from property names, types, and relationship cardinality — **not** optionality
or default values. The iPhone's store is already stamped version `6.0.0`, so
no migration stage re-runs and the store opens cleanly against the edited
model. Any structural change (rename, type change, add/remove attribute) would
break this and is out of scope.

## Current state

All paths are relative to the repository root. The model is the single source
of the bug; everything else is compile fallout from making its properties
optional.

### The buggy model — `Hugo/Persistence/SchemaVersions/V9/SubmittedReportV9.swift`

Every persisted property is currently non-optional with an inline default. The
composite array is the CloudKit blocker; the scalars are made optional too as
the defensive, Apple-recommended shape:

```swift
extension SchemaV9 {
    @Model
    final class SubmittedReport {
        var year: Int = 0
        var month: Int = 0
        var firstSubmittedAt: Date = Date.distantPast
        var submittedAt: Date = Date.distantPast
        var entriesClosedAt: Date = Date.distantPast
        var roundingRuleRaw: String = ""
        var fieldServiceSeconds: TimeInterval = 0
        var actualTotalSeconds: TimeInterval = 0
        var submittedHours: Int = 0
        var carriedInSeconds: TimeInterval = 0
        var carriedOutSeconds: TimeInterval = 0
        var roundedUpSeconds: TimeInterval = 0
        var roundedDownSeconds: TimeInterval = 0
        var totalBibleStudies: Int = 0
        var categories: [SubmittedCategory] = []   // ← non-optional Codable composite: the blocker
        // ... init(year: Int = 0, ...) assigns each ...
    }
}
```

The `yearMonth` computed property (`YearMonth(year: year, month: month)`) and
the nested `struct SubmittedCategory: Codable, Hashable, Identifiable` are
unchanged in shape — only the *stored* properties become optional.

### Persistence container (do NOT change) — `Hugo/Persistence/ModelContainerFactory.swift`

```swift
static func makeProductionContainer() throws -> ModelContainer {
    let schema = Schema(versionedSchema: CurrentSchema.self)
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    return try ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: [configuration])
}
```

`cloudKitDatabase` defaults to `.automatic`, so this store syncs. This is the
store that must become CloudKit-eligible. `makeInMemoryContainer()` sets
`cloudKitDatabase: .none` and is used by tests/previews — leave it alone.

### Migration plan (do NOT change) — `Hugo/Persistence/HugoMigrationPlan.swift`

`migrateV8toV9` is additive-only (`willMigrate` just saves; `didMigrate`
backfills one sentinel `SubmittedReport` per month that has entries). The
iPhone already ran it. Do not touch `AppSchema.swift`,
`HugoMigrationPlan.swift`, or the `CurrentSchema = SchemaV9` alias.

### The sentinel/rollup contract that constrains the fix

Two facts together forbid a naive "delete existing, insert fresh" submission:

1. **The backfill will not re-run on the iPhone.** Its store is already at
   `6.0.0`, so the sentinels that mark real submitted months must be preserved
   by *merging*, not recreated.
2. **`TheocraticYearReportBuilder` keys submissions by month**, so two rows for
   the same month would double-count the yearly rollup —
   `Hugo/Features/ServiceYear/Structs/TheocraticYearReportBuilder.swift:15`:

   ```swift
   let submissionsByMonth = Dictionary(uniqueKeysWithValues: submissions.map { ($0.yearMonth, $0) })
   ```

3. `TheocraticYearMonth.isSubmitted` treats `submittedAt == .distantPast` as
   "never submitted" (a sentinel) — `TheocraticYearReport.swift`:

   ```swift
   var isSubmitted: Bool {
       guard let submittedReport else { return false }
       return submittedReport.submittedAt != .distantPast
   }
   ```

### Current submission write — `Hugo/Features/Reports/SubmitReportFormModel.swift` (~lines 140–177)

```swift
func persistSubmission(in context: ModelContext) -> SubmittedReport? {
    guard isSubmittable else { return nil }
    let summary = self.summary
    let previous = existingSubmission

    let report = SubmittedReport(
        year: month.year,
        month: month.month,
        firstSubmittedAt: previous?.firstSubmittedAt ?? now,
        submittedAt: now,
        entriesClosedAt: monthEntries.map(\.createdAt).max() ?? now,
        roundingRuleRaw: selectedRule.rawValue,
        fieldServiceSeconds: summary?.mainDuration ?? 0,
        actualTotalSeconds: (summary?.totalSeconds ?? 0) + carriedIn,
        submittedHours: computation.submittedHours,
        carriedInSeconds: carriedIn,
        carriedOutSeconds: computation.carriedOutSeconds,
        roundedUpSeconds: computation.roundedUpSeconds,
        roundedDownSeconds: computation.roundedDownSeconds,
        totalBibleStudies: summary?.totalBibleStudies ?? 0,
        categories: (summary?.categories ?? []).map { category in
            SubmittedReport.SubmittedCategory(
                name: category.name, iconName: category.iconName,
                typeRaw: category.type?.rawValue, actualSeconds: category.duration,
                submittedHours: computation.categoryHours[category.id] ?? 0)
        }
    )

    if let previous {
        context.delete(previous)   // ← tombstones the row in CloudKit; re-insert resurrects it
    }
    context.insert(report)
    try? context.save()
    return report
}
```

`existingSubmission` (the "previous" for the *same* month) is a sentinel or a
real submission for that month. On the iPhone these rows already exist and
must be updated in place.

### Repo conventions to match

* **Domain types are pure value structs; `@Observable` classes own stateful
  workflow state** — see `plans/README.md` "Architecture decisions". The
  `SubmittedReport` model is a persisted `@Model`; the reporting domain
  (`MonthlyReportSummary`, `MonthlyCategorySummary` in
  `Hugo/Features/Reports/Domain/`) is already decoupled from it and needs no
  change.
* **Persistence names stay as-is** (`SubmittedReport`, sentinel semantics).
* **Commit style** (from `git log`): `` `014` Task 01 — <imperative> ``.
* Formatting is enforced — `xcrun swift-format lint --strict` runs in
  `Scripts/verify.sh`. Match the surrounding 4-space style.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint (strict) | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no findings |
| Build + unit tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData CODE_SIGNING_ALLOWED=NO` | exit 0, all tests pass |
| Static analysis | `xcodebuild analyze -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/HugoVerifyDerivedData-Analyze CODE_SIGNING_ALLOWED=NO` | exit 0, no issues |
| All three gates | `sh Scripts/verify.sh` | exit 0 |

(`Scripts/verify.sh` runs exactly the three commands above; you can run the
script or the individual commands. `DEVELOPER_DIR` defaults to
`/Applications/Xcode.app/Contents/Developer`.)

## Scope

**In scope** (the only files you should modify):

* `Hugo/Persistence/SchemaVersions/V9/SubmittedReportV9.swift`
* `Hugo/Features/Reports/SubmitReportFormModel.swift`
* `Hugo/Features/ServiceYear/Structs/TheocraticYearReport.swift`
* `Hugo/Features/Overview/OverviewView.swift`
* `Hugo/Features/Reports/MonthSubmissionStatusView.swift`
* `Hugo/Features/Reports/MonthlyReportEntryListView.swift`
* `Hugo/Features/Reports/Domain/ReportReminderSchedule.swift`
* `Hugo/Features/ServiceYear/Structs/TheocraticYearReportBuilder.swift`
* `HugoTests/Features/Reports/SubmitReportFormModelTests.swift` (add merge test)
* `plans/README.md` (status row only)

**Out of scope** (do NOT touch, even though they look related):

* `Hugo/Persistence/AppSchema.swift`, `Hugo/Persistence/HugoMigrationPlan.swift`,
  and everything under `Hugo/Persistence/SchemaVersions/V1`–`V8` — the
  migration chain and historical schemas are frozen compatibility definitions.
* `Hugo/Persistence/ModelContainerFactory.swift` — container config is correct;
  the bug is the model, not the container.
* `Hugo/Persistence/AppSchema.swift`'s `typealias CurrentSchema = SchemaV9` —
  we are not cutting a V10.
* `Hugo/PreviewSupport/ReportPreviewFixtures.swift` — its `SubmittedReport(...)`
  calls use the unchanged init and still compile.
* `HugoTests/Persistence/SchemaMigrationTests.swift` — the V8→V9 tests
  construct the model via its (unchanged) init and still compile.
* The CloudKit deployment itself (console clicks, archiving, TestFlight) is a
  manual operator runbook in "Manual deployment runbook" below — not something
  you execute or verify with a command.

## Git workflow

* Branch: `advisor/014-cloudkit-eligible-submittedreport`
* One commit per task; message style: `` `014` Task 01 — Make SubmittedReport CloudKit-eligible ``, `` `014` Task 02 — Coalesce optionality at read sites ``, etc.
* Do NOT push or open a PR unless the operator instructed it.

## Steps

### Task 1: Make every `SubmittedReport` stored property optional

Edit `Hugo/Persistence/SchemaVersions/V9/SubmittedReportV9.swift` only.

* Change each stored property to its optional form with a `nil` default:
  `var year: Int?`, `var month: Int?`, `var firstSubmittedAt: Date?`,
  `var submittedAt: Date?`, `var entriesClosedAt: Date?`,
  `var roundingRuleRaw: String?`, `var fieldServiceSeconds: TimeInterval?`,
  `var actualTotalSeconds: TimeInterval?`, `var submittedHours: Int?`,
  `var carriedInSeconds: TimeInterval?`, `var carriedOutSeconds: TimeInterval?`,
  `var roundedUpSeconds: TimeInterval?`, `var roundedDownSeconds: TimeInterval?`,
  `var totalBibleStudies: Int?`, and critically
  `var categories: [SubmittedCategory]?`.
* Keep the existing `init(year: Int = 0, month: Int = 0, firstSubmittedAt: Date = .distantPast, …, categories: [SubmittedCategory] = [])`
  signature **unchanged** (non-optional parameters with defaults). Assign each
  into the now-optional storage — Swift stores a non-optional argument into an
  optional property automatically, so the init body needs no logic change.
  This keeps every existing constructor call site compiling
  (`SubmitReportFormModel`, `ReportPreviewFixtures`, `SchemaMigrationTests`,
  the form-model tests).
* Update the `yearMonth` computed property to coalesce the now-optional
  scalars:

  ```swift
  var yearMonth: YearMonth {
      YearMonth(year: year ?? 0, month: month ?? 0)
  }
  ```

* Do **not** add `@Attribute(.unique)`, and do **not** add any `@Relationship`.
  The nested `SubmittedCategory` struct is unchanged.

**Verify**: `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/Persistence` → builds and the persistence tests pass (compile errors at downstream read sites are expected *here*; Task 2 fixes them — proceed even if feature targets fail to compile, as long as the model file itself is correct).

### Task 2: Coalesce optionality at every direct read site

These files read `SubmittedReport` properties directly and will not compile
until the optional values are coalesced. Make exactly these edits (preserve
existing logic; only add `??` coalescing). The sentinel semantics
(`submittedAt == .distantPast` ⇒ "never submitted") must be preserved.

* `Hugo/Features/ServiceYear/Structs/TheocraticYearReport.swift` (~line 15):
  `return submittedReport.submittedAt != .distantPast` →
  `return (submittedReport.submittedAt ?? .distantPast) != .distantPast`
* `Hugo/Features/Overview/OverviewView.swift` (~line 34):
  `return submission.submittedAt == .distantPast ? due : nil` →
  `return (submission.submittedAt ?? .distantPast) == .distantPast ? due : nil`
* `Hugo/Features/Reports/MonthlyReportEntryListView.swift` (~lines 10–11):
  `guard let report, report.submittedAt != .distantPast else { return false }`
  → `guard let report, (report.submittedAt ?? .distantPast) != .distantPast else { return false }`
  and `return entry.createdAt > report.entriesClosedAt` →
  `return entry.createdAt > (report.entriesClosedAt ?? .distantPast)`
* `Hugo/Features/Reports/Domain/ReportReminderSchedule.swift` (~lines 51–54):
  apply the same two coalesces to `report.submittedAt` and `report.entriesClosedAt`.
* `Hugo/Features/Reports/SubmitReportFormModel.swift` (~line 64):
  `submission.submittedAt != .distantPast` →
  `(submission.submittedAt ?? .distantPast) != .distantPast`
* `Hugo/Features/Reports/MonthSubmissionStatusView.swift` (~line 16):
  `if month.isSubmitted, let submittedAt = month.submittedReport?.submittedAt {`
  — this already optional-chains and `month.isSubmitted` already guards
  non-nil, so it should compile unchanged. **Only** touch it if the compiler
  flags it; if so, bind with `if month.isSubmitted, let submittedAt = month.submittedReport?.submittedAt ?? nil {`
  is wrong — instead leave as-is unless it errors, then report.

**Verify**: `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData CODE_SIGNING_ALLOWED=NO` → exit 0, **all** tests pass (the whole target now compiles).

### Task 3: Update the same-month submission in place instead of delete+insert

Still in `Hugo/Features/Reports/SubmitReportFormModel.swift`, rework
`persistSubmission(in:)` so that when `existingSubmission` (the same month's
sentinel or prior submission) is present, the new values are **written into
that same object** rather than deleting it and inserting a fresh
`SubmittedReport`. This preserves the CloudKit record identity (no
tombstone+resurrect) and keeps one row per month so the theocratic-year rollup
(`submissionsByMonth`) cannot double-count.

Target shape:

```swift
func persistSubmission(in context: ModelContext) -> SubmittedReport? {
    guard isSubmittable else { return nil }
    let summary = self.summary
    let snapshots = (summary?.categories ?? []).map { category in
        SubmittedReport.SubmittedCategory(
            name: category.name, iconName: category.iconName,
            typeRaw: category.type?.rawValue, actualSeconds: category.duration,
            submittedHours: computation.categoryHours[category.id] ?? 0)
    }

    if let existing = existingSubmission {
        existing.firstSubmittedAt = existing.firstSubmittedAt ?? now  // keep original on a real re-submit
        existing.submittedAt = now
        existing.entriesClosedAt = monthEntries.map(\.createdAt).max() ?? now
        existing.roundingRuleRaw = selectedRule.rawValue
        existing.fieldServiceSeconds = summary?.mainDuration ?? 0
        existing.actualTotalSeconds = (summary?.totalSeconds ?? 0) + carriedIn
        existing.submittedHours = computation.submittedHours
        existing.carriedInSeconds = carriedIn
        existing.carriedOutSeconds = computation.carriedOutSeconds
        existing.roundedUpSeconds = computation.roundedUpSeconds
        existing.roundedDownSeconds = computation.roundedDownSeconds
        existing.totalBibleStudies = summary?.totalBibleStudies ?? 0
        existing.categories = snapshots
        try? context.save()
        return existing
    }

    let report = SubmittedReport(
        year: month.year, month: month.month,
        firstSubmittedAt: now, submittedAt: now,
        entriesClosedAt: monthEntries.map(\.createdAt).max() ?? now,
        roundingRuleRaw: selectedRule.rawValue,
        fieldServiceSeconds: summary?.mainDuration ?? 0,
        actualTotalSeconds: (summary?.totalSeconds ?? 0) + carriedIn,
        submittedHours: computation.submittedHours,
        carriedInSeconds: carriedIn,
        carriedOutSeconds: computation.carriedOutSeconds,
        roundedUpSeconds: computation.roundedUpSeconds,
        roundedDownSeconds: computation.roundedDownSeconds,
        totalBibleStudies: summary?.totalBibleStudies ?? 0,
        categories: snapshots)
    context.insert(report)
    try? context.save()
    return report
}
```

Note `existing.year` / `existing.month` are already correct for that month and
need no reassignment. A sentinel's `firstSubmittedAt` is `.distantPast`
(truthy), so the `?? now` only fires if it was genuinely nil; a real
re-submission correctly keeps its original `firstSubmittedAt`.

**Verify**: `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/Features/Reports/SubmitReportFormModelTests` → all pass (see "STOP conditions" — an existing test may assert the old replace behavior).

## Test plan

* **New test** in `HugoTests/Features/Reports/SubmitReportFormModelTests.swift`,
  modeled on the existing re-submission test at
  `HugoTests/Features/Reports/SubmitReportFormModelTests.swift:128`
  (`let previous = SubmittedReport(...)` then assert a single row). Add
  `persistingIntoSentinelUpdatesInPlace()`:
  * Seed a sentinel `SubmittedReport(year: 2026, month: 7)` (no `submittedAt`,
    so it defaults to sentinel state) and entries for July 2026.
  * Call `persistSubmission(in:)`.
  * Assert `try context.fetchCount(FetchDescriptor<SubmittedReport>()) == 1`
    (still exactly one row — no duplicate).
  * Assert the fetched row's `submittedAt` is no longer `.distantPast`
    (sentinel became a real submission) and `firstSubmittedAt` is set.
* **No changes needed** to `HugoTests/Persistence/SchemaMigrationTests.swift` —
  the V8→V9 backfill tests and the round-trip test
  (`currentStoreRoundTripsSubmittedReportWithCategorySnapshots`, line 171)
  construct the model through its unchanged init and must keep passing,
  confirming the optionality change is storage-compatible.
* Verification: `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData CODE_SIGNING_ALLOWED=NO` → all pass, including the new merge test.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `xcrun swift-format lint --strict --recursive Hugo HugoTests` exits 0
- [ ] `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData CODE_SIGNING_ALLOWED=NO` exits 0; all tests pass, including the new sentinel-merge test
- [ ] `xcodebuild analyze -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/HugoVerifyDerivedData-Analyze CODE_SIGNING_ALLOWED=NO` exits 0
- [ ] `grep -n "var categories: \[SubmittedCategory\]$" Hugo/Persistence/SchemaVersions/V9/SubmittedReportV9.swift` returns no match (the property is now `… = nil` / optional)
- [ ] `grep -rn "context.delete(previous)" Hugo/Features/Reports/SubmitReportFormModel.swift` returns no match (replaced by in-place update)
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row for plan 014 updated

(Or simply: `sh Scripts/verify.sh` exits 0, plus the two `grep` checks.)

## Manual deployment runbook (operator-only — NOT executed by you)

These steps push the now-eligible schema to CloudKit and are done by the human
in Xcode / the CloudKit Console. You do not run them and cannot verify them
with a command; they are recorded here so the intent is unambiguous.

1. Fresh **Debug** install on a simulator (delete any existing app there
   first), signed into iCloud. Create an entry and submit a report to force a
   sync — this pushes the corrected V9 schema to the **Development**
   environment.
2. CloudKit Console → container `iCloud.com.ordellnielsen.Hugo` →
   **Development** → Record Types → confirm `CD_SubmittedReport` now exists.
3. Click **Deploy to Production**; it should now list the new record type.
4. CloudKit Console → **Production** → confirm `CD_SubmittedReport` is present.
5. Update the iPhone to the new TestFlight build (same V9, optionality-fixed).
   Its store opens with **no migration**; the previously-queued exports flush
   to Production.
6. **Do not delete the app from the iPhone** until CloudKit Console →
   Production → Data shows `CD_SubmittedReport` rows — data created while sync
   was failing exists only locally until then.

## STOP conditions

Stop and report back (do not improvise) if:

* The model or call sites in "Current state" don't match the live code (the
  codebase drifted since commit `6a2b67a`).
* Making `SubmittedReport` optional forces you to edit a file outside the
  in-scope list to get a clean build (the ripple is larger than mapped).
* You find that a correct fix requires a **structural** change (renaming,
  retyping, or adding/removing an attribute or entity). That breaks the
  entity version hash and **requires a V10 migration** — a different plan.
  Do not attempt it here.
* An existing `SubmitReportFormModelTests` test asserts the old
  delete-and-insert behavior (e.g. expects the same-month row count to change
  on re-submit). Reconciling the merge with that expectation is a product
  decision — report it rather than silently weakening the test.
* A step's verification fails twice after a reasonable fix attempt.

## Maintenance notes

* **Freeze V9 the moment its shape reaches Production or a user-installed
  build.** From then on, any change (new attribute, type change, optionality
  tightening) needs a `SchemaV10`. This is the convention already documented in
  `plans/README.md` ("Preserve every historical schema type…") and in
  `AppSchema.swift`'s migration-ballast comment.
* Reviewer: scrutinize (a) that every stored `SubmittedReport` property is now
  optional with a `nil` default while the `init` keeps its non-optional
  defaulted parameters, and (b) that `persistSubmission` mutates
  `existingSubmission` rather than delete+insert — the latter is what protects
  CloudKit record identity and the yearly rollup.
* Deferred out of scope: a first-launch `initializeCloudKitSchema()` helper
  and a CloudKit-sync error surface (the container currently fails silently
  when a model is ineligible — that's how this bug hid). Either would make the
  next eligibility regression loud instead of silent; both are separate,
  optional hardening.
* Future interaction: if a relationship is ever added to `SubmittedReport`,
  both sides must be optional with an inverse, and this plan's "optionality
  preserves the entity version hash" guarantee no longer holds for that
  change — it would require a new schema version.
