# Plan 050: Bring AGENTS.md and README up to date, document the folder conventions, and clear small hygiene items

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 3f8d48b..HEAD -- AGENTS.md README.md Hugo/Domain/UserDefaultsKeys.swift Hugo/App/AppRootView.swift Hugo/Features/Settings Hugo/Persistence/HugoMigrationPlan.swift Hugo/Persistence/AppSchema.swift Hugo/Features/Entries/EntryRow.swift`
> Earlier plans (037–049) edit `AppRootView.swift`, `HugoMigrationPlan.swift`,
> `EntryRow.swift` and `ReportSettingsView.swift` in other places. That is
> expected. Match the excerpts below by content and STOP if the text they
> describe is gone.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: run after plans 037–049 (it documents the patterns they introduce). Plan 053 depends on this plan: this plan writes the folder conventions into AGENTS.md, and 053 moves the files to match. Run 053 right after this one.
- **Category**: docs
- **Planned at**: commit `3f8d48b`, 2026-10-12; revised 2026-11-03 at `359d37e` (new folder conventions; the `Checkmark.swift` move now belongs to plan 053)
- **Issue**: [SLN-253](https://linear.app/sebastianln/issue/SLN-253)

## Why this matters

Agents working in this repo follow `AGENTS.md`, so stale guidance there turns into wrong code:

- It never mentions `Scripts/verify.sh`. The gate regressed two days after it was made green (plan 037 had to fix it).
- Its "theocratic year" section tells agents to "use or implement" a `Date.theocraticYearString` helper built on `Calendar.current`. That helper does not exist; `TheocraticYear` already covers it with an injectable calendar, so following the doc duplicates logic tests cannot control.
- Its preview example uses `ReportsView()`, which does not exist.
- It says nothing about the conventions the recent plans set: injecting `now`/`calendar`/`locale`/`UserDefaults`, Swift Testing, adding a migration stage with a test for schema changes, the sync-duplicate rule, and resolving an entry's category through one helper.

`README.md` describes `Hugo/Domain` wrongly and omits `Hugo/Resources` and the one Swift package. AGENTS.md also bans every catch-all folder outright, yet the project already has two (`Hugo/Views` with one generic view, and generic styles and tokens sitting in `Hugo/App`). The owner decided on 2026-11-03 to replace the ban with a `Hugo/DesignSystem` folder for truly generic UI, a fixed set of role folders inside every feature (`Screens`, `Views`, `State`, `Domain`, `Services`), and tests that mirror the source layout. This plan writes those rules down. Plan 053 moves the files. A few small code items also mislead readers: a commented-out block in the V10→V11 migration whose comment claims values are copied, a raw `"isOnboarding"` defaults key, four file headers naming the wrong file, and a leftover commented-out modifier.

## Current state

- `AGENTS.md:73-80` (preview example):

  ````markdown
  ## 4. Previews

  ```swift
  /// PREFERRED PATTERN FOR PREVIEWS
  #Preview {
      ReportsView()
          .modelContainer(.preview)
  }
  ```
  ````

- `AGENTS.md:89-110`: the "Calculations" bullet list ends, then `#### Swift helper implementation reference:` with a `Date.theocraticYearString` snippet using `Calendar.current`. Section `## 6. Principles` follows, then `## Final repository conventions` (5 bullets) ends the file.
- `Hugo/Features/ServiceYear/TheocraticYear.swift`: `TheocraticYear(startYear:)`, `displayName` (`"2026/2027"`), `months`, `contains(_:)`, `containing(_:calendar:)`, `availableYears(entryDates:now:calendar:)`, and (after plan 048) `dateRange(calendar:)`. `Date.theocraticYear(using:)` at the bottom of the file.
- `README.md:30-38`:

  ```markdown
  * `Hugo/App` — app composition, bootstrap, and CloudKit boundaries.
  * `Hugo/Domain` — pure publisher-status and user-default domain values.
  * `Hugo/Persistence` — SwiftData schema versions, migration plan, and container factory.
  * `Hugo/Features` — feature-first SwiftUI UI and feature-local domain logic.
  * `Hugo/PreviewSupport` — isolated, synchronous in-memory preview containers and fixtures.
  * `HugoTests` — domain, feature, persistence, and migration tests.
  * `Configuration` — project-only xcconfig and entitlement inputs; these are not app resources.
  ```

  Reality: `Hugo/Domain` holds `YearMonth.swift`, `RoundingRule.swift` and `UserDefaultsKeys.swift`; `PublisherStatus` lives in `Hugo/Features/PublisherStatus/Domain/`. `Hugo/Resources` holds `Localizable.xcstrings`, `InfoPlist.xcstrings` is in `Hugo/`, help Markdown in `Hugo/Resources/Markdown/Help/{Base,da}.lproj/`, and app icons. The project depends on one Swift package, MarkdownUI (`swift-markdown-ui`), used only by `Hugo/Features/Help/Screens/HelpView.swift`. After plan 041 `Hugo/Persistence` also holds `SyncDeduplicator.swift`.
- `Hugo/Persistence/HugoMigrationPlan.swift`, end of the loop in `migrateV10toV11.didMigrate`:

  ```swift
  report.reportingLines = submittedReportingLines

  // Preserve the V10 report-level values while adding the V11
  // reporting-line and carry-entry projections.
  //report.roundingRuleRaw = legacyReport.roundingRuleRaw
  //report.carriedInSeconds = legacyReport.carriedInSeconds
  //report.carriedOutSeconds = legacyReport.carriedOutSeconds
  //report.roundedUpSeconds = legacyReport.roundedUpSeconds
  //report.roundedDownSeconds = legacyReport.roundedDownSeconds
  ```

  The V10 fields carry over through the stage's inferred mapping; the test `migratingV10StorePreservesUnrelatedReportFields` (`HugoTests/Persistence/SchemaMigrationTests.swift`) proves it.
- Raw key: `Hugo/App/AppRootView.swift` `@AppStorage("isOnboarding") private var needsOnboarding = true` and `Hugo/Features/Settings/DebugSettingsView.swift:4` `@AppStorage("isOnboarding") var isOnboarding: Bool = true`. Other keys live in `Hugo/Domain/UserDefaultsKeys.swift` as `static let name = "name"`.
- Headers naming the wrong file (line 2 of each):
  - `Hugo/Features/Settings/Screens/ReportSettingsView.swift`: `//  SwiftUIView.swift`
  - `Hugo/Features/Settings/Screens/GeneralSettingsView.swift`: `//  AppSettingsView.swift`
  - `Hugo/Persistence/AppSchema.swift`: `//  Schema.swift`
  - `Hugo/Persistence/HugoMigrationPlan.swift`: `//  Migration.swift`
- `Hugo/Features/Entries/EntryRow.swift`: a line `// .background(Color(.red))` after the icon `ZStack`'s `.frame(...)`.
- The project uses filesystem-synchronized groups, so moving a Swift file between folders needs no project-file edit (plan 053 relies on this).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:

- `AGENTS.md`
- `README.md`
- `Hugo/Domain/UserDefaultsKeys.swift`
- `Hugo/App/AppRootView.swift` (the `@AppStorage` key only)
- `Hugo/Features/Settings/DebugSettingsView.swift` (the `@AppStorage` key only)
- `Hugo/Features/Settings/Screens/ReportSettingsView.swift`, `Hugo/Features/Settings/Screens/GeneralSettingsView.swift`, `Hugo/Persistence/AppSchema.swift` (header line only)
- `Hugo/Persistence/HugoMigrationPlan.swift` (header line and the commented-out block only)
- `Hugo/Features/Entries/EntryRow.swift` (the commented-out line only)
- `plans/README.md` (status row)

**Out of scope**:

- Headers in `Hugo/Persistence/SchemaVersions/**`. Those files are compatibility definitions; do not touch them.
- Any behavior change. The `"isOnboarding"` value must stay exactly `"isOnboarding"`, or existing users see onboarding again.
- Rewording AGENTS.md sections 1-3 and 6. Only the parts named in the steps change.
- Moving any Swift file (including `Hugo/Views/Checkmark.swift`). Plan 053 does all moves. Because of that, the paths in this plan are the pre-053 paths.

## Git workflow

- Branch: `advisor/050-docs-hygiene`
- Commit message style: short imperative sentence, for example `Document the verification gate in AGENTS.md`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Update AGENTS.md

1. Section 4: replace `ReportsView()` with `OverviewView()`.
2. Section 5: delete the `#### Swift helper implementation reference:` heading, its sentence and the `Date.theocraticYearString` code block. Put this in their place:

   ```markdown
   #### Use the existing helpers

   Use `TheocraticYear` (`Hugo/Features/ServiceYear/Domain/TheocraticYear.swift`) instead of writing new date logic: `TheocraticYear.containing(_:calendar:)` or `date.theocraticYear(using:)` to find a date's year, `displayName` for the `YYYY/YYYY` label, `months` for its twelve `YearMonth`s, and `dateRange(calendar:)` for query bounds. Months are `YearMonth` values (`Hugo/Domain/YearMonth.swift`). Always pass the `Calendar` in so tests can fix it.
   ```

   (The path uses the layout that plan 053 creates. If you are told 053 will not follow, write `Hugo/Features/ServiceYear/TheocraticYear.swift` instead.)
3. Insert two new sections before `## Final repository conventions`, with exactly this text:

   ````markdown
   ## 7. Project structure

   ### Top level of `Hugo/`

   - `App`: app entry point, root view, bootstrap and the CloudKit boundary. Composition only, no reusable UI.
   - `DesignSystem`: generic UI that knows nothing about any feature.
   - `Domain`: value types shared by several features (`YearMonth`, `RoundingRule`, `UserDefaultsKeys`).
   - `Features`: one folder per feature.
   - `Persistence`: SwiftData schemas, migrations, the container factory and sync repair.
   - `PreviewSupport`: preview containers and fixtures.
   - `Resources`: string catalogs, help Markdown and app icons.

   Do not add other top-level folders. Do not create catch-all folders such as `Utilities`, `Helpers`, `Managers`, `Common`, `Shared`, `Extensions` or a top-level `Views`. Every folder is named after what it holds or what role its files play.

   ### `DesignSystem`

   This is the place for UI that is generic on purpose. Its subfolders are named by role: `Components` (reusable views), `Styles` (`ButtonStyle` and similar), `Modifiers` (`ViewModifier` and `View` extensions), `Motion` and `Theme` (tokens such as `HugoLayout` and colors). Add a new role folder when a new kind of generic code appears.

   A file belongs here only if it names no feature type (no `Entry`, `Tracker`, `SubmittedReport` and so on), imports nothing from a feature, and either two or more features use it or it was written to be used anywhere. A view that shows an entry or a category belongs to its feature, even when it looks reusable. Features may use `DesignSystem` and `Domain`. `DesignSystem` and `Domain` never use a feature.

   ### Feature folders

   Every Swift file in a feature lives in a role folder, even when it is the only file in that role. Create a role folder when its first file arrives, and do not leave empty folders. The roles are:

   - `Screens`: destinations. Tab roots, pushed screens and sheets, which normally own a navigation title or toolbar.
   - `Views`: components embedded in screens, including UIKit bridges (`UIViewRepresentable`).
   - `State`: `@MainActor @Observable` classes that hold a screen's state and workflow.
   - `Domain`: value types and logic, `nonisolated` where possible. No views and no `ModelContext`.
   - `Services`: types that read or write the SwiftData context or the system, for example `CategoryDeletionService`.

   Use no other role folders and do not nest folders inside a role folder. If a role folder grows too large, the feature probably contains two features. A feature may use another feature's types when it has to (for example `Entries` uses `CategoryPicker`), but avoid circular dependencies between features.

   Tests mirror the source layout: the test for `Hugo/Features/Reports/Domain/ReportComposer.swift` lives in `HugoTests/Features/Reports/Domain/`. Shared test helpers live in `HugoTests/TestSupport`.

   ## 8. Verification and testing

   - Run `Scripts/verify.sh` before every commit. It runs `swift-format lint --strict`, the tests (serially) and static analysis, and must exit 0. Use 4-space indentation; tabs fail the lint.
   - Tests use Swift Testing (`import Testing`, `@Test`, `#expect`). Persistence tests use `InMemoryModelContainer.make()`.
   - Types with time- or locale-dependent logic take `now`, `calendar`, `locale` and `UserDefaults` as initializer parameters with production defaults (see `SubmitReportFormModel`). Tests pass fixed values.
   - Schema changes need a new `VersionedSchema`, a stage in `HugoMigrationPlan`, and a test in `SchemaMigrationTests`. Never edit a shipped schema version.
   - CloudKit sync can duplicate rows, because it cannot enforce uniqueness. Merges live in `SyncDeduplicator` and must choose the surviving row from synced attributes only.
   - Get an entry's category with `entry.resolvedCategory()`, never from `entry.tracker` directly.
   ````

4. In `## Final repository conventions`, replace the first bullet (the one that lists `Hugo/App`, `Hugo/Domain`, `Hugo/Persistence`, `Hugo/Features` and `Hugo/PreviewSupport` and warns against catch-all `Views`, `Managers` or `Utilities` folders) with:

   ```markdown
   * Put new code where section 7 says. Do not add catch-all folders; generic UI goes in `Hugo/DesignSystem` under its admission rule.
   ```

   Leave the other bullets unchanged. If `Scripts/install-hooks.sh` exists (plan 051 has landed), add one bullet to section 8: ``- Run `Scripts/install-hooks.sh` once after cloning. The pre-commit hook formats staged Swift files.``

**Verify**:

- `grep -n 'theocraticYearString\|ReportsView' AGENTS.md` → no matches.
- `grep -n '^## 7. Project structure\|^## 8. Verification and testing' AGENTS.md` → two matches.
- `grep -n 'Utilities' AGENTS.md` → matches only inside section 7's "do not create" sentence.

### Step 2: Update the README architecture list

Replace the `Hugo/Domain` bullet and add two bullets, keeping the list's style. Also change the `Hugo/Features` bullet to end with `, organized into Screens, Views, State, Domain and Services folders (see AGENTS.md).` and the `Hugo/App` bullet to start with `app composition only (entry point, root view, bootstrap)` (generic UI moves to `DesignSystem` in plan 053):

```markdown
* `Hugo/Domain` — small value types shared across features: `YearMonth`, `RoundingRule`, and `UserDefaultsKeys`.
* `Hugo/DesignSystem` — generic UI that knows nothing about any feature: theme tokens, styles, modifiers, reusable components.
* `Hugo/Resources` — the string catalog, localized help pages (Markdown), and app icons.
```

Add a sentence after the list: `The only Swift package dependency is MarkdownUI, used by the help screen.`

If plan 041 has landed, extend the `Hugo/Persistence` bullet with `, and the sync-duplicate merge`.

**Verify**: `grep -n 'publisher-status' README.md` → no matches.

Commit steps 1-2: `Document the folder conventions, verification gate and current helpers`.

### Step 3: Small code hygiene

1. Add `static let isOnboarding = "isOnboarding"` to `UserDefaultsKeys` and use `UserDefaultsKeys.isOnboarding` in `AppRootView.swift` and `DebugSettingsView.swift`.
2. Fix the four header lines so they name their own file (`ReportSettingsView.swift`, `GeneralSettingsView.swift`, `AppSchema.swift`, `HugoMigrationPlan.swift`).
3. In `HugoMigrationPlan.swift`, replace the comment and the five commented-out assignments with:

   ```swift
   // The V10 report-level fields (rounding rule, carried and rounded
   // seconds) carry over unchanged through this stage's inferred mapping.
   // This stage only adds reporting lines and carried-in entries.
   ```

4. Delete the `// .background(Color(.red))` line in `EntryRow.swift`.

**Verify**:

- `grep -rn '"isOnboarding"' Hugo` → one match, in `UserDefaultsKeys.swift`.
- `grep -n '//report\.' Hugo/Persistence/HugoMigrationPlan.swift` → no matches.
- `Scripts/verify.sh` → exit 0 (including `migratingV10StorePreservesUnrelatedReportFields`).

Commit: `Tidy headers, a defaults key and dead comments`.

### Step 4: Update the index

In `plans/README.md`, set this plan's row to DONE.

## Test plan

No new tests. The migration comment change is covered by `migratingV10StorePreservesUnrelatedReportFields`; the key change keeps the same string value; the build covers the rest.

## Done criteria

- [ ] `grep -c 'Scripts/verify.sh' AGENTS.md` prints at least 1
- [ ] `grep -c '^## 7. Project structure' AGENTS.md` prints `1`
- [ ] `grep -rn '"isOnboarding"' Hugo | wc -l` prints `1`
- [ ] `Scripts/verify.sh` exits 0
- [ ] `git status --porcelain` lists only files from the Scope list
- [ ] `plans/README.md` row for 050 updated

## STOP conditions

Stop and report back if:

- `migratingV10StorePreservesUnrelatedReportFields` does not exist, or fails after Step 3. The comment would then be wrong; report instead of rewording it.
- Any helper named in the new AGENTS.md text (`dateRange(calendar:)`, `SyncDeduplicator`, `resolvedCategory()`, `InMemoryModelContainer`) does not exist yet. Drop that sentence or bullet and list it in your report. (Paths that only exist after plan 053, such as `Hugo/DesignSystem` and role folders, are expected to be missing; do not treat them as a STOP.)

## Maintenance notes

- When a plan introduces a convention agents must follow, add it to AGENTS.md section 7 or 8 in the same change.
- Plan 053 makes the repository match section 7 and adds `Scripts/check-layout.sh` to enforce the folder rules. If section 7 changes, update that script too.
- The `## Final repository conventions` section and sections 7 and 8 overlap slightly. Merge them if AGENTS.md is reorganized.
