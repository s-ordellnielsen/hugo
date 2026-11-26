#!/bin/sh
# Runs the gate from AGENTS.md section 8: layout check, strict lint, the tests
# and static analysis. It must exit 0 before every commit.
#
# The tests run on a simulator that only this script uses ("Hugo Verify iOS
# 26.5", created on first use), and only one run happens at a time. Two test
# runs sharing a simulator replace each other's installed app, and the tests
# then fail at random because resources such as the string catalog vanish.
#
# Output is quiet. Each stage prints one "ok" line, or on failure the matching
# error lines (or the last 15 lines of its log if none match) and the log path. Logs are in
# /tmp/hugo-verify-logs. Options:
#   --verbose, -v      print everything, as the tools write it (or VERIFY_VERBOSE=1)
#   --only <Suite>     run only that test suite, repeatable. Skips lint and
#                      analysis, so it is not the commit gate. See test-quick.sh.
set -eu
cd "$(dirname "$0")/.."

verbose=0
only=""
while [ $# -gt 0 ]; do
    case "$1" in
    --verbose | -v) verbose=1 ;;
    --only)
        shift
        if [ $# -eq 0 ]; then
            echo "verify: --only needs a test suite name, for example HugoTests/YearMonthTests" >&2
            exit 2
        fi
        only="$only -only-testing:$1"
        ;;
    *)
        echo "verify: unknown option $1" >&2
        exit 2
        ;;
    esac
    shift
done
if [ "${VERIFY_VERBOSE:-0}" = 1 ]; then
    verbose=1
fi

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR
DERIVED_DATA="${DERIVED_DATA:-/tmp/HugoVerifyDerivedData}"
SIMULATOR_RUNTIME="${SIMULATOR_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-5}"
SIMULATOR_TYPE="${SIMULATOR_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro}"
SIMULATOR_NAME="${SIMULATOR_NAME:-Hugo Verify iOS 26.5}"
LOCK_DIR="${VERIFY_LOCK_DIR:-/tmp/hugo-verify.lock}"

LOG_DIR="${VERIFY_LOG_DIR:-/tmp/hugo-verify-logs}"
mkdir -p "$LOG_DIR"

# run_stage <name> <command...>: quiet unless --verbose or the stage fails.
run_stage() {
    stage=$1
    shift
    if [ "$verbose" -eq 1 ]; then
        echo "== $stage"
        "$@"
        return
    fi
    log="$LOG_DIR/$stage.log"
    started=$(date +%s)
    if "$@" >"$log" 2>&1; then
        echo "ok   $stage ($(($(date +%s) - started))s)"
        warnings=$(grep -cE '\.swift:[0-9]+:[0-9]+: warning:' "$log" || true)
        if [ "$warnings" -gt 0 ]; then
            echo "     $warnings compiler warnings, see $log"
        fi
    else
        status=$?
        echo "FAIL $stage (exit $status), full log: $log"
        matches=$(grep -E 'error:|✘|\*\* [A-Z]+ FAILED|Failing tests' "$log" | head -n 30 || true)
        if [ -n "$matches" ]; then
            echo "$matches"
        else
            echo "--- last 15 lines"
            tail -n 15 "$log"
        fi
        exit "$status"
    fi
}

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

if [ -n "$only" ]; then
    echo "verify: partial run (--only). This is not the commit gate; run Scripts/verify.sh before committing."
    # $only is split into words on purpose, one -only-testing: option per suite.
    # shellcheck disable=SC2086
    run_stage tests xcodebuild test -project Hugo.xcodeproj -scheme Debug -configuration Debug \
        -destination "$DESTINATION" -derivedDataPath "$DERIVED_DATA" -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO $only
    exit 0
fi

run_stage layout Scripts/check-layout.sh
run_stage lint xcrun swift-format lint --strict --recursive Hugo HugoTests
run_stage tests xcodebuild test -project Hugo.xcodeproj -scheme Debug -configuration Debug \
    -destination "$DESTINATION" -derivedDataPath "$DERIVED_DATA" -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
run_stage analyze xcodebuild analyze -project Hugo.xcodeproj -scheme Debug -configuration Debug \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "${DERIVED_DATA}-Analyze" CODE_SIGNING_ALLOWED=NO
