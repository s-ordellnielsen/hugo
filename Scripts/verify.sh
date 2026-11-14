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
