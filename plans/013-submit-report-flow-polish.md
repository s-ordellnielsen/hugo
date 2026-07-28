# Plan 013: Polish the submit report flow — localized hours, greeting {month}/{year} tags, orange send button, and a month-card dropdown

> **Executor instructions**: Follow this plan task by task, in order. Run every
> verification command and confirm the expected result before moving to the
> next task. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for plan 013
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 32ef3d3..HEAD -- Hugo/Features/Reports/SubmitReportView.swift Hugo/Features/Reports/Domain/ReportComposer.swift Hugo/Features/Reports/MonthlyReportRow.swift Hugo/Features/Settings/GreetingTemplateView.swift Hugo/Domain/YearMonth.swift Hugo/Resources/Localizable.xcstrings HugoTests/Features/Reports/ReportComposerTests.swift HugoTests/Features/Reports/YearMonthTests.swift plans/README.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/012-monthly-report-submission.md (DONE)
- **Category**: bug (Danish hours unit) + requested behavior changes
- **Planned at**: commit `32ef3d3`, 2026-07-28

## Why this matters

The monthly report submission flow shipped in plan 012. Four problems were
reported against it:

1. The floating **Send to Group Overseer** button renders black, not orange.
   Root cause: `MonthlyReportRow` applies `.tint(.primary)` to the whole card,
   and that tint propagates through the presented sheet into the
   `.borderedProminent` button.
2. The composed message force-inserts a `June 2026` line between the greeting
   and the numbers. The user wants `{month}` and `{year}` as greeting-template
   tags instead, so they can position them freely (or omit them).
3. Hours render as `5 h` everywhere. In Danish the correct unit is `t`
   (`5 t`). The literal `" h"` is hardcoded in two places.
4. The Year screen shows an inline **Submit Report** button at the bottom of
   each month card, and it disappears once a month is submitted (unless new
   entries appear). The user wants the card's chevron replaced by a dropdown
   menu that offers submission **at any time**, because re-submitting is a
   legitimate action even when nothing warns about it.

## Current state

All paths are relative to the repository root.

- `Hugo/Features/Reports/SubmitReportView.swift` — the submit sheet. The
  floating send button (around lines 136–148):

  ```swift
  .safeAreaInset(edge: .bottom) {
      Button {
          sendViaMessages()
      } label: {
          Text("report.submit.send")
              .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(!model.isSubmittable || !MessageComposeView.canSendText)
      .padding(.horizontal)
      .padding(.vertical, 8)
  }
  ```

  Per-category hours row (around line 177): `Text("\(model.computation.categoryHours[category.id] ?? 0) h")`.

- `Hugo/Features/Reports/Domain/ReportComposer.swift` — message builder.

  ```swift
  static func render(template: String, firstName: String, lastName: String) -> String {
      let rendered = template
          .replacingOccurrences(of: "{first}", with: firstName)
          .replacingOccurrences(of: "{last}", with: lastName)
      return rendered
          .components(separatedBy: .whitespacesAndNewlines)
          .filter { !$0.isEmpty }
          .joined(separator: " ")
          .trimmingCharacters(in: .whitespacesAndNewlines)
  }
  ```

  Note: this **flattens newlines** — multi-line templates become one line.
  `message(...)` builds `var lines: [String] = [greeting, "", month]` where
  `month = summary.id.monthYearString(locale: locale, calendar: calendar)`,
  then appends `"Field Service: \(fieldServiceHours) h"`, one
  `"\(category.name): \(hours) h"` per non-main category, and
  `"Bible studies: \(n)"`. Category labels resolve via `String(localized:)`.

- `Hugo/Features/Reports/SubmitReportFormModel.swift` — calls
  `ReportComposer.message(summary:computation:template:firstName:lastName:calendar:)`
  from `prepareSubmission()` (no `locale:` argument; the default `.current`
  is used). The stored greeting template comes from
  `UserDefaultsKeys.overseerGreetingTemplate`, falling back to `"Hi {first}!"`.
  **No change is needed in this file.**

- `Hugo/Features/Reports/MonthlyReportRow.swift` — the Year-screen month card.
  Header shows the month name and a decorative chevron:

  ```swift
  Spacer()
  Image(systemName: "chevron.right")
      .foregroundStyle(.tertiary)
      .font(.caption)
  ```

  The whole card has `.onTapGesture { isExpanded.toggle() }` (opens the detail
  sheet) and `.tint(.primary)`. At the bottom:

  ```swift
  if !month.isFuture && (!month.isSubmitted || month.hasUnreportedEntries) {
      Button(submitButtonTitle) {
          isPresentingSubmitSheet.toggle()
      }
      .buttonStyle(.bordered)
      .padding(.top, 12)
  }
  ```

  `submitButtonTitle` returns `report.submit.resubmit` when
  `month.isSubmitted && month.hasUnreportedEntries`, else
  `report.submit.button`.

- `Hugo/Features/Settings/GreetingTemplateView.swift` — greeting editor.
  `effectiveTemplate` falls back to `String(localized: "report.greeting.default")`;
  the preview calls `ReportComposer.render(template:firstName:lastName:)`.
  The footer key `report.greeting.footer` currently reads
  `Use {first} and {last} to insert the group overseer's name.` /
  `Brug {first} og {last} til at indsætte gruppetjenerens navn.`

- `Hugo/Domain/YearMonth.swift` — `monthYearString(locale:calendar:)` formats
  with `DateFormatter` dateFormat `"LLLL yyyy"`. There is no month-name-only
  helper.

- `Hugo/Resources/Localizable.xcstrings` — single catalog, `sourceLanguage:
  en`, every shipped key has both `en` and `da` values (this is a hard repo
  convention — plan 012 had a "raw keys visible" bug that must not regress).

### Conventions to match

- **Localization**: add/edit keys in `Hugo/Resources/Localizable.xcstrings`
  with **both `en` and `da`** `stringUnit` values. `String(localized:)` is
  used inside the composer (see `report.compose.field-service`); SwiftUI
  views use `Text("key")` / `Button("key")`.
- **Menus**: `EntryDetailView.swift` (lines ~74–85) is the exemplar:
  `Menu { Button("key", systemImage: ...) {...} } label: { Label("common.more", systemImage: "ellipsis") }`.
  The key `common.more` already exists (en `More` / da `Mere`).
- **Orange accent**: `OnboardingView.swift` uses `.tint(.orange)` and
  `Color.orange`; `MonthSubmissionStatusView` uses `.foregroundStyle(.orange)`.
- **Tests**: swift-testing (`import Testing`, `@Test`, `#expect`), modeled on
  `HugoTests/Features/Reports/ReportComposerTests.swift` — fixed GMT gregorian
  calendar, `en_US_POSIX` locale, `String(localized:)` resolves to the
  development language (en) in tests.
- **Git**: work happens directly on `main`, one commit per task, message
  style `` `013` Task 01 — <short title> `` (see `git log` for plan 012).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Build | `xcodebuild -project Hugo.xcodeproj -scheme Hugo -destination 'platform=iOS Simulator,name=iPhone 17' build` | `BUILD SUCCEEDED` |
| Tests | `xcodebuild -project Hugo.xcodeproj -scheme Hugo -destination 'platform=iOS Simulator,name=iPhone 17' test` | all tests pass |
| Manual Danish check | run the app on a simulator with device language set to Dansk | hours show `t`, greeting renders tags |

## Scope

**In scope** (the only files you may modify):

- `Hugo/Features/Reports/Domain/ReportComposer.swift`
- `Hugo/Features/Reports/SubmitReportView.swift`
- `Hugo/Features/Reports/MonthlyReportRow.swift`
- `Hugo/Features/Settings/GreetingTemplateView.swift`
- `Hugo/Domain/YearMonth.swift`
- `Hugo/Resources/Localizable.xcstrings`
- `HugoTests/Features/Reports/ReportComposerTests.swift`
- `HugoTests/Features/Reports/YearMonthTests.swift`
- `plans/README.md` (status row only)

**Out of scope** (do NOT touch, even though they look related):

- `Hugo/Features/ServiceYear/MonthlyReportEmptyRow.swift` — it also has an
  inline submit button, but it has no chevron, and that button is the *only*
  submit affordance for zero-entry months (a deliberate 012 feature: empty
  months are submittable). Removing it would strand the feature. See
  Decision D3.
- `Hugo/Features/Overview/ReportReminderCard.swift` — separate surface, not
  part of the request.
- `Hugo/Features/Reports/SubmitReportFormModel.swift`,
  `Domain/ReportRoundingCalculator.swift`, `Domain/ServiceDurationFormatter.swift`,
  persistence (`Hugo/Persistence/**`), `OverseerPicker.swift` /
  `MessageComposeView` — untouched by this plan.
- No schema/version changes of any kind.

## Decisions (recommended — adjust only if the reviewer disagrees)

- **D1 — Default greeting gains the month tag.** Since the composer no longer
  appends the month line, the localized default template changes to keep the
  month in the message for everyone who never customized it:
  en `Hi {first}!\nHere is my report for {month}.` /
  da `Hej {first}!\nHer er min rapport for {month}.`
  Users with a *customized* stored template keep it verbatim and will no
  longer get an automatic month line — that is exactly the requested
  trade-off ("so the user can include it where they want").
- **D2 — Menu trigger icon: `ellipsis`** with accessibility label
  `common.more`, matching the `EntryDetailView` menu convention. It sits in
  the header where the chevron was, styled `.font(.caption)` /
  `.foregroundStyle(.tertiary)` is NOT recommended for the trigger — keep it
  visible: use secondary or default prominence. (Alternative if the reviewer
  prefers continuity: `chevron.down`.)
- **D3 — `MonthlyReportEmptyRow` is unchanged.** Its small caption button is
  the only way to submit an empty month. Consistency can be revisited later.
- **D4 — The menu also contains "View Details"** (opens the same detail
  sheet as tapping the card) because the chevron it replaces implied
  navigation. Submit is listed first.
- **D5 — Tag values**: `{month}` = localized full month name (`LLLL`,
  e.g. `June` / `juni`); `{year}` = plain 4-digit year (`2026`).
- **D6 — `render` preserves line breaks.** "Include it where they want"
  includes "on its own line", so the whitespace normalization is reworked to
  collapse spaces *within* each line (keeping the empty-name double-space
  fix) and drop empty lines, instead of flattening everything to one line.

## Git workflow

- Branch: `main` (repo convention; plan 012 shipped this way).
- One commit per task: `` `013` Task 01 — Localize hours unit `` etc.
- Do NOT push unless the operator instructs it.

## Task Overview

| # | Task | Depends on | Leaves app in this state | Verified by |
|---|------|-----------|--------------------------|-------------|
| 1 | Localize the hours unit (`h`/`t`) | None | Submit sheet and message body use a catalog unit; Danish shows `t` | build + existing composer tests + grep for `" h"` + manual Danish run |
| 2 | Add `{month}`/`{year}` greeting tags and drop the built-in month line | None | Message body has no forced month line; greeting editor documents and previews the new tags | build + updated/new composer and YearMonth tests + manual run |
| 3 | Make the send button orange | None | Floating send button renders orange regardless of presenter tint | build + manual visual check (light + dark) |
| 4 | Replace the card chevron with an always-available submit dropdown | None | Month cards have a menu with Submit (always, for non-future months) and View Details; inline bottom button removed | build + manual simulator walkthrough of all three month states |

Tasks 1–4 are mutually independent; they are ordered so the two composer-surface
changes (1, 2) land before the two pure-view changes (3, 4).

---

## Task 1 — Localize the hours unit so Danish shows "t" instead of "h"

**Goal**: both the submit sheet's per-category hours and the composed message
body render the unit through one localized string (en `h`, da `t`).

**Depends on**: None.

**Precondition**: drift check passed; `ReportComposer.swift` and
`SubmitReportView.swift` match the excerpts in "Current state".

**Context**: The literal `" h"` exists in exactly three places (verified by
`grep -rn ') h"' Hugo --include="*.swift"`):

- `Hugo/Features/Reports/Domain/ReportComposer.swift` lines ~48 and ~51
  (message body, field-service line and per-category lines)
- `Hugo/Features/Reports/SubmitReportView.swift` line ~177 (`computedRow`)

`ServiceDurationFormatter` (`HH:MM`) is unrelated — do not touch it.
`String(localized:)` inside the composer resolves to the device's locale at
runtime and to the development language (en) in unit tests — same behavior as
the existing `report.compose.field-service` key.

**Files to touch**:

- `Hugo/Resources/Localizable.xcstrings` — add key `report.hours.unit`:
  en `h`, da `t`. (Edit in Xcode's catalog editor, or insert well-formed
  JSON `localizations`/`stringUnit` entries matching neighboring keys.)
- `Hugo/Features/Reports/Domain/ReportComposer.swift` — use the unit.
- `Hugo/Features/Reports/SubmitReportView.swift` — use the unit.
- `HugoTests/Features/Reports/ReportComposerTests.swift` — no expectation
  changes required (tests resolve to en ⇒ still ` h`); add nothing here.

**Steps**:

1. Add `report.hours.unit` to the catalog (en `h`, da `t`).
2. In `ReportComposer.message(...)`, near the top add
   `let hoursUnit = String(localized: "report.hours.unit")` and change the
   two append sites to
   `"Field Service: \(fieldServiceHours) \(hoursUnit)"` (keeping the
   `fieldServiceLabel` localization) and
   `"\(category.name): \(computation.categoryHours[category.id] ?? 0) \(hoursUnit)"`.
3. In `SubmitReportView.computedRow(_:)`, change the text to
   `Text("\(model.computation.categoryHours[category.id] ?? 0) \(String(localized: "report.hours.unit"))")`.
4. Commit: `` `013` Task 01 — Localize hours unit ``.

**Not in this task**: the greeting template / month-line work (Task 2), the
button tint (Task 3), the card menu (Task 4). Do not touch
`ServiceDurationFormatter` or any total row that shows `HH:MM`.

**Tests**: no new tests; `ReportComposerTests` must keep passing unchanged
(en expectations such as `"Field Service: 5 h"` remain valid).

**Verification**:

- `xcodebuild -project Hugo.xcodeproj -scheme Hugo -destination 'platform=iOS Simulator,name=iPhone 17' test` → all pass.
- `grep -rn ') h"' Hugo --include="*.swift"` → no matches.
- Manual: simulator set to Dansk → submit sheet shows e.g. `5 t`; the
  composed message (Copy Report) shows `Felttjeneste: 5 t`. Device set to
  English → `5 h` in both places.

**Working state after this task**: fully shippable; hours unit localized
everywhere the whole-hour value appears.

**Acceptance criteria**:

- [ ] Tests pass with zero modifications to existing expectations.
- [ ] No `" h"` string literals remain in app sources.
- [ ] Danish device shows `t`, English device shows `h`, in both the sheet
  and the message body.

---

## Task 2 — Add `{month}`/`{year}` greeting tags and remove the built-in month line

**Goal**: the composed message no longer auto-inserts a `Month Year` line;
`ReportComposer.render` substitutes `{month}` and `{year}` (and preserves
line breaks); the greeting settings screen documents the tags and previews
them with the current month.

**Depends on**: None (independent of Task 1; if both touch
`ReportComposer.swift`, land Task 1 first and rebase/merge trivially).

**Precondition**: drift check passed; `ReportComposer.swift`,
`GreetingTemplateView.swift`, and `YearMonth.swift` match "Current state".

**Context**:

- `render(template:firstName:lastName:)` currently supports `{first}`/`{last}`
  and flattens all whitespace **including newlines** (see excerpt). Decision
  D6 reworks normalization: collapse runs of spaces within each line
  (preserving the existing empty-name double-space fix, verified by
  `renderCollapsesWhitespaceLeftByEmptyNames`), drop empty lines, join with
  `\n`.
- `message(...)` builds `[greeting, "", month]`; the `month` element and the
  `let month = summary.id.monthYearString(...)` local go away. Keep the
  blank separator (`""`) after the greeting.
- `SubmitReportFormModel.prepareSubmission()` calls `message(...)` with the
  existing signature — `message` computes the tag values internally from
  `summary.id`, `locale`, and `calendar`. **Do not modify the form model.**
- `GreetingTemplateView`'s preview calls `render(...)` and must be updated in
  the same task (build must stay green).
- `report.greeting.default` is used in two places: the form model's fallback
  literal `"Hi {first}!"` is **not** localized (leave it — it only applies
  when the key was never localized, see note in steps) — actually the form
  model falls back to the literal `"Hi {first}!"`; the *view* falls back to
  `String(localized: "report.greeting.default")`. Align the form model
  fallback with the new default so both paths behave identically: change the
  form model's literal to `"Hi {first}!\nHere is my report for {month}."`.
  (This is the one allowed exception to "do not modify the form model".)

**Files to touch**:

- `Hugo/Domain/YearMonth.swift` — add `monthName(locale:calendar:)`.
- `Hugo/Features/Reports/Domain/ReportComposer.swift` — new `render`
  signature + normalization; `message` drops the month line.
- `Hugo/Features/Reports/SubmitReportFormModel.swift` — fallback literal only
  (one line).
- `Hugo/Features/Settings/GreetingTemplateView.swift` — preview passes
  month/year.
- `Hugo/Resources/Localizable.xcstrings` — update `report.greeting.footer`
  and `report.greeting.default` (en + da).
- `HugoTests/Features/Reports/ReportComposerTests.swift` — update + add tests.
- `HugoTests/Features/Reports/YearMonthTests.swift` — add `monthName` tests.

**Steps**:

1. In `YearMonth.swift`, add next to `monthYearString`:

   ```swift
   nonisolated func monthName(locale: Locale = .current, calendar: Calendar = .current) -> String
   ```

   Same body as `monthYearString` but `formatter.dateFormat = "LLLL"`.
2. In `ReportComposer`, change `render` to
   `static func render(template: String, firstName: String, lastName: String, month: String, year: String) -> String`
   that replaces `{first}`, `{last}`, `{month}`, `{year}`, then normalizes
   per line:

   ```swift
   rendered
       .components(separatedBy: .newlines)
       .map { line in
           line.components(separatedBy: .whitespaces)
               .filter { !$0.isEmpty }
               .joined(separator: " ")
       }
       .filter { !$0.isEmpty }
       .joined(separator: "\n")
   ```

3. In `ReportComposer.message(...)`:
   - Replace the greeting computation with a call passing
     `month: summary.id.monthName(locale: locale, calendar: calendar)` and
     `year: String(summary.id.year)`.
   - Delete `let month = summary.id.monthYearString(...)` and change
     `var lines: [String] = [greeting, "", month]` to `[greeting, ""]`.
   - Update the doc comment: supported tags are `{first}`, `{last}`,
     `{month}`, `{year}`.
4. In `SubmitReportFormModel.swift`, change the `greetingTemplate` fallback
   literal from `"Hi {first}!"` to
   `"Hi {first}!\nHere is my report for {month}."` (one line; nothing else
   in this file changes).
5. In `GreetingTemplateView.swift`, update the preview:

   ```swift
   private var previewMonth: YearMonth { Date().yearMonth() }
   // in `preview`:
   ReportComposer.render(
       template: effectiveTemplate,
       firstName: previewFirstName,
       lastName: previewLastName,
       month: previewMonth.monthName(),
       year: String(previewMonth.year)
   )
   ```

6. In `Localizable.xcstrings`:
   - `report.greeting.footer` →
     en `Use {first} and {last} for the overseer's name, and {month} and {year} for the report month.`
     da `Brug {first} og {last} til gruppetjenerens navn, og {month} og {year} til rapportmåneden.`
     (Danish tone may be adjusted.)
   - `report.greeting.default` →
     en `Hi {first}!\nHere is my report for {month}.`
     da `Hej {first}!\nHer er min rapport for {month}.` (Decision D1.)
7. Update `ReportComposerTests` (see Tests below) and add `monthName` tests
   to `YearMonthTests`.
8. Commit: `` `013` Task 02 — Greeting {month}/{year} tags; drop built-in month line ``.

**Not in this task**: hours-unit localization (Task 1), button tint (Task 3),
card menu (Task 4). Do not change `prepareSubmission()`'s call signature or
any persistence code.

**Tests** (`HugoTests/Features/Reports/ReportComposerTests.swift`):

- Update `messageContainsGreetingMonthHoursAndBibleStudies`: with template
  `"Hi {first}!"` the body is now exactly
  `["Hi John!", "", "Field Service: 5 h", "LDC: 1 h", "Bible studies: 3"]`
  (delete the `lines[2] == "June 2026"` assertion; renumber the rest).
- New test — tags render inline:
  template `"Hi {first}!\nReport for {month} {year}."` over the June-2026
  fixture ⇒ `lines[0] == "Hi John!"`, `lines[1] == "Report for June 2026."`,
  `lines[2] == ""`, `lines[3] == "Field Service: 5 h"`.
- New test — `render` preserves intentional line breaks and drops empty
  lines: `"A\n\nB {month}"` with month `June` ⇒ `"A\nB June"`.
- Update `localeDrivesTheMonthNameWhileLabelsFollowTheDevelopmentLanguage`:
  remove `lines[2] == "juni 2026"`; instead use template
  `"Hej {first}! {month}"` with the `da_DK` locale and assert
  `lines[0] == "Hej Jens! juni"`. Keep the existing assertions that labels
  follow the development language.
- Existing `render*` tests: update calls to the new signature (pass
  `month: "June", year: "2026"`); single-line expectations are unchanged.
- `HugoTests/Features/Reports/YearMonthTests.swift`: add
  `monthName` returns `June` for `YearMonth(year: 2026, month: 6)` under
  `en_US_POSIX` + GMT, and `juni` under `da_DK`.

**Verification**:

- `xcodebuild -project Hugo.xcodeproj -scheme Hugo -destination 'platform=iOS Simulator,name=iPhone 17' test` → all pass, including the new/updated tests.
- Manual: Settings → Greeting → footer mentions `{month}`/`{year}`; preview
  shows the current month name. Submit sheet → Copy Report ⇒ the pasted body
  has no standalone `June 2026` line; with the default template the greeting
  contains `... for {current month}.` localized.

**Working state after this task**: message month placement is fully
user-controlled via the greeting template; default users keep a month line
inside the greeting.

**Acceptance criteria**:

- [ ] No automatic month line exists in `ReportComposer.message`.
- [ ] `{month}` and `{year}` substitute correctly, unknown tags untouched,
  newlines preserved, empty-name whitespace still collapses.
- [ ] Footer + default template updated in both `en` and `da`; no raw keys
  visible in the UI.
- [ ] All tests green.

---

## Task 3 — Make the "Send to Group Overseer" button orange

**Goal**: the floating send button in the submit sheet renders orange
regardless of the presenting view's tint.

**Depends on**: None.

**Precondition**: drift check passed; `SubmitReportView.swift` matches
"Current state".

**Context**: `MonthlyReportRow` applies `.tint(.primary)` to the whole card
(see its excerpt), and the tint propagates through the sheet's environment,
turning the `.borderedProminent` button black. The Overview's
`ReportReminderCard` presents the same sheet; fixing the tint **on the
button itself** covers every presenter. Repo orange convention:
`.tint(.orange)` (see `OnboardingView.swift` lines ~68, ~103).

**Files to touch**:

- `Hugo/Features/Reports/SubmitReportView.swift` — one modifier.

**Steps**:

1. In the `.safeAreaInset(edge: .bottom)` button chain, add `.tint(.orange)`
   after `.buttonStyle(.borderedProminent)`.
2. Commit: `` `013` Task 03 — Orange send button ``.

**Not in this task**: removing `.tint(.primary)` from `MonthlyReportRow` (it
is load-bearing for the rest of the card), any other button, any other view.

**Tests**: none — pure visual change; existing tests must keep passing.

**Verification**:

- `xcodebuild ... build` → `BUILD SUCCEEDED`.
- Manual: open the submit sheet from a Year card (and from the Overview
  reminder card) in light and dark appearance ⇒ the floating button is
  orange; the disabled state still reads clearly.

**Working state after this task**: fully shippable visual fix.

**Acceptance criteria**:

- [ ] Send button is orange in both appearances and from both entry points.
- [ ] No other button in the app changed appearance (spot-check the Year
  card and the copy/settings buttons in the sheet).

---

## Task 4 — Replace the month-card chevron with a dropdown that always offers submit

**Goal**: `MonthlyReportRow`'s header chevron becomes a `Menu` containing
**Submit Report** / **Submit Updated Report** (always present for non-future
months, including already-submitted ones) and **View Details**; the inline
button at the bottom of the card is removed.

**Depends on**: None.

**Precondition**: drift check passed; `MonthlyReportRow.swift` matches
"Current state".

**Context**:

- The submit sheet is already re-entrant: `SubmitReportFormModel`
  `persistSubmission` replaces an existing month's report (preserving
  `firstSubmittedAt`), and `isSubmittable` is simply `month <= now`. So
  "always offer submit" needs no domain change — only the view's
  `(!month.isSubmitted || month.hasUnreportedEntries)` gate goes away.
- `submitButtonTitle` currently returns *resubmit* only when
  `isSubmitted && hasUnreportedEntries`. For the menu, broaden it: return
  `report.submit.resubmit` whenever `month.isSubmitted`, else
  `report.submit.button` (en `Submit Report`/`Submit Updated Report`, da
  `Indsend rapport`/`Indsend opdateret rapport` — keys already exist).
- Tapping a `Menu` inside the card does not fire the card's `.onTapGesture`
  (the existing inner `Button` already proves controls take precedence).
- Menu exemplar: `EntryDetailView.swift` (~lines 74–85) — `Menu { Button(...) }
  label: { Label("common.more", systemImage: "ellipsis") }`.
- Keep `.sheet(isPresented: $isExpanded)` and
  `.sheet(isPresented: $isPresentingSubmitSheet)` exactly as they are.

**Files to touch**:

- `Hugo/Features/Reports/MonthlyReportRow.swift` — header menu, remove bottom
  button, adjust `submitButtonTitle`.
- `Hugo/Resources/Localizable.xcstrings` — add `report.row.menu.details`:
  en `View Details`, da `Vis detaljer` (tone adjustable).

**Steps**:

1. Change `submitButtonTitle` to return
   `String(localized: "report.submit.resubmit")` when `month.isSubmitted`
   and `String(localized: "report.submit.button")` otherwise.
2. Replace the header `Image(systemName: "chevron.right")` block with:

   ```swift
   Menu {
       Button(submitButtonTitle, systemImage: "paperplane") {
           isPresentingSubmitSheet = true
       }
       Button("report.row.menu.details", systemImage: "doc.text.magnifyingglass") {
           isExpanded = true
       }
   } label: {
       Label("common.more", systemImage: "ellipsis")
           .labelStyle(.iconOnly)
   }
   .menuStyle(.borderlessButton) // keep it flat inside the card, if needed for styling
   ```

   Notes for the executor:
   - `Button(submitButtonTitle, ...)` uses the `Button(_ title: S, ...)`
     overload (String, not LocalizedStringKey) — correct here because the
     title was already resolved.
   - Do **not** apply the chevron's `.foregroundStyle(.tertiary)` to the
     menu trigger; it must stay discoverable (Decision D2). Match the
     header's caption size if it looks oversized.
   - `menuStyle` line is optional; drop it if the default looks right.
3. Gate the submit item for future months instead of the whole menu — wrap
   only the submit `Button` in `if !month.isFuture { ... }` inside the
   `Menu` content. (View Details stays available for any month with
   entries.)
4. Delete the bottom block:

   ```swift
   if !month.isFuture && (!month.isSubmitted || month.hasUnreportedEntries) {
       Button(submitButtonTitle) { ... }
       .buttonStyle(.bordered)
       .padding(.top, 12)
   }
   ```

5. Add the `report.row.menu.details` catalog key (en + da).
6. Commit: `` `013` Task 04 — Month-card dropdown with always-available submit ``.

**Not in this task**: `MonthlyReportEmptyRow` (Decision D3),
`ReportReminderCard`, `ServiceYearPageView`, the submit sheet itself, any
domain or persistence code.

**Tests**: no unit tests (view-only change; the repo has no view tests).
Existing tests must keep passing. Verification is manual.

**Verification**:

- `xcodebuild ... build` → `BUILD SUCCEEDED`.
- Manual simulator walkthrough of the Year screen:
  - Month with entries, never submitted ⇒ menu shows **Submit Report**;
    choosing it presents the submit sheet; sending/copying still persists.
  - Month already submitted, no new entries ⇒ menu shows **Submit Updated
    Report** and it works (previously impossible from the card).
  - Month submitted with new entries ⇒ same as above.
  - Future month with entries (seed a future-dated entry if needed) ⇒ menu
    has **View Details** only.
  - Tapping the menu does **not** open the detail sheet; tapping elsewhere
    on the card still does.
  - No inline submit button remains at the bottom of any card.

**Working state after this task**: the Year screen's cards offer submission
from the dropdown at all times for non-future months; the flow is complete.

**Acceptance criteria**:

- [ ] Chevron gone; menu present on every entry-month card.
- [ ] Submit option available after submission, hidden only for future
  months.
- [ ] Bottom inline button removed; layout of the card otherwise unchanged.
- [ ] Danish + English menu items render from the catalog (no raw keys).

---

## Done criteria (whole plan)

- [ ] `xcodebuild ... build` and `... test` both succeed; no existing test
  modified except the `ReportComposerTests` updates specified in Task 2.
- [ ] `grep -rn ') h"' Hugo --include="*.swift"` → no matches.
- [ ] Danish device: `t` units in sheet and message; greeting footer and
  default template localized; card menu localized.
- [ ] Message body contains no automatic month line; `{month}`/`{year}`
  render from the greeting template.
- [ ] Send button is orange from every entry point.
- [ ] Card dropdown offers submit in all non-future states.
- [ ] `git status` shows no modifications outside the in-scope list.
- [ ] `plans/README.md` row for 013 set to `DONE`.

## STOP conditions

Stop and report back (do not improvise) if:

- Any "Current state" excerpt does not match the live code (drift).
- `String(localized: "report.hours.unit")` (or the greeting keys) renders as
  a raw key on a Danish device after the catalog edit — the `.xcstrings`
  entry is malformed; fix the JSON or use Xcode's catalog editor, and if it
  still fails, stop.
- Updating `render`'s signature reveals call sites beyond
  `ReportComposer.message` and `GreetingTemplateView` (check with
  `grep -rn "ReportComposer.render" Hugo HugoTests`).
- Broadening submit availability uncovers that `SubmitReportFormModel`
  rejects re-submission for a submitted month (contrary to what this plan
  states) — the domain behavior drifted; re-plan.
- A task's verification fails twice after a reasonable fix attempt, or the
  fix requires touching an out-of-scope file.

## Maintenance notes

- Users who customized their greeting template lose the automatic month
  line — intentional (D1); the greeting settings footer now documents
  `{month}`/`{year}` so they can add it back wherever they want.
- The composer's body labels (`report.compose.*`) still resolve against the
  development language at runtime; the hours unit now follows the same
  catalog path. A future "message language" decision should revisit all of
  them together.
- The empty-name whitespace collapsing in `render` is covered by
  `renderCollapsesWhitespaceLeftByEmptyNames`; the rework in Task 2 must not
  regress those expectations.
- `MonthlyReportEmptyRow` still shows its small inline submit button
  (Decision D3); if the card-menu pattern is preferred there later, mirror
  Task 4 — it is a one-view change.
- Reviewer should scrutinize: the per-line normalization in `render`, the
  Danish string tone, and that the card tap gesture and menu never both
  fire.

---

**Boundaries of this planning pass**

- No implementation was performed.
- Investigation was limited to the four requested changes and their direct
  dependencies (submit sheet, composer, greeting settings, Year-screen rows,
  YearMonth helper, localization catalog, existing tests).
- No whole-codebase audit was performed.
- No unrelated fixes, cleanup, refactors, or roadmap work are included.
