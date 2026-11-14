# Plan 118: Keep the report, Planner and Service Year settings the same on all of the user's devices

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 7e3c4e9..HEAD -- Hugo/App/HugoApp.swift Hugo/App/AppRootView.swift Hugo/Domain/UserDefaultsKeys.swift Hugo/Info.plist Hugo/InfoPlist.xcstrings Hugo/Resources/Markdown/Legal CONTEXT.md`
> Expected: plan 115 changed `Hugo/App/AppRootView.swift` (it removed
> `TabPlacement.compactOnly`). Nothing else may have changed. Compare the
> excerpts below with the live files. A mismatch is a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M + owner (two devices on one Apple Account; the contact picker; the website copy of the privacy policy)
- **Risk**: MED. New sync behavior, but small and well bounded: nine string or number settings, and no SwiftData or CloudKit schema change.
- **Depends on**: 114 (the gate), 115 (also edits `AppRootView.swift`)
- **Category**: direction
- **Planned at**: commit `7e3c4e9`, 2026-11-14
- **Issue**: [SLN-289](https://linear.app/sebastianln/issue/SLN-289)

## Why this matters

Entries, categories, reports and plans sync through iCloud, but settings don't. Someone who installs Hugo on a new iPhone or an iPad gets all their hours but has to set everything up again: the group overseer's name and phone number, the greeting, the Planner target, the Current Month Calculation and the minute interval. Until they do, a report sent from the iPad has no recipient. Many users are older and won't expect to repeat setup.

The app already has the iCloud key-value storage entitlement (`com.apple.developer.ubiquity-kvstore-identifier` in `Configuration/Hugo.entitlements`), but nothing uses it. This plan copies nine settings between `UserDefaults` and `NSUbiquitousKeyValueStore`. `@AppStorage` reads `UserDefaults`, so every screen picks up a synced value without changes.

Two related changes ship with it:
1. **Privacy policy.** It currently says "Your settings, including your group overseer's name and phone number, stay on the device where you entered them." That becomes false, so the English and Danish policies change in the same commit.
2. **Contacts permission text.** `Info.plist` asks for Contacts access, but Hugo only uses the system contact picker (`CNContactPickerViewController`), which needs no permission. Removing the key keeps App Review and the privacy answers honest.

## Decisions (owner defaults, 2026-11-14)

- **Which settings sync:** `yearlyGoalPacing`, `plannerTargetBase`, `plannerExtraHours`, `durationMinuteInterval`, `overseerFullName`, `overseerPhoneNumber`, `overseerGreetingTemplate`, `overseerFirstName`, `overseerLastName`.
- **Which stay on the device:** `isOnboarding` and `hasRunInitialSetup` (per device by nature), `publisherStatus` (SLN-227 moves it into synced data later; syncing it now would conflict with that), `overviewListStyle` (a view preference).
- **Conflicts:** at launch, a value already in iCloud wins over the device's value, so a new device adopts the settings of the user's existing devices. After launch, the latest change wins, which is how `NSUbiquitousKeyValueStore` resolves conflicts itself. One consequence: if two existing devices had *different* overseers, the first device to launch this build decides for both. That's acceptable. The owner can change this later.

## Current state

`Hugo/Domain/UserDefaultsKeys.swift` (whole file):

```swift
enum UserDefaultsKeys {
    static let isOnboarding = "isOnboarding"
    static let hasRunInitialSetup = "hasRunInitialSetup"

    static let publisherStatus = "publisherStatus"
    static let yearlyGoalPacing = "yearlyGoalPacing"
    static let plannerTargetBase = "plannerTargetBase"
    static let plannerExtraHours = "plannerExtraHours"

    static let durationMinuteInterval = "durationMinuteInterval"

    static let overseerFullName = "overseerFullName"
    static let overseerPhoneNumber = "overseerPhoneNumber"
    static let overseerGreetingTemplate = "overseerGreetingTemplate"
    static let overseerFirstName = "overseerFirstName"
    static let overseerLastName = "overseerLastName"

    static let overviewListStyle = "overviewListStyle"
}
```

The values are plain property-list types: `String`, `Int` and the raw values (`String` or `Int`) of enums stored with `@AppStorage`, such as `@AppStorage(UserDefaultsKeys.yearlyGoalPacing) private var pacing: YearlyGoalPacing = .proRated`. `NSUbiquitousKeyValueStore` stores these as they are. `@AppStorage` doesn't write its default value into `UserDefaults`, so `UserDefaults.object(forKey:)` is `nil` for a setting the user never touched.

`Hugo/App/HugoApp.swift:1-20`:

```swift
import SwiftData
import SwiftUI

@main
struct HugoApp: App {
    @State private var loader = ModelContainerLoader(makeContainer: HugoApp.makeContainer)

    var body: some Scene {
        WindowGroup {
            switch loader.state {
            case .loaded(let container):
                AppRootView()
                    .tint(.primary)
                    .modelContainer(container)
            case .failed(let details):
                StoreLoadFailureView(report: .current(errorDetails: details), retry: loader.retry)
                    .tint(.primary)
            }
        }
    }
```

Further down the same file, `private static var isRunningTests: Bool` is true inside the unit-test host. `AppRootView()` (line 12) is the only place that creates `AppRootView`, and `AppRootView` has no `#Preview`.

`Hugo/App/AppRootView.swift:1-18` and `49-72` (the lifecycle modifiers; the file already imports `Combine` and listens to notifications with `.onReceive(…publisher(for:)…receive(on: RunLoop.main))`, so follow that pattern):

```swift
import Combine
import CoreData
import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(UserDefaultsKeys.isOnboarding) private var needsOnboarding = true

    @State private var bootstrapper = AppBootstrapper()
    @State private var selectedTab: AppTab = .overview
    @State private var yearResetToken = UUID()
    @State private var plannerResetToken = UUID()
    @State private var bootstrapErrorMessage: String?
```

```swift
        .task {
            await bootstrapper.start(context: context)
            SyncDeduplicator(context: context).run()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { SyncDeduplicator(context: context).run() }
        }
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
        .sheet(isPresented: $needsOnboarding) { OnboardingView { needsOnboarding = false } }
```

Note: every stored property of `AppRootView` is `private`, so its implicit memberwise initializer is private. Adding a parameter therefore needs an explicit `init`.

`Hugo/Info.plist:5-6`:

```xml
	<key>NSContactsUsageDescription</key>
	<string>Hugo uses your contacts to fill in the group overseer&apos;s name and phone number for the monthly report.</string>
```

`Hugo/InfoPlist.xcstrings` (55 lines, no trailing newline). Lines 34-56:

```json
      "shouldTranslate" : false
    },
    "NSContactsUsageDescription" : {
      "comment" : "Privacy - Contacts Usage Description",
      "extractionState" : "extracted_with_value",
      "localizations" : {
        "da" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Hugo bruger dine kontakter til at udfylde gruppetjenerens navn og telefonnummer på månedsrapporten."
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "new",
            "value" : "Hugo uses your contacts to fill in the group overseer's name and phone number for the monthly report."
          }
        }
      }
    }
  },
  "version" : "1.2"
}
```

The only Contacts code is `Hugo/Features/Reports/Views/OverseerPicker.swift`, which uses `CNContactPickerViewController`. `grep -rn "CNContactStore" Hugo` finds nothing.

`Hugo/Resources/Markdown/Legal/Base.lproj/PrivacyPolicy.md`, line 3 and lines 23-29:

```markdown
Last updated: November 13, 2026
```

```markdown
- your settings, such as your publisher status, your goals and your group overseer's name and phone number

All of it is stored on your device.

If you're signed in to iCloud and iCloud is turned on for Hugo, your entries, categories, plans and submitted reports are also saved in your private iCloud database, so they stay the same on all your devices. Apple keeps this data under your Apple Account, and we can't access it. Apple's privacy policy covers how Apple handles iCloud.

Your settings, including your group overseer's name and phone number, stay on the device where you entered them.
```

`Hugo/Resources/Markdown/Legal/da.lproj/PrivacyPolicy.md`, line 3 and line 29:

```markdown
Senest opdateret: 13. november 2026
```

```markdown
Dine indstillinger, også din gruppetjeners navn og telefonnummer, bliver på den enhed, hvor du skrev dem.
```

Project layout rules (`AGENTS.md` section 7): a feature's `Domain` folder holds value types and logic, `nonisolated` where possible. `Services` holds "types that read or write the SwiftData context or the system". The project has MainActor default isolation and Swift 6 strict concurrency. New files in `Hugo/` and `HugoTests/` are picked up automatically (synchronized folders), so don't edit `project.pbxproj`. Tests mirror the source layout and use Swift Testing with `UserDefaults(suiteName: "<TestName>-\(UUID().uuidString)")!` for isolated defaults (see `HugoTests/App/AppBootstrapperTests.swift:20`).

`CONTEXT.md` has a `## Sync` section (lines 162-170) with entries in this shape:

```markdown
**Sync duplicate**:
Two copies of the same row that two devices each created before they synced. Hugo merges them and keeps one, the survivor.
_Avoid_: Conflict
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `xcrun swift-format lint --strict <changed Swift files>` | exit 0, no output |
| Plist | `plutil -lint Hugo/Info.plist` | `Hugo/Info.plist: OK` |
| JSON | `python3 -I -c "import json;json.load(open('Hugo/InfoPlist.xcstrings'))"` | exit 0 |
| Full gate | `Scripts/verify.sh` | exit 0 (several minutes; run with a 600000 ms timeout or in the background) |

## Scope

**In scope**:
- `Hugo/Features/Settings/Domain/SyncedSettings.swift` (create)
- `Hugo/Features/Settings/Services/SettingsSyncService.swift` (create)
- `HugoTests/Features/Settings/Services/SettingsSyncServiceTests.swift` (create)
- `Hugo/App/HugoApp.swift` (one line)
- `Hugo/App/AppRootView.swift` (an `init`, one property, the `.task` and two `.onReceive`)
- `Hugo/Info.plist` (remove the Contacts key)
- `Hugo/InfoPlist.xcstrings` (remove the Contacts entry)
- `Hugo/Resources/Markdown/Legal/Base.lproj/PrivacyPolicy.md` and `Hugo/Resources/Markdown/Legal/da.lproj/PrivacyPolicy.md` (the date and one paragraph each)
- `CONTEXT.md` (one new term)

**Out of scope**:
- `Hugo/Domain/UserDefaultsKeys.swift`. The key names stay as they are.
- Every screen that uses `@AppStorage`. They need no change.
- `Configuration/Hugo.entitlements`. The entitlement is already there.
- The Terms of Use, the website and App Store Connect. The owner handles the website copy.
- `Hugo.xcodeproj` and `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` (uncommitted change by the owner; never stage, commit, revert or stash it).

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- Never stage `plans/`, `.claude/` or `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage files by explicit path.
- Two commits:
  1. `feat: sync report, Planner and Service Year settings through iCloud` (the Swift files, both privacy policies and `CONTEXT.md`)
  2. `chore: remove the unused Contacts permission text` (`Info.plist` and `InfoPlist.xcstrings`)

## Steps

### Step 1: List the synced settings

Create `Hugo/Features/Settings/Domain/SyncedSettings.swift`:

```swift
/// The settings that stay the same on every device signed in to the user's
/// Apple Account, through iCloud key-value storage. Every other key in
/// `UserDefaultsKeys` stays on the device: the onboarding and setup flags,
/// the publisher status (the planned status timeline moves it into synced
/// data) and the Overview's list style.
nonisolated enum SyncedSettings {
    static let keys: [String] = [
        UserDefaultsKeys.yearlyGoalPacing,
        UserDefaultsKeys.plannerTargetBase,
        UserDefaultsKeys.plannerExtraHours,
        UserDefaultsKeys.durationMinuteInterval,
        UserDefaultsKeys.overseerFullName,
        UserDefaultsKeys.overseerPhoneNumber,
        UserDefaultsKeys.overseerGreetingTemplate,
        UserDefaultsKeys.overseerFirstName,
        UserDefaultsKeys.overseerLastName,
    ]
}
```

**Verify**: `xcrun swift-format lint --strict Hugo/Features/Settings/Domain/SyncedSettings.swift` → exit 0.

### Step 2: Write the sync service

Create `Hugo/Features/Settings/Services/SettingsSyncService.swift`:

```swift
import Foundation

/// The part of iCloud key-value storage that `SettingsSyncService` uses, so
/// tests can pass an in-memory store.
protocol CloudSettingsStore: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: CloudSettingsStore {}

/// Keeps the synced settings (`SyncedSettings.keys`) the same on all of the
/// user's devices by copying them between this device's `UserDefaults` and
/// iCloud key-value storage.
///
/// - At launch, `start()` takes every value iCloud already has, so a new
///   device picks up the settings of the user's other devices. It then sends
///   the settings only this device has.
/// - After that, `pushToCloud()` sends changes made on this device, and
///   `pullFromCloud()` writes changes from other devices into `UserDefaults`,
///   where `@AppStorage` picks them up.
///
/// A value is only written when it differs, so a change never bounces back
/// and forth between the two stores.
struct SettingsSyncService {
    private let defaults: UserDefaults
    private let cloud: any CloudSettingsStore
    private let keys: [String]

    init(
        defaults: UserDefaults = .standard,
        cloud: any CloudSettingsStore = NSUbiquitousKeyValueStore.default,
        keys: [String] = SyncedSettings.keys
    ) {
        self.defaults = defaults
        self.cloud = cloud
        self.keys = keys
    }

    /// Call once at launch.
    func start() {
        cloud.synchronize()
        pullFromCloud()
        pushToCloud()
    }

    /// Writes every synced setting that iCloud has into `UserDefaults`.
    func pullFromCloud() {
        for key in keys {
            guard let cloudValue = cloud.object(forKey: key) else { continue }
            if !Self.isEqual(defaults.object(forKey: key), cloudValue) {
                defaults.set(cloudValue, forKey: key)
            }
        }
    }

    /// Sends every synced setting this device has to iCloud.
    func pushToCloud() {
        for key in keys {
            guard let localValue = defaults.object(forKey: key) else { continue }
            if !Self.isEqual(cloud.object(forKey: key), localValue) {
                cloud.set(localValue, forKey: key)
            }
        }
    }

    private static func isEqual(_ lhs: Any?, _ rhs: Any) -> Bool {
        guard let lhs = lhs as? NSObject, let rhs = rhs as? NSObject else { return false }
        return lhs.isEqual(rhs)
    }
}
```

If the compiler rejects the `NSUbiquitousKeyValueStore` conformance or the protocol under strict concurrency, you may make the **smallest** change that compiles (for example marking the protocol `@MainActor`). Explain it in your report. If it needs more than that, STOP.

**Verify**: `xcrun swift-format lint --strict Hugo/Features/Settings/Services/SettingsSyncService.swift` → exit 0.

### Step 3: Test the service

Create `HugoTests/Features/Settings/Services/SettingsSyncServiceTests.swift`:

```swift
import Foundation
import Testing

@testable import Hugo

@MainActor
struct SettingsSyncServiceTests {
    private final class FakeCloudStore: CloudSettingsStore {
        var values: [String: Any] = [:]
        private(set) var writeCount = 0

        func object(forKey key: String) -> Any? { values[key] }

        func set(_ value: Any?, forKey key: String) {
            writeCount += 1
            values[key] = value
        }

        func synchronize() -> Bool { true }
    }

    private let defaults = UserDefaults(suiteName: "SettingsSyncServiceTests-\(UUID().uuidString)")!
    private let cloud = FakeCloudStore()

    private var service: SettingsSyncService {
        SettingsSyncService(defaults: defaults, cloud: cloud)
    }

    @Test
    func startTakesTheCloudValueOverTheDevicesValue() {
        defaults.set("Old Name", forKey: UserDefaultsKeys.overseerFullName)
        cloud.values[UserDefaultsKeys.overseerFullName] = "New Name"

        service.start()

        #expect(defaults.string(forKey: UserDefaultsKeys.overseerFullName) == "New Name")
        #expect(cloud.writeCount == 0)
    }

    @Test
    func startSendsSettingsOnlyThisDeviceHas() {
        defaults.set("+45 12 34 56 78", forKey: UserDefaultsKeys.overseerPhoneNumber)
        defaults.set(5, forKey: UserDefaultsKeys.durationMinuteInterval)

        service.start()

        #expect(cloud.values[UserDefaultsKeys.overseerPhoneNumber] as? String == "+45 12 34 56 78")
        #expect(cloud.values[UserDefaultsKeys.durationMinuteInterval] as? Int == 5)
    }

    @Test
    func untouchedSettingsAreNotSent() {
        service.start()

        #expect(cloud.values.isEmpty)
    }

    @Test
    func deviceOnlySettingsNeverSync() {
        defaults.set("regular-pioneer", forKey: UserDefaultsKeys.publisherStatus)
        defaults.set(false, forKey: UserDefaultsKeys.isOnboarding)
        defaults.set(true, forKey: UserDefaultsKeys.hasRunInitialSetup)
        defaults.set("byCategory", forKey: UserDefaultsKeys.overviewListStyle)
        cloud.values[UserDefaultsKeys.publisherStatus] = "publisher"

        service.start()

        #expect(cloud.values.count == 1)
        #expect(defaults.string(forKey: UserDefaultsKeys.publisherStatus) == "regular-pioneer")
    }

    @Test
    func aChangeOnThisDeviceIsSent() {
        service.start()
        defaults.set("Hej {first}!", forKey: UserDefaultsKeys.overseerGreetingTemplate)

        service.pushToCloud()

        #expect(cloud.values[UserDefaultsKeys.overseerGreetingTemplate] as? String == "Hej {first}!")
    }

    @Test
    func aChangeFromAnotherDeviceIsWrittenToUserDefaults() {
        service.start()
        cloud.values[UserDefaultsKeys.plannerExtraHours] = 3

        service.pullFromCloud()

        #expect(defaults.integer(forKey: UserDefaultsKeys.plannerExtraHours) == 3)
    }

    @Test
    func equalValuesAreNotWrittenAgain() {
        defaults.set("Jens", forKey: UserDefaultsKeys.overseerFirstName)
        cloud.values[UserDefaultsKeys.overseerFirstName] = "Jens"

        service.start()
        service.pushToCloud()
        service.pullFromCloud()

        #expect(cloud.writeCount == 0)
    }
}
```

**Verify**: `xcrun swift-format lint --strict HugoTests/Features/Settings/Services/SettingsSyncServiceTests.swift` → exit 0.

### Step 4: Start the sync in the app

1. In `Hugo/App/HugoApp.swift`, change `AppRootView()` to:

```swift
                AppRootView(settingsSync: Self.isRunningTests ? nil : SettingsSyncService())
```

2. In `Hugo/App/AppRootView.swift`, add this after the `@State private var bootstrapErrorMessage: String?` line:

```swift

    /// Copies the synced settings to and from iCloud. `nil` in the unit-test
    /// host, so tests never touch the real iCloud store.
    private let settingsSync: SettingsSyncService?

    init(settingsSync: SettingsSyncService? = nil) {
        self.settingsSync = settingsSync
    }
```

3. In the same file, change the `.task` to:

```swift
        .task {
            settingsSync?.start()
            await bootstrapper.start(context: context)
            SyncDeduplicator(context: context).run()
        }
```

4. Directly after the existing `.onReceive(…eventChangedNotification…) { … }` block and before `.sheet(isPresented: $needsOnboarding)`, add:

```swift
        .onReceive(
            NotificationCenter.default
                .publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
                .receive(on: RunLoop.main)
        ) { _ in
            settingsSync?.pullFromCloud()
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: UserDefaults.didChangeNotification)
                .receive(on: RunLoop.main)
        ) { _ in
            settingsSync?.pushToCloud()
        }
```

**Verify**: `grep -c "settingsSync" Hugo/App/AppRootView.swift` → `6`. `grep -c "SettingsSyncService()" Hugo/App/HugoApp.swift` → `1`. `xcrun swift-format lint --strict Hugo/App/AppRootView.swift Hugo/App/HugoApp.swift` → exit 0.

### Step 5: Update the privacy policy and CONTEXT.md

1. English policy (`Base.lproj/PrivacyPolicy.md`):
   - Line 3 becomes `Last updated: November 14, 2026`
   - Replace the line `Your settings, including your group overseer's name and phone number, stay on the device where you entered them.` with:

```markdown
If iCloud is on, most of your settings are also saved in your own iCloud, so they're the same on all your devices: your group overseer's name and phone number, your greeting, and your settings under General (Planner, Service Year and the minute interval). Your publisher status and the way the Overview list is shown stay on the device where you chose them.
```

2. Danish policy (`da.lproj/PrivacyPolicy.md`):
   - Line 3 becomes `Senest opdateret: 14. november 2026`
   - Replace the line `Dine indstillinger, også din gruppetjeners navn og telefonnummer, bliver på den enhed, hvor du skrev dem.` with:

```markdown
Hvis iCloud er slået til, gemmes de fleste af dine indstillinger også i din egen iCloud, så de er de samme på alle dine enheder: din gruppetjeners navn og telefonnummer, din hilsen og dine indstillinger under Generelt (Planlæg, Tjenesteår og minutinterval). Din forkynderstatus og visningen af listen i Overblik bliver på den enhed, hvor du valgte dem.
```

3. `CONTEXT.md`: in the `## Sync` section, after the **Canonical report** entry and before `## Flagged ambiguities`, add:

```markdown
**Synced setting**:
A setting that stays the same on all of the user's devices through iCloud key-value storage, such as the group overseer or the Planner target. The publisher status and the onboarding flags are not synced settings.
```

   Keep one blank line between entries, as in the rest of the file.

**Verify**:
- `grep -c "stay on the device where you entered them" Hugo/Resources/Markdown/Legal/Base.lproj/PrivacyPolicy.md` → `0`
- `grep -c "bliver på den enhed, hvor du skrev dem" Hugo/Resources/Markdown/Legal/da.lproj/PrivacyPolicy.md` → `0`
- `grep -c "November 14, 2026" Hugo/Resources/Markdown/Legal/Base.lproj/PrivacyPolicy.md` → `1`; `grep -c "14. november 2026" Hugo/Resources/Markdown/Legal/da.lproj/PrivacyPolicy.md` → `1`
- `grep -c "^\*\*Synced setting\*\*:" CONTEXT.md` → `1`

### Step 6: Run the gate and make commit 1

**Verify**: `Scripts/verify.sh` → exit 0, with all seven `SettingsSyncServiceTests` passing. `BundledMarkdownTests` still pass (the policies still contain the website URL and the email address).

Commit 1: `SyncedSettings.swift`, `SettingsSyncService.swift`, `SettingsSyncServiceTests.swift`, `HugoApp.swift`, `AppRootView.swift`, both `PrivacyPolicy.md` files and `CONTEXT.md`, by path.

### Step 7: Remove the Contacts permission text and make commit 2

1. In `Hugo/Info.plist`, delete lines 5 and 6 (the `NSContactsUsageDescription` key and its string).
2. In `Hugo/InfoPlist.xcstrings`, delete the whole `"NSContactsUsageDescription" : { … }` entry (the lines from `"NSContactsUsageDescription" : {` to its closing `}` before `  },`). The entry before it then becomes the last one, so its closing line `    },` (after `"shouldTranslate" : false`) loses its comma and becomes `    }`. Keep the file without a trailing newline.

**Verify**:
- `plutil -lint Hugo/Info.plist` → `Hugo/Info.plist: OK`
- `python3 -I -c "import json;d=json.load(open('Hugo/InfoPlist.xcstrings'));print(sorted(d['strings']))"` → `['CFBundleDisplayName', 'CFBundleName']`
- `grep -rn "NSContactsUsageDescription" Hugo` → no output
- `Scripts/verify.sh` → exit 0

Commit 2: `Hugo/Info.plist` and `Hugo/InfoPlist.xcstrings`, by path.

## Test plan

- New: `SettingsSyncServiceTests`, seven tests. They cover cloud-wins-at-launch, sending local-only settings, untouched settings not being sent, device-only keys never syncing, pushing a local change, pulling a remote change, and no redundant writes (the protection against values bouncing back and forth).
- The app wiring (`AppRootView`) and real iCloud can't be unit-tested. The owner checks them on devices.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0 after each commit
- [ ] `grep -rn "NSUbiquitousKeyValueStore" Hugo --include='*.swift'` shows only `SettingsSyncService.swift` and `AppRootView.swift`
- [ ] `grep -rn "NSContactsUsageDescription" Hugo` prints nothing
- [ ] `git show --stat HEAD~1` lists the nine files of commit 1; `git show --stat HEAD` lists the two files of commit 2
- [ ] `git diff --stat 7e3c4e9..HEAD -- Hugo/Domain/UserDefaultsKeys.swift Configuration` prints nothing

## STOP conditions

- The drift check shows changes other than plan 115's, and the excerpts don't match.
- The `CloudSettingsStore` conformance needs more than a one-attribute change to compile.
- A test other than the new ones fails after Step 4. The wiring may be affecting the test host; report which test fails.
- Removing the Contacts key makes any test or the analyzer fail.

## Owner checks

1. **Two devices.** Install the Debug build on two devices signed in to the same Apple Account. (Debug builds use the bundle ID `com.ordellnielsen.Hugo.dev`, so they share one key-value store with each other, separate from TestFlight.) On device A, set an overseer, a greeting and the minute interval. Open Hugo on device B: within a minute or so the same values appear under Settings. Change the greeting on B and check that A follows.
2. **New device.** Delete Hugo from device B and install it again. After onboarding, the overseer and the Planner settings are already there. The publisher status is asked for in onboarding as before.
3. **Contact picker.** Settings → Report → Group Overseer → choose a contact. The system picker opens without a permission prompt, and the name and phone number are filled in.
4. **Privacy policy.** Read the new paragraph in English and Danish in Settings → Privacy Policy. Publish the same text at `https://hugo.ordellnielsen.com/privacy` (SLN-53).

## Maintenance notes

- To sync a new setting, add its key to `SyncedSettings.keys`. Only plain property-list values (String, Int, Bool, Double, Data, Date, and arrays or dictionaries of these) can sync. iCloud key-value storage allows 1 MB and 1 024 keys per app.
- When the publisher status timeline (SLN-227) lands, decide whether `publisherStatus` becomes synced data in SwiftData. Don't add it to `SyncedSettings`.
- A future "Allow Users to Disable iCloud Sync" setting (SLN-57) must also stop this service: pass `nil` to `AppRootView` or skip `start()`.
- `UserDefaults.didChangeNotification` fires for every change in the app's defaults. `pushToCloud()` compares nine values and writes only differences, so the cost is negligible.
