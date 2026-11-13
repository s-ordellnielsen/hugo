# Plan 103: Show a recovery screen instead of crashing when the data store can't open

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 3055ae6..HEAD -- Hugo/App/HugoApp.swift Hugo/Persistence/ModelContainerFactory.swift HugoTests/App`
> Expected: no output. Otherwise compare the excerpts below with the live
> files. A mismatch is a STOP condition. (`Scripts/verify.sh` may have changed
> because of plan 102. That is fine, see "Commands you will need".)

## Status

- **Priority**: P1
- **Effort**: M + owner (device check with a simulated failure)
- **Risk**: MED. It changes how the app starts. No data is changed or deleted.
- **Depends on**: none. Plan 102 (build configurations) can land before or after this one.
- **Category**: bug
- **Planned at**: commit `3055ae6`, 2026-11-13
- **Issue**: [SLN-172](https://linear.app/sebastianln/issue/SLN-172)

## Why this matters

Hugo opens its SwiftData store in `HugoApp.init()`. If that throws, the app calls `fatalError`. The store goes through 13 migration stages, so the throw can come from a failed migration, a corrupt file, a store written by a newer build (a TestFlight tester who installs an older build), a full disk, or a background launch from a CloudKit push before the device's first unlock after a restart. In every case the app crashes on launch, and it crashes again on every launch after that. The user sees Hugo flash and close, with no message and no way to reach support.

After this plan, the app catches the error and shows a plain screen. The screen says nothing has been deleted, and it offers **Retry**, **Contact Us** (an email draft with the error details filled in) and a **Details** section the user can copy or screenshot. Retry also runs by itself when the app comes back to the foreground, which handles the locked-device case without the user doing anything.

**What this plan does not do: it never deletes or resets the store.** A "reset and download again from iCloud" button was considered and left out. Hugo can't tell which local changes have not reached iCloud yet, so a reset could silently lose entries. Many of Hugo's users are older and would not understand that trade-off. Contacting support keeps the data safe until the developer can look at the error. See Maintenance notes.

## Current state

`Hugo/App/HugoApp.swift` (whole file, 34 lines):

```swift
import SwiftData
import SwiftUI

@main
struct HugoApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer =
                try Self.isRunningTests
                ? ModelContainerFactory.makeInMemoryContainer()
                : ModelContainerFactory.makeProductionContainer()
        } catch {
            fatalError("Could not create model container: \(error)")
        }
    }

    private static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["HUGO_TEST_MODE"] == "1"
            || environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .tint(.primary)
                .modelContainer(modelContainer)
        }
    }
}
```

`Hugo/Persistence/ModelContainerFactory.swift` has `makeProductionContainer()` and `makeInMemoryContainer()`, both `throws`. **Do not change this file.** The production configuration is `ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)`, which syncs with CloudKit through the entitlements.

Things that only run after the store opens, all inside `AppRootView` (`Hugo/App/AppRootView.swift`): `AppBootstrapper.start` (seeds the default category), `SyncDeduplicator.run`, the onboarding sheet, and every tab. The failure screen replaces `AppRootView` completely, so none of them run and nothing touches the store.

`fatalError` appears in exactly two places in `Hugo/`: `HugoApp.swift:15` (this plan removes it) and `Hugo/PreviewSupport/PreviewModelContainer.swift:24` (Xcode previews only; leave it).

### Conventions to match

- `@MainActor @Observable final class` for state, with dependencies passed into `init` so tests can replace them. Exemplar: `Hugo/App/AppBootstrapper.swift` (injects `lookup` and `userDefaults`, logs with `Logger(subsystem: "com.ordellnielsen.Hugo", category: ...)`).
- Its test, `HugoTests/App/AppBootstrapperTests.swift`, is the pattern for the new tests: `import Testing`, `@testable import Hugo`, a `@MainActor struct ...Tests`, small private stub types at the top of the file.
- On-disk store tests use `HugoTests/TestSupport/TemporaryStore.swift`: `let store = try TemporaryStore(); defer { store.remove() }`, then `store.storeURL`.
- Empty and error states use `ContentUnavailableView` with a serif title. Exemplar, `Hugo/Features/Overview/Views/OverviewListView.swift:24-37`:

  ```swift
  ContentUnavailableView {
      Label {
          Text("overview.entries.empty")
              .fontDesign(.serif)
      } icon: {
          Image(systemName: "text.page.badge.magnifyingglass")
      }
  } description: {
      Text("overview.entries.empty.description")
  } actions: {
      Button("overview.entries.empty.actions.add") {
          showAddEntrySheet.toggle()
      }
  }
  ```

- Spacing tokens are in `Hugo/DesignSystem/Theme/Theme.swift` (`HugoLayout.Spacing.small`, `.regular`).
- `Hugo/App/` holds the app entry point, root view and bootstrap. It has no role subfolders. The new files go directly in `Hugo/App/`. `Scripts/check-layout.sh` allows this.
- Swift 6 with complete concurrency checking and MainActor default isolation. 4-space indentation; tabs fail the lint.
- The support address comes from Info.plist key `SupportEmail` (value `$(SUPPORT_EMAIL)`, `app@ordellnielsen.com` in every configuration). `SettingsView` reads it with `Bundle.main.object(forInfoDictionaryKey: "SupportEmail") as? String`. Read it the same way. Do not edit `SettingsView`.

### Strings that already exist (reuse them, don't duplicate)

| Key | English | Danish |
|---|---|---|
| `common.retry` | Retry | Prøv igen |
| `settings.contact.email` | Contact Us | Kontakt os |

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Layout | `Scripts/check-layout.sh` | exit 0, no output |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/ModelContainerLoaderTests -only-testing:HugoTests/StoreLoadFailureReportTests` | `** TEST SUCCEEDED **` |
| Catalog JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0 |
| Full gate (before the commit) | `Scripts/verify.sh` | exit 0 |
| Whitespace | `git diff --check` | exit 0 |

If plan 102 has landed, the scheme may be called `Debug` instead of `Hugo`. Use the `-scheme` value that `Scripts/verify.sh` uses.

New files are picked up automatically (synchronized folders). Do not edit `project.pbxproj`.

## Scope

**In scope** (the only files you may modify or create):

- `Hugo/App/HugoApp.swift`
- `Hugo/App/ModelContainerLoader.swift` (create)
- `Hugo/App/StoreLoadFailureReport.swift` (create)
- `Hugo/App/StoreLoadFailureView.swift` (create)
- `Hugo/Resources/Localizable.xcstrings` (the four new keys in Step 4 only)
- `HugoTests/App/ModelContainerLoaderTests.swift` (create)
- `HugoTests/App/StoreLoadFailureReportTests.swift` (create)

**Out of scope** (do NOT touch):

- `Hugo/Persistence/**`: the factory, `HugoMigrationPlan`, every schema version, `SyncDeduplicator`. This plan only catches errors. It does not fix migrations.
- Any code that deletes, moves or renames the store file. No reset button.
- `Hugo/Features/Settings/Screens/SettingsView.swift`. Plan 102 changes it in parallel.
- `Hugo/App/AppRootView.swift`, `AppBootstrapper.swift`, and `Hugo/PreviewSupport/PreviewModelContainer.swift`.
- `Hugo.xcodeproj/**`, including the shared schemes. The owner adds the launch argument for the device check locally and does not commit it.
- `.claude/`, `plans/` and the owner's `Changelog/` changes. Never stage them.

## Git workflow

- Work on `main`. No branch, no worktree, no push. Stage files by path.
- One commit after `Scripts/verify.sh` exits 0: `fix: show a recovery screen instead of crashing when the data store can't open`.

## Steps

### Step 1: Add the failure report value

Create `Hugo/App/StoreLoadFailureReport.swift`. It is a pure value with no SwiftUI and no SwiftData, so it can be tested directly.

```swift
import Foundation

/// What Hugo shows and emails when its data store can't open: the app
/// version, the build number and the error text.
nonisolated struct StoreLoadFailureReport: Equatable, Sendable {
    let errorDetails: String
    let appVersion: String
    let buildNumber: String

    /// The report for this app, with version and build read from `bundle`.
    static func current(errorDetails: String, bundle: Bundle = .main) -> StoreLoadFailureReport {
        StoreLoadFailureReport(
            errorDetails: errorDetails,
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        )
    }

    /// The text shown under Details and used as the email body.
    var text: String {
        "Hugo \(appVersion) (\(buildNumber))\n\n\(errorDetails)"
    }

    /// A `mailto:` URL with `subject` and `text` filled in, or nil when
    /// `email` is empty.
    func mailURL(to email: String, subject: String) -> URL? {
        guard !email.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: text),
        ]
        return components.url
    }
}
```

**Verify**: `xcrun swift-format lint --strict --recursive Hugo HugoTests` exits 0.

### Step 2: Add the loader

Create `Hugo/App/ModelContainerLoader.swift`:

```swift
import Foundation
import OSLog
import Observation
import SwiftData

/// Opens Hugo's SwiftData store at launch. If opening or migrating the store
/// throws, it keeps the error text instead of crashing, so the app can show
/// `StoreLoadFailureView`. It never deletes or changes the store.
@MainActor
@Observable
final class ModelContainerLoader {
    enum State {
        case loaded(ModelContainer)
        case failed(details: String)
    }

    private(set) var state: State
    @ObservationIgnored private let makeContainer: @MainActor () throws -> ModelContainer
    private static let logger = Logger(subsystem: "com.ordellnielsen.Hugo", category: "Persistence")

    init(makeContainer: @escaping @MainActor () throws -> ModelContainer) {
        self.makeContainer = makeContainer
        self.state = Self.load(using: makeContainer)
    }

    /// Tries to open the store again. Does nothing once it is open.
    func retry() {
        guard case .failed = state else { return }
        state = Self.load(using: makeContainer)
    }

    private static func load(using makeContainer: @MainActor () throws -> ModelContainer) -> State {
        do {
            return .loaded(try makeContainer())
        } catch {
            let details = String(describing: error)
            logger.error("Could not open the data store: \(details, privacy: .public)")
            return .failed(details: details)
        }
    }
}

/// Thrown instead of opening the store when the app is launched with
/// `-HugoSimulateStoreLoadFailure`, so the failure screen can be checked on a
/// device. Only Xcode can pass launch arguments, so App Store users can't
/// trigger it.
struct SimulatedStoreLoadFailure: Error, CustomStringConvertible {
    var description: String {
        "Simulated store load failure (launch argument -HugoSimulateStoreLoadFailure)"
    }
}
```

`String(describing: error)` keeps the Core Data domain, code and user info, which says more than `localizedDescription`. The developer needs that detail in a support email.

**Verify**: lint exits 0.

### Step 3: Use the loader in `HugoApp`

Replace the body of `Hugo/App/HugoApp.swift` so it reads:

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

    private static func makeContainer() throws -> ModelContainer {
        if ProcessInfo.processInfo.arguments.contains("-HugoSimulateStoreLoadFailure") {
            throw SimulatedStoreLoadFailure()
        }
        return
            try isRunningTests
            ? ModelContainerFactory.makeInMemoryContainer()
            : ModelContainerFactory.makeProductionContainer()
    }

    private static var isRunningTests: Bool {
        // unchanged: keep the existing four checks exactly as they are
    }
}
```

Keep `isRunningTests` exactly as it is today (copy its body from the current file). The `let modelContainer` property, the `init()` and the `fatalError` go away. `StoreLoadFailureView` doesn't exist yet, so the build fails until Step 5. Do Steps 3–5 before building.

**Verify**: `grep -n "fatalError" Hugo/App/HugoApp.swift` prints nothing.

### Step 4: Add the strings

Add these four keys to `Hugo/Resources/Localizable.xcstrings`. Use the same JSON shape as the existing `common.retry` entry: a `comment`, then `localizations` with `da` and `en`, each `{"stringUnit": {"state": "translated", "value": ...}}`. Keep the file's existing formatting (2-space JSON, `" : "` separators, keys in sorted order). The simplest safe way is to open the catalog in Xcode's string editor, or to edit the JSON by hand next to a neighbouring key.

| Key | English | Danish | Comment |
|---|---|---|---|
| `launch.failure.title` | Hugo couldn't open your data | Hugo kunne ikke åbne dine data | Title of the screen shown when the data store can't open at launch. |
| `launch.failure.message` | Nothing has been deleted. Try again, or check that you have the latest version of Hugo. If it keeps happening, contact us. | Intet er blevet slettet. Prøv igen, eller tjek at du har den nyeste version af Hugo. Hvis det bliver ved med at ske, så kontakt os. | Explanation under the title on the launch failure screen. |
| `launch.failure.details` | Details | Detaljer | Disclosure that shows the technical error text on the launch failure screen. |
| `launch.failure.email.subject` | Hugo couldn't open its data | Hugo kunne ikke åbne sine data | Subject of the support email drafted from the launch failure screen. |

**Verify**: the catalog JSON check exits 0, and
`python3 -I -c "import json;s=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'];print(sum(k.startswith('launch.failure.') for k in s))"` prints `4`.

### Step 5: Add the failure screen

Create `Hugo/App/StoreLoadFailureView.swift`:

```swift
import SwiftUI

/// Shown in place of the app when the data store can't open. It explains that
/// nothing was deleted and offers Retry, Contact Us and the error details.
struct StoreLoadFailureView: View {
    let report: StoreLoadFailureReport
    let retry: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    private var supportMailURL: URL? {
        let email = Bundle.main.object(forInfoDictionaryKey: "SupportEmail") as? String ?? ""
        return report.mailURL(to: email, subject: String(localized: "launch.failure.email.subject"))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HugoLayout.Spacing.regular) {
                ContentUnavailableView {
                    Label {
                        Text("launch.failure.title")
                            .fontDesign(.serif)
                    } icon: {
                        Image(systemName: "externaldrive.badge.exclamationmark")
                    }
                } description: {
                    Text("launch.failure.message")
                } actions: {
                    Button("common.retry", action: retry)
                        .buttonStyle(.borderedProminent)
                    if let supportMailURL {
                        Button("settings.contact.email") {
                            openURL(supportMailURL)
                        }
                    }
                }

                DisclosureGroup("launch.failure.details") {
                    Text(verbatim: report.text)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, HugoLayout.Spacing.small)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { retry() }
        }
    }
}

#Preview {
    StoreLoadFailureView(
        report: StoreLoadFailureReport(
            errorDetails: "Error Domain=NSCocoaErrorDomain Code=134110",
            appVersion: "1.0",
            buildNumber: "125"
        ),
        retry: {}
    )
}
```

Notes:

- The preview needs no model container, so it does not use `.modelContainer(.preview)`.
- `onChange(of: scenePhase)` retries when the app comes back to the foreground. `ModelContainerLoader.retry()` does nothing once the store is open, so extra calls are harmless.
- If `HugoLayout.Spacing.regular` or `.small` don't exist under those names, use the names in `Hugo/DesignSystem/Theme/Theme.swift`. Don't add new tokens.

**Verify**: `Scripts/check-layout.sh` exits 0, lint exits 0, and the app target builds (the focused test command in Step 6 builds it).

### Step 6: Add the tests

Create `HugoTests/App/StoreLoadFailureReportTests.swift` and `HugoTests/App/ModelContainerLoaderTests.swift`, following the shape of `HugoTests/App/AppBootstrapperTests.swift`. Cases are listed in the Test plan below.

For the loader tests, use a small `@MainActor final class` stub with a `var failuresLeft: Int`, whose `make()` method throws a private error while `failuresLeft > 0` (and decrements it), then returns `try InMemoryModelContainer.make()`. Pass `{ try stub.make() }` as `makeContainer`. Don't capture a mutable local `var` in the closure. Swift 6 rejects that for a `@MainActor` closure.

Check the loader state with pattern matching, because `State` is not `Equatable`:

```swift
guard case .failed(let details) = loader.state else {
    Issue.record("Expected .failed, got \(loader.state)")
    return
}
#expect(details.contains("StubError"))
```

For the corrupt-store case, write bytes that aren't a SQLite database to `store.storeURL` (`try Data("not a database".utf8).write(to: store.storeURL)`), then create the loader with a closure that opens that URL the way `SchemaMigrationTests.makeCurrentStore(at:)` does:

```swift
let schema = Schema(versionedSchema: CurrentSchema.self)
let configuration = ModelConfiguration(schema: schema, url: store.storeURL, cloudKitDatabase: .none)
return try ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: [configuration])
```

**Verify**: the focused test command prints `** TEST SUCCEEDED **`. Then `Scripts/verify.sh` exits 0 and `git diff --check` exits 0. Commit the in-scope files only.

## Test plan

`HugoTests/App/StoreLoadFailureReportTests.swift` (`@Suite struct`, no MainActor needed):

1. `text` contains the app version, the build number in parentheses, and the error details.
2. `mailURL(to: "app@example.com", subject: "S")` has scheme `mailto`, path `app@example.com`, a `subject` query item `S`, and a `body` query item equal to `text`. Read it back with `URLComponents(url:resolvingAgainstBaseURL:)`.
3. `mailURL(to: "", subject: "S")` is nil.
4. `current(errorDetails:bundle:)` with `Bundle(for:)` or `.main` returns non-empty `appVersion` and `buildNumber` (they fall back to `"?"`, never empty).

`HugoTests/App/ModelContainerLoaderTests.swift` (`@MainActor struct`):

1. A factory that succeeds gives `.loaded`.
2. A factory that throws gives `.failed`, and `details` contains the error's description.
3. `retry()` after a failure, with a factory that now succeeds, gives `.loaded`. The stub was called twice.
4. `retry()` while `.loaded` does not call the factory again (the stub's call count stays 1).
5. Opening a corrupt store file (see Step 6) gives `.failed` instead of crashing. This is the case that used to hit `fatalError`.

Expected: all existing tests still pass, plus 9 new ones.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -rn "fatalError" Hugo/App` prints nothing
- [ ] `grep -n "HugoSimulateStoreLoadFailure" Hugo/App/HugoApp.swift Hugo/App/ModelContainerLoader.swift` prints at least one line from each file
- [ ] The four `launch.failure.*` keys exist with `en` and `da` values (Step 4 check prints `4`)
- [ ] `git show --stat HEAD` lists only the in-scope files
- [ ] `git diff 3055ae6..HEAD --stat -- Hugo/Persistence` prints nothing
- [ ] `plans/README.md` row for 103 updated

## STOP conditions

Stop and report back if:

- The drift check shows changes to `HugoApp.swift` or `ModelContainerFactory.swift` and the excerpts no longer match.
- The corrupt-store test crashes the test process instead of failing to open. That would mean Core Data traps rather than throws for this case, which changes the plan's premise. Report it and don't delete the test to make the run pass.
- `@State` holding the loader in the `App` struct, or the `switch` inside `WindowGroup`, doesn't compile, and one obvious fix doesn't solve it.
- Making it work seems to need a change in `Hugo/Persistence` or `AppRootView.swift`.
- You feel the need to add any code that deletes, moves or resets the store. That is explicitly out of scope.

## Maintenance notes

**Owner device check** (after the commit):

1. In Xcode, Product → Scheme → Edit Scheme → Run → Arguments → "Arguments Passed On Launch", add `-HugoSimulateStoreLoadFailure` and keep it checked. This changes the shared scheme file, so don't commit it. Uncheck or remove it afterwards, and before running `Scripts/verify.sh`: the scheme's Test action reuses the Run arguments (`shouldUseLaunchSchemeArgsEnv = "YES"`), so the test host app would launch into the failure screen.
2. Run on a device. The failure screen appears instead of a crash, with the title, the message, Retry, Contact Us and Details.
3. Tap Retry. The screen stays, because the argument makes every attempt fail. That's expected.
4. Tap Contact Us. Mail opens with the subject and a body that starts with "Hugo 1.0 (build)" followed by the simulated error.
5. Open Details, then long-press the text to check it can be selected.
6. Repeat in Danish, with VoiceOver, and at the largest accessibility text size. The screen scrolls and nothing is cut off.
7. Remove the argument and run again. The app opens as normal with all data intact.

**Why there is no reset button.** The store is synced with the private CloudKit database, so deleting the local file and launching again would download most of the data again. But changes made offline, or just before the failure, may not have been exported yet, and Hugo has no reliable way to tell. A reset would lose them silently. If support emails show a failure that keeps coming back where a reset is the only way out, plan it separately. Put it behind a confirmation that names the risk, make it available only when the iCloud account is available, and move the old store aside rather than deleting it.

**Future interactions:**

- Plan 102 adds a build number to the support email subject in Settings, and maybe a shared support-mail helper. If it adds one, a later change can switch `StoreLoadFailureView.supportMailURL` to that helper. Don't merge them in this plan.
- Every new `VersionedSchema` (see AGENTS.md section 8) is a new way for the store to fail to open. This screen catches those failures, but it does not replace the migration test in `SchemaMigrationTests`.
- A crash inside a migration stage (a trap, not a throw) still crashes the app. Migration stages must keep using `try` and never use `try!` or `fatalError`. Reviewers should check this in every schema change.
- The failure screen never inserts anything into the store and never seeds the default category. If someone moves bootstrap work out of `AppRootView`, keep it behind the `.loaded` case.
