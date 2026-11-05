# Plan 037: Make `Scripts/verify.sh` pass again and run tests serially everywhere

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 3f8d48b..HEAD -- Hugo/Persistence/SchemaVersions/V11/EntryV11.swift Hugo/Features/Overview/Views/OverviewListView.swift Hugo.xcodeproj/xcshareddata/xcschemes HugoTests/Persistence/SchemaMigrationTests.swift`
> If any of these files changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding. On a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `3f8d48b`, 2026-10-12
- **Issue**: [SLN-246](https://linear.app/sebastianln/issue/SLN-246)

## Why this matters

`Scripts/verify.sh` is the gate every plan in this repo uses as its done check. It runs `swift-format lint --strict`, then the tests, then static analysis, under `set -eu`. At `3f8d48b` the lint step fails with 9 diagnostics, so tests and analysis never run and every later plan starts from a red baseline. Behind the lint failure, all 153 tests pass and analysis is clean, so this plan only needs whitespace fixes. Separately, both shared Xcode schemes mark the test target `parallelizable = "YES"`. Running the SwiftData migration tests in parallel is known to be flaky (`Failed to cast model ... to Entry`, recorded in `plans/031-formatting-and-verification-baseline.md`). `verify.sh` already passes `-parallel-testing-enabled NO`, but Cmd-U in Xcode and Xcode Cloud test actions use the scheme setting.

## Current state

- `Scripts/verify.sh` (read-only for this plan):

  ```sh
  xcrun swift-format lint --strict --recursive Hugo HugoTests
  xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug \
      -destination "$DESTINATION" -derivedDataPath "$DERIVED_DATA" -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
  xcodebuild analyze -project Hugo.xcodeproj -scheme Hugo -configuration Debug \
      -destination 'generic/platform=iOS Simulator' -derivedDataPath "${DERIVED_DATA}-Analyze" CODE_SIGNING_ALLOWED=NO
  ```

- The 9 lint diagnostics at `3f8d48b`, all tab indentation or trailing whitespace added by the last commit:

  ```text
  Hugo/Features/Overview/Views/OverviewListView.swift:218:1: error: [Indentation] replace leading whitespace with 12 spaces
  Hugo/Features/Overview/Views/OverviewListView.swift:222:1: error: [Indentation] replace leading whitespace with 16 spaces
  Hugo/Features/Overview/Views/OverviewListView.swift:223:1: error: [Indentation] replace leading whitespace with 20 spaces
  Hugo/Features/Overview/Views/OverviewListView.swift:225:1: error: [Indentation] replace leading whitespace with 12 spaces
  Hugo/Features/Overview/Views/OverviewListView.swift:229:1: error: [Indentation] replace leading whitespace with 12 spaces
  Hugo/Persistence/SchemaVersions/V11/EntryV11.swift:54:1: error: [TrailingWhitespace] remove trailing whitespace
  Hugo/Persistence/SchemaVersions/V11/EntryV11.swift:55:1: error: [Indentation] replace leading whitespace with 8 spaces
  Hugo/Persistence/SchemaVersions/V11/EntryV11.swift:56:1: error: [Indentation] replace leading whitespace with 12 spaces
  Hugo/Persistence/SchemaVersions/V11/EntryV11.swift:57:1: error: [Indentation] replace leading whitespace with 8 spaces
  ```

- `Hugo/Persistence/SchemaVersions/V11/EntryV11.swift:54-57` (tabs shown as `→`):

  ```swift
  →→→
  →→→var isCarriedIn: Bool {
  →→→→sourceReportYear != nil && sourceReportMonth != nil
  →→→}
  ```

  This is the current SwiftData schema file. Whitespace changes do not affect the model hash, but no other change to this file is allowed.

- `Hugo.xcodeproj/xcshareddata/xcschemes/Hugo.xcscheme:40-42` and the identical block in `Production.xcscheme:40-42`:

  ```xml
         <TestableReference
            skipped = "NO"
            parallelizable = "YES">
  ```

- `HugoTests/Persistence/SchemaMigrationTests.swift:1-8`:

  ```swift
  import Foundation
  import SwiftData
  import Testing

  @testable import Hugo

  @MainActor
  struct SchemaMigrationTests {
  ```

- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest.
- `.swift-format` sets 4-space indentation and a 120-character line length.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Format two files | `xcrun swift-format format --in-place Hugo/Persistence/SchemaVersions/V11/EntryV11.swift Hugo/Features/Overview/Views/OverviewListView.swift` | exit 0 |
| Tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **`, `Test run with 153 tests in 17 suites passed` |
| Full gate | `Scripts/verify.sh` | exit 0 |

If the `iPhone 17 Pro` / `OS=26.5` simulator is missing, list simulators with `xcrun simctl list devices available` and pass another iOS 26 device through `DESTINATION='platform=iOS Simulator,name=<name>,OS=<os>' Scripts/verify.sh`.

## Scope

**In scope** (the only files you should modify):

- `Hugo/Persistence/SchemaVersions/V11/EntryV11.swift` (whitespace only)
- `Hugo/Features/Overview/Views/OverviewListView.swift` (whitespace only)
- `Hugo.xcodeproj/xcshareddata/xcschemes/Hugo.xcscheme` (one attribute)
- `Hugo.xcodeproj/xcshareddata/xcschemes/Production.xcscheme` (one attribute)
- `HugoTests/Persistence/SchemaMigrationTests.swift` (one attribute line)
- `plans/README.md` (status row)

**Out of scope**:

- Any non-whitespace change to Swift files. Plan 042 changes `OverviewCarriedEntriesView` behavior later. Do not fix it here.
- `Scripts/verify.sh`. It is correct.
- Running `swift-format format` on any other file or directory. Other files already pass lint, and reformatting them adds blame noise.
- `Hugo.xcodeproj/project.pbxproj`.

## Git workflow

- Branch: `advisor/037-green-gate`
- Commit messages are short imperative sentences without prefixes, for example `Run tests serially in verify.sh` or `Format sources with swift-format` (from `git log`).
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Reformat the two files

Run the format command from the table. Then confirm that only whitespace changed:

**Verify**:

- `xcrun swift-format lint --strict --recursive Hugo HugoTests` → exit 0, no output.
- `git diff -w --ignore-blank-lines -- Hugo` → prints nothing (no non-whitespace change).
- `git diff --stat` → only the two Swift files listed.

Commit: `Fix tab indentation from carried-entries commit`.

### Step 2: Disable parallel testing in both shared schemes

In `Hugo.xcodeproj/xcshareddata/xcschemes/Hugo.xcscheme` and `Production.xcscheme`, change `parallelizable = "YES"` to `parallelizable = "NO"` inside the `<TestableReference>` for `HugoTests`. Change nothing else in either file.

**Verify**: `grep -n 'parallelizable' Hugo.xcodeproj/xcshareddata/xcschemes/*.xcscheme` → exactly two lines, both `parallelizable = "NO">`.

### Step 3: Serialize the migration suite in-process

Swift Testing can also run test functions of one suite concurrently. Add the `.serialized` trait to the migration suite so it stays serial even if someone re-enables parallel testing:

```swift
@MainActor
@Suite(.serialized)
struct SchemaMigrationTests {
```

**Verify**: `grep -n '@Suite(.serialized)' HugoTests/Persistence/SchemaMigrationTests.swift` → one match on the line before `struct SchemaMigrationTests {`.

Commit steps 2 and 3 together: `Run migration tests serially in Xcode and Xcode Cloud`.

### Step 4: Run the full gate

**Verify**: `Scripts/verify.sh` → exit 0. The output contains `** TEST SUCCEEDED **` with `153 tests in 17 suites passed`, and `** ANALYZE SUCCEEDED **`.

## Test plan

No new tests. This plan restores the existing suite as the gate. The expected count after this plan is 153 tests in 17 suites.

## Done criteria

- [ ] `xcrun swift-format lint --strict --recursive Hugo HugoTests` exits 0
- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -c 'parallelizable = "NO"' Hugo.xcodeproj/xcshareddata/xcschemes/Hugo.xcscheme Hugo.xcodeproj/xcshareddata/xcschemes/Production.xcscheme` prints `1` for each file
- [ ] `git diff -w --ignore-blank-lines 3f8d48b -- Hugo` prints nothing
- [ ] `git status --porcelain` lists no files outside the Scope list
- [ ] `plans/README.md` row for 037 says DONE

## STOP conditions

Stop and report back if:

- The lint step reports diagnostics in files other than the two listed (someone committed new formatting problems). Report the list. Do not format other files.
- `git diff -w --ignore-blank-lines` shows any non-whitespace change after formatting.
- Tests fail after Step 1. A whitespace-only change cannot break tests, so this means the baseline moved.
- `Scripts/verify.sh` fails at the analyze step.

## Maintenance notes

- The gate regressed within two days of plan 031 because nothing runs it automatically. A git pre-commit hook or an Xcode Cloud `ci_scripts/ci_post_clone.sh` that runs the lint step would prevent a repeat. That is not part of this plan.
- If the migration suite becomes too slow serially, the fix is removing the shared `nonisolated(unsafe)` staging statics in `HugoMigrationPlan.swift`. That was deliberately deferred in an earlier audit.
