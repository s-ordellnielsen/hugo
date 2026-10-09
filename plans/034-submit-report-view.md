# Plan 034: Finish the Submit Report screen

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat dc0b7f6..HEAD -- Hugo/Features/Reports/SubmitReportView.swift Hugo/Resources/Localizable.xcstrings`
> Expected: plan 031 whitespace and plan 033 step 6 compile fixes. Anything
> else is a STOP condition.

## Status

- **Priority**: P1 (TestFlight blocker)
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/033-submit-model-reporting-lines.md
- **Category**: bug
- **Planned at**: commit `dc0b7f6`, 2026-10-09

## Why this matters

The redesigned submit screen is a first draft. Several controls are broken:
- There is no way to choose a rounding rule.
- The prominent toolbar button opens an empty sheet.
- Both overflow-menu actions do nothing.
- The settings sheet's Cancel button dismisses the whole report screen.
- The "Actual Time" label sits above the reported hours.

Users can't submit a report reliably, and on devices that can't send texts there is no way to submit at all.

## Current state

`Hugo/Features/Reports/SubmitReportView.swift` (265 lines at `dc0b7f6` plus uncommitted edits):

- `:60-66` iterates `summary.categories` and calls `computedRow(category)`.
- `:117` the toolbar button only toggles the sheet. It never calls `prepareSubmission()`, so `model.preparedContent` is `nil` and the sheet renders nothing:
  `Button("", systemImage: "arrow.up.message.fill") { isComposingMessage.toggle() }`
- `:123,125` empty actions and hardcoded English:
  `Button("Send as Message", systemImage: "arrow.up.message") {}` / `Button("Copy to Clipboard", systemImage: "document.on.document") {}`
- `:130-139` bottom button `report.submit.send` calls `sendViaMessages()` and is disabled when `!MessageComposeView.canSendText`.
- `:143-151` settings sheet. `Button(role: .cancel) { dismiss() }` uses the **outer** `@Environment(\.dismiss)`, which closes the report screen.
- `:202-223` (uncommitted, tab-indented) a grid row labelled `Text("Actual Time")` that shows `model.computation.categoryHours` (the *reported* hours).
- `:247-256` `sendViaMessages()` and `copyReport()` exist and are correct; `copyReport()` is never called.
- Model API after plan 033: `model.results: [ReportingLineResult]`, `model.rule(for:)`, `model.setRule(_:for:)`, `model.canSend`, `model.prepareSubmission()`, `model.preparedContent`. `ReportingLine` has `id`, `type`, `name`, `iconName`, `actualSeconds`, `carriedInSeconds`, `carriedInFrom: [YearMonth]`. `RemainderDisposition`: `.none`, `.undecided(seconds:)`, `.roundedUp`, `.roundedDown`, `.transferred`.
- Duration formatting helper: `Hugo/Features/Reports/Domain/ServiceDurationFormatter.swift`. Reuse it; don't hand-format minutes.
- Motion tokens: `Hugo/App/Motion.swift` (`Motion.value` for value changes, applied via `.motion(Motion.value, value:)`; it respects Reduce Motion).
- Existing localized keys to reuse: `category.default.label` ("Field Service"/"Tjeneste"), `rounding-rule.up|down|transfer`, `report.hours.unit`, `report.submit.send`, `report.submit.copied`, `common.ok`. Untranslated keys from the draft: `Actual Time`, `Send as Message`, `Copy to Clipboard`.
- Project rules (`AGENTS.md`): SwiftUI only, `@Observable` state, no logic in view bodies, explain the UI for users aged 13–70, and support accessibility.

### Card design (owner decision)

Each reporting line is one card:
- **Actual time**: the real logged duration, e.g. `12 h 40 min`. If `carriedInSeconds > 0`, add a secondary line: `↘ 15 min transferred from May`.
- **Reported time**: whole hours, plus what happens to the remainder:
  - `↗ 40 min transferred to next month`
  - `⤓ 40 min rounded down`
  - `⤒ 20 min rounded up`
- If the disposition is `.undecided`, Reported time shows a prompt ("Choose what to do with 40 min") with a rule picker instead of a number.
- The picker uses `RoundingRule.allCases` and their `localizedName`. Show it on every card that has a remainder, and leave it changeable after picking.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Build + tests | `Scripts/verify.sh` | exit 0 |
| Strings check | `python3 -c "import json;d=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'];print([k for k,v in d.items() if v.get('shouldTranslate',True) and k and 'da' not in v.get('localizations',{})])"` | lists none of this plan's keys |

## Scope

**In scope:**
- `Hugo/Features/Reports/SubmitReportView.swift`
- `Hugo/Features/Reports/ReportingLineCard.swift` (create)
- `Hugo/Resources/Localizable.xcstrings` (keys added by this plan)

**Out of scope:**
- `SubmitReportFormModel.swift` and domain files. If the view needs a new derived value, STOP and report; don't compute it in the view.
- Overseer settings (`ReportSettingsView`).

## Git workflow

Branch `advisor/034-submit-report-view`. Commit `Finish submit report screen`. Do not push.

## Steps

### Step 1: Extract the card

Create `ReportingLineCard: View` taking `result: ReportingLineResult`, `rule: Binding<RoundingRule?>`, and `monthName: (YearMonth) -> String`. Layout:
- Header: icon in a circle (keep the current `computedRow` styling), then the title: `category.default.label` for the main line, `line.name` otherwise.
- "Actual time" section: caption plus the formatted `actualSeconds`. If carry-in exists, a secondary `↘` line naming the months from `carriedInFrom`.
- "Reported time" section: `submittedHours` plus `report.hours.unit` and the disposition line, or the undecided prompt.
- A `Picker` (menu style) bound to `rule`, shown when `result.line.needsRule`.

Mark the glyphs `.accessibilityHidden(true)`. Give each section a combined accessibility label that spells out the meaning, e.g. "40 minutes transferred to next month".

Animate value changes with `.contentTransition(.numericText())` and `.motion(Motion.value, value: result.submittedHours)`.

### Step 2: Use the card in the screen

Replace both `ForEach(summary.categories...)` blocks with `ForEach(model.results) { result in ReportingLineCard(...) }`. Bind the rule with `Binding(get: { model.rule(for: result.id) }, set: { model.setRule($0, for: result.id) })`. Delete `computedRow` and `rowColumns`. Convert any remaining tab indentation to 4 spaces.

### Step 3: Fix the actions

- Toolbar prominent button: call `sendViaMessages()`. Disable it with `!model.canSend || !MessageComposeView.canSendText`.
- Menu "Send as Message" → `sendViaMessages()`; "Copy to Clipboard" → `copyReport()` (disabled when `!model.canSend`).
- Bottom button: keep `sendViaMessages()` when `MessageComposeView.canSendText`, otherwise label it `report.submit.copy` and call `copyReport()`. Disable when `!model.canSend`.
- Below the cards, when `!model.canSend && model.isSubmittable`, show a short footnote: "Choose what to do with the extra minutes before sending."

### Step 4: Fix the settings sheet dismissal

Wrap the settings sheet content in a small private view that reads its own `@Environment(\.dismiss)`, or set `showingSettings = false` directly. Cancel must close only the settings sheet.

### Step 5: Localize

Use keys, not English literals. Add to `Localizable.xcstrings` with `en` and `da`:

| Key | en | da |
|---|---|---|
| `report.line.actual` | Actual time | Faktisk tid |
| `report.line.reported` | Reported time | Indberettet tid |
| `report.line.carried-in.%@.%@` | %1$@ transferred from %2$@ | %1$@ overført fra %2$@ |
| `report.line.transferred.%@` | %@ transferred to next month | %@ overført til næste måned |
| `report.line.rounded-up.%@` | %@ rounded up | %@ rundet op |
| `report.line.rounded-down.%@` | %@ rounded down | %@ rundet ned |
| `report.line.choose.%@` | Choose what to do with %@ | Vælg, hvad der skal ske med %@ |
| `report.submit.choose-rule` | Choose what to do with the extra minutes before sending. | Vælg, hvad der skal ske med de ekstra minutter, før du sender. |
| `report.submit.send-message` | Send as Message | Send som besked |
| `report.submit.copy` | Copy to Clipboard | Kopiér til udklipsholder |

Remove the `Actual Time`, `Send as Message`, and `Copy to Clipboard` literal keys.

**Verify:** the strings check prints a list without any of the keys above.

### Step 6: Previews and gate

Keep the `#Preview` using `.modelContainer(.preview)`. Add a second preview for a month with a remainder, if the preview container makes one easy to construct. Otherwise skip it. Then run `Scripts/verify.sh` → exit 0.

## Test plan

This plan is view-only, so there are no unit tests. Manual check on the iPhone 17 Pro (iOS 26.5) simulator:
1. Month with 12 h 40 min → card shows "Choose what to do with 40 min", and Send is disabled.
2. Pick "Transfer" → `↗ 40 min transferred to next month`, 12 h, and Send is enabled.
3. Toolbar button opens Messages with the composed text. On a simulator without Messages, the bottom button reads "Copy to Clipboard" and shows the copied alert.
4. Settings link → Cancel closes only settings.
5. Switch the simulator to Danish; no English remains on the screen.
6. Increase text size to AX3; nothing truncates or overlaps.

## Done criteria

- [ ] `grep -n '{}' Hugo/Features/Reports/SubmitReportView.swift` shows no empty button actions
- [ ] `grep -n '"Actual Time"\|"Send as Message"\|"Copy to Clipboard"' Hugo/Features/Reports/*.swift` → no matches
- [ ] `Scripts/verify.sh` exits 0
- [ ] Manual checks 1–6 performed and noted in the PR description
- [ ] `plans/README.md` row updated

## STOP conditions

- The card needs data the model doesn't expose (e.g. formatted month names).
- `MessageComposeView` can't be presented after `prepareSubmission()` because of sheet timing. Report it rather than adding delays.

## Maintenance notes

- The visually distinct, non-editable style for generated entries in lists is a separate owner task; this screen only shows carry-in as text.
- If Danish wording for the rounding dispositions is changed, keep it consistent with `rounding-rule.*`.
