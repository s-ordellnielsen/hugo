# Plan 001: Establish a refactoring safety net

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> STOP condition occurs, stop and report it rather than improvising. When done,
> update this plan's row in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat c047d57..HEAD -- Hugo HugoTests Hugo.xcodeproj`
> If any in-scope file changed, compare the current-state excerpts below with
> live code. Stop if behavior or paths no longer match.

## Status

* **Priority**: P1
* **Effort**: M
* **Risk**: LOW
* **Depends on**: none
* **Category**: tests / DX
* **Planned at**: commit `c047d57`, July 27, 2026

## Why this matters

The application builds and its test action succeeds, but the only test has no
assertions. A broad file move and rename would therefore have no automated way
to detect changes to duration formatting, monthly grouping, publisher goals,
symbol filtering, or default-tracker behavior. This plan adds characterization
tests without changing production behavior, creating the safety boundary for
all subsequent plans.

## Current state

* `HugoTests/HugoTests.swift:10-14` contains only `example()` with a template comment and no `#expect`.
* `Hugo/Utilities/functions.swift:10-14` formats a duration as zero-padded `HH:mm`.
* `Hugo/Utilities/YearMonth.swift:10-38` implements month identity, ordering, and localized display.
* `Hugo/Data/PublisherStatusConfig.swift:17-31` converts yearly and monthly goals.
* `Hugo/Features/SymbolPicker/Structs/SymbolDefinition.swift:29-47` implements localized text and attribute filtering.
* `Hugo/Managers/TrackerManager.swift:18-31` clears every existing default tracker and sets a new default, but currently swallows fetch and save errors.
* `Hugo.xcodeproj/xcshareddata/xcschemes/Hugo.xcscheme` includes `HugoTests` in the test action.
* The verified baseline command passes one empty test using Xcode 26.6 and an iOS 26.5 simulator.

Current duration behavior:

```swift
func formatDuration(_ totalSeconds: TimeInterval) -> String {
    let hours = Int(totalSeconds / 3600)
    let minutes = Int(totalSeconds.truncatingRemainder(dividingBy: 3600) / 60)
    return String(format: "%02d:%02d", hours, minutes)
}
```

Current goal behavior:

```swift
public func monthlyGoal() -> Int {
    if goalType == .yearly {
        return goal / 12
    }
    return goal
}
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Baseline tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan001DerivedData CODE_SIGNING_ALLOWED=NO` | Exit 0 and `TEST SUCCEEDED` |
| Build | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/HugoPlan001Build CODE_SIGNING_ALLOWED=NO` | Exit 0 and `BUILD SUCCEEDED` |
| Changed files | `git status --short` | Only files listed in Scope plus `plans/README.md` |

## Scope

**In scope**:

* `HugoTests/HugoTests.swift` — delete after replacement.
* `HugoTests/TestSupport/InMemoryModelContainer.swift` — create.
* `HugoTests/Domain/DurationFormattingTests.swift` — create.
* `HugoTests/Domain/YearMonthTests.swift` — create.
* `HugoTests/Domain/PublisherStatusConfigTests.swift` — create.
* `HugoTests/Features/SymbolDefinitionTests.swift` — create.
* `HugoTests/Persistence/TrackerManagerTests.swift` — create.
* `plans/README.md` — status update only.

**Out of scope**:

* Production source changes, including making private APIs testable.
* SwiftData migration tests; Plan 003 owns those.
* UI snapshot or UI automation tests.
* Testing localized copy word-for-word in both languages.
* Introducing a mocking or assertion library.

## Git workflow

* Branch: `advisor/001-refactor-safety-net`
* Commit style follows this repository's sentence-style history; use `Added characterization tests for core Hugo behavior`.
* Do not push or open a pull request unless instructed.

## Steps

### Step 1: Replace the placeholder with domain characterization tests

Delete `HugoTests/HugoTests.swift`. Every replacement test file must import
`Testing` and `@testable import Hugo`.

Create table-driven `formatDuration` tests for:

* zero seconds → `00:00`
* 59 seconds → `00:00`
* 60 seconds → `00:01`
* 3,661 seconds → `01:01`
* 90,000 seconds → `25:00`

Create `YearMonth` tests for cross-year and same-year ordering. Test
`monthYearString(locale:)` with a fixed `en_US_POSIX` locale and assert the
current behavior for September 2025. Do not test `Locale.current`.

Create publisher-status tests that assert:

* a yearly goal of 600 produces a monthly goal of 50
* a monthly goal of 30 produces a yearly goal of 360
* `current("regular-pioneer")` resolves correctly
* an empty or unknown identifier resolves to `nil`

**Verify**: Run the baseline test command. It must exit 0 and execute at least
12 non-placeholder tests.

### Step 2: Characterize symbol matching

Create `SymbolDefinitionTests.swift` with a locally constructed symbol using
existing localization keys. Cover:

* empty query and no attribute matches
* matching localized name matches case-insensitively
* matching a comma-separated keyword matches
* a required attribute that is absent does not match
* an attribute-only filter matches when the attribute exists

Do not change production visibility. `SymbolDefinition` and `matches` are
internal and accessible through `@testable import Hugo`.

**Verify**: Run the baseline test command. It must exit 0 and all symbol tests
must pass.

### Step 3: Add an in-memory SwiftData test container

Create `InMemoryModelContainer.swift` as a small `@MainActor` test helper. It
must create a `Schema(versionedSchema: CurrentSchema.self)` and a
`ModelConfiguration` with `isStoredInMemoryOnly: true` and CloudKit disabled.
Return a fresh container for each test; never share a static mutable context.

Use the helper in `TrackerManagerTests.swift` to insert three trackers, make one
the current default, call `TrackerManager.setAsDefault` with another tracker,
and assert exactly one default remains and it is the selected tracker.

Add a second test asserting that calling the method for the current default
leaves exactly one default. This captures behavior, not the current swallowed
error implementation.

**Verify**: Run the baseline test command. It must exit 0 and the two SwiftData
tests must pass repeatedly.

### Step 4: Confirm the suite is deterministic

Run the complete test command twice after deleting `/tmp/HugoPlan001DerivedData`
between runs. No test may depend on execution order, the device's current month,
or mutable `UserDefaults.standard` state.

**Verify**: Both runs exit 0 with the same test count and `TEST SUCCEEDED`.

## Test plan

* This plan is itself the test-baseline plan.
* Use Swift Testing (`@Test`, `#expect`), matching the existing test target.
* Keep fixtures local except the reusable in-memory container helper.
* Do not add sleeps, real CloudKit access, or current-date assertions.

## Done criteria

* [ ] The empty `example()` test no longer exists.
* [ ] `rg -n '@Test' HugoTests` finds at least 16 real tests.
* [ ] `rg -n 'Write your test here|example\(\)' HugoTests` returns no matches.
* [ ] The complete test command passes twice.
* [ ] The Debug simulator build passes.
* [ ] Production files under `Hugo/` are unchanged.
* [ ] `plans/README.md` marks Plan 001 DONE.

## STOP conditions

* The baseline test command fails before test changes.
* `@testable import Hugo` cannot access the current internal symbols.
* Creating an in-memory `CurrentSchema` container requires changing production schema declarations.
* SwiftData tests require CloudKit credentials or network access.
* Any assertion would need to guess behavior not visible in current source.

## Maintenance notes

* Plans 003–008 must move or rename these tests alongside the production APIs they characterize.
* Characterization tests intentionally encode current behavior, even when naming is poor. Later plans may update both implementation and tests deliberately.
* A reviewer should reject tests that merely assert construction succeeds or repeat implementation internals without observable outcomes.
