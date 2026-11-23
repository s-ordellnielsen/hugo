# Plan 150: Rename the Year tab to "Service Year"

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 07d4c61..HEAD -- Hugo/App/AppRootView.swift CONTEXT.md Hugo/Resources/Markdown Hugo/Features/Planner/Screens/BufferScopeSettingsView.swift`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` shows `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit, and this plan must edit the same file). See "String
> catalog" below.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW. Text only. The risk is the label being cut off in the iPhone tab bar, which the owner checks.
- **Depends on**: none
- **Category**: copy
- **Planned at**: commit `07d4c61`, 2026-11-23
- **Issue**: [SLN-331](https://linear.app/sebastianln/issue/SLN-331)

## Why this matters

The tab is called "Year" in English and "Tjenesteår" in Danish. The Danish
name already says "service year", the English one does not. After this plan
the English tab is "Service Year", and every English sentence that names the
tab uses the same words. Danish stays as it is.

## Current state

- The tab title key: `Hugo/App/AppRootView.swift:143`, `case .year: return "tab.year"`. The code names `AppTab.year` and `yearResetToken` stay.
- The catalog entry `tab.year` in `Hugo/Resources/Localizable.xcstrings` (about line 6038): en "Year", da "Tjenesteår". The Danish term is confirmed: the catalog already uses "Tjenesteår" for this tab in the Danish help articles (`Hugo/Resources/Markdown/Help/da.lproj/TargetThisMonth.md`, `FieldServiceAndCredit.md`) and in the strings below. No Danish change is needed.
- The page title is not this string. `ServiceYearView` shows the selected year, for example `2026/2027` (`.navigationTitle(activeYear.displayName)`). Nothing to change there.
- `tab.year` is also used as a label in `Hugo/Features/Planner/Screens/BufferScopeSettingsView.swift:18`: `Toggle(isOn: $includeInYear) { Text("tab.year") }`. It will say "Service Year" too, which is right.
- One unit test asserts the English strings: `HugoTests/Features/Planner/Domain/PlannerTargetTests.swift` lines 120 and 123 (`bufferScopeSummaryNamesEveryCombinationOfSwitches`) expect "Planner, Year" and "Planner, Overview, Year". They must change to "Planner, Service Year" and "Planner, Overview, Service Year" (found by the first executor run). There is no `HugoUITests` folder.
- Domain conflict to flag: `CONTEXT.md` line 52, under "Theocratic year", says `_Avoid_: Service year, school year`. The owner now wants "Service Year" as the tab name. See Step 4.

English text that names the tab (found with `grep -rIn 'Year tab\|Year switch\|in Year' ...`):

| File | Lines | What |
|---|---|---|
| `Hugo/Resources/Localizable.xcstrings` | 6050 (en value), 3010, 3078, 3180, 4533 (en values) | "Year", "Planner, Overview, Year", "Planner, Year", "Include Buffer in Year", "...menu on the Year tab." |
| same, comments only | 2999, 3067, 4522, 6039, 6864, 6881, 7051, 7068 | say "Year tab" |
| `Hugo/Resources/Markdown/Help/Base.lproj/TargetThisMonth.md` | 3, 32, 34 | "the Year tab", "in Year", "With the Year switch on" |
| `Hugo/Resources/Markdown/Help/Base.lproj/FieldServiceAndCredit.md` | 27 | "on the Year tab" |
| `CONTEXT.md` | 134 ("Year tab" x1, "Year switch" x1), 160 ("Year tab" x2, "Year switch" x1) | goal bar and Buffer terms |
| Swift doc comments | `MonthDetailView.swift:4`, `MonthHeadline.swift:4`, `TheocraticYearPicker.swift:6,10,142`, `HelpArticle.swift:42`, `UserDefaultsKeys.swift:10` | "Year tab" |

Not changed: `Changelog/1.0.0/137.en.txt` (a shipped changelog), the Danish
files, "Year details" (the year details screen), and plans in `plans/`.

Rules from `AGENTS.md` that apply: strings live in the string catalog in
English and Danish with comments; update `CONTEXT.md` in the same change when
a domain term changes; never edit generated or shipped text history.

## String catalog (read this)

The owner has uncommitted edits in `Hugo/Resources/Localizable.xcstrings`.
Edit only the English values and comments listed above and nothing else. When
you commit, use `git add -p Hugo/Resources/Localizable.xcstrings` and stage
only your hunks. If `git diff` for the file shows your lines tangled with the
owner's hunks so that `git add -p` cannot split them, STOP and ask.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Find leftovers | `grep -rIn 'Year tab\|Year switch' Hugo CONTEXT.md` | only the Danish-free lines you meant to keep (none expected) |

## Scope

**In scope**: the files in the table above, except the shipped changelog, plus `HugoTests/Features/Planner/Domain/PlannerTargetTests.swift` (lines 120 and 123 only) and the catalog comment "Spoken label of the Year switch on the Count Buffer in page." (change "Year switch" to "Service Year switch").

**Out of scope**:

- `AppTab.year`, `yearResetToken`, the `tab.year` key name, any other code name.
- Danish strings (already "Tjenesteår").
- The year page title and the year picker.
- Renaming other tabs.

## Git workflow

- Work on `main`. One commit, for example `feat(copy): rename Year tab to Service Year`.
- Do not push. Stage the catalog only with `git add -p`.

## Steps

### Step 1: Catalog

In `Localizable.xcstrings` change only the English values: `tab.year` to
"Service Year"; the other four value lines in the table to the same wording
("Planner, Overview, Service Year", "Planner, Service Year", "Include Buffer
in Service Year", "...menu on the Service Year tab."). In the comment lines
listed, replace "Year tab" with "Service Year tab", and in the comment at
4522 say the tab name is "Service Year" / "Tjenesteår".

**Verify**: `git diff Hugo/Resources/Localizable.xcstrings` shows only your lines among the owner's hunks, and the file still parses (`python3 -c "import json; json.load(open('Hugo/Resources/Localizable.xcstrings'))"`; `plutil -lint` does not accept this catalog).

### Step 2: Help articles

In `Help/Base.lproj/TargetThisMonth.md` and `FieldServiceAndCredit.md` write
"the Service Year tab", "in Service Year" and "With the Service Year switch
on". Do not touch `da.lproj`.

**Verify**: `grep -n "Year" Hugo/Resources/Markdown/Help/Base.lproj/TargetThisMonth.md` shows no bare "Year tab", "in Year" or "Year switch".

### Step 3: Swift comments

Replace "Year tab" with "Service Year tab" in the doc comments listed. No code changes.

**Verify**: `grep -rn "Year tab" Hugo --include='*.swift'` returns no matches.

### Step 4: CONTEXT.md

Replace "Year tab" with "Service Year tab" and "Year switch" with "Service
Year switch" on lines 134 and 160. Then resolve the conflict on line 52: the
"Theocratic year" entry says `_Avoid_: Service year`. Change it to
`_Avoid_: School year`, and add one sentence to its definition: "The tab that
shows it is named Service Year ("Tjenesteår"). In sentences about the
calendar, say theocratic year." Do not rename the term itself.

**Verify**: `grep -n "Year tab\|Year switch" CONTEXT.md` shows only "Service Year" forms.

### Step 5: Gate

**Verify**: `Scripts/verify.sh` exits 0.

## Test plan

No logic changes and no test looks up the label, so no new tests.

Owner check on device:

- iPhone tab bar: the label "Service Year" shows in full, at the default text size and at the largest non-accessibility size, with three tabs (Settings is sidebar-only on iPhone). If it truncates ("Service Y..."), do this: add a second key `tab.year.short` ("Year" / "Tjenesteår") and make `AppTab.titleKey` return it for the tab bar only, keeping "Service Year" for the iPad sidebar and the Buffer toggle. That is a separate small change: ask first.
- iPad sidebar: the row reads "Service Year".
- Buffer page: the toggle reads "Service Year".
- Danish: nothing changed.
- Help: open "Target this month" and the credit article and read the sentences.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -rIn 'Year tab\|Year switch' Hugo CONTEXT.md` returns no matches except Danish-free historical text (none expected)
- [ ] `git status --short` shows only the in-scope files, and the catalog is staged only with your hunks
- [ ] `plans/README.md` row updated

## STOP conditions

Stop and report if:

- `git add -p` cannot separate your catalog lines from the owner's.
- A test other than `PlannerTargetTests` lines 120 and 123 looks up the old label.
- The owner's catalog edit already changes `tab.year`.

## Maintenance notes

- Owner to confirm: the Danish term "Tjenesteår" is kept as is. It is what the app already uses.
- Owner to confirm: `CONTEXT.md` listed "Service year" under Avoid for the theocratic year. This plan keeps "theocratic year" as the term in prose and only uses "Service Year" as the tab's name.
- Keep the tab's English name in one place: the `tab.year` catalog value. Help and `CONTEXT.md` copy it.
