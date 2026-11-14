# Plan 114: Make `Scripts/verify.sh` give the same answer every time it runs on the same code

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 7e3c4e9..HEAD -- Scripts/verify.sh README.md HugoTests/Features/SymbolPicker/Domain/SymbolDefinitionTests.swift`
> Expected: no output. Otherwise compare the excerpts below with the live
> files. A mismatch is a STOP condition.

## Status

- **Priority**: P1 (every other plan's review trusts this gate)
- **Effort**: M
- **Risk**: LOW. A shell script, one README paragraph and one test. No app code.
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `7e3c4e9`, 2026-11-14
- **Issue**: [SLN-312](https://linear.app/sebastianln/issue/SLN-312)

## Why this matters

`Scripts/verify.sh` is the gate every commit must pass (`AGENTS.md` section 8). On 2026-11-14 it failed twice and passed twice on the same, unchanged code. A gate that flips at random gets ignored, or blocks good work.

The failing runs had this signature:

1. The simulator's test host logged `[strings] Unable to load .strings file`.
2. Tests that read bundled resources failed: `BundledMarkdownTests`, the Danish `hoursStringShortensMinutesInDanish`, `PlannerTargetTests.settingSummary…` and `AddEntryFormModelTests.draftWithoutTracker…`.
3. The test host crashed with `Index out of range` in `SymbolDefinitionTests.commaSeparatedKeywordMatches` and restarted.

The built app in derived data contained every resource. The copy installed in the simulator apparently didn't, partway through the run.

**The advisor's diagnosis (to be confirmed in Step 2):** something replaced or removed the installed test host app on the simulator while the tests ran. Every verify run, every agent's ad-hoc `xcodebuild test` and Xcode itself use the same simulator. There is exactly one "iPhone 17 Pro" on iOS 26.5 on this Mac (UDID `2EFEF2D8-3511-44AE-AF08-E8CE18E8A0C0`), and the script's default destination `platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5` picks it. Agents have run verify concurrently with their own derived-data folders (`/tmp/HugoVerify-067`, `-068`, `-069` and `-073` exist), so two runs installing the same bundle ID (`com.ordellnielsen.Hugo.dev`) on one simulator at once is a real possibility. The `Index out of range` is a side effect: when strings fail to load, `String(localized:)` returns the key, which has no commas, so `keywords[1]` is out of range. The crash then takes the whole test host down and makes more tests fail.

**The fix:**
- verify.sh runs on its own simulator, named `Hugo Verify iOS 26.5`, which nothing else uses.
- Only one verify.sh run can happen at a time. A second run waits for the first one.
- The keyword test fails cleanly instead of crashing the host.

## Current state

`Scripts/verify.sh` (whole file, 15 lines):

```sh
#!/bin/sh
set -eu

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5}"
DERIVED_DATA="${DERIVED_DATA:-/tmp/HugoVerifyDerivedData}"

Scripts/check-layout.sh
xcrun swift-format lint --strict --recursive Hugo HugoTests
xcodebuild test -project Hugo.xcodeproj -scheme Debug -configuration Debug \
    -destination "$DESTINATION" -derivedDataPath "$DERIVED_DATA" -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
xcodebuild analyze -project Hugo.xcodeproj -scheme Debug -configuration Debug \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "${DERIVED_DATA}-Analyze" CODE_SIGNING_ALLOWED=NO
```

`README.md:22-28`:

````markdown
The local verification entry point is:

```sh
Scripts/verify.sh
```

It runs strict Swift-format lint, Debug tests, and static analysis. `DESTINATION` and `DERIVED_DATA` can be overridden.
````

`HugoTests/Features/SymbolPicker/Domain/SymbolDefinitionTests.swift:28-35`:

```swift
    @Test
    func commaSeparatedKeywordMatches() {
        let keywords = String(localized: symbol.keywordsKey)
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        #expect(symbol.matches(String(keywords[1]), nil))
    }
```

Facts checked on this Mac on 2026-11-14:
- Xcode 27.2 (27B52). The runtime `com.apple.CoreSimulator.SimRuntime.iOS-26-5` (iOS 26.5, 23F77) and the device type `com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro` are installed.
- Existing iPhone 17 Pro simulators: one per runtime 26.0, 26.1, 26.2, 26.4 and 26.5. No device named `Hugo Verify…` exists yet.
- Scripts in `Scripts/` are POSIX `sh` with `set -eu` and 4-space indentation (see `Scripts/check-layout.sh`). Match that.
- Tests use Swift Testing. `#require` returns the unwrapped value and fails the test without crashing when it's nil (used in `HugoTests/Features/Reports/State/SubmitReportFormModelTests.swift:129`, `let report = try #require(...)`). A test using `try` must be marked `throws`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full gate | `Scripts/verify.sh` | exit 0. Takes several minutes. |
| Shell syntax | `sh -n Scripts/verify.sh` | exit 0, no output |
| Simulators | `xcrun simctl list devices available` | lists devices with UDIDs |
| Format | `xcrun swift-format lint --strict HugoTests/Features/SymbolPicker/Domain/SymbolDefinitionTests.swift` | exit 0, no output |

Run long commands with a 600000 ms timeout, or in the background. A verify run can take 5 to 10 minutes.

## Scope

**In scope** (the only files you may modify):
- `Scripts/verify.sh`
- `README.md` (only the paragraph quoted above)
- `HugoTests/Features/SymbolPicker/Domain/SymbolDefinitionTests.swift` (only `commaSeparatedKeywordMatches`)

You may create and delete simulators and files under `/tmp/hugo-114/` for the experiments.

**Out of scope**:
- Any file under `Hugo/`. The app is not the problem.
- `Hugo.xcodeproj` and its schemes. `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` has an uncommitted change by the owner. Never stage, commit, revert or stash it.
- Do not delete or erase any simulator you did not create in this plan. In particular, leave `2EFEF2D8-3511-44AE-AF08-E8CE18E8A0C0` alone apart from running tests on it in Step 2.
- Do not "fix" other tests that fail. Report them.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- Never stage `plans/`, `.claude/` or `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage files by explicit path.
- Commit messages follow Conventional Commits, for example `fix: count time without a category as main time everywhere` (from `git log`).
- Two commits:
  1. `test: fail the keyword test instead of crashing when strings don't load`
  2. `build: run verify.sh on its own simulator, one run at a time`

## Steps

### Step 1: Make the keyword test fail cleanly

Replace `commaSeparatedKeywordMatches` with:

```swift
    @Test
    func commaSeparatedKeywordMatches() throws {
        let keywords = String(localized: symbol.keywordsKey)
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        // Without the string catalog `String(localized:)` returns the key,
        // which has no commas. Fail here instead of crashing the test host.
        let secondKeyword = try #require(keywords.dropFirst().first)

        #expect(symbol.matches(String(secondKeyword), nil))
    }
```

**Verify**: `xcrun swift-format lint --strict HugoTests/Features/SymbolPicker/Domain/SymbolDefinitionTests.swift` → exit 0, no output.

Commit 1 (only this file).

### Step 2: Confirm the diagnosis (an experiment, no file changes)

The goal: show that two test runs on the same simulator at the same time break each other with the logged signature, and that two runs on two separate simulators don't.

Run each command below with a 600000 ms timeout. Write down every exit code and every count; Step 5's report needs them.

1. Build the tests once:
   ```sh
   mkdir -p /tmp/hugo-114
   xcodebuild build-for-testing -project Hugo.xcodeproj -scheme Debug -configuration Debug \
       -destination 'id=2EFEF2D8-3511-44AE-AF08-E8CE18E8A0C0' -derivedDataPath /tmp/hugo-114/dd \
       CODE_SIGNING_ALLOWED=NO > /tmp/hugo-114/build.log 2>&1; echo "build exit $?"
   ```
   Expected: `build exit 0`. If it isn't, STOP (the code doesn't build, which isn't this plan's problem).

2. **Experiment A: two runs on the same simulator at the same time.**
   ```sh
   cd /Users/sebastiannielsen/Documents/Areas/Personal/Apps/Hugo
   for n in 1 2; do
       ( xcodebuild test-without-building -project Hugo.xcodeproj -scheme Debug -configuration Debug \
           -destination 'id=2EFEF2D8-3511-44AE-AF08-E8CE18E8A0C0' -derivedDataPath /tmp/hugo-114/dd \
           -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO > /tmp/hugo-114/a$n.log 2>&1; \
         echo $? > /tmp/hugo-114/a$n.exit ) &
       sleep 20
   done
   wait
   for n in 1 2; do
       echo "A$n exit $(cat /tmp/hugo-114/a$n.exit)" \
           "strings=$(grep -c 'Unable to load .strings file' /tmp/hugo-114/a$n.log)" \
           "failed=$(grep -c -E 'Test .* failed|✘' /tmp/hugo-114/a$n.log)" \
           "crash=$(grep -c -E 'Index out of range|Restarting after unexpected exit|crashed' /tmp/hugo-114/a$n.log)"
   done
   ```
   Expected if the diagnosis is right: at least one run exits non-zero, with `strings` > 0, or `crash` > 0, or failed tests in `BundledMarkdownTests`, or an xcodebuild error about the device or the app being replaced. Write down which of these you saw. Copy up to 20 relevant lines from the logs into your report (`grep -n -E 'strings file|failed|crash|Restarting|error' /tmp/hugo-114/a1.log | head -20`).

3. Create two throwaway simulators:
   ```sh
   B1=$(xcrun simctl create "Hugo 114 B1" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-5)
   B2=$(xcrun simctl create "Hugo 114 B2" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-5)
   echo "$B1 $B2" > /tmp/hugo-114/b-ids
   ```
   Expected: two UDIDs.

4. **Experiment B: two runs at the same time, each on its own simulator.** Repeat the loop from 2, but run 1 uses `-destination "id=$B1"` and run 2 uses `-destination "id=$B2"`. Logs go to `/tmp/hugo-114/b$n.log`, exit codes to `/tmp/hugo-114/b$n.exit`. Print the same summary line (prefix `B$n`).
   Expected if the diagnosis is right: both exit 0 and `strings=0`.

5. Delete the throwaway simulators: `xcrun simctl delete $(cat /tmp/hugo-114/b-ids)`. Expected: exit 0.

How to read the results:

| A | B | Meaning | What to do |
|---|---|---|---|
| fails with the signature | both pass | Diagnosis confirmed | Continue with Step 3 |
| fails with the signature | a run fails too | Separate simulators aren't enough | STOP and report both summaries and log excerpts |
| both pass | both pass | Not reproduced | Continue with Step 3 (the isolation is still right), and say "not reproduced" in the report |
| both pass | a run fails | Something else is wrong | STOP and report |

**Verify**: you have written down four summary lines (A1, A2, B1, B2), and `xcrun simctl list devices | grep -c "Hugo 114"` prints `0`.

### Step 3: Give verify.sh its own simulator and a lock

Replace the whole of `Scripts/verify.sh` with the following. Keep the file executable (`ls -l Scripts/verify.sh` shows `x`); writing the file with an editor keeps the mode, but check.

```sh
#!/bin/sh
# Runs the gate from AGENTS.md section 8: layout check, strict lint, the tests
# and static analysis. It must exit 0 before every commit.
#
# The tests run on a simulator that only this script uses ("Hugo Verify iOS
# 26.5", created on first use), and only one run happens at a time. Two test
# runs sharing a simulator replace each other's installed app, and the tests
# then fail at random because resources such as the string catalog vanish.
set -eu
cd "$(dirname "$0")/.."

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR
DERIVED_DATA="${DERIVED_DATA:-/tmp/HugoVerifyDerivedData}"
SIMULATOR_RUNTIME="${SIMULATOR_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-5}"
SIMULATOR_TYPE="${SIMULATOR_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro}"
SIMULATOR_NAME="${SIMULATOR_NAME:-Hugo Verify iOS 26.5}"
LOCK_DIR="${VERIFY_LOCK_DIR:-/tmp/hugo-verify.lock}"

# One run at a time. A second run waits up to 30 minutes. A lock left behind
# by a run that no longer exists is removed.
waited=0
until mkdir "$LOCK_DIR" 2>/dev/null; do
    owner=$(cat "$LOCK_DIR/pid" 2>/dev/null || true)
    if [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; then
        echo "verify: removing a stale lock from process $owner"
        rm -rf "$LOCK_DIR"
        continue
    fi
    if [ "$waited" -eq 0 ]; then
        echo "verify: another run is active (lock $LOCK_DIR); waiting for it to finish"
    fi
    if [ "$waited" -ge 1800 ]; then
        echo "verify: gave up after 30 minutes; remove $LOCK_DIR if no run is active" >&2
        exit 1
    fi
    sleep 5
    waited=$((waited + 5))
done
echo $$ >"$LOCK_DIR/pid"
trap 'rm -rf "$LOCK_DIR"' EXIT
trap 'exit 130' INT TERM

if [ -z "${DESTINATION:-}" ]; then
    simulator_id=$(xcrun simctl list devices available |
        grep -F "    $SIMULATOR_NAME (" |
        head -n 1 |
        sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
    if [ -z "$simulator_id" ]; then
        echo "verify: creating the simulator \"$SIMULATOR_NAME\""
        simulator_id=$(xcrun simctl create "$SIMULATOR_NAME" "$SIMULATOR_TYPE" "$SIMULATOR_RUNTIME")
    fi
    DESTINATION="id=$simulator_id"
fi

Scripts/check-layout.sh
xcrun swift-format lint --strict --recursive Hugo HugoTests
xcodebuild test -project Hugo.xcodeproj -scheme Debug -configuration Debug \
    -destination "$DESTINATION" -derivedDataPath "$DERIVED_DATA" -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
xcodebuild analyze -project Hugo.xcodeproj -scheme Debug -configuration Debug \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "${DERIVED_DATA}-Analyze" CODE_SIGNING_ALLOWED=NO
```

Notes:
- `cd "$(dirname "$0")/.."` is new. It lets the script run from any folder, like `Scripts/check-layout.sh` does.
- `DESTINATION` still overrides everything, as the README promises.

**Verify**:
- `sh -n Scripts/verify.sh` → exit 0, no output.
- `test -x Scripts/verify.sh && echo executable` → `executable`.
- `grep -c "name=iPhone 17 Pro" Scripts/verify.sh` → `0`.

### Step 4: Run the new gate, including the lock

1. Run `Scripts/verify.sh > /tmp/hugo-114/v1.log 2>&1; echo "exit $?"` (timeout 600000 ms, or in the background).
   Expected: `exit 0`. The log contains `creating the simulator "Hugo Verify iOS 26.5"` on the first run and `** TEST SUCCEEDED **`.
   Then `xcrun simctl list devices available | grep -c "Hugo Verify iOS 26.5"` → `1`.
2. Lock check. Start a run in the background and a second one 30 seconds later:
   ```sh
   ( Scripts/verify.sh > /tmp/hugo-114/v2.log 2>&1; echo $? > /tmp/hugo-114/v2.exit ) &
   sleep 30
   ( Scripts/verify.sh > /tmp/hugo-114/v3.log 2>&1; echo $? > /tmp/hugo-114/v3.exit ) &
   wait
   echo "v2 $(cat /tmp/hugo-114/v2.exit) v3 $(cat /tmp/hugo-114/v3.exit)"
   grep -c "another run is active" /tmp/hugo-114/v3.log
   ```
   Expected: `v2 0 v3 0`, and the grep prints `1`. Neither log contains `creating the simulator` (the device exists now). This can take 20 minutes, so run it in the background if your tool's timeout is shorter. `test -d /tmp/hugo-verify.lock || echo "no lock"` afterwards prints `no lock`.

If a run in this step fails, check its log for `Unable to load .strings file`. If the signature is there, STOP and report. If another test fails, report it with its name and message, and STOP.

### Step 5: Update the README and commit

Replace the sentence `It runs strict Swift-format lint, Debug tests, and static analysis. \`DESTINATION\` and \`DERIVED_DATA\` can be overridden.` in `README.md` with:

```markdown
It runs strict Swift-format lint, Debug tests, and static analysis. The tests run on a simulator that only this script uses, `Hugo Verify iOS 26.5`, which the script creates the first time. Only one run happens at a time: a second run waits for the first. Don't point other test runs or Xcode at that simulator. `DESTINATION` and `DERIVED_DATA` can be overridden.
```

**Verify**: `grep -c "Hugo Verify iOS 26.5" README.md` → `1`.

Commit 2: `Scripts/verify.sh` and `README.md`, by path.

## Test plan

- No new tests. Step 1 changes how an existing test fails. It still passes when the catalog loads, which Step 4 shows.
- Steps 2 and 4 are the evidence. The report must include the four Step 2 summary lines and the Step 4 results.

## Done criteria

- [ ] `sh -n Scripts/verify.sh` exits 0
- [ ] `Scripts/verify.sh` exits 0 (Step 4.1)
- [ ] Two overlapping runs both exit 0, and the second one logged that it waited (Step 4.2)
- [ ] `xcrun simctl list devices | grep -c "Hugo 114"` prints `0`
- [ ] `git show --stat HEAD~1` lists only `SymbolDefinitionTests.swift`; `git show --stat HEAD` lists only `Scripts/verify.sh` and `README.md`
- [ ] `git status --short` still shows ` M Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` (untouched)

## STOP conditions

- The drift check shows changes and the excerpts don't match.
- `build-for-testing` in Step 2.1 fails.
- Step 2 gives one of the two STOP rows in its table.
- Step 4 fails with the `Unable to load .strings file` signature on the new simulator.
- `xcrun simctl create` fails because the runtime or the device type is missing.

## Maintenance notes

- When the project moves to a newer simulator runtime, change `SIMULATOR_RUNTIME` and `SIMULATOR_NAME` together. The old `Hugo Verify iOS 26.5` device can then be deleted with `xcrun simctl delete "Hugo Verify iOS 26.5"`.
- Agents that want parallel test runs should not pass `DESTINATION`. The lock then serializes them on the dedicated simulator. Passing `DESTINATION` bypasses the simulator choice but still takes the lock.
- If the signature ever comes back on the dedicated simulator, the cause is inside the test run. The next suspect is Swift Testing running tests in parallel within the host process: `-parallel-testing-enabled NO` may not cover it. Look for tests that change `UserDefaults.standard` or global state.
