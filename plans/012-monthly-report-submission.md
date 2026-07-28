# Plan 012: Monthly report submission — reminder, rounding, and send-to-overseer

> **Executor instructions**: Follow this plan step by step. Tasks are ordered;
> each task leaves the app building and all existing tests passing. Run every
> verification command and confirm the expected result before moving to the
> next task. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, add a status row for this plan in
> `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat f869f81..HEAD -- Hugo/Persistence Hugo/Features/Reports Hugo/Features/ServiceYear Hugo/Features/Settings Hugo/Features/Overview Hugo/Domain Hugo/Info.plist Hugo/Resources/Localizable.xcstrings HugoTests`
> If any of these changed since this plan was written, compare the "Current
> state" excerpts against the live code before proceeding; on a mismatch,
> treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: MED
- **Depends on**: none (builds on the landed plan 010/011 Year screen)
- **Category**: direction
- **Planned at**: commit `f869f81`, 2026-07-28
- **Issue**: n/a

## Why this matters

At the end of each month publishers must send a report of their field service
activity to their group overseer. Today Hugo only *displays* monthly totals —
the user must remember the deadline, do the hour-rounding math in their head,
carry leftover minutes into next month manually, and compose the message
themselves. After this plan lands: the Overview tab reminds the user when a
report is due, a submission flow computes rounded totals with a per-user
rounding rule (round up / round down / carry minutes into next month), the
result is persisted as a `SubmittedReport` so the app can warn when a
submitted month is edited afterwards, and the report is handed to Messages as
a pre-filled text addressed to the user's chosen group overseer.

## Current state

### Files that own the behavior today

- `Hugo/Persistence/AppSchema.swift` — declares `SchemaV1`…`SchemaV8`. Current is V8 (version `5,0,0`) with models `[Entry, Tracker, Report]`; `SchemaV8.Report` is an **empty ballast model** (`Hugo/Persistence/SchemaVersions/V8/ReportV8.swift`):

  ```swift
  extension SchemaV8 {
      @Model
      final class Report {
          init() {}
      }
  }
  ```

  `typealias CurrentSchema = SchemaV8`, `typealias Entry = CurrentSchema.Entry`, `typealias Tracker = CurrentSchema.Tracker`. **There is no `Report` alias** (deliberate — see `plans/README.md`).
- `Hugo/Persistence/HugoMigrationPlan.swift` — `MigrationPlan` lists all schemas and stages; `migrateV7toV8` deletes legacy reports and turns them into entries. New stages append to `stages`.
- `Hugo/Persistence/ModelContainerFactory.swift` — `makeProductionContainer()` (default `ModelConfiguration`, i.e. CloudKit on) and `makeInMemoryContainer()` (`cloudKitDatabase: .none`). Both use `Schema(versionedSchema: CurrentSchema.self)` + `MigrationPlan.self`, so a new schema version flows through automatically.
- `Hugo/Domain/YearMonth.swift` — `nonisolated struct YearMonth: Hashable, Comparable { let year: Int; let month: Int }` with `Date.yearMonth(using:)`, `monthYearString(locale:calendar:)`, and `date(day:calendar:)`. **It has no `nextMonth()`** — Task 1 adds one.
- `Hugo/Domain/UserDefaultsKeys.swift` — currently only `hasRunInitialSetup` and `publisherStatus`.
- `Hugo/Features/Reports/Domain/MonthlyReportBuilder.swift` — `@MainActor enum` whose `summaries(from:calendar:locale:)` groups `[Entry]` into `[MonthlyReportSummary]`, already computing `totalSeconds`, `mainDuration`, `separateDuration`, `totalBibleStudies`, and per-category `MonthlyCategorySummary` (with `type: TrackerType?`). This is the aggregation layer the submit flow must reuse — do **not** re-aggregate in views.
- `Hugo/Features/Reports/Domain/ServiceDurationFormatter.swift` — `nonisolated enum` with `string(from:)` producing `"HH:mm"`.
- `Hugo/Features/Reports/MonthlyReportRow.swift` — month card on the Year screen; taps present `MonthlyReportDetailView(summary:)` in a sheet.
- `Hugo/Features/Reports/MonthlyReportDetailView.swift` — sheet listing `MonthlyReportTotalsView` + `MonthlyReportEntryListView`; toolbar has a plus button presenting `AddEntryView(seededDate: summary.id.date())`.
- `Hugo/Features/ServiceYear/Structs/TheocraticYearReport.swift` / `TheocraticYearReportBuilder.swift` — `TheocraticYearMonth { id: YearMonth, displayName, summary: MonthlyReportSummary?, isFuture }`; the builder takes `(year, entries, now, calendar, locale)`. The builder does **not** know about submissions yet.
- `Hugo/Features/ServiceYear/ServiceYearPageView.swift` — renders `MonthlyReportRow` (has summary) or `MonthlyReportEmptyRow` (no summary) per month.
- `Hugo/Features/ServiceYear/MonthlyReportEmptyRow.swift` — placeholder row for entry-less months; tapping past months presents `AddEntryView(seededDate:)`.
- `Hugo/Features/Overview/OverviewView.swift` — root tab. `@Query` of current-month entries (`CurrentMonthInterval`), body is `ScrollView { VStack { MonthlyProgressCard(...); Spacer(minLength: 32); EntryListView(entries:) }.padding() }`. No notion of "report due".
- `Hugo/Features/Settings/SettingsView.swift` — the "Account" sheet (opened via `SettingsButton`). Sections: publisher status, categories link, debug. This is where the "Report" group (rounding default, overseer, greeting) goes.
- `Hugo/Resources/Localizable.xcstrings` — source language `en`, translations `en` + `da`. All UI text is keyed localization (e.g. `"report.bible-studies"`, `"year.month.empty"`). **Every new user-facing string must get both `en` and `da` values.**
- No Contacts or MessageUI usage anywhere in the codebase yet. `Hugo/Info.plist` exists (contains `UIBackgroundModes`/`remote-notification`) with `GENERATE_INFOPLIST_FILE = YES` in the project, so adding `NSContactsUsageDescription` to `Hugo/Info.plist` is sufficient. New Swift files are picked up automatically (synchronized file-system groups) — no pbxproj editing needed.

### Conventions to match

- **Tests** use Swift Testing (`import Testing`, `@Test`, `#expect`, `#require`) and `@MainActor` structs. Model after `HugoTests/Persistence/SchemaMigrationTests.swift` (on-disk store migration: `TemporaryStore`, build a V8 store with `Schema(versionedSchema: SchemaV8.self)` + `cloudKitDatabase: .none`, then reopen with `CurrentSchema` + `MigrationPlan`) and `HugoTests/Features/Reports/MonthlyReportBuilderTests.swift` (fixed GMT calendar + `en_US_POSIX` locale, `InMemoryModelContainer.make()` when persistence is needed).
- **Architecture** (from `AGENTS.md`): iOS 26+/Swift 6 strict concurrency; SwiftUI only; views stay visual; pure value logic lives in structs/enums (no ViewModel); `@Observable @MainActor` classes for stateful workflows; persistence names stay `Tracker` even though the UI says "Category".
- **CloudKit constraint**: every persisted property needs a default value or optionality; no `@Attribute(.unique)`.
- The app-wide naming rule from plan 005: UI vocabulary is "Category"; persisted model names stay `Tracker`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Build | `xcodebuild -project Hugo.xcodeproj -scheme Hugo -destination 'platform=iOS Simulator,name=iPhone 17' build` | `** BUILD SUCCEEDED **` |
| Tests | `xcodebuild -project Hugo.xcodeproj -scheme Hugo -destination 'platform=iOS Simulator,name=iPhone 17' test` | `** TEST SUCCEEDED **` |
| Focused tests | same as above with `-only-testing:HugoTests/<SuiteName>` | all pass |

(If the simulator destination name differs on the executor's machine, list available devices with `xcodebuild -project Hugo.xcodeproj -scheme Hugo -showdestinations` and pick any iOS 26 iPhone.)

## Scope

**In scope** (the only files you should modify or create):

- `Hugo/Domain/RoundingRule.swift` (new)
- `Hugo/Domain/UserDefaultsKeys.swift`
- `Hugo/Domain/YearMonth.swift`
- `Hugo/Persistence/AppSchema.swift`
- `Hugo/Persistence/HugoMigrationPlan.swift`
- `Hugo/Persistence/SchemaVersions/V9/SubmittedReportV9.swift` (new)
- `Hugo/Features/Reports/Domain/ReportRoundingCalculator.swift` (new)
- `Hugo/Features/Reports/Domain/ReportComposer.swift` (new)
- `Hugo/Features/Reports/Domain/ReportReminderSchedule.swift` (new)
- `Hugo/Features/Reports/SubmitReportFormModel.swift` (new)
- `Hugo/Features/Reports/SubmitReportView.swift` (new)
- `Hugo/Features/Reports/OverseerPicker.swift` (new)
- `Hugo/Features/Reports/MonthSubmissionStatusView.swift` (new)
- `Hugo/Features/Reports/MonthlyReportRow.swift`
- `Hugo/Features/Reports/MonthlyReportDetailView.swift`
- `Hugo/Features/Reports/MonthlyReportEntryListView.swift`
- `Hugo/Features/ServiceYear/Structs/TheocraticYearReport.swift`
- `Hugo/Features/ServiceYear/Structs/TheocraticYearReportBuilder.swift`
- `Hugo/Features/ServiceYear/ServiceYearView.swift`
- `Hugo/Features/ServiceYear/ServiceYearPageView.swift`
- `Hugo/Features/ServiceYear/MonthlyReportEmptyRow.swift`
- `Hugo/Features/Overview/ReportReminderCard.swift` (new)
- `Hugo/Features/Overview/OverviewView.swift`
- `Hugo/Features/Settings/SettingsView.swift`
- `Hugo/Features/Settings/OverseerSettingsView.swift` (new)
- `Hugo/Features/Settings/GreetingTemplateView.swift` (new)
- `Hugo/Info.plist`
- `Hugo/Resources/Localizable.xcstrings`
- `HugoTests/**` (new test files under existing conventions)

**Out of scope** (do NOT touch, even though they look related):

- `Hugo/Persistence/SchemaVersions/V1`–`V8` — historical compatibility definitions; never edit.
- `SchemaV8.Report` empty ballast model — removal is a separate, future schema project (see `plans/README.md`, "Findings considered and rejected").
- `Hugo/Persistence/ModelContainerFactory.swift`, `Hugo/App/*` — they reference `CurrentSchema`/`MigrationPlan` symbolically and pick up V9 for free.
- `MonthlyReportBuilder.swift` — its aggregation output is consumed as-is; do not reshape it for this feature.
- Any push-notification-based reminder (would need a server; the reminder is in-app only).
- Editing a submitted report's stored totals after the fact, multi-overseer support, and email/share-sheet exports — deliberate non-goals.

## Product decisions (assumptions, flagged)

1. **Schema evolution, not resurrection.** The empty `SchemaV8.Report` is migration ballast whose removal is deferred by `plans/README.md`. Rather than reviving it (which would couple this feature to that removal), a **new model `SubmittedReport`** is introduced in a new `SchemaV9`. The legacy `Report` stays in V9's model list untouched.
2. **Carry-over affects what you *report*, not what you *record*.** With the `transfer` rounding rule, leftover minutes are added into the *submitted total* of the next month (matching how publishers report carried time), not into the tracked entries. `SubmittedReport.carriedInSeconds` on month N must equal `carriedOutSeconds` of month N−1's submission (or the actual minutes if N−1 used round-up/down, in which case carry-in is zero — the value is derived from the previous submission, not recomputed).
3. **Editing after submission never blocks.** Entries added/edited after submission surface a non-destructive warning ("these entries are not included in the submitted report"). The user may then re-submit: a second `SubmittedReport` for the same month **replaces** the first (keeps `firstSubmittedAt`, refreshes `submittedAt` and all totals).
4. **Due window:** a report for month M becomes due on the **last day of M** and stays due until a `SubmittedReport` for M exists. Only the *previous* calendar month is ever due (at most one reminder card). The reminder shows on the Overview tab.
5. **Empty month with carry-in can be submitted** (submitting pure carried-over minutes is legitimate and is how the carry chain gets recorded), but an empty month **without** carry-in cannot.
6. **Submitting future months is not allowed**; only past months and the current month.
7. **Contacts & Messages**: `MFMessageComposeViewController` (MessageUI) requires a UIKit bridge — acceptable per `AGENTS.md` ("unavoidable" case: there is no SwiftUI message composer). If the device can't send texts, the composer falls back to copying the message body to the pasteboard. The overseer is stored as `fullName + phoneNumber` in `UserDefaults` (the contact identifier is intentionally *not* stored, so greeting/name resolution always reflects the last picked values and no contact-store sync issues arise; re-picking updates them).
8. **Greeting template** lives in `UserDefaults` with an `en`/`da`-aware default ("Hi {first}!" / "Hej {first}!"). Supported tags in v1: `{first}`, `{last}`. Unknown tags are left as-is.

## Steps

### Task 1 — Schema V9 with the `SubmittedReport` model

**Goal** — Persist submitted monthly reports (identity, snapshot totals, rounding audit trail) without touching historical schemas.

**Depends on**: None.

**Precondition**: `CurrentSchema = SchemaV8`; the app builds; `SchemaMigrationTests` pass.

**Context**: See "Current state" for `AppSchema.swift`, the empty `SchemaV8.Report`, and the CloudKit rules (defaults/optional everything, no unique constraints). All category snapshots must be self-contained on the report (a `Tracker` may be renamed or deleted later — same reasoning as `Entry.storedTracker`). The migration from V8 must backfill `entriesClosedAt` from the newest `Entry.createdAt` of each month so pre-existing entries in already-submitted months are not falsely flagged as "added after submission".

**Files to touch**:

- `Hugo/Persistence/SchemaVersions/V9/SubmittedReportV9.swift` (**new**) — `extension SchemaV9 { @Model final class SubmittedReport { ... } }` with these stored properties (all with defaults, CloudKit-safe):

  | Property | Type | Meaning |
  |---|---|---|
  | `year`, `month` | `Int` | Gregorian calendar month identity (matches `YearMonth`) |
  | `firstSubmittedAt` | `Date` | First submission of this month |
  | `submittedAt` | `Date` | Latest submission (== `firstSubmittedAt` unless re-submitted) |
  | `entriesClosedAt` | `Date` | `max(Entry.createdAt)` included in this submission; entries with `createdAt > entriesClosedAt` are "unreported" |
  | `roundingRuleRaw` | `String` | `RoundingRule` raw value used |
  | `fieldServiceSeconds` | `TimeInterval` | Actual (unrounded) total of `.main` categories — "Field Service" |
  | `actualTotalSeconds` | `TimeInterval` | Actual grand total incl. carry-in, before rounding |
  | `submittedHours` | `Int` | The whole-hour total sent to the overseer |
  | `carriedInSeconds` | `TimeInterval` | Minutes carried in from the previous month's submission |
  | `carriedOutSeconds` | `TimeInterval` | Minutes carried out to next month (transfer rule only) |
  | `roundedUpSeconds` | `TimeInterval` | Minutes added by rounding up (0 otherwise) |
  | `roundedDownSeconds` | `TimeInterval` | Minutes dropped by rounding down (0 otherwise) |
  | `totalBibleStudies` | `Int` | Snapshot |
  | `categories` | `[SubmittedCategory]` | Value-type snapshot list (Codable struct stored like `Entry.EntryTracker`) |

  `SubmittedCategory: Codable, Hashable, Identifiable` with `name`, `iconName`, `typeRaw: String`, `actualSeconds`, `submittedHours: Int`, `id` derived from `name` (same pattern as `Entry.EntryTracker` in `Hugo/Persistence/SchemaVersions/V8/EntryV8.swift`).
  Add a `var yearMonth: YearMonth { YearMonth(year: year, month: month) }` computed convenience.

- `Hugo/Persistence/AppSchema.swift` — add `enum SchemaV9: VersionedSchema` (version `6,0,0`, models `[Entry.self, Tracker.self, Report.self, SubmittedReport.self]`, reusing `SchemaV8.Entry/Tracker/Report` via typealiases exactly like earlier versions reused prior models); change `typealias CurrentSchema = SchemaV9`; add `typealias SubmittedReport = CurrentSchema.SubmittedReport`. Keep the existing comment about `SchemaV8.Report` ballast.
- `Hugo/Persistence/HugoMigrationPlan.swift` — append `SchemaV9.self` to `schemas` and add `migrateV8toV9` (`.custom`): for every `SchemaV8.Entry`, group by `date.yearMonth`, and for each group insert a `SchemaV9.SubmittedReport` with **only** `year`, `month`, `firstSubmittedAt = Date.distantPast`, `submittedAt = .distantPast`, and `entriesClosedAt = max(createdAt of the group)` — every other field stays at its zero default. This marks all pre-existing data as "never submitted, but closed up to the newest entry", which the UI must treat as *not submitted* (see Task 2).
- `HugoTests/Persistence/SchemaMigrationTests.swift` — add tests per below.

**Not in this task**: any view, any rounding math, any reminder logic. `SubmittedReport` is persisted but unreachable from UI.

**Tests** (in `HugoTests/Persistence/SchemaMigrationTests.swift`, modeled on the existing V7→V8 tests):
- Migrating a V8 store with entries in two months creates exactly two `SubmittedReport` rows with `submittedAt == .distantPast` and `entriesClosedAt` equal to the newest `createdAt` per month.
- Migrating an empty V8 store creates zero rows.
- A current-schema store round-trips a fully populated `SubmittedReport` including the `categories` snapshot array.

**Verification**:
- `xcodebuild ... -only-testing:HugoTests/SchemaMigrationTests test` → all pass (3 new).
- `xcodebuild ... build` → `** BUILD SUCCEEDED **`.

**Working state after this task**: New model exists and migrates; no UI references it. App behaves exactly as before.

**Acceptance criteria**:
- [ ] `SchemaV9` declared, `CurrentSchema = SchemaV9`, `SubmittedReport` alias exists.
- [ ] `MigrationPlan.stages` ends with `migrateV8toV9`; backfill behavior proven by tests.
- [ ] No file under `SchemaVersions/V1`–`V8` modified.

---

### Task 2 — Rounding, submission-state, composer, and reminder domain logic

**Goal** — All pure logic for the feature, unit-tested, before any UI consumes it.

**Depends on**: Task 1.

**Precondition**: `SubmittedReport` fetchable under the current schema; tests green.

**Context**: Pure value types live under `Hugo/Domain` or `Hugo/Features/<Feature>/Domain` (precedent: `MonthlyReportBuilder`, `ServiceDurationFormatter`). Durations are `TimeInterval` seconds; `ServiceDurationFormatter.string(from:)` renders `HH:mm`. Category redistribution rule (state this in code comments): each category's *actual* seconds are rounded to whole hours using the same proportional split as the total (`floor` each, then distribute the remaining hours to the largest remainders; with the transfer rule the remainder minutes ride along inside `carriedOut`). The main-type ("Field Service") subtotal follows the same rule. `submittedHours` (grand total) = `round(actualTotal + carriedIn)` per the rule; the sum of category hours + distribution must equal it.

**Files to touch**:

- `Hugo/Domain/RoundingRule.swift` (**new**) — `enum RoundingRule: String, Codable, CaseIterable, Identifiable, Sendable { case up, down, transfer }` with a `nameKey: String` returning the localization key (`rounding-rule.up` etc.).
- `Hugo/Domain/UserDefaultsKeys.swift` — add `defaultRoundingRule = "defaultRoundingRule"`, `overseerFullName = "overseerFullName"`, `overseerPhoneNumber = "overseerPhoneNumber"`, `overseerGreetingTemplate = "overseerGreetingTemplate"`.
- `Hugo/Domain/YearMonth.swift` — add `nextMonth(calendar:) -> YearMonth`, `lastDay(calendar:) -> Int`, `endDate(calendar:) -> Date` **if not already present** (plan 011 may have added `endDate`; reuse it — drift-check this file first), and `static func previous(before:calendar:)`.
- `Hugo/Features/Reports/Domain/ReportRoundingCalculator.swift` (**new**) —

  ```swift
  nonisolated struct RoundingComputation {
      let submittedHours: Int
      let categoryHours: [String: Int]   // keyed by MonthlyCategorySummary.id
      let carriedOutSeconds: TimeInterval
      let roundedUpSeconds: TimeInterval
      let roundedDownSeconds: TimeInterval
  }
  nonisolated enum ReportRoundingCalculator {
      static func compute(summary: MonthlyReportSummary, carriedIn: TimeInterval, rule: RoundingRule) -> RoundingComputation
  }
  ```

- `Hugo/Features/Reports/Domain/ReportComposer.swift` (**new**) —

  ```swift
  struct ReportMessageContent { let recipient: String?; let body: String }
  nonisolated enum ReportComposer {
      static func render(template: String, firstName: String, lastName: String) -> String  // {first}/{last}; unknown tags untouched; empty-name edge cases collapse whitespace
      static func message(summary:, computation:, template:, firstName:, lastName:, locale:, calendar:) -> ReportMessageContent
  }
  ```

  Body layout: greeting line, blank line, month name, "Field Service: X h" line, one line per other category, "Bible studies: N" line. Hours render as whole hours (`%lld h`), not `HH:mm`. (Exact keys in Task 6; this task only needs the renderer deterministic for tests.)
- `Hugo/Features/Reports/Domain/ReportReminderSchedule.swift` (**new**) —

  ```swift
  nonisolated enum ReportReminderSchedule {
      static func dueMonth(now: Date, calendar: Calendar = .current) -> YearMonth?  // previous calendar month, only if now >= last day of it
      static func hasUnreportedEntries(report: SubmittedReport?, entries: [Entry], month: YearMonth, calendar: Calendar = .current) -> Bool
  }
  ```

  `hasUnreportedEntries` is true when `report == nil` **or** `report.submittedAt == .distantPast` **or** any entry in `month` has `createdAt > report.entriesClosedAt`. (The `.distantPast` sentinel from Task 1's migration is what distinguishes "never submitted" from "submitted".)
- `HugoTests/Domain/RoundingRuleTests.swift`, `HugoTests/Features/Reports/ReportRoundingCalculatorTests.swift`, `ReportComposerTests.swift`, `ReportReminderScheduleTests.swift` (**new**).

**Not in this task**: SwiftUI, SwiftData writes, Contacts, MessageUI. The calculator takes a `MonthlyReportSummary` value; it does not query.

**Tests** (naming the required cases):
- Calculator: round-up adds `roundedUpSeconds` and yields `ceil`; round-down yields `floor` with `roundedDownSeconds`; transfer yields `floor` with `carriedOutSeconds == remainder`; carry-in participates in the total (`actual 5h20m + carriedIn 40m`, transfer → 6 h submitted, 0 carried out); category hour redistribution sums to `submittedHours` (largest-remainder order, tie-broken by category sort order); zero-minute months need no rounding.
- Composer: `{first}`/`{last}` substitution; unknown `{foo}` untouched; empty last name doesn't leave double spaces; full message contains the formatted month, every category hour, and bible-study count.
- Schedule: due only on/after the last day of the previous month; not due when that month has a real submission; `hasUnreportedEntries` true for newer `createdAt`, false otherwise, true for sentinel reports.
- YearMonth: `nextMonth` across year boundary; `lastDay` for leap February.

**Verification**: `xcodebuild ... -only-testing:HugoTests test` → all pass (existing + new).

**Working state after this task**: Logic proven in isolation; still no UI.

**Acceptance criteria**:
- [ ] All four domain types compile under Swift 6 strict concurrency (`nonisolated` where cross-actor).
- [ ] Every listed test case exists and passes.

---

### Task 3 — Submission status on the Year screen (post-submission warnings)

**Goal** — The Year screen shows each month's submission status and warns when entries were added after submission.

**Depends on**: Tasks 1–2.

**Precondition**: Domain logic available; `ServiceYearView` currently builds `TheocraticYearReportBuilder.report(for:entries:)` without submissions.

**Context**: `TheocraticYearMonth` is the per-month view data. `MonthlyReportRow` and `MonthlyReportEmptyRow` render from it. `MonthlyReportEntryListView` lists `summary.entries` in the detail sheet. Keep views visual: pass computed values in; derive via the builder.

**Files to touch**:

- `Hugo/Features/ServiceYear/Structs/TheocraticYearReport.swift` — add to `TheocraticYearMonth`: `submittedReport: SubmittedReport?`, `hasUnreportedEntries: Bool`, `isSubmitted: Bool` (`submittedReport != nil && submittedAt != .distantPast`).
- `Hugo/Features/ServiceYear/Structs/TheocraticYearReportBuilder.swift` — new parameter `submissions: [SubmittedReport]`; index by `YearMonth`; compute `hasUnreportedEntries` via `ReportReminderSchedule.hasUnreportedEntries` using the month's entries.
- `Hugo/Features/ServiceYear/ServiceYearView.swift` — add `@Query(sort: \SubmittedReport.yearMonth?) private var submissions: [SubmittedReport]` (sort by `year` — pick any stable sort, e.g. `\SubmittedReport.year`); pass into the builder.
- `Hugo/Features/Reports/MonthSubmissionStatusView.swift` (**new**) — small status block used by the row: if `isSubmitted` → checkmark + submission date (+ `hasUnreportedEntries` warning: orange `exclamationmark.triangle.fill` + `report.status.unreported-entries`); if not submitted → nothing (empty).
- `Hugo/Features/Reports/MonthlyReportRow.swift` — render `MonthSubmissionStatusView` under the month title; add a "Submit report" button (`report.submit.button`) that presents `SubmitReportView(month: summary.id)` (button hidden once submitted-without-unreported; shown as "Submit updated report" when unreported entries exist). The sheet type arrives in Task 5 — for this task, present a placeholder `Text("report.submit.placeholder")` sheet behind the same state flag, or simply wire the button and leave the sheet content to Task 5 **only if** the build stays green; preferred: implement the button + flag now, swap the sheet content in Task 5 (single-line change).
- `Hugo/Features/Reports/MonthlyReportDetailView.swift` — when `month.hasUnreportedEntries`, show a banner section at the top of the list (`report.detail.unreported.banner`).
- `Hugo/Features/Reports/MonthlyReportEntryListView.swift` — entries with `createdAt > report.entriesClosedAt` get an inline warning tint/icon (`exclamationmark.triangle.fill`, secondary).
- `Hugo/Features/ServiceYear/MonthlyReportEmptyRow.swift` — non-future empty months gain a `report.submit.button` button when `isSubmitted == false` (legitimate for months that only carry in minutes; Task 5's form decides submittability), plus the same `hasUnreportedEntries` warning presentation when the month *was* submitted (edge: submitted month whose entries were all deleted).
- `Hugo/PreviewSupport/ReportPreviewFixtures.swift` — extend fixtures so at least one month shows submitted + one shows unreported-entries state (may require inserting a `SubmittedReport` into the preview container instead — if so, do it in `PreviewModelContainer` only if strictly needed; keep fixtures value-only where possible).
- `Hugo/Resources/Localizable.xcstrings` — new keys, `en` + `da` (list below in Task 6; add the keys you use now).

**Not in this task**: the submit form itself, reminder card, settings. No Contacts/MessageUI.

**Tests**: extend `HugoTests/Features/TheocraticYear/TheocraticYearReportBuilderTests.swift` — builder maps submissions to months, sets `isSubmitted`, and flags `hasUnreportedEntries` exactly per `ReportReminderSchedule` semantics (including the `.distantPast` sentinel case).

**Verification**: build + full test suite pass; previews render the three states (unsubmitted / submitted / submitted-with-new-entries).

**Working state after this task**: Users can see submission status and post-submission warnings on the Year screen (driven by Task 1's backfill: everything shows "not submitted" — no false warnings on existing data). The submit button exists but its form is a stub.

**Acceptance criteria**:
- [ ] Months with `submittedAt != .distantPast` show the submitted state; sentinel rows do not.
- [ ] An entry created after `entriesClosedAt` triggers both the row-level warning and the entry-level marker.
- [ ] Existing tests unmodified and green.

---

### Task 4 — Overview reminder card

**Goal** — A reminder to submit appears on the Overview tab from the last day of the month until that month is submitted.

**Depends on**: Tasks 1–2 (independent of Task 3; either order, but do not reorder the numbering).

**Precondition**: `OverviewView` shows `MonthlyProgressCard` + `EntryListView` for the current month only.

**Context**: `OverviewView`'s `@Query` is scoped to the current month; the reminder concerns the *previous* month, so it needs its own data. `ReportReminderSchedule.dueMonth(now:)` (Task 2) decides whether anything is due at all.

**Files to touch**:

- `Hugo/Features/Overview/ReportReminderCard.swift` (**new**) — card matching the existing visual language (`Color(.secondarySystemGroupedBackground)`, 32 pt corner radius, padded 24): `exclamationmark.paperplane.fill` (or similar) icon, `report.reminder.title` (month name interpolated), `report.reminder.description`, and a primary button `report.reminder.action` presenting `SubmitReportView(month: dueMonth)`. Until Task 5 lands, the button may present the same stub sheet as Task 3 (single-line swap later).
- `Hugo/Features/Overview/OverviewView.swift` — add `@Query private var submissions: [SubmittedReport]` and a second `@Query` for previous-month entries only when the reminder is relevant. Simplest correct approach: keep the existing filtered query and add an unfiltered `@Query private var allEntries: [Entry]` is **not** acceptable (performance); instead compute `dueMonth` first, and if non-nil, query entries for that month with a `#Predicate` using the same `CurrentMonthInterval`-style bounds for the *previous* month — since `@Query` predicates are fixed at init, gate the whole card on `dueMonth != nil` and accept the predicate being built for "previous month of view appearance" (the view re-inits on tab re-entry; acceptable and simple). Insert `ReportReminderCard` above `MonthlyProgressCard` when `dueMonth` is non-nil and that month has no real submission.

**Not in this task**: badge counts, notifications, snooze. The card disappears solely by submitting.

**Tests**: `ReportReminderSchedule` already covered in Task 2. Add a lightweight test in `HugoTests/Features/Overview/` only if the gating logic grows beyond a direct call to `dueMonth` — otherwise state "covered by ReportReminderScheduleTests" in the PR description.

**Verification**: build + tests; manually in simulator: set device date to the last day of a month with prior-month entries → card appears; submit (stub) → relaunch → card gone once a real `SubmittedReport` exists.

**Working state after this task**: The reminder renders and routes to the (stubbed) submit sheet.

**Acceptance criteria**:
- [ ] Card visible exactly when `dueMonth != nil` && month not really submitted.
- [ ] No change to `MonthlyProgressCard`, metrics, or the existing entries query.

---

### Task 5 — Submit report flow (form, carry chain, Messages composer)

**Goal** — The user reviews computed totals, picks a rounding rule, and sends the report via Messages; submission persists a `SubmittedReport` (re-submission replaces).

**Depends on**: Tasks 1–3 (Task 4's stub swap is one line; fold it in).

**Precondition**: Domain logic tested; rows/cards present `SubmitReportView(month:)` (currently stubs).

**Context**: AGENTS.md prefers no UIKit wrapper "unless absolutely unavoidable" — `MFMessageComposeViewController` has no SwiftUI equivalent, so a `UIViewControllerRepresentable` is the accepted pattern. State workflows use `@Observable @MainActor` classes (precedent: `AddEntryFormModel`). The form queries `Tracker`s and `Entry`/`SubmittedReport` via the environment context.

**Files to touch**:

- `Hugo/Features/Reports/SubmitReportFormModel.swift` (**new**) — `@Observable @MainActor final class SubmitReportFormModel`:

  - Inputs: `month: YearMonth`, `context: ModelContext`, `calendar`, `now`, plus `defaultRoundingRule` read from `UserDefaults` (key from Task 2).
  - Derived: `summary: MonthlyReportSummary?` (via `MonthlyReportBuilder.summaries` on the month's entries), `previousSubmission` (month − 1), `carriedIn` (previous submission's `carriedOutSeconds`), `computation` (via `ReportRoundingCalculator.compute(summary:carriedIn:rule:)`), `selectedRule: RoundingRule` (seeded from the default), `isSubmittable` (summary has entries OR carry-in > 0; month not in the future).
  - `submit()` — builds the message via `ReportComposer.message`, then **either** presents the MessageUI composer (if `MFMessageComposeViewController.canSendText()`) **or** copies the body via `UIPasteboard.general.string` and surfaces a "copied" notice; on confirmed send/copy, persists: delete any existing `SubmittedReport` for the month, insert the new snapshot (all fields from Task 1's table; `entriesClosedAt = max(entry.createdAt)`; preserve `firstSubmittedAt` when replacing), `context.save()`.
  - Keep UIKit imports out of the model: the representable reports `didFinish` back through a closure; the model owns persistence only.

- `Hugo/Features/Reports/SubmitReportView.swift` (**new**) — sheet (matches `MonthlyReportDetailView` chrome: inline title, `xmark` cancel toolbar item):
  - Month title + `report.submit.subtitle`.
  - Rounding rule picker (`Picker` with the three `RoundingRule.nameKey`s, segmented style) bound to the model.
  - Totals section mirroring `MonthlyReportTotalsView`'s look but showing *computed submitted hours*: "Field Service" (main types), each other category with computed hours, carry-in line (when > 0), carried-out/rounded line (when applicable), bible studies.
  - Overseer section: if `UserDefaultsKeys.overseerPhoneNumber` is empty → hint text + button linking to Settings; else shows the overseer name.
  - Primary button `report.submit.send` (disabled when `!isSubmittable`) → `submit()`.
  - Replace the two stub sheets from Tasks 3–4 with `SubmitReportView(month:)`.
- `Hugo/Features/Reports/OverseerPicker.swift` (**new**) — contains *both* bridges, used here and in Task 6 settings:
  - `OverseerContactPicker: UIViewControllerRepresentable` wrapping `CNContactPickerViewController` (ContactsUI), `predicateForEnablingContact: NSPredicate(format: "phoneNumbers.@count > 0")`, on select → callback `(fullName, phoneNumber, firstName, lastName)` where first/last come from `CNContact.givenName/familyName`.
  - `MessageComposeView: UIViewControllerRepresentable` wrapping `MFMessageComposeViewController` with recipients + body and a `didFinish: (Bool) -> Void`.
- `Hugo/Features/Reports/MonthlyReportRow.swift`, `MonthlyReportEmptyRow.swift`, `Hugo/Features/Overview/ReportReminderCard.swift` — swap stub sheets for `SubmitReportView(month:)`.
- `Hugo/Resources/Localizable.xcstrings` — keys for all of the above, `en` + `da`.

**Not in this task**: settings UI for the overseer/greeting/default rule (Task 6) — the form *reads* the defaults but provides only the deep-link hint when no overseer is set. No actual SMS sending in tests.

**Tests** (`HugoTests/Features/Reports/SubmitReportFormModelTests.swift`, **new**; model after `AddEntryFormModelTests`):
- Computation refreshes when `selectedRule` changes; `carriedIn` derives from the previous month's submission, zero when none or when previous used up/down.
- `persist()` (factor the SwiftData write into a `persistSubmission()` method so tests skip Messages): inserts one snapshot with correct totals and `entriesClosedAt`; calling again for the same month replaces (count stays 1, `firstSubmittedAt` preserved, `submittedAt`/`entriesClosedAt` refreshed).
- `isSubmittable` matrix: future month false; empty month without carry-in false; empty month with carry-in true.
- Composer formatting covered in Task 2; here only assert the model hands the right inputs to it (via the produced `ReportMessageContent`).

**Verification**: full test suite; manual simulator run: submit a month with 5 h 20 m under each rule and verify persisted snapshot + message text; re-submit same month → one row; delete the month's tracker afterwards → snapshot categories still render.

**Working state after this task**: End-to-end submission works from Year rows and the reminder card.

**Acceptance criteria**:
- [ ] Exactly one `SubmittedReport` per month under any sequence of submits.
- [ ] Carry chain: month N's `carriedInSeconds` == month N−1's `carriedOutSeconds`.
- [ ] Messages composer pre-filled with overseer number + localized body; pasteboard fallback when `canSendText()` is false.
- [ ] Build green with strict concurrency (representables are `Sendable`-safe; no `DispatchQueue.main.async` anywhere).

---

### Task 6 — Settings: default rounding rule, group overseer, greeting template

**Goal** — The Account screen lets the user set their default rounding rule, pick their group overseer from Contacts, and customize the greeting template.

**Depends on**: Tasks 2 and 5 (reuses `RoundingRule`, `OverseerContactPicker`, `ReportComposer.render`).

**Precondition**: `SettingsView` has publisher-status / categories / debug sections.

**Context**: `SettingsView` uses `List` + `Section` with `NavigationLink`s and `@AppStorage`. `Hugo/Info.plist` exists with `GENERATE_INFOPLIST_FILE = YES`, so adding the contacts usage key is a plain plist edit. All strings need `en` + `da`.

**Files to touch**:

- `Hugo/Info.plist` — add `NSContactsUsageDescription` with a user-facing reason (must itself be localizable via the xcstrings `InfoPlist` mechanism if the project already localizes Info.plist strings — it does not; a Danish-appropriate bilingual-safe English/Danish single string is acceptable here, but prefer adding `InfoPlist.xcstrings` **only if** trivial; otherwise use a Danish string, matching the app's primary audience — flag the choice in the PR).
- `Hugo/Features/Settings/SettingsView.swift` — new "Report" section (above the categories section):
  - `NavigationLink` → rounding rule picker row showing current `RoundingRule` name.
  - `NavigationLink` → `OverseerSettingsView` showing overseer full name or `report.overseer.empty`.
  - `NavigationLink` → `GreetingTemplateView` showing a one-line preview of the rendered greeting.
- `Hugo/Features/Settings/OverseerSettingsView.swift` (**new**) — shows current overseer (name + phone), button `report.overseer.pick` presenting the `OverseerContactPicker` (from Task 5) which writes `overseerFullName`/`overseerPhoneNumber` (+ given/family names for tag rendering — store as two more keys, `overseerFirstName`/`overseerLastName`, added to `UserDefaultsKeys`), and a `report.overseer.clear` destructive button when set.
- `Hugo/Features/Settings/GreetingTemplateView.swift` (**new**) — `TextEditor`/`TextField` bound to `overseerGreetingTemplate` (default `"Hi {first}!"`/`"Hej {first}!"` per locale when unset), a live preview rendered through `ReportComposer.render(template:firstName:lastName:)` using stored overseer names (or placeholder names when unset), and a short footer listing the supported tags `{first}` `{last}` (`report.greeting.footer`).
- Rounding-rule selection can live directly in the section as a `Picker` (three cases) rather than a separate screen — match `PublisherStatusSelectionView`'s pattern if a separate view reads better; pick one, keep it simple.
- `Hugo/Domain/UserDefaultsKeys.swift` — add `overseerFirstName`, `overseerLastName` (if not added in Task 5 — coordinate: they belong to whichever task lands the picker write; put them in Task 6 and have Task 5 read only, guarded for absence).
- `Hugo/Resources/Localizable.xcstrings` — all keys, `en` + `da`.

**Not in this task**: validation of the phone number, multiple overseers, contact-identifier persistence (decision 7), per-month greeting overrides.

**Tests**: none required for the thin settings views beyond Task 2's `ReportComposer.render` coverage; add a `UserDefaults`-round-trip test only if a new mapping layer is introduced (it should not be).

**Verification**: build + full suite; manual: pick an overseer (contacts permission prompt shows the new usage string), change the template with `{first}`, submit a report → message greeting reflects both.

**Working state after this task**: The feature is fully configurable; shipping-complete.

**Acceptance criteria**:
- [ ] All new UI text has `en` + `da` values; no raw keys visible anywhere (the previous raw-key bug must not regress).
- [ ] Permission prompt appears exactly once with a sensible usage string.
- [ ] Defaults flow: changing the default rule changes the *initial* rule in the submit form without locking the per-submission choice.

---

### Required localization keys (en / da) — final list owned by Tasks 3–6

| Key | en | da |
|---|---|---|
| `rounding-rule.up` | Round up | Rund op |
| `rounding-rule.down` | Round down | Rund ned |
| `rounding-rule.transfer` | Transfer to next month | Overfør til næste måned |
| `report.submit.button` | Submit Report | Indsend rapport |
| `report.submit.resubmit` | Submit Updated Report | Indsend opdateret rapport |
| `report.submit.subtitle` | Review and send your monthly report | Gennemse og send din månedsrapport |
| `report.submit.send` | Send to Group Overseer | Send til gruppetjeneren |
| `report.submit.copied` | Report copied — paste it into a message to your group overseer | Rapporten er kopieret — sæt den ind i en besked til din gruppetjener |
| `report.reminder.title` | Time to submit your %@ report | Tid til at indsende din rapport for %@ |
| `report.reminder.description` | The month has ended. Send your report to your group overseer. | Måneden er slut. Send din rapport til din gruppetjener. |
| `report.reminder.action` | Review Report | Gennemse rapport |
| `report.status.submitted` | Submitted %@ | Indsendt %@ |
| `report.status.unreported-entries` | New entries are not included in the submitted report | Nye registreringer er ikke med i den indsendte rapport |
| `report.detail.unreported.banner` | Entries added after submission are marked below. Submit an updated report to include them. | Registreringer tilføjet efter indsendelsen er markeret nedenfor. Indsend en opdateret rapport for at medtage dem. |
| `report.overseer.empty` | No group overseer selected | Ingen gruppetjener valgt |
| `report.overseer.pick` | Choose Group Overseer | Vælg gruppetjener |
| `report.overseer.clear` | Remove Group Overseer | Fjern gruppetjener |
| `report.greeting.footer` | Use {first} and {last} to insert the group overseer's name. | Brug {first} og {last} til at indsætte gruppetjenerens navn. |
| `settings.group.report` | Report | Rapport |
| `settings.report.rounding-rule` | Rounding Rule | Afrundingsregel |
| `settings.report.overseer` | Group Overseer | Gruppetjener |
| `settings.report.greeting` | Greeting | Hilsen |

(Executor may adjust Danish for tone; both languages are mandatory per key.)

## Test plan

- New suites: `RoundingRuleTests`, `ReportRoundingCalculatorTests`, `ReportComposerTests`, `ReportReminderScheduleTests`, `SubmitReportFormModelTests`; extended: `SchemaMigrationTests`, `TheocraticYearReportBuilderTests`, `YearMonthTests`.
- Structural patterns: `HugoTests/Persistence/SchemaMigrationTests.swift` (TemporaryStore + explicit versioned schemas) and `HugoTests/Features/Reports/MonthlyReportBuilderTests.swift` (fixed GMT calendar, `en_US_POSIX`).
- Verification: `xcodebuild -project Hugo.xcodeproj -scheme Hugo -destination 'platform=iOS Simulator,name=iPhone 17' test` → all pass.

## Done criteria

- [ ] `xcodebuild ... build` and `... test` both succeed; no existing test modified in behavior.
- [ ] `SubmittedReport` persists identity, snapshot totals (Field Service + per category), submitted whole hours, and the full rounding audit trail (carry-in/out, rounded up/down amounts).
- [ ] Overview shows the reminder exactly from the last day of the month until submission.
- [ ] Year screen shows submitted state and post-submission entry warnings at row and entry level.
- [ ] Messages composer opens addressed to the chosen overseer with localized greeting + report; pasteboard fallback works when Messages is unavailable.
- [ ] `git status` shows no modifications outside the in-scope list.
- [ ] `plans/README.md` gains a row: `| 012 | Monthly report submission — reminder, rounding, and send-to-overseer | P1 | L | 010, 011 | DONE |`.

## STOP conditions

Stop and report back (do not improvise) if:

- `SchemaV8.Report` is not empty or `CurrentSchema` is not `SchemaV8` at drift-check time — the persistence layer drifted; re-plan.
- Backfilling `SubmittedReport` rows during V8→V9 migration turns out to make CloudKit initial sync upload thousands of synthetic rows for existing users in a way the team considers unacceptable. If flagged, replace the backfill with *no rows* and make every "not submitted" code path treat "no row" and the sentinel identically (the Task 2 schedule API already isolates this decision — change it there only).
- `CNContactPickerViewController` cannot supply given/family names reliably enough for `{first}`/`{last}` (e.g. limited-contact-access on iOS 26 returns empty name components). Fall back to splitting `CNContactFormatter` output and flag it.
- `MFMessageComposeViewController` is unavailable in the target runtime for reasons other than `canSendText() == false` (e.g. iPad without SIM behaves differently than assumed) — keep the pasteboard fallback as the primary path and report.
- A step's verification fails twice after a reasonable fix attempt, or the fix requires touching an out-of-scope file (in particular anything under `SchemaVersions/V1`–`V8` or `ModelContainerFactory.swift`).

## Maintenance notes

- **Removing the ballast `SchemaV8/V9.Report`** must remain a separate schema project; do not let a future executor "clean it up" inside a feature branch — `plans/README.md` explains why.
- `entriesClosedAt` vs. entry *edits*: SwiftData `Entry` has no `updatedAt`, so edits to pre-existing old entries are invisible to the warning system. If that ever matters, add `updatedAt` in a future schema version and compare against it in `ReportReminderSchedule.hasUnreportedEntries` — one isolated call site.
- The carry chain is only as strong as its derivation rule (previous submission's `carriedOutSeconds`). Skipping a month (submitting month N without N−1) yields zero carry-in by design; if users ask for "unclaimed" carry, that is a product decision, not a bug.
- Reviewers should scrutinize, in order: the V8→V9 backfill (sentinel + `entriesClosedAt`), the largest-remainder category hour redistribution (must always sum to `submittedHours`), the re-submit replace semantics (never two rows per month), and the Danish localization of the message body.
- Deliberately deferred: push/local-notification reminders, editing stored snapshots, share-sheet/email export, storing the contact identifier, multi-overseer, and an "unsubmit" affordance.

---

**Boundaries of this planning pass**

- No implementation was performed.
- Investigation was limited to the requested submission feature and its direct dependencies (schema/migration chain, report aggregation domain, Year screen, Overview, Settings, localization catalog, test support).
- No whole-codebase audit was performed.
- No unrelated fixes, cleanup, refactors, or roadmap work are included; the only planned new persistence type is the one the feature requires.
