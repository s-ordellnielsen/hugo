# Plan 175: Add the first widget, a small home screen widget for this month's progress

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 8f9c2e7..HEAD -- Hugo/Persistence Hugo/App Hugo/Domain Hugo/Features/Overview Hugo/Features/Settings Configuration Hugo/Info.plist HugoTests/Persistence HugoTests/TestSupport`
> Expected: no output. Any output: compare the "Current state" excerpts with
> the live code and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). This plan does not touch that file. Never stage it.

## Status

- **Priority**: P2
- **Effort**: L + owner
- **Risk**: MED. The widget opens the user's store from a second process. Every choice below keeps it read-only and makes it show a placeholder instead of guessing.
- **Depends on**: plan 174 (SLN-350, done, owner checks pending). Its store must be in the App Group on the owner's devices before the widget shows data.
- **Category**: direction
- **Planned at**: commit `8f9c2e7`, 2026-11-27
- **Issue**: [SLN-351](https://linear.app/sebastianln/issue/SLN-351)

**Tier**: Large, because it adds an extension target, an entitlement, a new set of shared settings keys and a second reader of the CloudKit-mirrored store (AGENTS.md section 9).

## Why this matters

Hugo's main number is "how far am I this month". Today the user has to open
the app to see it. A small widget shows it on the home screen. Plan 174 put the
store in an App Group so a widget can read it. This plan is only the first
widget: `systemSmall`, this month's time against the Monthly goal, with the
same numbers as the Overview circle. No Due month reminder, no medium or lock
screen families, no configuration intent.

## Decisions already made (do not reopen)

- Store: the widget opens the App Group store at the URL `StoreRelocator` chose, read-only (`allowsSave: false`), CloudKit off (`cloudKitDatabase: .none`). It never relocates, copies, migrates or deletes anything. When the app has not moved the store yet, the widget shows a placeholder.
- The app syncs; the widget only reads.
- Constraints: Swift 6 strict concurrency, SwiftUI only, iOS 26+, 4-space indentation, vanilla+ native style, VoiceOver label with the full sentence, Dynamic Type.

## Answers to the open design questions (decided in this plan)

1. **Sharing code: dual target membership, no local package.** The widget needs the SwiftData model classes, and those live in `Hugo/Persistence/SchemaVersions/V14/` and are named through the typealiases in `Hugo/Persistence/AppSchema.swift`, which also declares every older schema and so pulls in all older version folders. A package would mean moving the schema files, which the repo forbids editing by habit and which would break `CODEMAP.md`, the tests' `@testable import Hugo` and the folder rules in AGENTS.md section 7. With dual membership no file moves. The rule that keeps it clean: **testable logic lives in `Hugo/Features/Widget/` (roles `Domain` and `Services`) and is a member of both the app and the widget; `HugoWidget/` at the repo root holds only WidgetKit glue and views, and is a member of the widget only.** `HugoWidget/` is a sibling of `Hugo/` and `HugoTests/`, so it adds no top-level folder inside `Hugo/` (AGENTS.md section 7 gets one sentence for it). `TheocraticYear` is not needed: the widget shows a calendar month, so it uses `YearMonth` only.
2. **Settings: the app mirrors them into the App Group `UserDefaults` suite, as a new key set.** `UserDefaults.standard` and iCloud key-value storage are not readable by the widget. The widget needs only three values, all read by `OverviewDayView` today: the publisher status id (`publisherStatus`), the Buffer hours (`plannerExtraHours`) and whether Overview counts the Buffer (`bufferInOverview`). The Planner target (`plannerTargetBase`) is not used by `OverviewMetrics`, so it is NOT mirrored. The app writes one JSON value, `WidgetSettings`, under one new key, `widgetSettings`, in the suite named by `HugoAppGroupIdentifier`. It holds the publisher status id, the effective Buffer hours (already 0 when the Overview switch is off, so the widget repeats no rule), and the schema version of the app build that wrote it. `widgetSettings` goes into `UserDefaultsKeys` with a comment, is device-only and is NOT added to `SyncedSettings.keys` (it is derived from synced settings on every device). `SyncedSettings` gets a doc sentence that says so.
3. **Timeline and reloads.** One timeline entry per load, policy `.after(<start of tomorrow + 1 minute>)`, so the widget reloads once a day around midnight, which also handles the month rollover. The app calls `WidgetCenter.shared.reloadAllTimelines()` through one coalescing scheduler, `WidgetRefreshScheduler`, modeled on `SyncDeduplicationScheduler`. Call sites, all in `AppRootView`: after the first launch work in `.task`; on every `scenePhase` change to `.active` or `.background`; on `ModelContext.didSave` (Entry, Plan and School credit changes, carried-in entries included); on the existing `UserDefaults.didChangeNotification` receiver (settings changes, and settings pulled from iCloud, because the pull writes `UserDefaults.standard`); and on the existing CloudKit `.import` event (changes made on another device). Each request rewrites the mirror only when it differs from what is stored, so the suite write cannot start a notification loop.
4. **Schema change: none.** No `VersionedSchema`, no CloudKit schema change, no model edit. The widget uses `CurrentSchema` and never a migration plan. It compares the app-written `storeSchemaVersion` with its own `CurrentSchema` version and shows the placeholder on a mismatch, so a widget updated before the app has run (and migrated) never opens a store of an older version and never triggers a migration.

Two smaller decisions the plan makes:

- **Fresh installs get a marker.** Plan 174 writes no marker on a fresh install (rule 5), so the widget could not tell "real store" from "nothing there". `StoreRelocator` gets `markFreshInstallIfNeeded()`, which writes `confirmed` only when no marker exists, and the factory calls it after the container opened and answered its probe. The widget treats the store as readable only when the marker is `copied` or `confirmed` and the store file exists. Devices already on plan 174's build with no marker get one on their next launch, because rule 5 runs again.
- **Widget strings live in `HugoWidget/Localizable.xcstrings`, not in `Hugo/Resources/Localizable.xcstrings`.** The widget bundle cannot read the app's catalog. Sharing that catalog would ship every app string in the extension and mix their stale-string tracking, and the owner has uncommitted edits in it. The widget has about eight keys, English and Danish.

## Current state

- `Hugo/Features/Overview/Domain/OverviewMetrics.swift`: the numbers of the card. `make(entries:status:bufferHours:now:calendar:)` returns `totalHours` (the sum of every entry's duration in the list, carried-in entries included, divided by 3600), `monthlyGoal` (`status?.monthlyGoal + max(0, bufferHours)`), `hasOwnEntries`, and `progress = max(totalHours, 0)`. Note: this is the month's logged total, not "Counted time" in the sense of `CONTEXT.md`. The widget matches the card, so it uses `OverviewMetrics.progress` and calls it "this month's time" in code and text.
- `Hugo/Features/Overview/Domain/MonthlyCircleFill.swift`: `MonthlyCircleFill.make(monthlyGoalHours:loggedSeconds:plannedSeconds:hasOwnEntries:)` gives the circle's `fraction` and `basis` (`.monthlyGoal`, `.plan` when there is no goal but there are plans, `.presence`).
- `Hugo/Features/Overview/Screens/OverviewView.swift` (`OverviewDayView`): the exact inputs to copy. Entries and plans of the month use `today.yearMonth(using: .current).dateRange(calendar: .current)` with `$0.date >= start && $0.date < end`. Settings come from `@AppStorage` `publisherStatus`, `plannerExtraHours`, `bufferInOverview`. `bufferHours: includeBuffer ? extraHours : 0`. `plannedSeconds` there is `PlannerMonth.planned.total`, which is the sum of the month's plan durations.
- `Hugo/Features/Overview/Views/MonthlyProgressCard.swift`: hero number uses `HeadlineDuration(seconds: (value * 3_600).rounded())` (`Hugo/Domain/HeadlineDuration.swift`): whole hours, or minutes under an hour. VoiceOver text per basis lives in `accessibilityValueText`.
- `Hugo/Domain/UserDefaultsKeys.swift` (`nonisolated enum`): every key lives here with a comment saying whether it syncs. `Hugo/Features/Settings/Domain/SyncedSettings.swift`: the list of synced keys. `Hugo/Features/Settings/Services/SettingsSyncService.swift`: copies synced keys between `UserDefaults` and iCloud.
- `Hugo/Persistence/StoreRelocator.swift`: `storeFileName = "default.store"`, private `markerFileName = "store-move-state"`, `copiedState`, `confirmedState`, `productionGroupDirectory(bundle:fileManager:)` (reads `HugoAppGroupIdentifier` from the bundle's Info.plist, creates `<group>/Library/Application Support`). `StoreFiles` is declared in `Hugo/Persistence/StoreCopier.swift`.
- `Hugo/Persistence/ModelContainerFactory.swift`: `makeProductionContainer(relocator:cloudKitDatabase:)` with `openAndProbe`. After a successful open it calls `markCopied()` (fresh copy) or `confirmAndDeleteLegacyStore()` (cleanup pending) and does nothing else for a fresh install.
- `Hugo/Persistence/SyncDeduplicationScheduler.swift`: the pattern for a coalescing `@MainActor` scheduler with an injected `perform` closure. Copy its shape.
- `Hugo/App/AppRootView.swift`: `.task` runs `settingsSync?.start()`, `bootstrapper.start`, `deduplication.request`. It already has `onChange(of: scenePhase)`, an `NSPersistentCloudKitContainer.eventChangedNotification` receiver (import events) and a `UserDefaults.didChangeNotification` receiver.
- `Configuration/Debug.xcconfig`, `TestFlight.xcconfig`, `Production.xcconfig` each set `APP_GROUP_IDENTIFIER = group.$(PRODUCT_BUNDLE_IDENTIFIER)`. `Configuration/Hugo.entitlements` lists `$(APP_GROUP_IDENTIFIER)`. `Hugo/Info.plist` has `HugoAppGroupIdentifier = $(APP_GROUP_IDENTIFIER)`. The widget has its own bundle ID, so `group.$(PRODUCT_BUNDLE_IDENTIFIER)` would resolve differently for it (plan 174, maintenance notes).
- `Hugo.xcodeproj` uses synchronized folder groups (objectVersion 77): target `Hugo` syncs the folder `Hugo`, `HugoTests` syncs `HugoTests`. Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` on the app target.
- Tests: `HugoTests/TestSupport/InMemoryModelContainer.swift`, `TemporaryStore.swift`; store-at-a-URL pattern in `HugoTests/Persistence/StoreRelocatorTests.swift` and `ModelContainerFactoryTests.swift` (plan 174); coalescing-scheduler test pattern in the `SyncDeduplicationScheduler` tests under `HugoTests/Persistence/`.
- Vocabulary from `CONTEXT.md`: Monthly goal, Publisher status, Buffer, Synced setting, Month, Entry. No new domain term appears. Use "Monthly goal" in names and text.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| One suite | `Scripts/test-quick.sh HugoTests/MonthProgressTests` | suite passes |
| Targets in the project | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Hugo.xcodeproj -list` | lists targets (`HugoWidget` only after the owner step) |
| Resolved settings | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Hugo.xcodeproj -scheme Debug -configuration Debug -showBuildSettings \| grep -E "^\s*(APP_GROUP_IDENTIFIER\|PRODUCT_BUNDLE_IDENTIFIER) ="` | one line per setting |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:
- `Hugo/Features/Widget/Domain/WidgetSettings.swift`, `MonthProgress.swift` (create)
- `Hugo/Features/Widget/Services/WidgetSettingsMirror.swift`, `WidgetStoreReader.swift`, `WidgetRefreshScheduler.swift` (create)
- `Hugo/Domain/UserDefaultsKeys.swift`, `Hugo/Features/Settings/Domain/SyncedSettings.swift` (comments and one key)
- `Hugo/Persistence/StoreRelocator.swift` (`markFreshInstallIfNeeded()` and the marker constants made internal), `Hugo/Persistence/ModelContainerFactory.swift` (one call)
- `Hugo/App/AppRootView.swift` (the reload call sites only)
- `Configuration/Debug.xcconfig`, `TestFlight.xcconfig`, `Production.xcconfig` (the `APP_GROUP_IDENTIFIER` line), `Configuration/HugoWidget.entitlements` (create)
- `HugoWidget/` (create): `HugoWidgetBundle.swift`, `MonthProgressWidget.swift`, `MonthProgressProvider.swift`, `MonthProgressWidgetView.swift`, `Info.plist`, `Localizable.xcstrings`
- `HugoTests/Features/Widget/MonthProgressTests.swift`, `WidgetSettingsMirrorTests.swift`, `WidgetStoreReaderTests.swift`, `WidgetRefreshSchedulerTests.swift` (create); `HugoTests/Persistence/StoreRelocatorTests.swift` and `ModelContainerFactoryTests.swift` (add cases)
- `CODEMAP.md`, `README.md`, `AGENTS.md` (one sentence in section 7), `plans/README.md`

**Out of scope** (do NOT touch):
- Any `VersionedSchema`, model, `HugoMigrationPlan`, `SyncDeduplicator`, `AppBootstrapper`, `CloudTrackerLookup`, `ModelContainerLoader`.
- `Hugo/Resources/Localizable.xcstrings` (owner's uncommitted edit; the widget has its own catalog).
- `Hugo.xcodeproj/project.pbxproj`. The owner creates the target and the memberships (see "Owner steps").
- `OverviewMetrics`, `MonthlyCircleFill` and `OverviewView` behavior. The widget calls them; it must not change them.
- Other widget families, the Due month reminder, a configuration intent, Live Activities, the Planner target.
- `CONTEXT.md` (no new domain term).

## Git workflow

- Work on `main`. Commit per step with Conventional Commits, for example `feat(widget): mirror the widget settings into the App Group`. Do not push.
- Never stage `Hugo/Resources/Localizable.xcstrings`.

## Steps

### Step 1: App Group build settings, widget entitlements, fresh-install marker

- In the three xcconfig files change `APP_GROUP_IDENTIFIER = group.$(PRODUCT_BUNDLE_IDENTIFIER)` to `APP_GROUP_IDENTIFIER = group.$(BUNDLE_IDENTIFIER)`. The widget's own `PRODUCT_BUNDLE_IDENTIFIER` ends in `.widget`, `BUNDLE_IDENTIFIER` (already defined in each xcconfig) does not.
- Create `Configuration/HugoWidget.entitlements` holding only `com.apple.security.application-groups` with `$(APP_GROUP_IDENTIFIER)`, same format as `Configuration/Hugo.entitlements`. No iCloud, push or key-value keys.
- In `StoreRelocator.swift`: make `markerFileName`, `copiedState`, `confirmedState` non-private (`static let`, internal). Add
  `func markFreshInstallIfNeeded()`: when `readMarker() == nil`, `writeMarker(Self.confirmedState)`; otherwise do nothing.
- In `ModelContainerFactory.makeProductionContainer`, inside the `do` after a successful `openAndProbe`, add an `else` branch to the `isFreshCopy` / `legacyCleanupPending` chain that calls `relocator.markFreshInstallIfNeeded()`. The legacy location returns earlier and is untouched.

**Verify**: run the "Resolved settings" command for the Debug scheme. Expected: `APP_GROUP_IDENTIFIER` is `group.` plus the printed `PRODUCT_BUNDLE_IDENTIFIER`, the same value as before the edit (plan 174's report gave `group.com.ordellnielsen.Hugo.dev` for Debug). If it differs or is empty, STOP. Then `Scripts/test-quick.sh HugoTests/StoreRelocatorTests HugoTests/ModelContainerFactoryTests` passes (existing cases that expect "no marker after a fresh install" must be updated in step 6, so run this check again there).

### Step 2: The shared keys and `WidgetSettings`

- `UserDefaultsKeys`: add `static let widgetSettings = "widgetSettings"` with a comment: "The widget's copy of the settings it needs, as JSON in the App Group suite. Written by the app, read by the widget. Device-only: never synced, derived from the synced settings. See `WidgetSettings`."
- `SyncedSettings.swift`: add one sentence to the doc comment: `widgetSettings` is a device-only copy in the App Group and is not a synced setting.
- Create `Hugo/Features/Widget/Domain/WidgetSettings.swift`:

```swift
nonisolated struct WidgetSettings: Codable, Equatable, Sendable {
    /// `UserDefaultsKeys.publisherStatus`, so `PublisherStatus.status(for:)` finds the Monthly goal.
    var publisherStatusID: String
    /// The Buffer hours the Overview adds to the goal: 0 when its switch is off.
    var bufferHours: Int
    /// "major.minor.patch" of the schema of the app build that wrote this.
    var storeSchemaVersion: String

    static func current(defaults: UserDefaults) -> WidgetSettings   // reads the three standard keys; bufferHours = bufferInOverview ? plannerExtraHours : 0
    static func schemaVersionString() -> String                     // from CurrentSchema.versionIdentifier
}
```

Keep the type `nonisolated` like `UserDefaultsKeys`, so the widget can use it off the main actor.

**Verify**: `Scripts/test-quick.sh HugoTests/StoreRelocatorTests` passes (proves the module compiles).

### Step 3: `MonthProgress` (the numbers) and `WidgetStoreReader` (read-only open)

Create `Hugo/Features/Widget/Domain/MonthProgress.swift`:

```swift
nonisolated struct MonthProgress: Equatable, Sendable {
    let month: YearMonth
    let loggedSeconds: TimeInterval       // OverviewMetrics.progress * 3600
    let goalHours: Double                 // OverviewMetrics.monthlyGoal
    let fill: MonthlyCircleFill

    static func make(entries: [Entry], plannedSeconds: TimeInterval, settings: WidgetSettings, now: Date, calendar: Calendar) -> MonthProgress
}
```

`make` calls `OverviewMetrics.make(entries:status: PublisherStatus.status(for: settings.publisherStatusID), bufferHours: settings.bufferHours, now:calendar:)` and `MonthlyCircleFill.make(monthlyGoalHours:loggedSeconds:plannedSeconds:hasOwnEntries:)` with exactly the arguments `OverviewDayView.body` passes. Add `var headline: HeadlineDuration` (`HeadlineDuration(seconds: loggedSeconds.rounded())`). Do not copy any formula; call the two existing types.

Create `Hugo/Features/Widget/Services/WidgetStoreReader.swift` with:

```swift
enum WidgetState: Equatable, Sendable {
    case ready(MonthProgress)
    case unavailable          // the placeholder: the app has not moved the store, or has not run this build
}

struct WidgetStoreReader {
    init(groupDirectory: URL?, settingsSuite: UserDefaults?, fileManager: FileManager = .default)
    func load(now: Date, calendar: Calendar) -> WidgetState
    static func production() -> WidgetStoreReader   // StoreRelocator.productionGroupDirectory() and UserDefaults(suiteName: <HugoAppGroupIdentifier>)
}
```

`load` returns `.unavailable` unless ALL hold, checked in this order and without opening anything before the last two: the group directory is not nil; the marker file (`StoreRelocator.markerFileName`) reads `copied` or `confirmed`; `<group>/default.store` exists; the suite holds a decodable `widgetSettings`; its `storeSchemaVersion` equals `WidgetSettings.schemaVersionString()`. Then it opens the store:

```swift
let schema = Schema(versionedSchema: CurrentSchema.self)
let configuration = ModelConfiguration(schema: schema, url: storeURL, allowsSave: false, cloudKitDatabase: .none)
let container = try ModelContainer(for: schema, configurations: [configuration])   // no migration plan, on purpose
```

It fetches the month's entries and plans with the same predicate as `OverviewDayView` (`today.yearMonth(using: calendar).dateRange(calendar: calendar)`, `date >= start && date < end`), sums the plan durations for `plannedSeconds`, and returns `.ready(MonthProgress.make(...))`. Any thrown error returns `.unavailable` (log with `Logger(subsystem: "com.ordellnielsen.Hugo", category: "Widget")`). The reader never writes, never creates directories (use a non-creating lookup: if you reuse `productionGroupDirectory`, that is acceptable because it only creates the empty group folder), never calls `StoreRelocator.resolve()` and never passes a migration plan.

**Verify**: `Scripts/test-quick.sh HugoTests/StoreRelocatorTests` passes.

### Step 4: `WidgetSettingsMirror` and `WidgetRefreshScheduler`

Create `Hugo/Features/Widget/Services/WidgetSettingsMirror.swift`:

```swift
struct WidgetSettingsMirror {
    init(source: UserDefaults = .standard, suite: UserDefaults?)
    @discardableResult func write() -> Bool          // true when the suite value changed
    static func read(from suite: UserDefaults?) -> WidgetSettings?
}
```

`write()` builds `WidgetSettings.current(defaults: source)`, encodes it with `JSONEncoder` (sorted keys, so equal values give equal bytes), compares with the stored `Data` and writes only when different. A nil suite writes nothing and returns false.

Create `Hugo/Features/Widget/Services/WidgetRefreshScheduler.swift`, shaped like `SyncDeduplicationScheduler`: `@MainActor final class`, `init(delay: Duration = .seconds(1), mirror: WidgetSettingsMirror, reload: @escaping () -> Void)`, `func request()` cancels the pending task and starts a new wait; when it fires it calls `mirror.write()` then `reload()`. The production `reload` closure is `{ WidgetCenter.shared.reloadAllTimelines() }` (`import WidgetKit`), passed from `AppRootView`; tests pass a counter.

**Verify**: `Scripts/test-quick.sh HugoTests/StoreRelocatorTests` passes.

### Step 5: Reload call sites in `AppRootView`

In `AppRootView.swift` add `@State private var widgetRefresh = WidgetRefreshScheduler(mirror: WidgetSettingsMirror(suite: <suite from HugoAppGroupIdentifier>), reload: { WidgetCenter.shared.reloadAllTimelines() })`. In the unit-test host the app builds `AppRootView` without a settings sync service; follow that for the scheduler too: create it only when `settingsSync != nil`, so tests never write the real App Group suite or call WidgetKit (`widgetRefresh: WidgetRefreshScheduler?`, `nil` otherwise). Call `widgetRefresh?.request()`:

1. in `.task`, after `await bootstrapper.start(context: context)`;
2. in the existing `onChange(of: scenePhase)`, for every phase change (`.active`, `.inactive`, `.background`);
3. in the existing CloudKit receiver, next to `deduplication.request(context: context)` (import events only, same guard);
4. in the existing `UserDefaults.didChangeNotification` receiver, next to `settingsSync?.pushToCloud()`;
5. in a new `.onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave).receive(on: RunLoop.main))` that calls `widgetRefresh?.request()`.

Do not change any other line of the file.

**Verify**: `Scripts/test-quick.sh HugoTests/AppRootViewTests` (or the existing suite name under `HugoTests/App/` that builds `AppRootView`; run `ls HugoTests/App`) passes.

### Step 6: Tests

Swift Testing, `@MainActor`, `TemporaryStore` for directories, `defer { remove() }`, a fresh `UserDefaults(suiteName: UUID().uuidString)` per test (remove the persistent domain at the end). Build real stores by opening SwiftData at a URL with `cloudKitDatabase: .none`, inserting rows and letting the container go out of scope (pattern: `StoreRelocatorTests` from plan 174). Fixed calendar (Gregorian, UTC) and fixed `now`.

`MonthProgressTests` (`HugoTests/Features/Widget/`):
1. Parity: for a month with entries (one carried-in, one in a Credit category, one on the last day of the previous month and one on the first of the next, which must be excluded by the reader but are passed only to `OverviewMetrics` in this test as the month's list), `MonthProgress.make` has `loggedSeconds == OverviewMetrics.make(...).progress * 3600`, `goalHours == metrics.monthlyGoal` and `fill == MonthlyCircleFill.make(...)` for regular pioneer (goal 50), auxiliary pioneer (30) and publisher (0).
2. Buffer: `bufferHours` 5 gives goal 55 for the regular pioneer; 0 gives 50.
3. No goal and a plan: `fill.basis == .plan` and the fraction is logged over planned. No goal and no plan: `.presence`, with and without an own entry (carried-in only stays 0).
4. `headline` shows minutes under an hour and whole hours above (45 min, 59 min, 60 min, 12 h).

`WidgetSettingsMirrorTests`:
5. Round trip: set the three standard keys in a fake `source` suite, `write()` returns true, `read(from:)` equals `WidgetSettings(publisherStatusID:bufferHours:storeSchemaVersion:)`.
6. Second `write()` with unchanged values returns false. Changing `plannerExtraHours` returns true and the read value follows.
7. `bufferInOverview` false stores `bufferHours` 0 even when `plannerExtraHours` is 5; true stores 5.
8. Nil suite: `write()` is false and `read(from: nil)` is nil.

`WidgetStoreReaderTests`:
9. Ready: a real store in a temp "group" directory with marker `confirmed`, mirror written by `WidgetSettingsMirror`, entries in the fixed month. `load` returns `.ready` with the expected `loggedSeconds`.
10. Read-only: the store file's bytes (and the `-wal` and `-shm` files if present) are identical before and after `load`, and a `ModelContext` saved through a container built with `allowsSave: false` over the same URL throws or saves nothing (assert on what SwiftData does; if the save does not throw, assert the row count is unchanged after reopening).
11. Placeholder cases, each returns `.unavailable`: group directory nil; no marker; marker `copied` but no store file; store file but no marker; no `widgetSettings` in the suite; `storeSchemaVersion` of "0.0.1"; a garbage file at the store URL with marker `confirmed`.
12. `load` creates no files: the directory listing before and after is the same in the unavailable cases.

`WidgetRefreshSchedulerTests`: 13. Three `request()` calls inside the delay give one `reload` call and one mirror write (use a tiny delay and a 5x margin, as the `SyncDeduplicationScheduler` tests do). 14. A `request()` after the delay gives a second call.

Add to `StoreRelocatorTests`: 15. `markFreshInstallIfNeeded()` writes `confirmed` when there is no marker. 16. It leaves `copied` as `copied` and `confirmed` as `confirmed`. Add to `ModelContainerFactoryTests`: 17. A fresh install (no legacy store, group available) leaves the marker at `confirmed` after the factory returns. Update any existing case that asserts "no marker" after a fresh install.

The VoiceOver sentence and the strings live in the widget bundle, which the test host cannot load, so they are an owner check, not a test.

**Verify**: `Scripts/test-quick.sh HugoTests/MonthProgressTests HugoTests/WidgetSettingsMirrorTests HugoTests/WidgetStoreReaderTests HugoTests/WidgetRefreshSchedulerTests HugoTests/StoreRelocatorTests HugoTests/ModelContainerFactoryTests` passes with 17 new tests.

### Step 7: The widget sources in `HugoWidget/`

These files are compiled only after the owner adds the target (see "Owner steps"). Keep them thin: all logic is already in `Hugo/Features/Widget/`.

- `HugoWidgetBundle.swift`: `@main struct HugoWidgetBundle: WidgetBundle { var body: some Widget { MonthProgressWidget() } }`.
- `MonthProgressProvider.swift`: `TimelineProvider` with `Entry` = `MonthProgressEntry { date: Date; state: WidgetState }`. `placeholder` and `getSnapshot` (when `context.isPreview`) return sample data (use 32 of 50 hours). Otherwise `getSnapshot` and `getTimeline` call `WidgetStoreReader.production().load(now: .now, calendar: .current)`. `getTimeline` returns one entry and `Timeline(entries: [entry], policy: .after(<start of tomorrow plus 1 minute, from Calendar.current>))`. If the compiler reports isolation errors on the provider methods, mark them `nonisolated` as the SDK signature requires and keep the reader call synchronous.
- `MonthProgressWidget.swift`: `StaticConfiguration(kind: "MonthProgress", provider:)`, `.configurationDisplayName("widget.month.name")`, `.description(Text("widget.month.description"))`, `.supportedFamilies([.systemSmall])`, `.containerBackground(.fill.tertiary, for: .widget)` (system background, no custom color).
- `MonthProgressWidgetView.swift`: for `.ready`: the month name (`Text(date, format: .dateTime.month(.wide))`, `.caption`, semibold, secondary), the hero number from `progress.headline` in `.system(.largeTitle, design: .serif, weight: .bold)` with `minimumScaleFactor(0.5)` and `lineLimit(1)`, the unit ("min" only for minutes) as secondary text, then with a goal a line "of N hours" and a `Gauge(value: fill.fraction)` with `.gaugeStyle(.accessoryLinearCapacity)` tinted `.mint`; without a goal and with plans "of N hours planned"; without both, only the hero number. For `.unavailable`: a `Label` "Open Hugo to set up the widget" with the app's SF Symbol `chart.pie` (secondary) and no number. Both states are one accessibility element with a full-sentence label (`.accessibilityElement(children: .ignore)` plus `.accessibilityLabel`), for example "November: 32 hours of 50 hours" (goal), "November: 32 hours of 40 hours planned" (plan), "November: 12 hours" (neither), "Hugo widget. Open Hugo to set it up." (unavailable). Build the hours text with `progress.headline.spokenText()` and `ServiceDurationFormatter.hoursString(from:locale:)` so Danish and the minute case read correctly. Use Dynamic Type text styles only; no fixed font sizes except through `.largeTitle`. Add `#Preview(as: .systemSmall)` with a ready state, a no-goal state, a minutes state and the unavailable state.
- `Info.plist`: keys `HugoAppGroupIdentifier = $(APP_GROUP_IDENTIFIER)` and `NSExtension` with `NSExtensionPointIdentifier = com.apple.widgetkit-extension`.
- `Localizable.xcstrings`: keys `widget.month.name` (en "This Month", da "Denne måned"), `widget.month.description` (en "Your time this month against your goal.", da "Din tid denne måned mod dit mål."), `widget.month.of.goal.%lld` (en "of %lld hours", da "af %lld timer", with plural variations if the app's catalog uses them for hours, copy its form), `widget.month.of.planned.%lld` (en "of %lld hours planned", da "af %lld timer planlagt"), `widget.month.minutes.unit` (en "min", da "min"), `widget.month.setup` (en "Open Hugo to set up the widget", da "Åbn Hugo for at sætte widgetten op"), `widget.month.a11y.goal.%@.%@.%@` (month, time, goal), `widget.month.a11y.plan.%@.%@.%@`, `widget.month.a11y.nogoal.%@.%@`, `widget.month.a11y.unavailable`. Match the key and state style of the existing `a11y.monthly_progress_card.*` entries in the app catalog. Mark every key `translated` in both languages.
- No asset catalog. `Color.hugoAccent` is `.mint` (`Hugo/DesignSystem/Theme/Theme.swift`) and lives in the app's `DesignSystem`, which the widget must not use, so the gauge uses `.tint(.mint)` with a comment that it matches `Color.hugoAccent`.

**Verify**: `swift-format lint --strict --recursive HugoWidget` exits 0 (the folder is not compiled yet). The widget is compiled in the owner phase.

### Step 8: Docs

- `CODEMAP.md`: add a section "Features/Widget": shared logic for the home screen widget, `WidgetSettings`, `MonthProgress` (Domain), `WidgetSettingsMirror`, `WidgetStoreReader`, `WidgetRefreshScheduler` (Services); the folder is a member of the app and the widget; `HugoWidget/` holds the WidgetKit glue and views. Tests: `HugoTests/Features/Widget/`. Add rows to the task table: "Change what the widget shows" to `Hugo/Features/Widget/Domain/MonthProgress.swift`, `HugoWidget/MonthProgressWidgetView.swift`; "Give the widget another setting" to `Hugo/Features/Widget/Domain/WidgetSettings.swift` and `WidgetSettingsMirror.swift`. In the Persistence paragraph add `markFreshInstallIfNeeded`. In the Domain paragraph, mention `widgetSettings` as a device-only key.
- `README.md`, "Builds": add one sentence: the widget extension has the bundle ID of the app plus `.widget` and shares the app's App Group, and `APP_GROUP_IDENTIFIER` is derived from `BUNDLE_IDENTIFIER`, not from `PRODUCT_BUNDLE_IDENTIFIER`. Add `HugoWidget` to the "Architecture" list.
- `AGENTS.md`, section 7: add one sentence under "Top level of `Hugo/`": "`HugoWidget/` at the repo root holds the widget extension's WidgetKit glue and views. Logic the widget shares with the app lives in `Hugo/Features/Widget` and is a member of both targets."
- `plans/README.md`: add this row after plan 174, status `TODO` until done:

`| 175 | Add the first widget: a small home screen widget for this month's progress | P2 | L + owner | 174 | TODO | [SLN-351](https://linear.app/sebastianln/issue/SLN-351) |`

**Verify**: `grep -n "WidgetStoreReader" CODEMAP.md` matches; `grep -n "^| 175 " plans/README.md` matches.

### Step 9: Full gate

**Verify**: `Scripts/verify.sh` exits 0. `git status --short` shows only in-scope files (and the owner's unstaged `Localizable.xcstrings`). The widget sources are not compiled yet, so a green gate here does not prove them; the owner phase does.

## Owner steps (the executor cannot do these)

Do them after the executor is done. The plan-executor cannot create targets, change signing or use the developer portal.

1. **Create the target** in Xcode: File, New, Target, Widget Extension. Product name `HugoWidget`. Untick Live Activity, Control and "Include Configuration App Intent". Embed in the Hugo app. Delete the template's Swift files. Remove the template's own `HugoWidget` folder reference if Xcode made a new one, and instead add the existing repo folder `HugoWidget/` (created by the executor) as the target's synchronized folder.
2. **Build settings** for the new target, in all three configurations: base configuration the same xcconfig as the app (Debug, TestFlight, Production); iOS deployment target 26.0; Swift language version 6; `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (the shared files are written for it); `PRODUCT_BUNDLE_IDENTIFIER = $(BUNDLE_IDENTIFIER).widget`; `CODE_SIGN_ENTITLEMENTS = Configuration/HugoWidget.entitlements`; `INFOPLIST_FILE = HugoWidget/Info.plist` with generated Info.plist keys still on; same development team as the app. Check the Compile Sources list for `Hugo/Features/Widget/...` after step 4.
3. **Target membership**: in the file inspector tick `HugoWidget` for these (folders are fine in a synchronized group): `Hugo/Features/Widget`, `Hugo/Persistence/SchemaVersions`, `Hugo/Persistence/Legacy`, `Hugo/Persistence/AppSchema.swift`, `Hugo/Persistence/StoreRelocator.swift`, `Hugo/Persistence/StoreCopier.swift`, `Hugo/Domain/UserDefaultsKeys.swift`, `Hugo/Domain/YearMonth.swift`, `Hugo/Domain/HeadlineDuration.swift`, `Hugo/Domain/ServiceDurationFormatter.swift`, `Hugo/Features/PublisherStatus/Domain/PublisherStatus.swift`, `Hugo/Features/Overview/Domain/OverviewMetrics.swift`, `Hugo/Features/Overview/Domain/MonthlyCircleFill.swift`. Build the widget scheme. For every "cannot find ... in scope" error add that one file from `Hugo/Domain`, `Hugo/Persistence` or a `Domain` folder. Never add a `Screens`, `Views`, `State` or `DesignSystem` file; if the compiler asks for one, stop and ask for a Revision, because a shared type is leaking UI.
4. **Developer portal**: register the App Group the executor reports from step 1 (it is the same value plan 174 registered) and add the App Groups capability to the new widget App IDs (`com.ordellnielsen.Hugo.dev.widget` and `com.ordellnielsen.Hugo.widget`). With automatic signing, Xcode can do this in Signing & Capabilities for the widget target.
5. **Build and fix**: build the `Debug` scheme. If the widget glue in `HugoWidget/` does not compile (isolation errors on the provider are the likely ones), ask for a Revision of this plan with the compiler messages. Then run `Scripts/verify.sh` again; it builds the widget because the app embeds it.

## Owner checks (after the target builds)

- Install on Mona (iPhone) over the build that already ran plan 174's move, launch the app once, add the Hugo widget (small) on the home screen. It shows this month's time and the goal bar, and the number equals the Overview circle's number.
- Add and delete an entry in the app: the widget updates within a few seconds. Change the publisher status, the Buffer hours and the "Count Buffer in" Overview switch: the goal in the widget follows.
- Install a build with the widget but delete and reinstall Hugo (fresh store, no data) and add the widget before opening the app: it shows "Open Hugo to set up the widget"; after opening the app once it shows data.
- On the iPad (Sean) the widget appears in the gallery as a small widget and shows the same.
- Check English and Danish, the largest Dynamic Type size, dark mode, and VoiceOver reading the full sentence. Check a month with under one hour (minutes shown) and a Publisher status with no Monthly goal (with and without plans).
- Cross midnight on the last day of a month, or change the date in Settings with the app closed: after the next widget refresh the new month shows.
- Confirm in the Xcode console (subsystem `com.ordellnielsen.Hugo`, category `Widget`) that the widget logs no store errors.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] The new suites pass: `Scripts/test-quick.sh HugoTests/MonthProgressTests HugoTests/WidgetSettingsMirrorTests HugoTests/WidgetStoreReaderTests HugoTests/WidgetRefreshSchedulerTests` and the 3 added relocator and factory cases
- [ ] `grep -rn "APP_GROUP_IDENTIFIER" Configuration` shows `group.$(BUNDLE_IDENTIFIER)` in all three xcconfig files and the entitlements files
- [ ] `grep -rn "widgetSettings" Hugo/Domain/UserDefaultsKeys.swift` matches and `grep -n "widgetSettings" Hugo/Features/Settings/Domain/SyncedSettings.swift` matches only in the comment, not in `keys`
- [ ] `grep -rn "resolve()\|confirmAndDeleteLegacyStore\|abandonCopy\|migrationPlan\|MigrationPlan" Hugo/Features/Widget HugoWidget` prints nothing
- [ ] `grep -rn "cloudKitDatabase: .none" Hugo/Features/Widget/Services/WidgetStoreReader.swift` and `grep -n "allowsSave: false" Hugo/Features/Widget/Services/WidgetStoreReader.swift` both match
- [ ] `git diff --stat 8f9c2e7..HEAD -- Hugo/Persistence/SchemaVersions Hugo/Persistence/AppSchema.swift Hugo/Persistence/HugoMigrationPlan.swift Hugo/Persistence/SyncDeduplicator.swift Hugo/Features/Overview Hugo/Resources` prints nothing
- [ ] No file outside the in-scope list is modified (`git status`)
- [ ] `plans/README.md` status row updated (DONE with the owner steps and checks pending)

## STOP conditions

Stop and report (do not improvise) if:

- The drift check shows changes, or `OverviewMetrics.make`, `MonthlyCircleFill.make` or `makeProductionContainer` differ from the descriptions above.
- `APP_GROUP_IDENTIFIER` resolves empty, or differs from `group.com.ordellnielsen.Hugo.dev` for the Debug scheme after step 1.
- A store at a `url:` cannot be opened with `allowsSave: false` and `cloudKitDatabase: .none` in a test (the read-only design needs rethinking; report the error text).
- You would need to edit a schema, a model, `OverviewMetrics`, `MonthlyCircleFill`, `AppBootstrapper` or any out-of-scope file.
- A step's verification fails twice after a reasonable fix attempt.
- You find code in the widget that writes, migrates, deletes or relocates the store. That must stay absent.

## Maintenance notes

- A new schema version: the widget shows the placeholder until the user opens the app once (the app rewrites `widgetSettings` with the new `storeSchemaVersion` after it migrated). That is intended. Remember the widget target compiles `CurrentSchema`, so it moves with the app.
- A new widget family or a second number (Due month reminder, Plan pace) means more fields in `WidgetSettings` and more fetches in `WidgetStoreReader`. Keep the rule: the widget calls existing Domain types and copies no formula.
- If the shared file list grows past the Domain and Persistence folders, reconsider a local Swift package (the other option in this plan's question 1).
- A reviewer should check: the widget code path has no write, migration or relocation call (done criteria grep); `markFreshInstallIfNeeded` can never overwrite `copied`; the scheduler cannot loop (the mirror writes only on a difference).
- Known limit: the widget shows data from the last time the app saved or synced. Changes that CloudKit imports while the app is not running appear after the next app launch or the midnight reload.
- Deferred: lock screen and medium families, the Due month reminder, a widget tap target (`widgetURL`) that opens Add Entry, and removing the `copied`/`confirmed` distinction when plan 174's cleanup code goes.
