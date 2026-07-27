# Plan 009: Normalize Xcode project hygiene, formatting, and documentation

> **Executor instructions**: Apply this only after all source moves are complete.
> Keep formatting changes mechanical and do not combine them with behavior
> changes. Update `plans/README.md` after the one-command verification succeeds.
>
> **Drift check (run first)**:
> `git diff --stat c047d57..HEAD -- Hugo.xcodeproj Configuration .gitignore README.md AGENTS.md Hugo HugoTests`
> Expect prior plans to have changed most source paths; stop only if the target
> architecture in `plans/README.md` was intentionally superseded.

## Status

* **Priority**: P2
* **Effort**: M
* **Risk**: LOW
* **Depends on**: Plans 001 through 008
* **Category**: DX / docs / tech-debt
* **Planned at**: commit `c047d57`, July 27, 2026

## Why this matters

The repository tracks user-specific Xcode state, keeps build configuration files
inside the app's synchronized source root, has no formatter configuration, and
does not document a repeatable command-line verification flow. Once source
structure stabilizes, a final mechanical pass makes the architecture legible
and prevents Xcode metadata or formatting drift from recreating noise.

## Current state

* Tracked files include `Hugo.xcodeproj/xcuserdata/**`, a breakpoint list, and workspace user data.
* `Hugo/ConfigDebug.xcconfig` and `ConfigRelease.xcconfig` sit inside the synchronized target root and were copied into the app before Plan 002's exception.
* `Dev.entitlements` is not referenced; all configurations currently point to `Hugo/Resources/Entitlements/Hugo.entitlements`.
* The xcconfig files define `APP_GROUP_IDENTIFIER`, but no source, entitlement, or build setting consumes it.
* Project build settings repeat bundle identifiers and environment suffixes while xcconfig values are partly unused.
* There is no `.swift-format`, `.gitignore` coverage for Xcode user data, CI, or verification script.
* README describes product intent but not architecture, setup, or commands.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift-format format --in-place --recursive Hugo HugoTests` | Exit 0 |
| Format lint | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift-format lint --strict --recursive Hugo HugoTests` | Exit 0 and no diagnostics |
| Tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan009DerivedData CODE_SIGNING_ALLOWED=NO` | Exit 0 and `TEST SUCCEEDED` |
| Analyze | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild analyze -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/HugoPlan009Analyze CODE_SIGNING_ALLOWED=NO` | Exit 0 and `ANALYZE SUCCEEDED` |
| User-data check | `git ls-files \| rg 'xcuserdata\|xcuserstate\|xcscmblueprint\|Breakpoints_v2'` | No matches |

## Scope

**In scope**:

* `.gitignore` — create or update.
* `.swift-format` — create.
* `Configuration/` — create and move xcconfig/entitlement inputs here.
* `Hugo.xcodeproj/project.pbxproj`
* Shared schemes only where paths/configuration references need updates.
* Tracked `xcuserdata` and breakpoint files — remove from Git.
* `README.md`
* `AGENTS.md`
* `Scripts/verify.sh` — optional but recommended.
* All `Hugo/**/*.swift` and `HugoTests/**/*.swift` for mechanical formatting only.
* `plans/README.md` status update.

**Out of scope**:

* Functional source changes.
* Adding third-party lint/format dependencies.
* Rewriting localization catalogs.
* Changing team IDs, iCloud identifiers, app IDs, signing style, or deployment target.
* Adding CI that requires credentials; document a follow-up if desired.

## Git workflow

* Branch: `advisor/009-project-hygiene`
* Commit project metadata/docs first and mechanical formatting separately.
* Suggested messages: `Normalized Xcode project configuration` and `Applied Swift formatting`.

## Steps

### Step 1: Stop tracking user-specific Xcode state

Add ignore rules for:

```gitignore
.DS_Store
DerivedData/
*.xcuserstate
xcuserdata/
*.xccheckout
*.xcscmblueprint
```

Remove already tracked `Hugo.xcodeproj/**/xcuserdata/**`, breakpoint lists, and
workspace user-state files from Git. Keep shared schemes under `xcshareddata`.

**Verify**: User-data check returns no matches and `git status --ignored --short`
shows local user state as ignored.

### Step 2: Move build configuration outside the synchronized app root

Move active xcconfig and entitlement files to `Configuration/` with concise
names such as `Debug.xcconfig`, `Release.xcconfig`, and `Hugo.entitlements`.
Update project references and `CODE_SIGN_ENTITLEMENTS` paths.

Delete the unused `Dev.entitlements` after confirming no configuration refers
to it. Remove unused xcconfig variables such as `APP_GROUP_IDENTIFIER`, or wire
them consistently only if an existing entitlement consumes them. Do not invent
an app group capability.

Consolidate bundle identifiers so each environment has one source of truth.
Preserve effective values:

* Debug: `com.ordellnielsen.Hugo.dev`
* Release: `com.ordellnielsen.Hugo`

Preserve the existing production iCloud container and signing team.

**Verify**: `xcodebuild -showBuildSettings` reports the same effective IDs,
Debug tests pass, and Production Release builds.

### Step 3: Add a repository Swift format policy

Create `.swift-format` based on Xcode's bundled formatter and the current Swift
version. Use conservative settings: 4-space indentation, readable line length,
ordered imports, and no rules that rename APIs or rewrite semantics.

Run formatter once across final app/test paths. Review the diff to ensure it is
mechanical. Do not hand-edit behavior in the formatting commit.

**Verify**: Strict formatter lint exits 0, then full tests pass.

### Step 4: Add one-command local verification

Create executable `Scripts/verify.sh` that:

* resolves `DEVELOPER_DIR`, defaulting to `/Applications/Xcode.app/Contents/Developer`
* runs strict swift-format lint
* runs Debug tests on an overridable simulator destination
* runs static analyze
* uses DerivedData under `/tmp` or a caller-provided path

Allow environment variables for simulator destination rather than hardcoding a
machine UUID. Keep the script side-effect-free with respect to source.

**Verify**: `Scripts/verify.sh` exits 0 from a clean checkout on this machine.

### Step 5: Document the final architecture and workflow

Expand README with:

* requirements: Xcode 26.6+, iOS/iPadOS 26+
* how to open/build/test
* `Scripts/verify.sh`
* the final source tree and responsibility of App, Domain, Persistence, Features, Shared, PreviewSupport, and Tests
* the deliberate Category UI versus Tracker persistence terminology boundary
* SwiftData migration rule: never edit shipped historical shape casually

Update `AGENTS.md` paths and examples to match the final architecture and Swift
6 settings. Remove any instruction that mandates a ViewModel for every view;
retain the distinction established in Plan 008.

**Verify**: Every path and command in README exists and the verification script
passes.

## Test plan

* Run formatter lint before and after all project metadata changes.
* Run Debug tests and static analyze.
* Run Production Release build after config moves.
* Inspect the built app bundle to ensure documentation and config files are not copied as resources.
* Compare effective bundle, deployment, entitlement, and iCloud settings before/after.

## Done criteria

* [ ] No Xcode user data or breakpoint state is tracked.
* [ ] Build configuration lives outside the synchronized app source root.
* [ ] Unused entitlement/config variables are gone without changing effective capabilities.
* [ ] Swift format config exists and strict lint passes.
* [ ] `Scripts/verify.sh` passes.
* [ ] README documents final architecture and commands accurately.
* [ ] Debug tests, analyze, and Production Release build pass.
* [ ] Built app bundle excludes README, AGENTS, xcconfig, and source-only metadata.
* [ ] Plan 009 is marked DONE.

## STOP conditions

* Moving entitlements changes effective signing capabilities or iCloud container values.
* Formatter output contains semantic changes or fails to parse generated Swift.
* A shared scheme depends on a user-specific path slated for deletion.
* Verification requires committing credentials or machine-specific simulator IDs.

## Maintenance notes

* Keep local verification aligned with any future CI; one should call the other rather than duplicate command logic.
* Add new source files under feature/domain folders and keep project-only inputs outside the synchronized app root.
* Reviewers should treat a future reappearance of `Views`, `Managers`, or `Utilities` catch-all folders as an architecture smell, not an automatic prohibition.
