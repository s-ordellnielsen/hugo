# Hugo

Hugo is an iOS/iPadOS 26+ SwiftUI app for tracking service entries and monthly publisher goals.

## Requirements

* Xcode 26.6 or newer
* iOS/iPadOS 26 or newer
* Swift 6 with complete strict-concurrency checking

## Build and test

Open `Hugo.xcodeproj` in Xcode, or run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
    -project Hugo.xcodeproj -scheme Hugo -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
    -derivedDataPath /tmp/HugoDerivedData CODE_SIGNING_ALLOWED=NO
```

The local verification entry point is:

```sh
Scripts/verify.sh
```

It runs strict Swift-format lint, Debug tests, and static analysis. `DESTINATION` and `DERIVED_DATA` can be overridden.

## Architecture

* `Hugo/App` — app composition, bootstrap, and CloudKit boundaries.
* `Hugo/Domain` — pure publisher-status and user-default domain values.
* `Hugo/Persistence` — SwiftData schema versions, migration plan, and container factory.
* `Hugo/Features` — feature-first SwiftUI UI and feature-local domain logic.
* `Hugo/PreviewSupport` — isolated, synchronous in-memory preview containers and fixtures.
* `HugoTests` — domain, feature, persistence, and migration tests.
* `Configuration` — project-only xcconfig and entitlement inputs; these are not app resources.

The UI uses **Category** terminology, while SwiftData persistence deliberately retains **Tracker** names and identities. Historical schema shapes are compatibility APIs and must not be edited casually; add a tested migration stage for future changes.
