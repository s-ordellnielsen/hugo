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
