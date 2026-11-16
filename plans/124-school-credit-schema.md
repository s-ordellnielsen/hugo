# Plan 124: Add a synced `SchoolCredit` model and a school catalog in schema V14

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 9d5a547..HEAD -- Hugo/Persistence Hugo/Features/SchoolCredits HugoTests/Persistence/SchemaMigrationTests.swift CONTEXT.md`
> Expected: no output. If anything changed, compare with the excerpts below and STOP if they differ.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED. A new schema version changes the store on every device. The stage is lightweight (one new model, one new optional attribute), the same kind as V11→V12.
- **Depends on**: none. Plans 125 and 126 build on this one.
- **Category**: direction
- **Planned at**: commit `9d5a547`, 2026-11-16
- **Issue**: [SLN-156](https://linear.app/sebastianln/issue/SLN-156)

## Why this matters

A regular pioneer who attends Pioneer Service School gets a fixed credit of hours (30) that counts toward the yearly goal the same way as Field Service time. Hugo has no way to record it today. This plan adds the data layer only:

- a synced `SchoolCredit` model: one school, one month, a whole number of hours;
- an optional `schoolCreditHours` attribute on `SubmittedReport`, holding the credit that a sent report included;
- a `School` catalog that lists each school, its credit quota and which publisher statuses may use it. It starts with Pioneer Service School (30 hours, regular pioneers). Another school is one new enum case;
- a `SchoolCreditService` that adds, changes and deletes credits and rejects hours outside `1...quota`.

Decisions already made with the owner (2026-11-16):
- A credit is not an entry and not a category. It doesn't go through rounding or the separate allowance.
- A school that spans two months is entered as two credits, one per month (e.g. 15 + 15). The range check is per credit; nothing checks the sum across credits.
- The credit is stored in its own model, not only on `SubmittedReport`, because users add it before the month's report exists.
- The snapshot on the report is a new attribute, **not** an extra reporting line. Older builds decode an unknown `SubmittedReportingLine.typeRaw` as `.main` (`SubmittedReportV13.swift`: `TrackerType(rawValue: typeRaw) ?? .main`), which would give it the Field Service line's id `""` and show a false unreported change on those builds.

Plans 125 (counting and report message) and 126 (Year page UI) use what this plan adds. This plan changes no behavior a user can see.

## Current state

### Schema versions

`Hugo/Persistence/AppSchema.swift` ends like this (at `9d5a547`):

```swift
/// Replaces the never-used `hue`, `sat` and `bri` category channels with
/// optional `colorHue` and `colorTone`. `Tracker` changes, so `Entry` and
/// `SubmittedReport`, which relate to it, and `Plan`, whose initializer takes
/// a `Tracker`, get V13 classes too. Their stored attributes are unchanged.
enum SchemaV13: VersionedSchema {
    static let versionIdentifier = Schema.Version(10, 0, 0)

    typealias Report = SchemaV12.Report

    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self, SubmittedReport.self, Plan.self]
    }
}

typealias CurrentSchema = SchemaV13

// SchemaV8/V9.Report remains as migration compatibility ballast until a tested
// future schema version can remove it safely.
typealias Entry = CurrentSchema.Entry
typealias Tracker = CurrentSchema.Tracker
typealias SubmittedReport = CurrentSchema.SubmittedReport
typealias Plan = CurrentSchema.Plan
```

Each version's model classes live in `Hugo/Persistence/SchemaVersions/V13/` as `extension SchemaV13 { @Model final class ... }`: `EntryV13.swift`, `TrackerV13.swift`, `SubmittedReportV13.swift`, `PlanV13.swift`. Inside the extension, `Entry`, `Tracker`, `SubmittedReport` and `Plan` resolve to the V13 classes.

Why V14 needs copies of all four: `SubmittedReport` gets a new attribute, so it needs a V14 class. `Entry` has `@Relationship var sourceSubmission: SubmittedReport?` and `SubmittedReport` has `inverse: \Entry.sourceSubmission`, so `Entry` needs a V14 class. `Tracker` relates to `Entry`, and `Plan`'s initializer takes a `Tracker`, so both need V14 classes too. The V13 change did the same for the same reason (commit `b4def03`).

`Hugo/Persistence/SchemaVersions/V13/SubmittedReportV13.swift` lines 13-51 hold the stored attributes. The ones near the new attribute:

```swift
        var roundedDownSeconds: TimeInterval?

        var totalBibleStudies: Int?
```

### Migration plan

`Hugo/Persistence/HugoMigrationPlan.swift` lines 15-30:

```swift
    static var schemas: [any VersionedSchema.Type] {
        [
            SchemaV1.self, SchemaV2.self, SchemaV2_1.self, SchemaV3.self,
            SchemaV4.self, SchemaV5.self, SchemaV6.self, SchemaV7.self,
            SchemaV8.self, SchemaV9.self, SchemaV10.self, SchemaV11.self, SchemaV12.self,
            SchemaV13.self,
        ]
    }

    static var stages: [MigrationStage] {
        [
            migrateV1toV2, migrateV2ToV21, migrateV21ToV3, migrateV3toV4,
            migrateV4toV5, migrateV5toV6, migrateV6toV7, migrateV7toV8,
            migrateV8toV9, migrateV9toV10, migrateV10toV11, migrateV11toV12,
            migrateV12toV13,
        ]
    }
```

and lines 380-386:

```swift
    /// Drops the never-used `hue`, `sat` and `bri` category channels and adds
    /// optional `colorHue` and `colorTone`. No screen ever wrote a color, so
    /// every category starts as Automatic.
    static let migrateV12toV13: MigrationStage = .lightweight(
        fromVersion: SchemaV12.self,
        toVersion: SchemaV13.self
    )
```

### Migration tests

`HugoTests/Persistence/SchemaMigrationTests.swift` has `migratingV12StoreStartsEveryCategoryAsAutomatic()` (line 1048) and helpers `makeV12Store(at:trackers:entries:plans:)` (line 1226) and `makeCurrentStore(at:)` (line 1260). `TemporaryStore` gives a store URL and `remove()`. Copy that test's shape.

### Service exemplar

`Hugo/Features/Planner/Services/PlanService.swift`:

```swift
/// Creates, changes and deletes plans. Every write is saved on its own, so a
/// failure never discards other edits.
@MainActor
struct PlanService {
    private let context: ModelContext
    ...
    @discardableResult
    func add(_ draft: PlanDraft) throws -> Plan {
        let plan = Plan(...)
        try context.performIsolatedChange { context.insert(plan) }
        return plan
    }

    func update(_ plan: Plan, with draft: PlanDraft) throws {
        try context.performIsolatedChange { ... }
    }

    func delete(_ plan: Plan) throws {
        try context.performIsolatedChange { context.delete(plan) }
    }
}
```

Its tests are in `HugoTests/Features/Planner/Services/PlanServiceTests.swift` (`InMemoryModelContainer.make()`, `ModelContext(container)`).

### Publisher statuses

`Hugo/Features/PublisherStatus/Domain/PublisherStatus.swift` defines ids `"regular-pioneer"`, `"auxiliary-pioneer"` and `"publisher"`.

### Localization pattern

`Hugo/Features/Reports/Domain/ReportComposer.swift` looks strings up in a given locale with `String(localized: LocalizedStringResource("report.compose.field-service", locale: locale))`. `String(localized:locale:)` would use the app's language instead, so don't use it.

### Conventions (from `AGENTS.md`)

- Swift 6, MainActor default isolation. Domain types are `nonisolated`.
- Feature files live in role folders: `Domain`, `Services`, `State`, `Screens`, `Views`. Tests mirror the source path.
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`).
- All SwiftData models must work with CloudKit: every stored property has a default value or is optional, no `@Attribute(.unique)`, relationships optional.
- Schema changes need a new `VersionedSchema`, a stage in `MigrationPlan`, and a test in `SchemaMigrationTests`. Never edit a shipped schema version (V13 and older stay as they are).
- 4-space indentation; tabs fail the lint.
- Domain words come from `CONTEXT.md`. This plan adds two terms there.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full gate (lint, layout, tests, analysis) | `Scripts/verify.sh` | exit 0 |
| Lint only | `swift-format lint --strict --recursive Hugo HugoTests` | no output, exit 0 |
| Catalog JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0 |

`Scripts/verify.sh` takes several minutes. Run it at the end and whenever a step says so.

## Scope

**In scope:**
- `Hugo/Persistence/SchemaVersions/V14/` (create: `EntryV14.swift`, `TrackerV14.swift`, `SubmittedReportV14.swift`, `PlanV14.swift`, `SchoolCreditV14.swift`)
- `Hugo/Persistence/AppSchema.swift`
- `Hugo/Persistence/HugoMigrationPlan.swift`
- `Hugo/Features/SchoolCredits/Domain/School.swift` (create)
- `Hugo/Features/SchoolCredits/Services/SchoolCreditService.swift` (create)
- `HugoTests/Persistence/SchemaMigrationTests.swift`
- `HugoTests/Features/SchoolCredits/Domain/SchoolTests.swift` (create)
- `HugoTests/Features/SchoolCredits/Services/SchoolCreditServiceTests.swift` (create)
- `Hugo/Resources/Localizable.xcstrings` (3 new keys)
- `CONTEXT.md`

**Out of scope:**
- Anything under `Hugo/Persistence/SchemaVersions/V13/` or older. Shipped schemas never change.
- `SyncDeduplicator.swift`. Credits are created once by the user on one device, so sync can't duplicate them the way it duplicates the seeded default category. No merge rule is needed.
- Any screen, `ServiceMonth`, `YearlyGoalProgress`, `ReportComposer` or `ReportSubmissionService`. Plans 125 and 126 change those.
- `Hugo/Features/Settings/Domain/DiagnosticsReport.swift` and its tests. They mention "SchemaV13" only in a comment and in test fixtures with literal strings.

## Git workflow

- Work on `main` directly. No branch, no worktree.
- One commit at the end, after `Scripts/verify.sh` exits 0. Message: `feat: add a synced school credit model and school catalog in schema V14`.
- Never stage anything under `.claude/` or `plans/`. Do not push.
- `Hugo/Resources/Localizable.xcstrings` and `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` may already show as modified before you start (the owner's own changes). Never stage the `.xcscheme`. The reviewer will tell you how to handle the string catalog.

## Steps

### Step 1: Copy the V13 model classes into V14

```sh
mkdir -p Hugo/Persistence/SchemaVersions/V14
for f in Entry Tracker SubmittedReport Plan; do
  sed 's/SchemaV13/SchemaV14/g; s/V13\.swift/V14.swift/g' \
    "Hugo/Persistence/SchemaVersions/V13/${f}V13.swift" \
    > "Hugo/Persistence/SchemaVersions/V14/${f}V14.swift"
done
```

**Verify**: `grep -c "extension SchemaV14" Hugo/Persistence/SchemaVersions/V14/*.swift` → each of the four files shows `1`. `grep -rn "SchemaV13" Hugo/Persistence/SchemaVersions/V14` → no output.

### Step 2: Add `schoolCreditHours` to the V14 `SubmittedReport`

In `Hugo/Persistence/SchemaVersions/V14/SubmittedReportV14.swift`, directly after `var totalBibleStudies: Int?`, add:

```swift

        /// Whole hours of school credit the report included, summed over the
        /// month's school credits when it was sent. Nil on reports sent before
        /// schema V14 and on placeholders; read nil as 0.
        var schoolCreditHours: Int?
```

Do not add it to the initializer. It starts as nil.

Also replace the file's header comment line `//  SubmittedReportV13.swift` if the `sed` in step 1 didn't (it should read `SubmittedReportV14.swift`).

### Step 3: Create the `SchoolCredit` model

Create `Hugo/Persistence/SchemaVersions/V14/SchoolCreditV14.swift`:

```swift
//
//  SchoolCreditV14.swift
//  Hugo
//

import Foundation
import SwiftData

extension SchemaV14 {
    /// Hours of school credit for one month, such as the credit a regular
    /// pioneer gets for attending Pioneer Service School. It counts toward
    /// the yearly goal like main time. It has no relationships, so later
    /// changes to other models never need a new `SchoolCredit` class.
    @Model
    final class SchoolCredit {
        var id: UUID = UUID()
        /// `School.rawValue`. A string, so a school added by a later build
        /// syncs to older builds without breaking them.
        var schoolID: String = ""
        var year: Int = 0
        var month: Int = 0
        var hours: Int = 0
        var createdAt: Date = Date()

        init(schoolID: String, month: YearMonth, hours: Int, createdAt: Date = .now) {
            self.schoolID = schoolID
            self.year = month.year
            self.month = month.month
            self.hours = hours
            self.createdAt = createdAt
        }

        var yearMonth: YearMonth {
            YearMonth(year: year, month: month)
        }
    }
}
```

### Step 4: Declare `SchemaV14`

In `Hugo/Persistence/AppSchema.swift`, after the `SchemaV13` enum, add:

```swift
/// Adds the synced `SchoolCredit` model and the optional
/// `SubmittedReport.schoolCreditHours`. `SubmittedReport` changes, so `Entry`
/// (which relates to it), `Tracker` (which relates to `Entry`) and `Plan`
/// (whose initializer takes a `Tracker`) get V14 classes too. Their stored
/// attributes are unchanged.
enum SchemaV14: VersionedSchema {
    static let versionIdentifier = Schema.Version(11, 0, 0)

    typealias Report = SchemaV13.Report

    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self, SubmittedReport.self, Plan.self, SchoolCredit.self]
    }
}
```

Change `typealias CurrentSchema = SchemaV13` to `typealias CurrentSchema = SchemaV14`, and add after `typealias Plan = CurrentSchema.Plan`:

```swift
typealias SchoolCredit = CurrentSchema.SchoolCredit
```

### Step 5: Add the migration stage

In `Hugo/Persistence/HugoMigrationPlan.swift`:
- In `schemas`, change the last line `SchemaV13.self,` to `SchemaV13.self, SchemaV14.self,`.
- In `stages`, change `migrateV12toV13,` to `migrateV12toV13, migrateV13toV14,`.
- After `migrateV12toV13`, add:

```swift

    /// Adds the `SchoolCredit` model and the optional
    /// `SubmittedReport.schoolCreditHours`. Existing reports keep nil, which
    /// reads as no school credit.
    static let migrateV13toV14: MigrationStage = .lightweight(
        fromVersion: SchemaV13.self,
        toVersion: SchemaV14.self
    )
```

**Verify** (steps 1-5 build together): `xcodebuild build -project Hugo.xcodeproj -scheme Debug -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | tail -20` → ends without `error:` lines. If the scheme name differs, run `xcodebuild -list -project Hugo.xcodeproj` and use the scheme `Scripts/verify.sh` uses (`grep -n "scheme" Scripts/verify.sh`).

### Step 6: Migration tests

In `HugoTests/Persistence/SchemaMigrationTests.swift`, add a helper next to `makeV12Store`:

```swift
    private func makeV13Store(
        at url: URL,
        trackers: [SchemaV13.Tracker] = [],
        entries: [SchemaV13.Entry] = [],
        reports: [SchemaV13.SubmittedReport] = []
    ) throws {
        let schema = Schema(versionedSchema: SchemaV13.self)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        trackers.forEach(context.insert)
        entries.forEach(context.insert)
        reports.forEach(context.insert)
        try context.save()
    }
```

Add two tests after `migratingV12StoreStartsEveryCategoryAsAutomatic()`:

1. `migratingV13StoreKeepsReportsAndStartsWithoutSchoolCredits()`: create a `SchemaV13.Tracker` ("Field Service", `.main`, `isDefault: true`, `iconName: "figure.walk"`), a `SchemaV13.Entry` of 3 600 s on it, and a `SchemaV13.SubmittedReport(year: 2026, month: 10, submittedHours: 1, totalBibleStudies: 2, reportingLines: [.init(typeRaw: "main", typeName: "", durationInSeconds: 3_600, submittedHours: 1)])`. Save with `makeV13Store`, open with `makeCurrentStore`, then expect: one `Entry` whose `tracker?.name == "Field Service"`; one `SubmittedReport` with `reportingLines.count == 1`, `totalBibleStudies == 2` and `schoolCreditHours == nil`; `FetchDescriptor<SchoolCredit>()` returns an empty array.
2. `currentStoreRoundTripsSchoolCreditsAndReportCreditHours()`: open `makeCurrentStore` on a `TemporaryStore`, insert `SchoolCredit(schoolID: "pioneer-service-school", month: YearMonth(year: 2026, month: 10), hours: 30)` and a `SubmittedReport(year: 2026, month: 10)` with `schoolCreditHours = 30`, save, open a **second** container on the same URL with `makeCurrentStore`, and expect the credit (`schoolID`, `yearMonth`, `hours`) and the report's `schoolCreditHours == 30` to come back.

Check the SubmittedReport V13 initializer parameter names in `SubmittedReportV13.swift:54-70` before writing the call; use only parameters that exist.

### Step 7: The school catalog

Create `Hugo/Features/SchoolCredits/Domain/School.swift`:

```swift
import Foundation

/// A school whose attendance gives a fixed credit of hours toward the yearly
/// goal, such as Pioneer Service School. `SchoolCredit.schoolID` stores the
/// raw value. To add a school, add a case and fill in every switch.
nonisolated enum School: String, CaseIterable, Identifiable, Sendable {
    case pioneerServiceSchool = "pioneer-service-school"

    var id: String { rawValue }

    /// The most hours one school credit may hold.
    var creditHours: Int {
        switch self {
        case .pioneerServiceSchool: 30
        }
    }

    /// The hours one school credit may hold: at least 1, at most `creditHours`.
    var hoursRange: ClosedRange<Int> { 1...creditHours }

    /// `PublisherStatus.id`s that may add a credit for this school.
    var publisherStatusIDs: Set<String> {
        switch self {
        case .pioneerServiceSchool: ["regular-pioneer"]
        }
    }

    /// The school's name in `locale`'s language.
    func name(locale: Locale = .current) -> String {
        switch self {
        case .pioneerServiceSchool:
            String(
                localized: LocalizedStringResource(
                    "school.pioneerServiceSchool.name", defaultValue: "Pioneer Service School", locale: locale,
                    comment: "Name of the school for regular pioneers. Shown on the Year page and in the report message."
                ))
        }
    }

    /// The name for a stored school id, or a generic name when this build
    /// doesn't know the id (a school added by a newer build on another device).
    static func name(forID id: String, locale: Locale = .current) -> String {
        if let school = School(rawValue: id) {
            return school.name(locale: locale)
        }
        return String(
            localized: LocalizedStringResource(
                "school.unknown.name", defaultValue: "School credit", locale: locale,
                comment: "Label for a school credit whose school this version of the app doesn't know."))
    }

    /// The schools a user with publisher status `statusID` may add credit for.
    static func available(forStatusID statusID: String) -> [School] {
        allCases.filter { $0.publisherStatusIDs.contains(statusID) }
    }
}
```

If `LocalizedStringResource(_:defaultValue:locale:comment:)` doesn't compile, the initializer's full parameter order is `(_ key:, defaultValue:, table:, locale:, bundle:, comment:)`; keep that order. If it still fails, STOP.

### Step 8: The service

Create `Hugo/Features/SchoolCredits/Services/SchoolCreditService.swift`:

```swift
import Foundation
import SwiftData

/// What the school credit form produces.
nonisolated struct SchoolCreditDraft: Equatable, Sendable {
    let school: School
    let month: YearMonth
    let hours: Int
}

/// Creates, changes and deletes school credits. Every write is saved on its
/// own, so a failure never discards other edits.
@MainActor
struct SchoolCreditService {
    enum ValidationError: LocalizedError, Equatable {
        case hoursOutOfRange(ClosedRange<Int>)

        var errorDescription: String? {
            switch self {
            case .hoursOutOfRange(let range):
                String(
                    localized: "schoolCredit.error.hoursOutOfRange",
                    defaultValue: "Choose between \(range.lowerBound) and \(range.upperBound) hours.",
                    comment: "Error when a school credit has too few or too many hours. The arguments are the smallest and largest allowed number of hours."
                )
            }
        }
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func add(_ draft: SchoolCreditDraft) throws -> SchoolCredit {
        try validate(draft)
        let credit = SchoolCredit(schoolID: draft.school.rawValue, month: draft.month, hours: draft.hours)
        try context.performIsolatedChange { context.insert(credit) }
        return credit
    }

    func update(_ credit: SchoolCredit, with draft: SchoolCreditDraft) throws {
        try validate(draft)
        try context.performIsolatedChange {
            credit.schoolID = draft.school.rawValue
            credit.year = draft.month.year
            credit.month = draft.month.month
            credit.hours = draft.hours
        }
    }

    func delete(_ credit: SchoolCredit) throws {
        try context.performIsolatedChange { context.delete(credit) }
    }

    private func validate(_ draft: SchoolCreditDraft) throws {
        guard draft.school.hoursRange.contains(draft.hours) else {
            throw ValidationError.hoursOutOfRange(draft.school.hoursRange)
        }
    }
}
```

Check `Hugo/Persistence/ModelContext+IsolatedChange.swift` for the exact name and signature of `performIsolatedChange` and match it.

### Step 9: Strings

Add these keys to `Hugo/Resources/Localizable.xcstrings`, each in its sorted position, with `en` and `da` `"state" : "translated"` and the comment from the code. JSON, two-space indentation, `" : "` separators. Copy the shape of `publisher.status.goal.description.monthly` (which uses `%lld`).

| Key | English | Danish |
|---|---|---|
| `school.pioneerServiceSchool.name` | Pioneer Service School | Pionerskolen |
| `school.unknown.name` | School credit | Skolekredit |
| `schoolCredit.error.hoursOutOfRange` | Choose between %1$lld and %2$lld hours. | Vælg mellem %1$lld og %2$lld timer. |

**Verify**: `python3 -I -c "import json;d=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'];k=['school.pioneerServiceSchool.name','school.unknown.name','schoolCredit.error.hoursOutOfRange'];print(all(d[x]['localizations'][l]['stringUnit']['value'] for x in k for l in ('en','da')))"` → `True`.

### Step 10: Tests for the catalog and the service

Create `HugoTests/Features/SchoolCredits/Domain/SchoolTests.swift` with:
- `pioneerServiceSchoolGivesThirtyHours`: `School.pioneerServiceSchool.creditHours == 30` and `hoursRange == 1...30`.
- `onlyRegularPioneersSeePioneerServiceSchool`: `School.available(forStatusID: "regular-pioneer") == [.pioneerServiceSchool]`; `available(forStatusID: "publisher")`, `("auxiliary-pioneer")` and `("")` are empty.
- `unknownSchoolIDGetsTheGenericName`: `School.name(forID: "future-school", locale: Locale(identifier: "en"))` == `"School credit"`, and `School.name(forID: "pioneer-service-school", locale: Locale(identifier: "en"))` == `"Pioneer Service School"`.

Create `HugoTests/Features/SchoolCredits/Services/SchoolCreditServiceTests.swift` (pattern: `PlanServiceTests`):
- `addStoresSchoolMonthAndHours`: add a 30-hour draft for October 2026, fetch, expect one credit with `schoolID == "pioneer-service-school"`, `yearMonth == YearMonth(year: 2026, month: 10)`, `hours == 30`.
- `addRejectsHoursOutsideTheQuota`: `#expect(throws: SchoolCreditService.ValidationError.hoursOutOfRange(1...30))` for 0 and for 31; the store stays empty.
- `updateChangesMonthAndHours`: add 30 h in October, update to 15 h in November, expect the fetched credit to match.
- `deleteRemovesTheCredit`.

**Verify**: `Scripts/verify.sh` → exit 0.

### Step 11: Domain vocabulary

In `CONTEXT.md`, under `## Goals`, after the **Separate allowance** entry, add:

```markdown
**School**:
A school whose attendance gives a fixed credit of hours toward the yearly goal, such as Pioneer Service School (30 hours, regular pioneers). Each school sets its quota and which publisher statuses may use it.

**School credit**:
Hours from a school, recorded for one month. It counts toward the yearly goal and the year total like main time, never goes through rounding, and is reported on its own line. A school that spans two months is entered as one school credit per month.
_Avoid_: PSS hours, credit hours
```

### Step 12: Commit

Run `Scripts/verify.sh` once more (→ exit 0), then commit only the in-scope files with the message from "Git workflow".

## Test plan

- `SchemaMigrationTests`: V13 store migrates with reports intact and `schoolCreditHours == nil`; current store round-trips a credit and the report attribute.
- `SchoolTests`: quota, range, status filter, unknown-id name.
- `SchoolCreditServiceTests`: add, reject out-of-range, update, delete.
- `Scripts/verify.sh` → exit 0 with the new tests passing.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -n "typealias CurrentSchema = SchemaV14" Hugo/Persistence/AppSchema.swift` → one match
- [ ] `grep -n "migrateV13toV14" Hugo/Persistence/HugoMigrationPlan.swift` → two matches (list and definition)
- [ ] `git diff --stat 9d5a547 -- Hugo/Persistence/SchemaVersions/V13` → no output
- [ ] `grep -n "School credit" CONTEXT.md` → at least one match
- [ ] `git status --short` shows no modified files outside the in-scope list, except the owner's `Debug.xcscheme`

## STOP conditions

- The V13 files don't match the excerpts (for example `SubmittedReportV13.swift` has no `var totalBibleStudies: Int?`).
- The build fails with a SwiftData error about the relationship between `Entry` and `SubmittedReport` after the copy. Report the exact error.
- A migration test fails with "Cannot use staged migration with an unknown model version" or a store-incompatibility error.
- `performIsolatedChange` doesn't exist or has a different shape you can't match.
- Any step seems to need a change to a V13-or-older schema file.

## Maintenance notes

- **CloudKit deploy (owner, before TestFlight):** `CD_SchoolCredit` and the new `CD_schoolCreditHours` field on `CD_SubmittedReport` must exist in the CloudKit Development schema and be deployed to Production before a build with V14 ships. Create at least one school credit and submit one report that includes it in a Development build first, so every field gets a value. In November 2026 a missing optional field (`CD_startMinute`) stopped all sync on a device.
- Older builds ignore both new fields. On those builds yearly progress leaves the credit out until they update.
- No `SyncDeduplicator` rule: credits are user-created rows with a random `id`. If a future feature seeds credits automatically on several devices, it needs a merge rule.
- Adding a school: add a `School` case, its quota, statuses and name string. Nothing else changes.
