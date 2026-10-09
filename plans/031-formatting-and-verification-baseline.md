# Plan 031: Make `Scripts/verify.sh` pass end to end

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat dc0b7f6..HEAD -- Hugo HugoTests Scripts .swift-format`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `dc0b7f6`, 2026-10-09

## Why this matters

`Scripts/verify.sh` is the repo's verification gate, and every later plan (032–036) uses it as a done criterion. Its first step, `xcrun swift-format lint --strict`, fails on 29 files, so the build, test, and analyze steps never run. The test step also runs in parallel, which makes the SwiftData migration suite flaky (`Failed to cast model ... to Entry`). This plan makes the gate green without changing behavior.

## Current state

- `.swift-format`: 4-space indentation, `lineLength` 120, `maximumBlankLines` 1, `respectsExistingLineBreaks` true.
- Lint baseline at `dc0b7f6`: 617 `Indentation` (tab-indented code), 124 `TrailingWhitespace`, 8 `Spacing`, 5 `LineLength`, 4 `NoAccessLevelOnExtensionDeclaration` (`ServiceYearMonthRow.swift`), 2 `NoBlockComments` (`OverviewDateRow.swift:12`), 1 `RemoveLine`, 1 `OrderedImports` (`ServiceYearMonthRow.swift:9`), 1 `AddLines` (`HugoApp.swift:10`).
- `Scripts/verify.sh` (complete file):

```sh
#!/bin/sh
set -eu

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5}"
DERIVED_DATA="${DERIVED_DATA:-/tmp/HugoVerifyDerivedData}"

xcrun swift-format lint --strict --recursive Hugo HugoTests
xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug \
    -destination "$DESTINATION" -derivedDataPath "$DERIVED_DATA" CODE_SIGNING_ALLOWED=NO
xcodebuild analyze -project Hugo.xcodeproj -scheme Hugo -configuration Debug \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "${DERIVED_DATA}-Analyze" CODE_SIGNING_ALLOWED=NO
```

- `Hugo/Features/Overview/Views/OverviewDateRow.swift` is an unused Xcode template whose body is `Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)`. Only the file itself references `OverviewDateRow`.
- The project uses `PBXFileSystemSynchronizedRootGroup`: adding or deleting a Swift file needs no `project.pbxproj` edit.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | no output, exit 0 |
| Format | `xcrun swift-format format --in-place --recursive Hugo HugoTests` | exit 0 |
| Gate | `Scripts/verify.sh` | contains `** TEST SUCCEEDED **` and `** ANALYZE SUCCEEDED **`, exit 0 |

## Scope

**In scope:** whitespace and formatting in `.swift` files under `Hugo/` and `HugoTests/`; deleting `OverviewDateRow.swift`; one flag in `Scripts/verify.sh`.

**Out of scope:**
- Any behavior change. `git diff -w` must stay small.
- Declarations under `Hugo/Persistence/SchemaVersions/**`. Whitespace there is fine; changing a type, default, attribute, or property is forbidden because it changes a shipped schema's version hash and breaks store loading (`NSCocoaErrorDomain 134504`).
- `Hugo/Resources/Localizable.xcstrings`.

## Git workflow

- Branch: `advisor/031-formatting-baseline`
- Commit style: plain imperative sentences (e.g. `Removed dead code`) or `SLN-###: Title`.
- Do not push.

## Steps

### Step 0: Preconditions

`git status --porcelain -- Hugo HugoTests Scripts`

**Expected:** no output.

**STOP** if anything is printed. At planning time `Hugo/Features/Reports/SubmitReportView.swift` and `Hugo/Resources/Localizable.xcstrings` held uncommitted work. The owner decides whether to commit, stash, or discard it.

Then `git switch -c advisor/031-formatting-baseline`.

### Step 1: Delete the template view

`git rm Hugo/Features/Overview/Views/OverviewDateRow.swift`

**Verify:** `grep -rn OverviewDateRow Hugo HugoTests` prints nothing.

### Step 2: Auto-format

`xcrun swift-format format --in-place --recursive Hugo HugoTests`

**Verify:** `git diff -w --stat` lists only a few files (import order, extension access-level moves, blank lines).

**STOP** if `git diff -w -- Hugo/Persistence/SchemaVersions` shows anything other than line-break changes.

### Step 3: Fix the remaining diagnostics by hand

Run the lint command. Expected leftovers:

- `Hugo/Features/Reports/Domain/ServiceDurationFormatter.swift:4` (line too long). Wrap it:

  ```swift
  private static let defaultAccessibilityStyle = Duration.UnitsFormatStyle(
      allowedUnits: [.hours, .minutes],
      width: .wide
  )
  ```

- `HugoTests/Domain/ServiceDurationFormatterTests.swift:16-17`: move each formatter call into a local `let`, then assert on the locals with the same boolean logic.
- `HugoTests/Persistence/SchemaMigrationTests.swift:338-339` and `:931-932`: bind each looked-up value to a local `let` (use `try #require(...)` where the original force-unwrapped), then compare the locals. Assertion semantics must not change.

**Verify:** the lint command prints nothing and exits 0.

### Step 4: Run tests serially

In `Scripts/verify.sh`, change the test command's second line to:

```sh
    -destination "$DESTINATION" -derivedDataPath "$DERIVED_DATA" -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

**Verify:** `grep -c "parallel-testing-enabled NO" Scripts/verify.sh` prints `1`.

### Step 5: Run the gate

`git diff --check && Scripts/verify.sh`

**Expected:** output contains `** TEST SUCCEEDED **` and `** ANALYZE SUCCEEDED **`; exit 0.

### Step 6: Commit

1. `Format sources with swift-format` (steps 1–3)
2. `Run tests serially in verify.sh` (step 4)
3. Add the first commit's full hash to `.git-blame-ignore-revs` (create it if missing): `Ignore formatting commit in blame`

## Test plan

No new tests. The existing suite (151 tests at `dc0b7f6`) must still pass.

## Done criteria

- [ ] Lint command exits 0 with no output
- [ ] `Scripts/verify.sh` exits 0
- [ ] `git diff -w dc0b7f6..HEAD -- Hugo/Persistence/SchemaVersions` shows no declaration changes
- [ ] `plans/README.md` row for 031 updated

## STOP conditions

- Step 0 finds uncommitted changes.
- The formatter changes a declaration under `Hugo/Persistence/SchemaVersions/**`.
- A test that passed before formatting fails afterwards.

## Maintenance notes

- Plans 032–036 quote code taken at `dc0b7f6`, some of it tab-indented. Differences that are only whitespace are not drift.
- Set Xcode to indent with 4 spaces so tabs don't return.
