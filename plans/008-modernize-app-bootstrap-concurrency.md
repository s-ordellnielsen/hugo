# Plan 008: Modernize app composition, bootstrap, and Swift concurrency

> **Executor instructions**: Replace manual continuation races before enabling
> Swift 6. Keep CloudKit behavior behind a testable boundary and preserve user
> defaults keys. Update `plans/README.md` only after Debug, Release, and tests
> all pass in Swift 6 mode.
>
> **Drift check (run first)**:
> `git diff --stat c047d57..HEAD -- Hugo/HugoApp.swift Hugo/ContentView.swift Hugo/Utilities/AppInitializer.swift Hugo/Features/Onboarding Hugo/PreviewSupport Hugo.xcodeproj/project.pbxproj AGENTS.md HugoTests`
> Stop if app startup or CloudKit strategy has changed.

## Status

* **Priority**: P1
* **Effort**: L
* **Risk**: HIGH
* **Depends on**: Plans 001 through 007
* **Category**: correctness / migration / tech-debt
* **Planned at**: commit `c047d57`, July 27, 2026

## Why this matters

`HugoApp` constructs persistence in a 54-line closure, preview detection creates
a non-memory store despite its log message, and preview fixtures seed inside an
unawaited Task. `AppInitializer` races multiple tasks against a mutable local
`didResume` captured by a checked continuation and a detached task. The project
documentation says Swift 6 strict concurrency, but effective build settings use
Swift 5. This plan first isolates and tests startup behavior, then turns on the
compiler mode the repository claims to use.

## Current state

* `HugoApp.swift:14-67` constructs ModelContainer inline and duplicates normal/preview configuration.
* Preview branch line 35 uses `isStoredInMemoryOnly: false` while logging in-memory storage.
* `ContentView` is the app root and starts bootstrap in the sheet's `onDismiss` callback, not as an independent app startup task.
* `OnboardingView.onDismiss()` sleeps for one second before dismissing, with no initialization work in that method.
* `AppInitializer.waitForCloudKitEvent` mutates `didResume` from a normal Task and `Task.detached`, then polls in a third Task.
* CloudKit failures are printed and converted to `false`, making “Cloud is empty” indistinguishable from “Cloud is unavailable.”
* Default seeding ignores `DefaultTrackerConfig.iconName`, `hue`, and `id`, using hardcoded values instead.
* `project.pbxproj` reports `SWIFT_VERSION = 5.0`; Xcode invokes `swiftc -swift-version 5` despite `AGENTS.md` claiming Swift 6 strict concurrency.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan008DerivedData CODE_SIGNING_ALLOWED=NO` | Exit 0 and bootstrap tests pass |
| Release build | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project Hugo.xcodeproj -scheme Production -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/HugoPlan008Release CODE_SIGNING_ALLOWED=NO` | Exit 0 and `BUILD SUCCEEDED` |
| Concurrency settings | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Hugo.xcodeproj -scheme Hugo -configuration Debug -showBuildSettings \| rg 'SWIFT_VERSION\|SWIFT_STRICT_CONCURRENCY\|SWIFT_DEFAULT_ACTOR_ISOLATION'` | Swift 6, complete checking, MainActor default |
| Legacy task check | `rg -n 'Task\.detached\|withCheckedContinuation\|nanoseconds:\|didResume\|try\? await Task\.sleep' Hugo --glob '*.swift'` | No obsolete bootstrap race or nanosecond sleep APIs |

## Scope

**In scope**:

* `Hugo/HugoApp.swift` → `Hugo/App/HugoApp.swift`
* `Hugo/ContentView.swift` → `Hugo/App/AppRootView.swift`
* `Hugo/Utilities/AppInitializer.swift` → app/bootstrap types.
* `Hugo/Data/DefaultTrackerConfig.swift` → category seed definition.
* `Hugo/Features/Onboarding/OnboardingView.swift` → `Hugo/Features/Onboarding/OnboardingView.swift` with explicit completion.
* `Hugo/PreviewSupport/PreviewModelContainer.swift`
* `Hugo/Persistence/ModelContainerFactory.swift` — create.
* Xcode Swift language/concurrency settings.
* `AGENTS.md` architecture/concurrency guidance.
* Bootstrap, factory, and onboarding state tests.
* `plans/README.md` status update.

**Out of scope**:

* Changing iCloud container identifiers, entitlements, or production schema.
* Deleting CloudKit synchronization.
* Adding a dependency-injection framework.
* New onboarding screens or visual redesign.
* Retry UX beyond a small explicit bootstrap error state.

## Target layout and names

```text
Hugo/App/
    HugoApp.swift
    AppRootView.swift
    AppBootstrapper.swift
    CloudTrackerLookup.swift
Hugo/Persistence/
    ModelContainerFactory.swift
Hugo/Features/Categories/
    DefaultCategoryDefinition.swift
Hugo/PreviewSupport/
    PreviewModelContainer.swift
    PreviewFixtures.swift
```

## Git workflow

* Branch: `advisor/008-app-bootstrap-concurrency`
* Commit bootstrap isolation before changing Swift language mode.
* Suggested messages: `Modernized app bootstrap flow` and `Enabled Swift 6 strict concurrency`.

## Steps

### Step 1: Extract ModelContainer construction

Create `@MainActor enum ModelContainerFactory` or another stateless namespace
with explicit functions for production and in-memory containers. Centralize:

* `Schema(versionedSchema: CurrentSchema.self)`
* `MigrationPlan.self`
* `ModelConfiguration`
* scoped `Logger` errors

`HugoApp` should hold one `let modelContainer` created by the factory and remain
small. Production construction failure may still be fatal at the app boundary,
but the factory itself should throw so tests and previews can handle errors.

Preview container creation must be synchronously populated on `@MainActor`
before return, not in an unawaited Task. It must always be in-memory and must
not query real CloudKit or mutate production `UserDefaults`.

**Verify**: Factory tests create isolated containers; two preview containers do
not share data. Full tests pass.

### Step 2: Define a testable CloudKit lookup boundary

Create a narrow `Sendable` protocol such as `CloudTrackerLookup` with a throwing
async `hasAnyTracker()` operation. Implement it with CloudKit in one file. Keep
record-name knowledge (`CD_Tracker`) private to that implementation.

Distinguish these outcomes:

* tracker exists in local SwiftData
* tracker exists in CloudKit
* CloudKit query succeeds with no tracker
* CloudKit is temporarily unavailable or unauthorized

Do not equate an error with an empty cloud store. Log errors with `Logger`
without dumping `CKError.userInfo` or user data.

**Verify**: Unit tests use fakes for exists/empty/error outcomes and make no
network requests.

### Step 3: Replace manual continuation racing with structured concurrency

Create `@MainActor @Observable final class AppBootstrapper` only if UI-visible
state (`idle`, `checking`, `ready`, `failed`) is needed; otherwise use a
stateless service. Inject `CloudTrackerLookup`, a clock/timeout abstraction if
needed, and category seed definitions.

Implement timeout/notification waiting with structured task groups or modern
clock APIs. The first completed operation cancels the other. There must be no
shared mutable `didResume`, `Task.detached`, polling loop, or checked
continuation that can resume twice.

Use `Task.sleep(for:)` or a clock, not nanoseconds. Make cancellation propagate.
Seed categories on MainActor through the provided `ModelContext`.

Honor every field in `DefaultCategoryDefinition`, including stable identifier,
localized name, icon, and color fields. Save once and surface errors.

**Verify**: Tests cover local data, cloud data, empty cloud seeding, lookup
error, timeout, cancellation, and idempotent second launch.

### Step 4: Make app-root and onboarding ownership explicit

Rename `ContentView` to `AppRootView`. It owns tab composition and the persisted
“needs onboarding” Boolean. Preserve the existing raw user-default key while
renaming the Swift property for positive semantics.

Run bootstrap from an explicit root `.task`, not only after onboarding sheet
dismissal. Give `OnboardingView` an explicit completion action or binding; on
completion, update the stored flag immediately. Remove the artificial one-second
sleep. Disable completion only while real work is pending.

Decide how a bootstrap failure is shown: a small retry alert/state is enough.
Do not silently dismiss onboarding while required seeding failed.

**Verify**: Tests cover persisted onboarding flag transitions, and manual
simulator checks confirm onboarding does not reappear after completion.

### Step 5: Enable Swift 6 strict concurrency

After all prior steps pass in Swift 5 mode, update all app and test target build
configurations to:

* Swift language version 6
* strict concurrency complete
* default actor isolation MainActor, preserving current project intent

Resolve compiler errors with actor annotations, Sendable value types, and
structured task ownership. Do not use `@unchecked Sendable` unless a type's
thread safety is proven and documented. Do not globally suppress diagnostics.

Update `AGENTS.md` to reflect nuanced SwiftUI guidance:

* pure value logic does not need a ViewModel
* simple views own local state
* `@Observable` is for stateful workflows
* SwiftData `@Model` objects use `@Bindable` when bindings are needed
* unstructured `Task` from a user action is valid when the view owns its lifetime; detached work requires justification

**Verify**: Build settings show Swift 6 and complete checking. Debug tests and
Production Release build both pass with no concurrency warnings.

### Step 6: Replace remaining operational `print` calls

Use scoped `Logger` values for persistence/bootstrap diagnostics. Preview-only
logs may be removed. Migration logging from Plan 003 remains in its own
category. No logger should emit tracker names, error userInfo dictionaries, or
other user content by default.

**Verify**: `rg -n '\bprint\(' Hugo --glob '*.swift'` returns no production
matches. Full tests pass.

## Test plan

* Use fake Cloud lookup implementations and an injectable clock/timeout.
* Assert exact seed counts and idempotency in fresh in-memory containers.
* Test cancellation without real sleeps.
* Test preview fixtures synchronously contain expected data at return.
* Run both Debug tests and Production Release build after Swift 6 activation.

## Done criteria

* [ ] `HugoApp` and `AppRootView` are small app-composition types under `App`.
* [ ] Model container construction is throwing, centralized, and testable.
* [ ] Preview data is in-memory, synchronous, and isolated.
* [ ] CloudKit lookup errors are distinct from empty results.
* [ ] Bootstrap uses structured concurrency without continuation races or detached polling.
* [ ] Onboarding has no artificial delay and has explicit ownership.
* [ ] Effective build settings use Swift 6 complete concurrency checking.
* [ ] Operational prints are replaced or removed.
* [ ] Debug tests and Production Release build pass.
* [ ] Plan 008 is marked DONE.

## STOP conditions

* CloudKit/SwiftData startup semantics cannot be tested without a real account.
* Enabling Swift 6 reveals a required framework API that is not Sendable and would need unchecked conformance.
* Moving bootstrap earlier causes duplicate seeding against real sync behavior.
* A change requires new iCloud entitlements, containers, or CloudKit schema deployment.

## Maintenance notes

* Keep CloudKit details behind the narrow lookup implementation; app bootstrap should reason in domain outcomes.
* The default MainActor setting is intentional for this UI-centric app, but pure Sendable value logic may be nonisolated where useful.
* Reviewers should test first launch offline, first launch with existing cloud data, and subsequent launch.
