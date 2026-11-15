# Plan 121: Show in Settings whether iCloud sync is working, and what to do when it isn't

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat d2d87d5..HEAD -- Hugo/App/AppRootView.swift Hugo/Domain/UserDefaultsKeys.swift Hugo/Features/Settings/Screens/SettingsView.swift Hugo/Resources/Localizable.xcstrings`
> Expected: only plan 120's changes to `SettingsView.swift` (an
> `appStoreLinks` property and a `#if SHOW_APP_STORE_LINKS` section) and to
> `Localizable.xcstrings` (four `settings.appStore.*` keys). Anything else is
> a mismatch: compare with the excerpts below and STOP if they differ.

## Status

- **Priority**: P2
- **Effort**: M + owner (device checks: signed out, offline, normal)
- **Risk**: LOW. Read-only: Hugo observes sync events it already receives and reads the account status. It doesn't change how sync works.
- **Depends on**: 120 (both edit `SettingsView.swift` and the string catalog)
- **Category**: direction
- **Planned at**: commit `d2d87d5`, 2026-11-14
- **Issue**: [SLN-219](https://linear.app/sebastianln/issue/SLN-219)

## Why this matters

Entries, categories, plans, reports and (since plan 118) settings all depend on iCloud, but sync can't be seen anywhere. When the user is signed out of iCloud, offline, out of iCloud storage, or sync fails, they just see missing hours on their other device, with no explanation. They can't tell whether it's safe to enter the data again, which risks duplicates. After this plan, Settings has an **iCloud** row. It shows the current state ("Up to date", "Offline", "Not signed in"…), and tapping it opens a short page that explains the state, when this device last synced, and what to do.

Owner defaults (2026-11-14):
- **No "Sync now" button.** `NSPersistentCloudKitContainer` has no public way to force a sync. A button that does nothing real would mislead. The page says Hugo retries by itself.
- **No deep links** into the Settings app: iOS offers no supported link to the iCloud pane. The page gives plain instructions instead.
- The last successful sync time is stored per device (`UserDefaults`, not synced).

## Current state

`Hugo/App/AppRootView.swift` already listens to CloudKit sync events, only to run the deduplicator after imports (lines 60-71 at `d2d87d5`):

```swift
        .onReceive(
            NotificationCenter.default
                .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
                .receive(on: RunLoop.main)
        ) { notification in
            guard
                let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                event.type == .import, event.endDate != nil
            else { return }
            SyncDeduplicator(context: context).run()
        }
```

The file starts with `import Combine`, `import CoreData`, `import SwiftData`, `import SwiftUI`. Its `@State` properties are at lines 13-17 (`bootstrapper`, `selectedTab`, `yearResetToken`, `plannerResetToken`, `bootstrapErrorMessage`), followed by plan 118's `private let settingsSync: SettingsSyncService?` and its `init`. The `body` is a `Group { if isCompact { compactLayout } else { regularLayout } }` followed by modifiers, the first of which is `.task {`.

An `NSPersistentCloudKitContainer.Event` has `identifier: UUID`, `type` (`.setup`, `.import`, `.export`), `startDate`, `endDate: Date?` (nil while it runs), `succeeded: Bool` and `error: Error?`. A started event and its finished copy share the same `identifier`. Events can't be created in tests, so the monitor below takes plain values.

**CloudKit in tests:** `CKContainer.default()` raises an Objective-C exception in the unsigned unit-test host, which kills the whole test run. `Hugo/App/CloudTrackerLookup.swift:13-38` guards against it like this. Copy the guard:

```swift
        if Self.isRunningTests { return false }
...
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
```

`Hugo/Features/Settings/Services/DiagnosticsCollector.swift:28-38` already maps `CKContainer.default().accountStatus()`:

```swift
            switch try await CKContainer.default().accountStatus() {
            case .available: return "available"
            case .noAccount: return "no account"
            case .restricted: return "restricted"
            case .temporarilyUnavailable: return "temporarily unavailable"
            case .couldNotDetermine: return "could not determine"
            @unknown default: return "unknown"
            }
```

`Hugo/Domain/UserDefaultsKeys.swift` holds every `UserDefaults` key as a `static let` (see plan 118 for the full file; the last key is `static let overviewListStyle = "overviewListStyle"`).

`Hugo/Features/Settings/Screens/SettingsView.swift` (at `d2d87d5`, lines 61-71) has the section with Report, Categories and General:

```swift
                Section {
                    NavigationLink(destination: ReportSettingsView()) {
                        Label("settings.group.settings.report", systemImage: "doc.text")
                    }
                    NavigationLink(destination: CategoryListView()) {
                        Label("settings.group.settings.category", systemImage: "square.grid.2x2")
                    }
                    NavigationLink(destination: GeneralSettingsView()) {
                        Label("settings.group.settings.general", systemImage: "gearshape")
                    }
                }
```

Its `List` ends at `.navigationTitle("settings.title")`. A row with a value on the right uses `LabeledContent`, as in `Hugo/Features/Settings/Screens/GeneralSettingsView.swift:15-24`:

```swift
                NavigationLink(destination: PlannerTargetSettingsView()) {
                    LabeledContent {
                        Text(
                            PlannerTarget.settingSummary(
                                base: base, extraHours: extraHours, status: status)
                        )
                        .foregroundStyle(.secondary)
                    } label: {
                        Label("planner.target.title", systemImage: "calendar")
                    }
                }
```

Domain types may expose `LocalizedStringResource` labels, as `PublisherStatus.label` does (`Hugo/Features/PublisherStatus/Domain/PublisherStatus.swift:7`).

Layout rules (`AGENTS.md` section 7): `Domain` holds value types, `nonisolated` where possible, but a type that uses main-actor-isolated values such as `UserDefaultsKeys` must not be `nonisolated` (plan 118 Revision 1 hit this). `State` holds `@MainActor @Observable` classes. `Services` holds types that talk to the system. `Screens` holds pushed screens. Tests mirror the source folders and use Swift Testing, with `UserDefaults(suiteName: "<Name>-\(UUID().uuidString)")!` for isolated defaults. The project has MainActor default isolation.

Strings go in `Hugo/Resources/Localizable.xcstrings`: JSON, two-space indentation, keys in sorted position, `en` and `da` both `"state" : "translated"`, with a `comment`. Copy the shape of an existing key such as `settings.account.shareTestFlight`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `xcrun swift-format lint --strict <changed Swift files>` | exit 0, no output |
| Catalog JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0 |
| Full gate | `Scripts/verify.sh > /tmp/verify121.log 2>&1; echo "exit $?"` | `exit 0` (about 5 minutes; 600000 ms timeout) |

## Scope

**In scope**:
- `Hugo/Features/Settings/Domain/CloudSyncStatus.swift` (create)
- `Hugo/Features/Settings/Services/CloudAccountStatusReader.swift` (create)
- `Hugo/Features/Settings/State/CloudSyncMonitor.swift` (create; the `State` folder is new for this feature)
- `Hugo/Features/Settings/Screens/CloudSyncStatusView.swift` (create)
- `HugoTests/Features/Settings/Domain/CloudSyncStatusTests.swift` (create)
- `HugoTests/Features/Settings/State/CloudSyncMonitorTests.swift` (create)
- `Hugo/Domain/UserDefaultsKeys.swift` (one key)
- `Hugo/App/AppRootView.swift` (the monitor, the environment, the event handler, one import)
- `Hugo/Features/Settings/Screens/SettingsView.swift` (one row and a `.task`)
- `Hugo/Resources/Localizable.xcstrings` (17 new keys)

**Out of scope**:
- `SyncDeduplicator`, `ModelContainerFactory` and anything that changes how sync runs.
- `Hugo/Features/Settings/Domain/SyncedSettings.swift`: the new key stays on the device.
- `DiagnosticsCollector`: it keeps its own account check.
- `Hugo.xcodeproj` and `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` (uncommitted change by the owner; never stage, commit, revert or stash it).

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- Never stage `plans/`, `.claude/` or `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage files by explicit path.
- One commit: `feat: show whether iCloud sync is working in Settings`

## Steps

### Step 1: The status rules (Domain)

Create `Hugo/Features/Settings/Domain/CloudSyncStatus.swift`:

```swift
import CloudKit
import Foundation

/// Whether this device's iCloud account can be used, as CloudKit reports it.
nonisolated enum CloudAccountState: Equatable {
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    /// Not read yet, or CloudKit couldn't tell.
    case unknown
}

/// Why the last sync attempt failed, from its CloudKit error code.
nonisolated enum CloudSyncFailure: Equatable {
    case signedOut
    case storageFull
    case offline
    case other

    init(ckErrorCode: Int?) {
        switch ckErrorCode.flatMap(CKError.Code.init(rawValue:)) {
        case .notAuthenticated?: self = .signedOut
        case .quotaExceeded?: self = .storageFull
        case .networkUnavailable?, .networkFailure?: self = .offline
        default: self = .other
        }
    }
}

/// What the iCloud row in Settings tells the user.
nonisolated enum CloudSyncStatus: Equatable {
    case upToDate(lastSync: Date?)
    case syncing
    case signedOut
    case restricted
    case storageFull
    case offline
    case problem

    /// The account problems come first, then the last failure, then a sync in
    /// progress. A successful sync clears the failure (see `CloudSyncMonitor`).
    static func make(
        account: CloudAccountState,
        isSyncing: Bool,
        failure: CloudSyncFailure?,
        lastSuccess: Date?
    ) -> CloudSyncStatus {
        switch account {
        case .noAccount: return .signedOut
        case .restricted: return .restricted
        case .available, .temporarilyUnavailable, .unknown: break
        }
        switch failure {
        case .signedOut?: return .signedOut
        case .storageFull?: return .storageFull
        case .offline?: return .offline
        case .other?: return .problem
        case nil: break
        }
        if isSyncing { return .syncing }
        if account == .temporarilyUnavailable { return .problem }
        return .upToDate(lastSync: lastSuccess)
    }

    var title: LocalizedStringResource {
        switch self {
        case .upToDate: "settings.sync.status.upToDate"
        case .syncing: "settings.sync.status.syncing"
        case .signedOut: "settings.sync.status.signedOut"
        case .restricted: "settings.sync.status.restricted"
        case .storageFull: "settings.sync.status.storageFull"
        case .offline: "settings.sync.status.offline"
        case .problem: "settings.sync.status.problem"
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .upToDate: "settings.sync.message.upToDate"
        case .syncing: "settings.sync.message.syncing"
        case .signedOut: "settings.sync.message.signedOut"
        case .restricted: "settings.sync.message.restricted"
        case .storageFull: "settings.sync.message.storageFull"
        case .offline: "settings.sync.message.offline"
        case .problem: "settings.sync.message.problem"
        }
    }

    var symbolName: String {
        switch self {
        case .upToDate: "checkmark.icloud"
        case .syncing: "arrow.triangle.2.circlepath.icloud"
        case .signedOut, .restricted: "icloud.slash"
        case .storageFull, .problem: "exclamationmark.icloud"
        case .offline: "wifi.slash"
        }
    }
}
```

**Verify**: `xcrun swift-format lint --strict Hugo/Features/Settings/Domain/CloudSyncStatus.swift` → exit 0.

### Step 2: Read the account status (Services)

Create `Hugo/Features/Settings/Services/CloudAccountStatusReader.swift`:

```swift
import CloudKit
import Foundation

/// Reads whether this device's iCloud account can be used. Returns `.unknown`
/// in the unit-test host: `CKContainer.default()` raises an Objective-C
/// exception there that would end the test run (see `CloudKitTrackerLookup`).
enum CloudAccountStatusReader {
    static func read() async -> CloudAccountState {
        if isRunningTests { return .unknown }
        do {
            switch try await CKContainer.default().accountStatus() {
            case .available: return .available
            case .noAccount: return .noAccount
            case .restricted: return .restricted
            case .temporarilyUnavailable: return .temporarilyUnavailable
            case .couldNotDetermine: return .unknown
            @unknown default: return .unknown
            }
        } catch {
            return .unknown
        }
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}
```

**Verify**: `xcrun swift-format lint --strict Hugo/Features/Settings/Services/CloudAccountStatusReader.swift` → exit 0.

### Step 3: Keep track of sync events (State)

1. In `Hugo/Domain/UserDefaultsKeys.swift`, add after `overviewListStyle`:

```swift

    /// When this device last finished a sync with iCloud. Device-only.
    static let cloudSyncLastSuccess = "cloudSyncLastSuccess"
```

2. Create `Hugo/Features/Settings/State/CloudSyncMonitor.swift`:

```swift
import Foundation
import Observation

/// Follows this device's iCloud sync for the iCloud row in Settings. The app
/// feeds it every sync event (`record`), and Settings asks it to read the
/// account status when it appears (`refreshAccount`). The time of the last
/// successful sync survives relaunches; everything else lives in memory.
@MainActor
@Observable
final class CloudSyncMonitor {
    private(set) var account: CloudAccountState = .unknown
    private(set) var lastSuccess: Date?
    private(set) var failure: CloudSyncFailure?
    private var running: Set<UUID> = []

    private let defaults: UserDefaults
    private let readAccount: () async -> CloudAccountState

    init(
        defaults: UserDefaults = .standard,
        readAccount: @escaping () async -> CloudAccountState = CloudAccountStatusReader.read
    ) {
        self.defaults = defaults
        self.readAccount = readAccount
        let stored = defaults.double(forKey: UserDefaultsKeys.cloudSyncLastSuccess)
        lastSuccess = stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    var status: CloudSyncStatus {
        CloudSyncStatus.make(
            account: account, isSyncing: !running.isEmpty, failure: failure, lastSuccess: lastSuccess)
    }

    /// Records a sync event. `endDate` is nil while the event runs.
    func record(id: UUID, endDate: Date?, succeeded: Bool, errorCode: Int?) {
        guard let endDate else {
            running.insert(id)
            return
        }
        running.remove(id)
        if succeeded {
            failure = nil
            lastSuccess = endDate
            defaults.set(endDate.timeIntervalSince1970, forKey: UserDefaultsKeys.cloudSyncLastSuccess)
        } else {
            failure = CloudSyncFailure(ckErrorCode: errorCode)
        }
    }

    func refreshAccount() async {
        account = await readAccount()
    }
}
```

If the compiler rejects the default argument `CloudAccountStatusReader.read` for the closure type, the smallest allowed fix is to wrap it: `readAccount: @escaping () async -> CloudAccountState = { await CloudAccountStatusReader.read() }`. Report it. Any other compile problem in this file: STOP.

**Verify**: `xcrun swift-format lint --strict Hugo/Domain/UserDefaultsKeys.swift Hugo/Features/Settings/State/CloudSyncMonitor.swift` → exit 0.

### Step 4: Tests

Create `HugoTests/Features/Settings/Domain/CloudSyncStatusTests.swift`:

```swift
import CloudKit
import Foundation
import Testing

@testable import Hugo

struct CloudSyncStatusTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func accountProblemsWinOverEverythingElse() {
        #expect(CloudSyncStatus.make(account: .noAccount, isSyncing: true, failure: .offline, lastSuccess: date) == .signedOut)
        #expect(CloudSyncStatus.make(account: .restricted, isSyncing: false, failure: nil, lastSuccess: nil) == .restricted)
    }

    @Test
    func aFailureWinsOverSyncing() {
        #expect(CloudSyncStatus.make(account: .available, isSyncing: true, failure: .storageFull, lastSuccess: date) == .storageFull)
        #expect(CloudSyncStatus.make(account: .available, isSyncing: false, failure: .offline, lastSuccess: date) == .offline)
        #expect(CloudSyncStatus.make(account: .available, isSyncing: false, failure: .other, lastSuccess: date) == .problem)
    }

    @Test
    func syncingThenUpToDate() {
        #expect(CloudSyncStatus.make(account: .available, isSyncing: true, failure: nil, lastSuccess: date) == .syncing)
        #expect(CloudSyncStatus.make(account: .available, isSyncing: false, failure: nil, lastSuccess: date) == .upToDate(lastSync: date))
        #expect(CloudSyncStatus.make(account: .unknown, isSyncing: false, failure: nil, lastSuccess: nil) == .upToDate(lastSync: nil))
    }

    @Test
    func temporarilyUnavailableAccountIsAProblem() {
        #expect(CloudSyncStatus.make(account: .temporarilyUnavailable, isSyncing: false, failure: nil, lastSuccess: date) == .problem)
    }

    @Test
    func failuresComeFromCloudKitErrorCodes() {
        #expect(CloudSyncFailure(ckErrorCode: CKError.Code.notAuthenticated.rawValue) == .signedOut)
        #expect(CloudSyncFailure(ckErrorCode: CKError.Code.quotaExceeded.rawValue) == .storageFull)
        #expect(CloudSyncFailure(ckErrorCode: CKError.Code.networkUnavailable.rawValue) == .offline)
        #expect(CloudSyncFailure(ckErrorCode: CKError.Code.networkFailure.rawValue) == .offline)
        #expect(CloudSyncFailure(ckErrorCode: CKError.Code.serverRejectedRequest.rawValue) == .other)
        #expect(CloudSyncFailure(ckErrorCode: nil) == .other)
    }
}
```

Create `HugoTests/Features/Settings/State/CloudSyncMonitorTests.swift`:

```swift
import CloudKit
import Foundation
import Testing

@testable import Hugo

@MainActor
struct CloudSyncMonitorTests {
    private let defaults = UserDefaults(suiteName: "CloudSyncMonitorTests-\(UUID().uuidString)")!
    private let end = Date(timeIntervalSince1970: 1_800_000_000)

    private func monitor(account: CloudAccountState = .available) -> CloudSyncMonitor {
        CloudSyncMonitor(defaults: defaults, readAccount: { account })
    }

    @Test
    func aRunningEventShowsSyncingUntilItEnds() {
        let monitor = monitor()
        let id = UUID()

        monitor.record(id: id, endDate: nil, succeeded: false, errorCode: nil)
        #expect(monitor.status == .syncing)

        monitor.record(id: id, endDate: end, succeeded: true, errorCode: nil)
        #expect(monitor.status == .upToDate(lastSync: end))
    }

    @Test
    func theLastSuccessSurvivesARelaunch() {
        monitor().record(id: UUID(), endDate: end, succeeded: true, errorCode: nil)

        #expect(monitor().lastSuccess == end)
    }

    @Test
    func aFailureShowsUntilTheNextSuccess() {
        let monitor = monitor()

        monitor.record(id: UUID(), endDate: end, succeeded: false, errorCode: CKError.Code.quotaExceeded.rawValue)
        #expect(monitor.status == .storageFull)

        monitor.record(id: UUID(), endDate: end.addingTimeInterval(60), succeeded: true, errorCode: nil)
        #expect(monitor.status == .upToDate(lastSync: end.addingTimeInterval(60)))
    }

    @Test
    func refreshingTheAccountCanShowSignedOut() async {
        let monitor = monitor(account: .noAccount)

        await monitor.refreshAccount()

        #expect(monitor.status == .signedOut)
    }
}
```

**Verify**: `xcrun swift-format lint --strict HugoTests/Features/Settings/Domain/CloudSyncStatusTests.swift HugoTests/Features/Settings/State/CloudSyncMonitorTests.swift` → exit 0. If the formatter wants to wrap the long `#expect` lines, run `xcrun swift-format format --in-place` on the two test files and check again.

### Step 5: The strings

Add these keys to `Hugo/Resources/Localizable.xcstrings`, each in its sorted position, with `en` and `da` `"state" : "translated"` and the comment shown:

| Key | English | Danish | Comment |
|---|---|---|---|
| `settings.sync.title` | iCloud | iCloud | Settings row and screen title for the iCloud sync status. |
| `settings.sync.lastSync.%@` | Last synced %@ | Sidst synkroniseret %@ | Footer on the iCloud screen. The argument is a relative time such as "2 minutes ago". |
| `settings.sync.lastSync.never` | This device hasn't synced with iCloud yet. | Denne enhed har ikke synkroniseret med iCloud endnu. | Footer on the iCloud screen before the first successful sync. |
| `settings.sync.status.upToDate` | Up to date | Opdateret | iCloud sync status: the last sync worked. |
| `settings.sync.status.syncing` | Syncing… | Synkroniserer… | iCloud sync status: a sync is running. |
| `settings.sync.status.signedOut` | Not signed in | Ikke logget ind | iCloud sync status: no iCloud account on this device. |
| `settings.sync.status.restricted` | Not allowed | Ikke tilladt | iCloud sync status: Screen Time or a profile blocks iCloud. |
| `settings.sync.status.storageFull` | iCloud is full | iCloud-lageret er fuldt | iCloud sync status: the user's iCloud storage is full. |
| `settings.sync.status.offline` | Offline | Offline | iCloud sync status: no network connection. |
| `settings.sync.status.problem` | Sync problem | Problem med synkronisering | iCloud sync status: sync failed for another reason. |
| `settings.sync.message.upToDate` | Your entries, categories, plans, reports and settings are saved in your iCloud, so they're the same on all your devices. | Dine registreringer, kategorier, planer, rapporter og indstillinger gemmes i din iCloud, så de er de samme på alle dine enheder. | Explanation on the iCloud screen when sync works. |
| `settings.sync.message.syncing` | Hugo is exchanging changes with iCloud right now. | Hugo udveksler ændringer med iCloud lige nu. | Explanation on the iCloud screen while a sync runs. |
| `settings.sync.message.signedOut` | Hugo keeps your data on this device only. To sync with your other devices, open the Settings app and sign in with your Apple Account at the top. | Hugo gemmer kun dine data på denne enhed. Hvis du vil synkronisere med dine andre enheder, skal du åbne appen Indstillinger og logge ind med din Apple-konto øverst. | Explanation on the iCloud screen when no iCloud account is signed in. |
| `settings.sync.message.restricted` | Screen Time or a profile has turned off iCloud on this device. Hugo keeps your data on this device only. | Skærmtid eller en profil har slået iCloud fra på denne enhed. Hugo gemmer kun dine data på denne enhed. | Explanation on the iCloud screen when iCloud is restricted. |
| `settings.sync.message.storageFull` | New changes stay on this device until there's room in your iCloud. To free up space, open the Settings app, tap your name, then iCloud. | Nye ændringer bliver på denne enhed, indtil der er plads i din iCloud. Du frigør plads ved at åbne appen Indstillinger, trykke på dit navn og derefter på iCloud. | Explanation on the iCloud screen when iCloud storage is full. |
| `settings.sync.message.offline` | Your changes are saved on this device and sync when you're back online. | Dine ændringer er gemt på denne enhed og synkroniseres, når du er online igen. | Explanation on the iCloud screen when the device is offline. |
| `settings.sync.message.problem` | Hugo couldn't sync just now. Your data is safe on this device, and Hugo tries again by itself. If it keeps happening, contact us. | Hugo kunne ikke synkronisere lige nu. Dine data er sikre på denne enhed, og Hugo prøver igen af sig selv. Hvis det bliver ved med at ske, så kontakt os. | Explanation on the iCloud screen when sync failed for another reason. |

**Verify**: `python3 -I -c "import json;d=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'];k=[x for x in d if x.startswith('settings.sync.')];print(len(k), all(d[x]['localizations']['da']['stringUnit']['value'] and d[x]['localizations']['en']['stringUnit']['value'] for x in k))"` → `17 True`.

### Step 6: The iCloud screen

Create `Hugo/Features/Settings/Screens/CloudSyncStatusView.swift`:

```swift
import SwiftUI

/// Explains the state of iCloud sync on this device and what to do about it.
struct CloudSyncStatusView: View {
    @Environment(CloudSyncMonitor.self) private var monitor: CloudSyncMonitor?

    private var status: CloudSyncStatus { monitor?.status ?? .upToDate(lastSync: nil) }

    var body: some View {
        List {
            Section {
                Label {
                    Text(status.title).font(.headline)
                } icon: {
                    Image(systemName: status.symbolName)
                }
                Text(status.message)
            } footer: {
                if let lastSuccess = monitor?.lastSuccess {
                    Text("settings.sync.lastSync.\(lastSuccess.formatted(.relative(presentation: .named)))")
                } else {
                    Text("settings.sync.lastSync.never")
                }
            }
        }
        .navigationTitle("settings.sync.title")
        .navigationBarTitleDisplayMode(.inline)
        .task { await monitor?.refreshAccount() }
    }
}

#Preview {
    NavigationStack {
        CloudSyncStatusView()
    }
    .environment(CloudSyncMonitor(readAccount: { .available }))
}
```

**Verify**: `xcrun swift-format lint --strict Hugo/Features/Settings/Screens/CloudSyncStatusView.swift` → exit 0.

### Step 7: Wire it into the app and Settings

1. `Hugo/App/AppRootView.swift`:
   - Add `import CloudKit` as the first import (keep the imports sorted: `CloudKit`, `Combine`, `CoreData`, `SwiftData`, `SwiftUI`).
   - After `@State private var bootstrapErrorMessage: String?`, add `@State private var syncMonitor = CloudSyncMonitor()`.
   - Directly after the closing `}` of the `Group { … }` in `body` and before `.task {`, add `.environment(syncMonitor)`.
   - Replace the `eventChangedNotification` handler's closure body (the `guard … SyncDeduplicator(context: context).run()` shown in "Current state") with:

```swift
            guard
                let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event
            else { return }
            syncMonitor.record(
                id: event.identifier,
                endDate: event.endDate,
                succeeded: event.succeeded,
                errorCode: (event.error as? CKError)?.code.rawValue
            )
            guard event.type == .import, event.endDate != nil else { return }
            SyncDeduplicator(context: context).run()
```

   The deduplicator still runs after each finished import, as before.

2. `Hugo/Features/Settings/Screens/SettingsView.swift`:
   - Add `@Environment(CloudSyncMonitor.self) private var syncMonitor: CloudSyncMonitor?` after the `openURL` environment line.
   - Directly after the Report/Categories/General `Section { … }`, add:

```swift

                Section {
                    NavigationLink(destination: CloudSyncStatusView()) {
                        LabeledContent {
                            Text(syncStatus.title).foregroundStyle(.secondary)
                        } label: {
                            Label("settings.sync.title", systemImage: syncStatus.symbolName)
                        }
                    }
                }
```

   - Add this computed property next to the other private properties (for example after `appStoreLinks`):

```swift

    private var syncStatus: CloudSyncStatus {
        syncMonitor?.status ?? .upToDate(lastSync: nil)
    }
```

   - After `.navigationTitle("settings.title")`, add `.task { await syncMonitor?.refreshAccount() }`.

**Verify**: `xcrun swift-format lint --strict Hugo/App/AppRootView.swift Hugo/Features/Settings/Screens/SettingsView.swift` → exit 0. `grep -c "syncMonitor" Hugo/App/AppRootView.swift` → `3`.

### Step 8: Run the gate and commit

**Verify**: `Scripts/verify.sh > /tmp/verify121.log 2>&1; echo "exit $?"` → `exit 0`. `grep -E "CloudSyncStatusTests|CloudSyncMonitorTests" /tmp/verify121.log | grep -c passed` → at least `2`, and no test fails.

Commit the ten in-scope files by path.

## Test plan

- New: `CloudSyncStatusTests` (the order of the rules and the error-code mapping) and `CloudSyncMonitorTests` (running and finished events, the persisted last-success time, a failure clearing on the next success, the account read).
- The screens and the event wiring are checked by the owner on a device.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, with both new suites passing
- [ ] `grep -rn "CKContainer.default()" Hugo --include='*.swift'` lists only `CloudTrackerLookup.swift`, `DiagnosticsCollector.swift` and `CloudAccountStatusReader.swift`
- [ ] `grep -c cloudSyncLastSuccess Hugo/Features/Settings/Domain/SyncedSettings.swift` → `0`
- [ ] `git show --stat HEAD` lists exactly the ten in-scope files

## STOP conditions

- The drift check shows changes other than plan 120's, and the excerpts don't match.
- `git status --short` shows `Hugo/Resources/Localizable.xcstrings` modified before you start.
- A compile problem other than the one allowed in Step 3.
- A test that touches CloudKit crashes the test host (look for an uncaught `NSException` or `CKContainer` in the log). That would mean a CloudKit call escaped the test guard.
- `Scripts/verify.sh` fails twice. Report the failing test names.

## Owner checks

On a device with the Debug build, in English and Danish:
1. Settings shows an **iCloud** row with "Up to date" on the right. Tapping it shows the explanation and "Last synced … ago".
2. Turn on Airplane Mode, add an entry, and wait a few seconds: the row shows "Offline" (CloudKit only reports this after it tries to export). Turn Airplane Mode off: it returns to "Up to date".
3. Optional, on a test device: sign out of iCloud and open Settings in Hugo. The row shows "Not signed in".

## Maintenance notes

- A future "turn off iCloud sync" setting (SLN-57) belongs on this screen.
- If Apple adds a public way to trigger a sync, a "Sync now" button can call it from `CloudSyncStatusView`.
- `CloudSyncFailure` maps only the common CloudKit errors. A `partialFailure` that wraps `quotaExceeded` shows as "Sync problem". If testers report that, unwrap `CKErrorPartialErrorsByItemIDKey` in `AppRootView`.

## Revision 1 (2026-11-15, after the owner's device check)

> **Execute only this revision.** Steps 1-8 are done (commit `5b0d21f`). Drift check for this revision:
> `git diff --stat c076cf9..HEAD -- Hugo/Features/Settings/Domain/CloudSyncStatus.swift Hugo/Features/Settings/State/CloudSyncMonitor.swift Hugo/App/AppRootView.swift HugoTests/Features/Settings`
> Expected: no output. Otherwise STOP.

### What the owner saw

In Airplane Mode the iCloud row never showed "Offline". It kept saying "Syncing…".

### Why

The plan assumed CloudKit fails an export with `networkUnavailable` when the device is offline. In practice NSPersistentCloudKitContainer starts the export event and then waits for the network, so the event stays running (`endDate == nil`) for as long as the device is offline, and the status rule reports `.syncing`. The fix doesn't rely on CloudKit's errors: Hugo watches the network path itself (`NWPathMonitor`, Network framework) and shows "Offline" whenever there is no connection.

### Scope of this revision

- `Hugo/Features/Settings/Services/NetworkPathWatcher.swift` (create)
- `Hugo/Features/Settings/Domain/CloudSyncStatus.swift` (`make` gains `isOnline`)
- `Hugo/Features/Settings/State/CloudSyncMonitor.swift` (`isOnline`, `setOnline`, `startWatchingNetwork`)
- `Hugo/App/AppRootView.swift` (one line in `.task`)
- `HugoTests/Features/Settings/Domain/CloudSyncStatusTests.swift` and `HugoTests/Features/Settings/State/CloudSyncMonitorTests.swift` (one test each)

No string changes: `settings.sync.status.offline` and `settings.sync.message.offline` already exist.

Commit: `fix: show Offline in the iCloud row whenever the device has no network`

### Step R1: Watch the network path (Services)

Create `Hugo/Features/Settings/Services/NetworkPathWatcher.swift`:

```swift
import Foundation
import Network

/// Calls `onChange` with whether the device has a network connection, once at
/// the start and again whenever it changes. It watches for as long as it
/// exists. `NWPathMonitor` needs a queue of its own; the result is handed to
/// the main actor.
final class NetworkPathWatcher {
    private let monitor = NWPathMonitor()

    init(onChange: @escaping @MainActor @Sendable (Bool) -> Void) {
        monitor.pathUpdateHandler = { path in
            let isOnline = path.status == .satisfied
            Task { @MainActor in onChange(isOnline) }
        }
        monitor.start(queue: DispatchQueue(label: "com.ordellnielsen.Hugo.network-path"))
    }
}
```

The `DispatchQueue` here is the queue `NWPathMonitor.start(queue:)` requires. It is not a `DispatchQueue.main.async` hop, which `AGENTS.md` forbids. If the compiler rejects a capture in `pathUpdateHandler` under strict concurrency, the smallest allowed fix is marking the class `nonisolated` or the closure `@Sendable`. Report it. Anything larger: STOP.

**Verify**: `xcrun swift-format lint --strict Hugo/Features/Settings/Services/NetworkPathWatcher.swift` → exit 0.

### Step R2: Put "no network" into the status rule

In `CloudSyncStatus.make`, add a parameter `isOnline: Bool = true` between `account` and `isSyncing`, and insert the offline check right after the account `switch`:

```swift
    static func make(
        account: CloudAccountState,
        isOnline: Bool = true,
        isSyncing: Bool,
        failure: CloudSyncFailure?,
        lastSuccess: Date?
    ) -> CloudSyncStatus {
        switch account {
        case .noAccount: return .signedOut
        case .restricted: return .restricted
        case .available, .temporarilyUnavailable, .unknown: break
        }
        if !isOnline { return .offline }
        switch failure {
```

(the rest of the function stays as it is). Update the doc comment above `make` to: `/// The account problems come first, then a missing network connection, then the last failure, then a sync in progress. A successful sync clears the failure (see `CloudSyncMonitor`).`

The default `true` keeps the existing tests compiling unchanged.

### Step R3: Let the monitor follow the network

In `CloudSyncMonitor`:

1. After `private(set) var failure: CloudSyncFailure?`, add `private(set) var isOnline = true`.
2. After `private var running: Set<UUID> = []`, add `@ObservationIgnored private var networkWatcher: NetworkPathWatcher?`.
3. In `status`, pass `isOnline: isOnline` to `CloudSyncStatus.make` (after `account:`).
4. Add these two methods after `refreshAccount()`:

```swift

    func setOnline(_ isOnline: Bool) {
        self.isOnline = isOnline
    }

    /// Starts following the network connection. Call once at launch; later
    /// calls do nothing.
    func startWatchingNetwork() {
        guard networkWatcher == nil else { return }
        networkWatcher = NetworkPathWatcher { [weak self] isOnline in
            self?.setOnline(isOnline)
        }
    }
```

5. Update the type's doc comment: after "The app feeds it every sync event (`record`)", add ", starts it watching the network at launch (`startWatchingNetwork`)".

### Step R4: Start watching at launch

In `Hugo/App/AppRootView.swift`, in the `.task`, add `syncMonitor.startWatchingNetwork()` directly after `settingsSync?.start()`.

**Verify**: `grep -c "startWatchingNetwork" Hugo/App/AppRootView.swift` → `1`.

### Step R5: Tests

1. In `CloudSyncStatusTests`, add:

```swift
    @Test
    func noNetworkShowsOfflineEvenWhileAnExportWaits() {
        #expect(
            CloudSyncStatus.make(account: .available, isOnline: false, isSyncing: true, failure: nil, lastSuccess: date)
                == .offline)
        #expect(
            CloudSyncStatus.make(account: .noAccount, isOnline: false, isSyncing: false, failure: nil, lastSuccess: nil)
                == .signedOut)
    }
```

2. In `CloudSyncMonitorTests`, add:

```swift
    @Test
    func losingTheNetworkShowsOfflineAndComingBackShowsSyncingAgain() {
        let monitor = monitor()
        monitor.record(id: UUID(), endDate: nil, succeeded: false, errorCode: nil)

        monitor.setOnline(false)
        #expect(monitor.status == .offline)

        monitor.setOnline(true)
        #expect(monitor.status == .syncing)
    }
```

If swift-format complains about line length in the tests, run `xcrun swift-format format --in-place` on that file and lint again.

### Step R6: Run the gate and commit

**Verify**: `xcrun swift-format lint --strict` on every changed Swift file → exit 0. `Scripts/verify.sh > /tmp/verify121r1.log 2>&1; echo "exit $?"` → `exit 0`, with the two new tests passing. Commit the six files by path.

### Owner check for this revision

Turn on Airplane Mode with Hugo open in Settings: the iCloud row changes to "Offline" within a second or two, with or without a pending change. Turn it off: the row goes to "Syncing…" or "Up to date".
