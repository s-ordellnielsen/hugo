# Plan 025: Folder organization, one-type-per-file, and stale-comment cleanup

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for plan 025
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat d65afec..HEAD -- Hugo/Features Hugo/Persistence`
> If any file this plan moves or edits changed, re-read it and treat content
> surprises as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW (moves are safe — see "Filesystem-synchronized groups" below)
- **Depends on**: plans/016-green-verification-gate.md, plans/023-dead-code-and-api-hygiene.md
- **Category**: organization
- **Planned at**: commit `d65afec`, 2026-08-06

## Why this matters

`AGENTS.md` mandates feature-first folders, *not* technical buckets. Three
places violate that today: `SymbolPicker/Enums/`, `SymbolPicker/Structs/`, and
`ServiceYear/Structs/` group files by *what they are* instead of *what feature
they serve*. A second control type (`SettingsButton`) is hidden inside
`SettingsView.swift`. And 46 files still carry Xcode's generated
`//` / `//  Created by` header comments, some naming files and dates that no
longer match reality. None of this breaks the build; all of it makes the
codebase slower to navigate and sets a bad template for new files.

## Filesystem-synchronized groups (why this is low-risk)

`Hugo.xcodeproj/project.pbxproj` uses `PBXFileSystemSynchronizedRootGroup`
(confirmed at lines 41–55). The project has **no per-file references** —
Xcode mirrors whatever is on disk. Moving files with `git mv` therefore
requires **no pbxproj edit** and cannot desynchronize the target. Verify this
is still true before starting (STOP condition below).

## Current state

### A. Technical-bucket subfolders

```
Hugo/Features/SymbolPicker/
    Enums/    SymbolAttribute.swift, SymbolSet.swift
    Structs/  SymbolDefinition.swift
    SymbolPicker.swift
Hugo/Features/ServiceYear/
    Structs/  TheocraticYear.swift, TheocraticYearReport.swift,
              TheocraticYearReportBuilder.swift
    MonthlyReportEmptyRow.swift, ServiceYearPageView.swift,
    ServiceYearView.swift, TheocraticYearTotalsView.swift
```

`Enums/` and `Structs/` are exactly the technical grouping `AGENTS.md` forbids.

### B. Reports/ServiceYear ownership overlap

`ServiceYearPageView.swift` renders `MonthlyReportRow` (lives in
`Features/Reports/`) and `MonthlyReportEmptyRow` (lives in
`Features/ServiceYear/`). The two row types are a matched pair — one file in
each feature folder. Meanwhile `Features/Reports/Domain/` is itself a
technical bucket, though a defensible one (pure logic, no views).

### C. Hidden control type

`Hugo/Features/Settings/SettingsView.swift` declares two types:
`SettingsView` (line 11) and `SettingsButton` (line 110). One type per file is
the convention used everywhere else.

### D. Stale generated headers

46 Swift files contain the Xcode template header block:

```swift
//
//  SymbolSet.swift
//  Hugo
//
//  Created by … on …
//
```

Several reference old filenames or task numbers. Example to spot-check:
`Hugo/Features/SymbolPicker/Enums/SymbolSet.swift` header. (Plan 019 keeps
`SymbolSet.swift` unsplit — do not re-litigate that here.)

### Conventions

- Feature-first: a file lives in the folder of the feature it serves.
- One primary type per file, filename matches the type.
- Persistence files under `Hugo/Persistence/` are **untouchable** here
  (entity-hash history — see plan 014's abandonment and 023's scope).
- Moving a file preserves its git history via `git mv`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Confirm FS-sync | `grep -c PBXFileSystemSynchronizedRootGroup Hugo.xcodeproj/project.pbxproj` | `≥ 1` and zero `PBXBuildFile` file-ref sections for these paths |
| Build | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan025 CODE_SIGNING_ALLOWED=NO` | `BUILD SUCCEEDED` |
| Full gate | `Scripts/verify.sh` | exit 0 |
| History check | `git log --follow --oneline -- <moved file>` | shows pre-move history |

## Scope

**In scope**:
- `Hugo/Features/SymbolPicker/{Enums,Structs}/` → flatten into `SymbolPicker/`
- `Hugo/Features/ServiceYear/Structs/` → flatten into `ServiceYear/`
- `Hugo/Features/Settings/SettingsView.swift` → split `SettingsButton`
- Pairing the two month-row views (Step 3 — decide, then do)
- Header-comment removal across all `Hugo/**/*.swift` files that have the
  template block
- `plans/README.md` reconciliation note for stale plans 008/009 (Step 5)

**Out of scope** (do NOT touch):
- Everything under `Hugo/Persistence/` — schemas, legacy models, migration
  plan. Their folder layout is historical and load-bearing.
- `Hugo.xcodeproj/project.pbxproj` — FS-sync means no edit is needed; if the
  pre-check shows otherwise, STOP.
- `Features/Reports/Domain/` contents — the logic files stay put. This plan
  only flattens view/type buckets; reorganizing domain logic is a separate
  design decision.
- Any code *content* change. Moves and comment deletions only. If a move
  forces a code edit (it should not), that is a STOP condition.

## Git workflow

- Branch: `advisor/025-organization-and-stale-comments`
- One commit per step, message style: `` `025` Step N — <summary> ``
- Do NOT push or open a PR.

## Steps

### Step 0: Pre-flight safety check

```sh
grep -c PBXFileSystemSynchronizedRootGroup Hugo.xcodeproj/project.pbxproj
grep -n "SymbolAttribute.swift\|TheocraticYear.swift" Hugo.xcodeproj/project.pbxproj || echo "no per-file refs"
```

Expect: count `≥ 1`, and the second command prints `no per-file refs` (or only
hits inside `PBXFileSystemSynchronizedRootGroup` exceptions lists, which are
fine). **If either file is referenced by a build-file entry, STOP** — the
project is not fully FS-synced and moves need pbxproj surgery this plan does
not cover.

### Step 1: Flatten SymbolPicker and ServiceYear buckets

```sh
cd Hugo/Features/SymbolPicker
git mv Enums/SymbolAttribute.swift SymbolAttribute.swift
git mv Enums/SymbolSet.swift SymbolSet.swift
git mv Structs/SymbolDefinition.swift SymbolDefinition.swift
rmdir Enums Structs
cd ../ServiceYear
git mv Structs/TheocraticYear.swift TheocraticYear.swift
git mv Structs/TheocraticYearReport.swift TheocraticYearReport.swift
git mv Structs/TheocraticYearReportBuilder.swift TheocraticYearReportBuilder.swift
rmdir Structs
```

No `#import`/module changes are needed — same module, same target.

**Verify**: `find Hugo/Features -type d -name Enums -o -type d -name Structs`
→ no output. Build command → `BUILD SUCCEEDED`. `git log --follow` on any moved
file still shows history.

### Step 2: Split SettingsButton into its own file

- Create `Hugo/Features/Settings/SettingsButton.swift`.
- Move the `struct SettingsButton: View { … }` declaration (from
  `SettingsView.swift` line 110 to its end) into it, verbatim.
- Keep the same `import` lines the type needs (`SwiftUI`; add `SwiftData` only
  if the moved body references it — check, don't assume).
- Remove it from `SettingsView.swift`.

**Verify**: `grep -n "struct SettingsButton" Hugo/Features/Settings/*.swift` →
exactly one match, in `SettingsButton.swift`. Build succeeds.

### Step 3: Resolve the month-row split — decide, then move ONE file

The pair `MonthlyReportRow` (Reports) and `MonthlyReportEmptyRow`
(ServiceYear) should live together. Both are rendered only by
`ServiceYearPageView`. Choose the destination by ownership:

- `MonthlyReportRow`/`MonthlyReportEmptyRow` are **presentation rows for the
  year page**, not report logic. The report *logic* (`MonthlyReportBuilder`,
  `MonthlyReportSummary`, …) already lives in `Reports/Domain/`.
- **Decision: move `MonthlyReportRow.swift` from `Features/Reports/` to
  `Features/ServiceYear/`**, so both rows sit beside their only consumer.

```sh
git mv Hugo/Features/Reports/MonthlyReportRow.swift Hugo/Features/ServiceYear/MonthlyReportRow.swift
```

If a *different* consumer of `MonthlyReportRow` exists outside ServiceYear
(check: `grep -rln "MonthlyReportRow(" Hugo/Features | grep -v ServiceYear`),
reconsider — if Overview or Reports proper uses it, keep it in Reports and
move `MonthlyReportEmptyRow` there instead. **Pick the folder that leaves the
fewest cross-feature references; do not move both.**

**Verify**: both row files in one folder; `grep -rln "MonthlyReportRow("`
consumers unchanged and building. Build succeeds.

### Step 4: Strip stale template headers

Remove the 6-line Xcode header block (`//` / `//  <File>.swift` / `//  Hugo` /
blank-`//` / `//  Created by …` / `//`) from every file that has it, leaving
`import …` as the first line. This is a mechanical deletion of the leading
comment block only — **do not touch any other comment**. Do it with a careful
script or per-file edit; either way, the diff must show *only* removed header
lines per file.

Concretely, for each file matching `grep -rln "^//$" Hugo --include="*.swift"`,
delete lines 1–6 **iff** they match the template shape; if a file's first lines
deviate, edit that one by hand.

**Verify**: `grep -rln "Created by" Hugo --include="*.swift"` → no matches.
`grep -rEn "^//  [A-Za-z]+\.swift$" Hugo --include="*.swift"` → no matches.
`Scripts/verify.sh` → exit 0 (swift-format strict will flag any leftover
header whitespace, which is the point).

### Step 5: Reconcile stale plans 008/009 in the index

Plans 008 and 009 are marked TODO but are partly overtaken by the current code
and by plans 016–025. In `plans/README.md`, annotate their rows (do not delete
the files): change status to `STALE — superseded in part by 016–025; re-scope
before executing`. This plan's own README row gets the normal update.

**Verify**: `plans/README.md` shows the annotation; no plan files deleted.

## Test plan

No behavioral change → no new tests. The gate is:

- Build succeeds after every step (moves) — the compiler is the move checker.
- `Scripts/verify.sh` exits 0 at the end.
- `git log --follow` preserves history on every moved file.

## Done criteria

ALL must hold:

- [ ] `find Hugo/Features -type d \( -name Enums -o -name Structs \)` → empty
- [ ] `SettingsButton` in its own file; `SettingsView.swift` declares only `SettingsView`
- [ ] `MonthlyReportRow.swift` and `MonthlyReportEmptyRow.swift` in the same folder
- [ ] `grep -rln "Created by" Hugo --include="*.swift"` → empty
- [ ] No pbxproj modification in `git diff`
- [ ] No Swift *content* change in `git diff` (only moves + header deletions + the SettingsButton cut/paste)
- [ ] `Scripts/verify.sh` exits 0
- [ ] `git log --follow` works on every moved file
- [ ] `plans/README.md` updated (025 row + 008/009 annotation)

## STOP conditions

Stop and report if:

- The Step 0 check finds per-file build references — the project is not fully
  FS-synced and moves are not free.
- Any move forces a code edit to compile (import cycle, name clash).
- A file's header block is not the standard 6-line template — hand-edit that
  one rather than scripting blind.
- Removing a header reveals the file's *only* documentation was inside it
  (rare, but if a `Created by` block carries a real design note, move that note
  into a proper doc comment above the type instead of deleting it).
- `MonthlyReportRow` has a consumer outside ServiceYear — re-decide Step 3's
  destination as instructed there rather than forcing the move.

## Maintenance notes

- After this lands, the *only* technical bucket left is `Features/Reports/Domain/`,
  which is intentional (pure logic, no SwiftUI). Keep new views out of it.
- New-file rule: no `Enums/`/`Structs/`/`Views/`/`Models/` subfolders under a
  feature. If a feature grows enough files to need grouping, group by
  *sub-feature* (like `Entries/AddEntry/`), not by kind.
- The header-strip is one-time. Disable the template going forward: Xcode →
  Settings → Text Editing → the `FILEHEADER` / organization macros, or a
  project-level `IDETemplateMacros.plist`. Not required by this plan.
- Reviewer should scrutinize: the Step 3 folder decision (it is the only
  judgment call) and that Step 4 deleted *only* headers.
