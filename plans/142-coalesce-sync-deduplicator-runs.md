# Plan 142: Coalesce SyncDeduplicator runs into one trailing run

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 5845483..HEAD -- Hugo/App/AppRootView.swift Hugo/Persistence/SyncDeduplicator.swift`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). Never touch, stage or commit it.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MEDIUM. The merge rules are untouched, but the timing of when duplicates merge changes by about a second.
- **Depends on**: none
- **Category**: perf
- **Planned at**: commit `5845483`, 2026-11-23
- **Issue**: [SLN-322](https://linear.app/sebastianln/issue/SLN-322)

## Why this matters

`SyncDeduplicator.run()` executes five merge passes on the main actor. It runs
at launch, every time the app becomes active, and after every CloudKit import
event. Each pass fetches whole tables (all categories, all submitted reports
several times, and the entries that carry a source report). During the first
sync after an install, CloudKit can post a burst of import events, so the app
repeats this work many times in a few seconds while SwiftUI is also redrawing
from the imported rows. The merges are idempotent, so one run after the burst
gives the same result as many. After this plan, requests within half a second
of each other collapse into one run.

This is unmeasured. The expected gain is fewer main-thread stalls during sync
and at launch, not a number.

## Current state

`Hugo/App/AppRootView.swift` calls `SyncDeduplicator(context: context).run()` in three places:

```swift
.task {
    settingsSync?.start()
    syncMonitor.startWatchingNetwork()
    await bootstrapper.start(context: context)
    SyncDeduplicator(context: context).run()
}
.onChange(of: scenePhase) { _, phase in
    if phase == .active { SyncDeduplicator(context: context).run() }
}
...
    guard event.type == .import, event.endDate != nil else { return }
    SyncDeduplicator(context: context).run()
}
```

`AppRootView` has `@Environment(\.modelContext) private var context` and keeps
long-lived objects as `@State` (for example `@State private var syncMonitor = CloudSyncMonitor()`).

`Hugo/Persistence/SyncDeduplicator.swift`: `@MainActor struct SyncDeduplicator`
with `init(context:)` and `func run()`. `run()` is safe to call often and logs
its own errors. Its rules must pick the same survivor on every device from
synced attributes only. Do not change them.

Rules from `AGENTS.md` that apply: Swift 6 strict concurrency, MainActor default
isolation; avoid unstructured `Task` where structured concurrency fits (a
debounce needs one cancellable task, which is the accepted exception here); no
`DispatchQueue`; tests use Swift Testing and `InMemoryModelContainer.make()`;
time-dependent types take their delay as an initializer parameter with a
production default; code in `Hugo/Persistence` is flat (see `SyncDeduplicator.swift`).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |

## Scope

**In scope**:

- `Hugo/Persistence/SyncDeduplicationScheduler.swift` (create)
- `Hugo/App/AppRootView.swift`
- `HugoTests/Persistence/SyncDeduplicationSchedulerTests.swift` (create)

**Out of scope**:

- `SyncDeduplicator.swift` and every merge rule in it.
- Reducing the number of fetches inside the merges. That is a separate change with its own risk to the tie-break logic.
- `CloudSyncMonitor`, `SettingsSyncService`, the bootstrapper.

## Git workflow

- Work on `main`. Commit per step. Conventional Commits, for example `perf: coalesce sync deduplication runs`.
- Do not push. Never stage `Hugo/Resources/Localizable.xcstrings`.

## Steps

### Step 1: Create the scheduler

Create `Hugo/Persistence/SyncDeduplicationScheduler.swift`:

```swift
import SwiftData

/// Runs `SyncDeduplicator` once after a quiet period. Every `request` cancels
/// the run that is still waiting and starts a new wait, so a burst of CloudKit
/// import events costs one run. The merges are idempotent, so skipping the
/// intermediate runs loses nothing.
@MainActor
final class SyncDeduplicationScheduler {
    private let delay: Duration
    private let perform: (ModelContext) -> Void
    private var pending: Task<Void, Never>?

    init(
        delay: Duration = .milliseconds(500),
        perform: @escaping (ModelContext) -> Void = { SyncDeduplicator(context: $0).run() }
    ) {
        self.delay = delay
        self.perform = perform
    }

    func request(context: ModelContext) {
        pending?.cancel()
        pending = Task { [delay, perform] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            perform(context)
        }
    }
}
```

If strict concurrency rejects capturing `context` or `perform` in the task, fix
it with the smallest change (for example `@MainActor` on the closure type).
Do not use `@unchecked Sendable`.

**Verify**: `swift-format lint --strict Hugo/Persistence/SyncDeduplicationScheduler.swift` exits 0.

### Step 2: Test the scheduler

Create `HugoTests/Persistence/SyncDeduplicationSchedulerTests.swift`, `@MainActor struct`,
Swift Testing, modeled on `SyncDeduplicatorTests.swift` (use `InMemoryModelContainer.make()` for a
`ModelContext`). Use a delay of `.milliseconds(50)` and a counter captured by the `perform`
closure. Tests:

1. `burstOfRequestsRunsOnce`: call `request` five times in a row, wait `.milliseconds(300)` with `Task.sleep`, expect the counter is 1.
2. `requestsFarApartRunTwice`: request, wait 300 ms, request, wait 300 ms, expect 2.
3. `noRequestNeverRuns`: wait 150 ms, expect 0.

Keep sleeps at least 5x the delay so the tests are not flaky.

**Verify**: `Scripts/verify.sh` exits 0, with 3 more tests than before.

### Step 3: Use the scheduler in `AppRootView`

Add `@State private var deduplication = SyncDeduplicationScheduler()` beside the other `@State` properties.
Replace the three `SyncDeduplicator(context: context).run()` calls with `deduplication.request(context: context)`.
Keep the rest of each closure exactly as it is, including the `guard` in the import handler.

**Verify**: `grep -n "SyncDeduplicator(context" Hugo/App/AppRootView.swift` returns no matches, and `Scripts/verify.sh` exits 0.

## Test plan

- The three scheduler tests. `SyncDeduplicatorTests` must keep passing unchanged, which proves the merge rules did not move.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, with 3 more tests than before
- [ ] `grep -rn "SyncDeduplicator(context" Hugo/App` returns no matches
- [ ] `git status --short` shows only the in-scope files (plus the owner's `Localizable.xcstrings`, unstaged)
- [ ] `plans/README.md` row updated

Owner check on a device: install over an existing store, open the app, and
confirm categories and reports look the same. With two devices on the same
iCloud account, confirm a duplicate default category still merges within a few
seconds of the second device syncing.

## STOP conditions

Stop and report if:

- `AppRootView` no longer calls `SyncDeduplicator` in the three places above.
- Strict concurrency cannot be satisfied without `@unchecked Sendable` or `nonisolated(unsafe)`.
- A `SyncDeduplicatorTests` test fails.
- You need to edit `SyncDeduplicator.swift`.

## Maintenance notes

- Any new caller of the deduplicator should call the scheduler, not `SyncDeduplicator(context:).run()`, unless it needs the result immediately (tests do).
- The half-second delay is a guess. If a device shows duplicates for visibly longer after a sync, lower it, but do not remove the coalescing.
- A follow-up could fetch `SubmittedReport` once per run instead of three times. It touches the tie-break code, so it needs its own plan and careful review.
