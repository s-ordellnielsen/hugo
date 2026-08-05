# Plan 016: Make `Scripts/verify.sh` pass so every later plan has a working gate

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for plan 016
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat d65afec..HEAD -- Hugo HugoTests Scripts/verify.sh .swift-format`
> If in-scope files changed since this plan was written, re-run the lint count
> in Step 1 and proceed from the live number.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx / standards
- **Planned at**: commit `d65afec`, 2026-08-06

## Why this matters

`README.md` calls `Scripts/verify.sh` "the local verification entry point", but
it has never passed. Line 9 runs `swift-format lint --strict` and the tree
currently has **1,061 violations**, so `set -eu` aborts the script *before*
`xcodebuild test` and `xcodebuild analyze` ever run. Every subsequent plan in
this directory uses `Scripts/verify.sh` as its done-criteria gate, so this is a
hard prerequisite. This plan is **mechanical formatting only** — zero behavior
change.

## Current state

- `.swift-format` at the repo root: 4-space indentation, `lineLength` 120,
  `maximumBlankLines` 1, `respectsExistingLineBreaks` true.
- `Scripts/verify.sh:9` — `xcrun swift-format lint --strict --recursive Hugo HugoTests`
- The violations are not scattered noise; they cluster into three shapes:
  1. **Whole files indented one level too deep.** The struct members sit at 8
     spaces instead of 4. Affected: `Hugo/Features/Entries/EntryDetailView.swift`,
     `Hugo/Features/Entries/EntryDurationPicker.swift`,
     `Hugo/Features/Entries/EntryListView.swift`,
     `Hugo/Features/Entries/EntryRow.swift`,
     `Hugo/Features/Categories/CategoryDetailView.swift`,
     `Hugo/Features/Categories/CategoryAdvancedOptionsView.swift`.
  2. **Tabs mixed into space-indented files.** `Hugo/App/AppRootView.swift:26-29`,
     `Hugo/Features/Reports/SubmitReportView.swift:55-92,131-144`,
     `Hugo/Features/Reports/SubmitReportFormModel.swift:63-97`,
     `Hugo/Features/ServiceYear/Structs/TheocraticYearReportBuilder.swift:45-128`,
     `Hugo/Features/ServiceYear/TheocraticYearTotalsView.swift:29-32`,
     `Hugo/Features/ServiceYear/MonthlyReportEmptyRow.swift:7-8,61-71`,
     `Hugo/Features/Reports/MonthlyReportDetailView.swift:4-43`,
     `Hugo/Domain/YearMonth.swift:57-97`,
     `Hugo/Features/Entries/AddEntry/AddEntryView.swift:7-14`,
     `Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift:26`.
  3. **Trailing whitespace, unsorted imports, over-long lines.**

  Example of shape 1 — `Hugo/Features/Entries/EntryDurationPicker.swift:10-14`
  as it exists today:

  ```swift
  struct EntryDurationPicker: View {
          @Binding var duration: TimeInterval

          @State var durationAsDate: Date
  ```

  Example of shape 2 — `Hugo/App/AppRootView.swift:25-31` (tabs on 26–29):

  ```swift
        TabView(selection: tabSelection) {
  				Tab("tab.overview", systemImage: "house", value: AppTab.overview) {
  					OverviewView()
  				}
  				Tab("tab.year", systemImage: "tray.full.fill", value: AppTab.year) {
                  ServiceYearView(resetToken: yearResetToken)
              }
        }
  ```

- Repo convention: `swift-format` is the single source of truth for layout. Do
  not hand-format; run the formatter and let it decide.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Count violations | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift-format lint --strict --recursive Hugo HugoTests 2>&1 \| wc -l` | a number (1061 before, 0 after) |
| Format in place | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift-format format --in-place --recursive Hugo HugoTests` | exit 0 |
| Lint | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan016 CODE_SIGNING_ALLOWED=NO` | `TEST SUCCEEDED` |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:
- Every `Hugo/**/*.swift` and `HugoTests/**/*.swift` — formatting only.
- `.swift-format` — only if Step 3 proves a rule is actively harmful.

**Out of scope** (do NOT touch):
- Any behavior, naming, API, or logic change. If the formatter's output looks
  semantically wrong, that is a STOP condition, not something to hand-fix.
- `Hugo/Resources/Localizable.xcstrings`.
- `Hugo.xcodeproj/project.pbxproj`, `Configuration/**` — plan 020+ territory,
  and the operator has explicitly excluded build-configuration changes.
- `Scripts/verify.sh` itself — it is correct; the tree is what's wrong.

## Git workflow

- Branch: `advisor/016-green-verification-gate`
- One commit for the formatting sweep, message style matching `git log`:
  `` `016` Format Hugo and HugoTests with swift-format ``
- Do NOT push or open a PR.

## Steps

### Step 1: Record the baseline

Run the count command and write the number down. Then confirm the test suite is
green *before* you touch anything, so a later failure is unambiguously yours.

**Verify**: count command → a positive number (expect `1061`).
`xcodebuild test …` → `TEST SUCCEEDED`.

### Step 2: Run the formatter

Run the format-in-place command over `Hugo` and `HugoTests`.

**Verify**: `git diff --stat` → shows only `.swift` files under `Hugo/` and
`HugoTests/`. `xcrun swift-format lint --strict --recursive Hugo HugoTests` →
exit 0, no output.

### Step 3: Review the diff for semantic damage

`swift-format` is layout-only, but review the diff for these specific risks and
confirm each is absent:

- No string literal contents changed (`git diff -U0 | grep -E '^[+-].*"' | less`).
- No `#Preview` body was reflowed into something that no longer compiles.
- Multi-line SwiftUI modifier chains are still attached to the same view.
- `Hugo/Features/Reports/SubmitReportView.swift` — the `.safeAreaInset` block
  (previously tab-indented) still wraps the send `Button`.

**Verify**: `xcodebuild test …` → `TEST SUCCEEDED` with the same test count as
Step 1.

### Step 4: Run the full gate

**Verify**: `Scripts/verify.sh` → exit 0, ending in `ANALYZE SUCCEEDED`.

If `xcodebuild analyze` reports pre-existing warnings unrelated to formatting,
record them in the plan's status row and STOP — do not fix them here.

## Test plan

No new tests. This plan's correctness proof is that the **existing** suite has
an identical pass count before and after.

- Before: run the test command, record the number of tests.
- After: run it again, confirm the same number, all passing.

## Done criteria

ALL must hold:

- [ ] `xcrun swift-format lint --strict --recursive Hugo HugoTests` exits 0 with no output
- [ ] `Scripts/verify.sh` exits 0
- [ ] `git status` shows changes only under `Hugo/**/*.swift` and `HugoTests/**/*.swift`
- [ ] `git diff --numstat -- Hugo.xcodeproj Configuration Hugo/Resources` returns nothing
- [ ] Test count is unchanged from the Step 1 baseline
- [ ] `plans/README.md` row for 016 updated to DONE

## STOP conditions

Stop and report if:

- The test suite is already failing at Step 1 (this plan cannot prove
  no-behavior-change on a red baseline).
- The formatter changes a string literal, a `#Predicate` body, or anything
  inside `Hugo/Persistence/SchemaVersions/**` in a way that alters a stored
  property name or type — SwiftData entity hashes are derived from these and
  the repo has already lost a schema version to a hash break (see plan 014).
- Tests pass before and fail after.
- The formatter output would exceed 120 columns and it cannot resolve it
  itself.

## Maintenance notes

- After this lands, `Scripts/verify.sh` is a real gate. Every later plan
  depends on it staying green — run it before every commit.
- Consider adding a pre-commit hook or an Xcode Cloud step that runs
  `swift-format lint --strict`. Deliberately **not** done here: it is a
  workflow decision, not a formatting one.
- Reviewer should scrutinize: the two tab-indented regions in
  `SubmitReportView.swift` and `TheocraticYearReportBuilder.swift`, which have
  the largest reflow diffs.
