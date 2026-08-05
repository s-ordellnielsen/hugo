# Plan 023: Remove dead code and inert UI, and retire deprecated API

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for plan 023
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat d65afec..HEAD -- Hugo/Features/ServiceYear Hugo/Features/Settings Hugo/Features/Onboarding Hugo/Features/Reports Hugo/Persistence/HugoMigrationPlan.swift Hugo/Features/Categories Hugo/Features/Entries Hugo/Features/SymbolPicker`
> If any in-scope file changed, compare the "Current state" excerpts against
> the live code; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED (Step 6 only)
- **Depends on**: plans/016-green-verification-gate.md, plans/022-motion-vocabulary.md
- **Category**: tech-debt
- **Planned at**: commit `d65afec`, 2026-08-06

## Why this matters

The app ships several controls that do nothing, several state variables nothing
reads, and a wired-but-unimplemented feature. That is worse than missing
functionality: a user who taps the help button in Publisher Status learns the
app is broken. Separately, 11 uses of the deprecated `.cornerRadius(_:)` and 3
of `.foregroundColor(_:)` will eventually warn, and one logger writes to a
different subsystem than the rest of the app — during the migrations that have
already caused two incidents.

## Current state

### A. Inert help button

`Hugo/Features/Settings/PublisherStatusSelectionView.swift:44-52`:

```swift
.toolbar {
    ToolbarItem {
        Button {

        } label: {
            Label("navigation.help", systemImage: "questionmark")
        }
    }
}
```

An empty action, shipping to users.

### B. Wired-but-unimplemented scroll-to-current-month

`Hugo/Features/ServiceYear/ServiceYearPageView.swift:4-35`:

```swift
struct ServiceYearPageView: View {
    let report: TheocraticYearReport
    let initialMonth: YearMonth?
    @State private var didScrollToCurrentMonth = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                …
                    ForEach(report.months) { month in
                        Group { … }
                        .id(month.id)
                    }
```

`proxy` is never used, `didScrollToCurrentMonth` is never read or written, and
`initialMonth` is passed by `ServiceYearView.swift:33` but never consumed. The
`.id(month.id)` anchors exist for a scroll that never happens.

### C. Dead loading state in onboarding

`Hugo/Features/Onboarding/OnboardingView.swift:15,79-109`:

```swift
@State private var isLoading: Bool = false
…
Button {
    Task {
        onComplete()
    }
} label: {
    HStack {
        if isLoading {
            ProgressView()
                .tint(.white)
                .transition(.blurReplace)
        } else {
            Label("splash.action.complete", systemImage: "arrow.right")
            .transition(.blurReplace)
        }
    }
    .animation(.smooth, value: isLoading)
```

`isLoading` is never set to `true`, so the `ProgressView`, both transitions and
the animation are unreachable. The `Task { onComplete() }` also wraps a
synchronous call, which `AGENTS.md` §2 forbids:

> Avoid unstructured `Task { ... }` where structural `async let` or `taskGroup`
> can be used.

### D. Unused local

`Hugo/Features/Reports/Domain/ReportRoundingCalculator.swift:64-69`:

```swift
private static func distributeHours(
    submittedHours: Int,
    categories: [MonthlyCategorySummary]
) -> [String: Int] {
    let hours: [String: Int] = [:]
    guard !categories.isEmpty else { return hours }
```

`hours` exists only to be returned empty; `[:]` says it better.

### E. Unrendered `marker`

`Hugo/Features/Overview/MonthlyProgressCircle.swift:6` declares
`let marker: Double?` and the body never uses it.
`MonthlyProgressCard.swift:12` passes `marker: expectedProgress`.

### F. Hardcoded UserDefaults keys

`Hugo/Features/Reports/SubmitReportFormModel.swift:230-237`:

```swift
private var overseerFirstName: String {
    // Stored by Task 6's overseer picker; falls back to the full name.
    userDefaults.string(forKey: "overseerFirstName") ?? overseerFullName
}

private var overseerLastName: String {
    userDefaults.string(forKey: "overseerLastName") ?? ""
}
```

`UserDefaultsKeys.overseerFirstName` and `.overseerLastName` already exist
(`Hugo/Domain/UserDefaultsKeys.swift:8-9`) and are used correctly by
`OverseerSettingsView` and `GreetingTemplateView`.

### G. Deprecated API

`.cornerRadius(_:)` — 11 uses across `EntryRow.swift:73`, `SymbolPicker.swift:92`,
`MonthlyReportEmptyRow.swift:59`, `TheocraticYearTotalsView.swift:36`,
`ServiceYearPageView.swift:54`, `ReportReminderCard.swift:36`,
`CategoryDetailView.swift:35`, `AddCategoryView.swift:31`,
`OnboardingView.swift:67,105`, `MonthlyReportRow.swift:98`.

`.foregroundColor(_:)` — `CategoryPicker.swift:49`, `CategoryListView.swift:41`,
`OnboardingView.swift:104`.

### H. Divergent logging subsystem

`Hugo/Persistence/HugoMigrationPlan.swift:13`:

```swift
private static let logger = Logger(subsystem: "Hugo.Persistence", category: "Migration")
```

Everything else uses `"com.ordellnielsen.Hugo"` — see `AppBootstrapper.swift:19`
and `ModelContainerFactory.swift:7`. One Console filter cannot see both.

### I. No-op custom migration stages

`Hugo/Persistence/HugoMigrationPlan.swift:62-82` — two `.custom` stages whose
`willMigrate` only calls `context.save()`:

```swift
static let migrateV2_1toV3 = MigrationStage.custom(
    fromVersion: SchemaV2_1.self,
    toVersion: SchemaV3.self,
    willMigrate: { context in
        logger.debug("Migrating from V2.1 to V3")

        try context.save()
    },
    didMigrate: nil
)
```

`migrateV3toV4` is identical in shape.

### Conventions

- `plans/README.md` records a standing decision: *"Preserve every historical
  schema type needed to open existing stores. A file that is unused by current
  UI is not dead if `HugoMigrationPlan` references its schema."* Honour it.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan023 CODE_SIGNING_ALLOWED=NO` | `TEST SUCCEEDED` |
| Migration tests only | same, plus `-only-testing:HugoTests/SchemaMigrationTests` | 8 tests pass |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:
- `Hugo/Features/Settings/PublisherStatusSelectionView.swift`
- `Hugo/Features/ServiceYear/ServiceYearPageView.swift`
- `Hugo/Features/ServiceYear/ServiceYearView.swift`
- `Hugo/Features/Onboarding/OnboardingView.swift`
- `Hugo/Features/Reports/Domain/ReportRoundingCalculator.swift`
- `Hugo/Features/Overview/MonthlyProgressCircle.swift`
- `Hugo/Features/Overview/MonthlyProgressCard.swift`
- `Hugo/Features/Reports/SubmitReportFormModel.swift`
- `Hugo/Persistence/HugoMigrationPlan.swift`
- All files listed under "Current state G" — modifier replacement only.

**Out of scope** (do NOT touch):
- `Hugo/Features/Settings/DebugSettingsView.swift` and its link from
  `SettingsView`. The operator has explicitly kept this as-is; do not add
  `#if DEBUG` or remove the link.
- `Configuration/**`, `Hugo.xcodeproj/project.pbxproj`, entitlements — the
  operator has excluded all build-configuration changes.
- `Hugo/Persistence/Legacy/DailyPoint.swift` and `TrackerSummary.swift`. They
  look orphaned but `SchemaV3`–`V7.Report` reference them and
  `HugoTests/Persistence/SchemaMigrationTests.swift:26,29,71` constructs them.
  **Not dead.**
- `Hugo/Persistence/SchemaVersions/**` beyond nothing — do not touch any schema
  file. Entity hashes are derived from these and plan 014 was abandoned over a
  hash break.
- `Hugo/Features/Entries/EntryDurationPicker.swift` and the duplicated
  duration↔date conversion in `EntryDetailView.swift`. Plan 026 deletes that
  picker outright; deduplicating it here would be thrown away.

## Git workflow

- Branch: `advisor/023-dead-code-and-api-hygiene`
- One commit per step, message style: `` `023` Step N — <summary> ``
- Do NOT push or open a PR.

## Steps

### Step 1: Remove the inert help button

Delete the entire `.toolbar { ToolbarItem { Button { } … } }` block from
`PublisherStatusSelectionView`. Do not replace it with a placeholder alert — if
help content is wanted later it is a feature, not a stub.

**Verify**: `grep -n "navigation.help" Hugo` → no matches. (Leave the
`navigation.help` key in the catalog; plan 024 audits unused keys.)

### Step 2: Either implement or remove the scroll-to-current-month

Choose **remove**, because the anchors carry a cost and the behavior has never
existed:

- Delete `initialMonth` from `ServiceYearPageView`'s signature.
- Delete `didScrollToCurrentMonth`.
- Delete the `ScrollViewReader` wrapper, keeping the `ScrollView` and its
  contents exactly as they are.
- Keep `.id(month.id)` on each row — it is also the `ForEach` identity anchor
  and removing it risks diffing changes.
- Update the two call sites: `ServiceYearView.swift:31-34` and the `#Preview` at
  `ServiceYearPageView.swift:58-62`.

**Verify**: `grep -rn "initialMonth\|didScrollToCurrentMonth\|ScrollViewReader" Hugo`
→ no matches. `Scripts/verify.sh` → exit 0.

### Step 3: Remove the dead onboarding loading state

In `OnboardingView`:
- Delete `@State private var isLoading: Bool = false`.
- Collapse the `HStack { if isLoading { … } else { … } }` to just the `Label`.
- Delete both `.transition(.blurReplace)` and `.animation(.smooth, value: isLoading)`.
- Replace `Button { Task { onComplete() } }` with `Button { onComplete() }` —
  `onComplete` is `() -> Void`, not async.

**Verify**: `grep -n "isLoading" Hugo/Features/Onboarding/OnboardingView.swift`
→ no matches. `grep -rn "Task {" Hugo` → only `AppRootView.swift`'s retry, which
genuinely awaits.

### Step 4: Trivial cleanups

1. `ReportRoundingCalculator.distributeHours` — replace `let hours: [String: Int] = [:]`
   + `return hours` with `guard !categories.isEmpty else { return [:] }`.
2. `MonthlyProgressCircle` — remove `let marker: Double?` and drop the
   `marker:` argument at `MonthlyProgressCard.swift:12`. It has never been
   rendered; a future "expected progress" tick mark should be added
   deliberately, with a design, not left as an unused parameter.
3. `SubmitReportFormModel` — replace the two string literals with
   `UserDefaultsKeys.overseerFirstName` / `.overseerLastName`, and delete the
   stale `// Stored by Task 6's overseer picker` comment.
4. `HugoMigrationPlan` — change the logger subsystem to
   `"com.ordellnielsen.Hugo"`, keeping `category: "Migration"`.
5. Delete the remaining stale task-note comments:
   `ReportComposer.swift:57-59` ("see the Task 2 note in the PR", "Task 6
   decides…") — keep the factual first sentence if it still describes behavior,
   drop the PR references. Leave the identical comment in
   `SchemaVersions/V9/SubmittedReportV9.swift:27` and `V10/SubmittedReportV10.swift:27`
   **alone** — schema files are out of scope.

**Verify**: `grep -rn '"overseerFirstName"\|"overseerLastName"' Hugo` → no
matches. `grep -rn "Hugo.Persistence" Hugo` → no matches.
`grep -rn "Task 2\|Task 6" Hugo` → matches only under `Hugo/Persistence/SchemaVersions/`.
All 11 `ReportRoundingCalculatorTests` pass.

### Step 5: Replace deprecated modifiers

Mechanical, two substitutions:

- `.cornerRadius(N)` → `.clipShape(.rect(cornerRadius: N))`
- `.foregroundColor(X)` → `.foregroundStyle(X)`

Apply to all 14 sites listed under "Current state G". `.cornerRadius` clips;
`.clipShape(.rect(cornerRadius:))` is the direct modern equivalent — do **not**
substitute `.background(in:)` or `.containerShape`, which have different
semantics.

**Verify**: `grep -rn "\.cornerRadius(" Hugo` → no matches.
`grep -rn "\.foregroundColor(" Hugo` → no matches. Manual: every card and tile
still has rounded corners.

### Step 6: Simplify the two no-op migration stages — RISKY, LAST

Convert `migrateV2_1toV3` and `migrateV3toV4` from `.custom` to `.lightweight`:

```swift
static let migrateV2_1toV3: MigrationStage = .lightweight(
    fromVersion: SchemaV2_1.self,
    toVersion: SchemaV3.self
)
```

A `.custom` stage whose `willMigrate` only calls `context.save()` is
behaviourally identical to `.lightweight`, so this is a simplification, not a
change. **But** this repository has already lost a schema version to a
migration subtlety (plan 014, abandoned after an entity-hash break), so treat it
as the riskiest step here.

**Verify**: the migration-tests-only command → all 8 tests in
`SchemaMigrationTests.swift` pass.

**If any migration test fails, revert this step only** — commit Steps 1–5 and
record Step 6 as BLOCKED with the failure output. Do not attempt to fix the
migration chain inside this plan.

## Test plan

No new behavior, so no new behavioral tests. Two additions guard the riskiest
changes:

- `HugoTests/Features/Reports/ReportRoundingCalculatorTests.swift` (11 existing
  tests; model after them):
  - `distributeHoursWithNoCategoriesReturnsEmpty` — pins Step 4.1.
- `HugoTests/Persistence/SchemaMigrationTests.swift` (8 existing tests):
  - No new test. The existing suite already walks the full V1→V10 chain, which
    is exactly the Step 6 guard. Confirm it does before relying on it; if it
    does not cover V2_1→V3→V4, **skip Step 6** and report.

Verification: test command → `TEST SUCCEEDED`, 1 more test than before.

## Done criteria

ALL must hold:

- [ ] `grep -rn "initialMonth\|didScrollToCurrentMonth\|ScrollViewReader" Hugo` → no matches
- [ ] `grep -n "isLoading" Hugo/Features/Onboarding/OnboardingView.swift` → no matches
- [ ] `grep -rn "navigation.help" Hugo` → no matches (Swift sources)
- [ ] `grep -rn "\.cornerRadius(\|\.foregroundColor(" Hugo` → no matches
- [ ] `grep -rn '"overseerFirstName"\|"overseerLastName"' Hugo` → no matches
- [ ] `grep -rn "Hugo.Persistence" Hugo` → no matches
- [ ] `grep -rn "marker" Hugo/Features/Overview` → no matches
- [ ] `Scripts/verify.sh` exits 0
- [ ] All 8 `SchemaMigrationTests` pass (or Step 6 reverted and marked BLOCKED)
- [ ] `git status` shows no files outside the in-scope list, and **nothing** under `Hugo/Persistence/SchemaVersions/`
- [ ] `plans/README.md` row for 023 updated

## STOP conditions

Stop and report if:

- Any test in `SchemaMigrationTests.swift` fails at any point. Revert Step 6
  and stop — do not debug the migration chain here.
- `SchemaMigrationTests` turns out not to exercise the V2_1→V3→V4 hops. Skip
  Step 6 entirely and report.
- Removing `marker` from `MonthlyProgressCircle` reveals a caller outside
  `MonthlyProgressCard`.
- `.clipShape(.rect(cornerRadius:))` changes any card's visual corner in a way
  that is noticeable side by side.
- A `git status` shows a modified file under `Hugo/Persistence/SchemaVersions/`.
  That is never correct in this plan.

## Maintenance notes

- After this lands, the app has no inert controls. Keep it that way: a control
  with an empty action should not be committed, even temporarily.
- The scroll-to-current-month behavior removed in Step 2 was a real intention.
  If it is wanted, it is a small feature: `ScrollViewReader` +
  `.onAppear { proxy.scrollTo(currentMonth, anchor: .top) }` guarded by a
  one-shot flag. The `.id(month.id)` anchors are still in place for it.
- `MonthlyProgressCircle.marker` was intended as an "expected progress" tick.
  Worth building deliberately — it would make the on/off-target status visual
  rather than textual.
- Step 6 is the only risky change in this plan and is sequenced last precisely
  so the other five can ship if it fails.
- Reviewer should scrutinize: Step 6's diff and the migration test output.
