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
    -project Hugo.xcodeproj -scheme Debug -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
    -derivedDataPath /tmp/HugoDerivedData CODE_SIGNING_ALLOWED=NO
```

The local verification entry point is:

```sh
Scripts/verify.sh
```

It runs strict Swift-format lint, Debug tests, and static analysis. The tests run on a simulator that only this script uses, `Hugo Verify iOS 26.5`, which the script creates the first time. Only one run happens at a time: a second run waits for the first. Don't point other test runs or Xcode at that simulator. `DESTINATION` and `DERIVED_DATA` can be overridden.

### Pre-commit format hook

Run once per clone:

    Scripts/install-hooks.sh

After that, every commit formats the staged Swift files with `swift-format`, adds the fixes to the commit, and rejects the commit only if something cannot be fixed automatically. Files with unstaged changes are not reformatted, only checked. It covers formatting only; run `Scripts/verify.sh` for tests and static analysis. Skip it in an emergency with `git commit --no-verify`.

## Builds

Hugo has three build configurations, each with a scheme of the same name:

* **Debug**: development in Xcode. Bundle ID `com.ordellnielsen.Hugo.dev`.
* **TestFlight**: what beta testers install. Archive with the `TestFlight` scheme.
* **Production**: the App Store build. Archive with the `Production` scheme.

TestFlight and Production share the App Store bundle ID and iCloud container. Each configuration turns feature flags on in its `Configuration/*.xcconfig` file, and Swift code checks the flag, never the build's name:

| Flag | Debug | TestFlight | Production |
|---|---|---|---|
| `SHOW_DEBUG_MENU` | on | on | off |
| `SHOW_SHARE_TESTFLIGHT` | on | on | off |
| `SHOW_JOIN_BETA` | off | off | on |

The App Store build must be its own Production archive. A TestFlight archive contains the debug menu and must not be sent to App Review.

All three schemes run the tests in the Debug configuration, because the tests use `@testable import Hugo`, which needs a build with testability on.

## Architecture

* `Hugo/App` — app composition only (entry point, root view, bootstrap), and CloudKit boundaries.
* `Hugo/Domain` — small value types shared across features: `YearMonth`, `RoundingRule`, and `UserDefaultsKeys`.
* `Hugo/DesignSystem` — generic UI that knows nothing about any feature: theme tokens, styles, modifiers, reusable components.
* `Hugo/Resources` — the string catalog, localized help pages (Markdown), and app icons.
* `Hugo/Persistence` — SwiftData schema versions, migration plan, container factory, and the sync-duplicate merge.
* `Hugo/Features` — feature-first SwiftUI UI and feature-local domain logic, organized into Screens, Views, State, Domain and Services folders (see AGENTS.md).
* `Hugo/PreviewSupport` — isolated, synchronous in-memory preview containers and fixtures.
* `HugoTests` — domain, feature, persistence, and migration tests.
* `Configuration` — project-only xcconfig and entitlement inputs; these are not app resources.

The only Swift package dependency is MarkdownUI, used by the help screen.

The UI uses **Category** terminology, while SwiftData persistence deliberately retains **Tracker** names and identities. Historical schema shapes are compatibility APIs and must not be edited casually; add a tested migration stage for future changes.
