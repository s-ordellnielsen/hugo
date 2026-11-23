# Plan 139: Accessibility regression tests for Overview and Service Year (XCUITest)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 0af2e24..HEAD -- Hugo/App/HugoApp.swift Hugo/Features/Overview Hugo/Features/ServiceYear Scripts/verify.sh Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`
> Expected: no output. If any file changed, compare it with "Current state" and STOP on a mismatch.
> Also `git status --short` must show nothing, or only untracked plan files
> and (after the owner's Step 0) the new `HugoUITests/` folder and the
> `Hugo.xcodeproj` changes Xcode made when the owner created the target.

## Status

- **Priority**: P3 (Medium)
- **Effort**: M
- **Risk**: MEDIUM. The riskiest part is adding a UI test target to the Xcode project (Step 0, done by the owner in Xcode, never by hand-editing `project.pbxproj`). The rest is one small test seam in the app and new test files. The audit will almost certainly report pre-existing violations (see "Honest expectations").
- **Depends on**: the owner creating the `HugoUITests` target (Step 0). Nothing else.
- **Category**: testing
- **Planned at**: commit `0af2e24`, 2026-11-23
- **Issue**: [SLN-214](https://linear.app/sebastianln/issue/SLN-214)

## Why this matters

Accessibility is a stated principle of this app (`AGENTS.md` section 6: users
from 13 to 70, "make good use of accessibility features"). Today it is held up
only by hand-written modifiers (`accessibilityLabel`, `accessibilityValue`,
`accessibilityElement(children:)`) that nothing checks. A refactor can silently
turn a card into plain text, drop a value, or lose the selected state, and no
test fails. The unit tests cannot see the accessibility tree; only an XCUITest
can, because it reads the tree through the same API VoiceOver uses.

This plan adds a small UI test target that launches the real app with seeded
data, asserts on the accessibility tree of the Overview and Year tabs, runs
`XCUIApplication.performAccessibilityAudit()` on both, and runs inside
`Scripts/verify.sh`. The issue text was written in August; the screens have
changed since, so the assertions below were re-derived from the code as it is
at `0af2e24`, not from the issue.

## Facts established while planning

- **No UI test target exists.** `xcodebuild -list` shows targets `Hugo` and `HugoTests` only. There is no `HugoUITests` folder.
- **The project uses synchronized folders** (`objectVersion = 77`, `PBXFileSystemSynchronizedRootGroup` for `Hugo` and `HugoTests`). Files placed in a target's folder join it automatically; only the target itself needs a project change.
- **`Scripts/verify.sh` runs one `xcodebuild test`** for the `Debug` scheme with `-parallel-testing-enabled NO` on a dedicated simulator ("Hugo Verify iOS 26.5", iPhone 17 Pro), behind a lock so only one run happens at a time. Every test bundle listed under the scheme's `TestAction` runs in that one command, serially. So a UI test bundle added to the scheme runs in the gate with no change to the test command. The script runs `swift-format lint --strict --recursive Hugo HugoTests`, which does not cover a new folder, so the script needs one edit.
- **`Debug.xcscheme` `TestAction`** lists only `HugoTests` as a testable (`BlueprintIdentifier = "E09054892E951E2C00254125"`). It sets the environment variable `HUGO_TEST_MODE=1` for the test run. UI-test apps are launched by the test runner and do not reliably inherit that variable, so the UI tests set it themselves (below).
- **There is no launch-time seeding today.** The "launch arguments for simulator screenshots" (memory note `simulator-screenshots`) only preset `@AppStorage` keys (`-publisherStatus regular-pioneer`, `-isOnboarding NO`) and rely on a real signed install. `HugoApp.makeContainer()` (`Hugo/App/HugoApp.swift` lines 23 to 30) picks an in-memory store when `HUGO_TEST_MODE=1` is in the environment, but inserts nothing. `PreviewSupport/PreviewModelContainer.swift` has preview data, but it uses `.now - 86_400`, which can fall in last month, and it is for previews. So the plan adds a small seeder.
- **Unsigned launch is safe in test mode.** With `HUGO_TEST_MODE=1`, `HugoApp` uses the in-memory container and passes `nil` for `SettingsSyncService`. `CloudKitTrackerLookup` (the code that crashes an unsigned app) is only called when `hasRunInitialSetup` is false; the tests pass `-hasRunInitialSetup YES`. Overview and Year read no CloudKit. `CloudAccountStatusReader` and `DiagnosticsCollector` (the other two `CKContainer` users) are only reached from Settings, which these tests never open. `verify.sh` builds with `CODE_SIGNING_ALLOWED=NO`, and the unit-test host already launches the app that way.
- **Estimated time added to `verify.sh`: 2 to 4 minutes** (an extra target build of roughly 20 to 40 seconds, then about 3 to 5 seconds per app launch for about 10 tests, plus 5 to 20 seconds per accessibility audit). This is an estimate; Step 7 measures it and records the number.
- **Swift Testing cannot drive `XCUIApplication`.** UI tests must be `XCTestCase`. This is the one place `AGENTS.md` section 8 ("Tests use Swift Testing") does not apply. The seeder's own unit test uses Swift Testing as usual.

## Current state (re-derived on 2026-11-23)

### What is on the Overview tab (`Hugo/Features/Overview`)

`OverviewView.swift` wraps `OverviewDayView`, a `NavigationStack` with a `ScrollView` containing, top to bottom: an optional `ReportReminderCard` (only when a month needs reporting; not seeded here), `MonthlyProgressCard`, and `OverviewListView`. A toolbar item holds `SettingsButton`.

`Views/MonthlyProgressCard.swift`:

- Lines 14 to 16: `MonthlyProgressCircle(...)` with `.accessibilityHidden(true)`. The circle is not exposed on its own.
- Lines 18 to 27: the month name and hero number are combined into one element: `.accessibilityElement(children: .combine)`, `.accessibilityLabel(Text("a11y.monthly_progress_card.label"))` (English: "Month Progress"), `.accessibilityValue(Text(verbatim: accessibilityValueText))`. The value is built at lines 86 to 112; every variant ends in "this month" (for example "5 of 50 hours this month", "1 hour 30 minutes this month").
- Lines 29 to 47: a `Button` to the plan pace sheet, shown only when plans exist (`planStatus != nil`). Not seeded here, so not asserted.
- Lines 51 to 61: `Button(action: onAddEntry) { Label("entry.add.label", systemImage: "plus") ... }` with `.labelStyle(.iconOnly)`. English label "Add Entry".

`Views/OverviewListView.swift`:

- Lines 40 to 46: when entries exist, a header `Text("entries.list.this_month.header")` and `OverviewListStyleControl(selection: $listStyle)`.
- `Views/OverviewListStyleControl.swift` lines 17 to 25: a `Picker` with `.pickerStyle(.segmented)`, two segments (`Image` with `.accessibilityLabel(Text(style.accessibilityLabel))`). English labels "Sort by Entry" and "Sort by Date". The default style is `.byDate` (`@AppStorage(UserDefaultsKeys.overviewListStyle) ... = .byDate`, line 14), so "Sort by Date" starts selected. This is the Overview's "selection exposed through `isSelected`" surface. (The August issue's "tappable cards" with selection no longer exist on Overview; the segmented control is the selection surface now.)
- Lines 194 to 230, `DateEntryRow`: each entry is a `Button` with `.accessibilityElement(children: .combine)`, label `"<time>, <category name>"` and value `EntryAccessibilityValue.text(duration:bibleStudies:)`. That function (`Hugo/Features/Entries/Domain/EntryAccessibilityValue.swift`) returns the spoken duration and, when `bibleStudies != 0`, appends ", Bible Studies: N" (string `entry.bibelstudies.count.accessibility.%lld`, English "Bible Studies: %lld"). This is how the Bible-study count is reachable on Overview.
- Lines 235 to 273, `OverviewCarriedEntriesView`: a button with hint "Shows the categories the time came from". Only for carried-in entries; not seeded here.

There is **no category breakdown on Overview** any more. The category breakdown lives on the Year tab month cards.

### What is on the Year tab (`Hugo/Features/ServiceYear`)

`Screens/ServiceYearView.swift` is a `NavigationStack` with a horizontal paging `ScrollView` of `ServiceYearPageView`s. The title toolbar item is a year picker button only when `years.count > 1` (line 107); with entries in one theocratic year only the plain title shows (line 130), so the picker is not asserted here. Navigation title is `activeYear.displayName`.

`Views/ServiceYearPageView.swift`:

- Lines 55 to 61: when the year has entries, a `NavigationLink` with `.buttonStyle(.card)` whose label is `TheocraticYearTotalsView`.
- `Views/TheocraticYearTotalsView.swift` lines 78 to 80: `.accessibilityElement(children: .ignore)`, `.accessibilityLabel(accessibilityLabelText)`, `.accessibilityHint("year.header.a11y.hint")`. The label (lines 104 to 124) starts with "Counted toward yearly goal:" (English) when the publisher status has a yearly goal, so the totals card is one button whose label carries the credited hours and the pace sentence. The goal bar (`MarkedProgressBar`) has no accessibility element of its own; its meaning is folded into this label. This card is the Year tab's "progress" surface.
- Lines 66 to 72: one `ServiceYearMonthRow` per month.

`Views/ServiceYearMonthRow.swift`:

- Lines 30 to 46: past and current months are a `NavigationLink` with `.buttonStyle(.card)` (a button). Future months are plain cards (not buttons).
- Lines 69 to 82: `card` has **no** `accessibilityElement` modifier, so the link's label is SwiftUI's automatic combination of its child texts. `MonthHeadline` (lines 41 to 42 of `MonthHeadline.swift`) is `.ignore` with a spoken label such as "2 hours".
- Lines 212 to 243, `activityBreakdown`: category rows, school credit rows, then a Bible studies row (`MonthBreakdownRow(title: Text("report.bible-studies"), systemImage: "book", value: String(count))`, English title "Bible Studies"). `MonthBreakdownRow` (`Views/MonthBreakdownRow.swift`) is an `HStack` of a title and a value `Text`; neither has its own accessibility value, so the category names, their hours and the Bible-study count are read as part of the month link's combined label.

So the Year tab exposes categories and the Bible-study count through the month card's button label, not as separate elements with `accessibilityValue`. That is how it works today, and the tests assert that (label contains the category name and the Bible-study count). Do not change app views to add separate values; that is a design decision for a separate issue.

### Tab bar

`Hugo/App/AppRootView.swift` lines 99 to 107: on a compact width, a `TabView` with `Tab(tab.titleKey, ...)` for `overview`, `planner`, `year` (settings is sidebar only). English titles "Overview", "Planner", "Year". The selected tab exposes `isSelected` on its tab bar button. This is the Year tab's selection surface.

### Launch seam today (`Hugo/App/HugoApp.swift` lines 23 to 37)

```swift
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
        let environment = ProcessInfo.processInfo.environment
        return environment["HUGO_TEST_MODE"] == "1"
            || environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
```

## Honest expectations about the audit

`performAccessibilityAudit()` checks contrast, hit-area size, text clipping, Dynamic Type support, missing element descriptions and more. This codebase has deliberate choices the audit may flag, so **expect the first run to fail** and do not read that as a mistake in the plan. Likely candidates, from the code:

- Dynamic Type: `ServiceYearView.yearTitle` and `yearTitleChevron` are capped with `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)` (lines 58 and 70), and `MonthlyProgressCard` uses `.font(.system(size: heroSize...))` with `@ScaledMetric`. The audit's Dynamic Type check can flag fixed or capped text.
- Contrast: `.secondary` and `.tertiary` text on `secondarySystemGroupedBackground`, `MarkedProgressBar` with `.hugoLightTrack`, and the faded `MonthHeadline` (`.tertiary`) for empty months.
- Hit area: small chevrons and the toolbar buttons.
- Text clipping at large sizes (the optional AX5 step).

How the executor handles findings (this is a rule, not a suggestion):

1. First run the audits with **no** filter and **record every issue** (audit type, element label or identifier, the issue's `compactDescription`) in the Step 6 log and in the plan's NOTES. Do not suppress anything before it has been recorded.
2. Do not fix app code in this plan (out of scope). Do not weaken an assertion, remove a test or pass `.all` minus a whole audit type to get green.
3. An issue may go into the explicit `KnownAuditIssues.list` (Step 5) only after it is recorded. Each entry names the audit type, the element's label, and a one-line reason that says "pre-existing, found by plan 139". Matching is by audit type plus element label, never a blanket "ignore this type".
4. The final report must list every known issue, so the owner can turn each into a follow-up issue. A new issue that is not in the list then fails the gate, which is the regression protection this plan exists for.
5. Do not ignore issues of type `.sufficientElementDescription` or `.trait` or `.parentChild` silently; if the first run produces any of those, say so prominently in the report. They mean a control with no usable name or the wrong trait, which is a real bug for VoiceOver users, not noise.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| List targets | `xcodebuild -list -project Hugo.xcodeproj` | Lists `HugoUITests` under Targets after Step 0 |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests HugoUITests` | exit 0, no output |
| Run only the UI tests | the `xcodebuild test ... -only-testing:HugoUITests` command in Step 6 | `** TEST SUCCEEDED **` |
| Whole gate | `Scripts/verify.sh` | exit 0 (layout, lint, all tests including UI tests, analyze) |

Always run `xcodebuild` and `verify.sh` in a Rex pane per the owner's global instructions, with output going to a log file under the scratchpad directory, and use the lock in `verify.sh` (it serializes runs). Never use the simulator "Hugo Verify iOS 26.5" for anything except through `Scripts/verify.sh`. For the faster "UI tests only" runs in Step 4, create a throwaway simulator (`xcrun simctl create "Hugo UITest Scratch" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-5`), and delete it when done (`xcrun simctl delete <id>`).

## Scope

**In scope** (the only files you may modify or create):

- `Hugo/App/HugoApp.swift` (seed hook in `makeContainer`)
- `Hugo/App/UITestSeed.swift` (new)
- `HugoTests/App/UITestSeedTests.swift` (new)
- `HugoUITests/` (new folder, created by the owner in Step 0; you add files inside it): `LaunchedApp.swift`, `KnownAuditIssues.swift`, `OverviewAccessibilityTests.swift`, `YearAccessibilityTests.swift`
- `Scripts/verify.sh` (lint path, scheme check)
- `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` (only to add the `HugoUITests` testable if the owner did not, Step 1)
- `plans/README.md` (status row)

**Out of scope** (do NOT touch):

- `Hugo.xcodeproj/project.pbxproj`. Never edit it by hand. The target comes from Xcode (Step 0).
- Any view under `Hugo/Features` or `Hugo/DesignSystem`. If the audit or a locator shows an accessibility bug, record it; do not fix it here.
- `Hugo/Features/Settings/**` and anything that reads CloudKit.
- `Production.xcscheme`, `TestFlight.xcscheme`, `MarkdownUI.xcscheme`, the `Configuration/*.xcconfig` files.
- `CONTEXT.md`: no new domain term is introduced. (Seed data and test names are not domain concepts.)

## Git workflow

- Commit straight to `main`. No branch, no worktree.
- Commit 1 (after Step 3, gate green): `test: add a seed for UI tests behind HUGO_TEST_MODE`.
- Commit 2 (after Step 8, gate green): `test: add accessibility tests for Overview and Year`. It includes the owner's `HugoUITests` target files and `Hugo.xcodeproj` changes only if the owner has not committed them yet; check `git status --short` first and stage by explicit path.
- Stage by explicit path only. Never `git add -A` or `git add .`. Never stage `.claude/`. Do not push.

## Steps

### Step 0: The owner creates the UI test target in Xcode (RISKIEST STEP, NOT AN EXECUTOR STEP)

Hand-editing `project.pbxproj` for a new target (a `PBXNativeTarget` of type `com.apple.product-type.bundle.ui-testing`, its `PBXFileSystemSynchronizedRootGroup`, three build phases, a `PBXContainerItemProxy` and `PBXTargetDependency`, product reference, three build configurations and `TargetAttributes`) is fragile, and a mistake can corrupt the project. The owner does this once in Xcode:

1. File > New > Target > iOS > **UI Testing Bundle**. Product Name `HugoUITests`, Language Swift, Project Hugo, **Target to be Tested: Hugo**. Finish. Xcode creates a `HugoUITests` folder with two template files; delete both template files (`HugoUITests.swift`, `HugoUITestsLaunchTests.swift`) and leave the folder empty (the executor adds the files).
2. Select the `HugoUITests` target > Build Settings, and set for **all three configurations** to match `HugoTests`: iOS Deployment Target `26.0`, Swift Language Version `6`, Strict Concurrency Checking `Complete`, Approachable Concurrency `Yes`, Default Actor Isolation `MainActor`, Development Team the same as `HugoTests` (`CAJA48GKTR`), Targeted Device Family `iPhone, iPad`.
3. Product > Scheme > Edit Scheme (scheme **Debug**) > Test: confirm `HugoUITests` is listed next to `HugoTests`; if it is not, press `+` and add it.
4. Commit nothing yet, or commit as `build: add the HugoUITests target`. Either is fine; the executor handles both.

**Verify (the executor runs this first)**:
- `xcodebuild -list -project Hugo.xcodeproj` lists `HugoUITests` under Targets.
- `ls HugoUITests` succeeds (an empty folder is fine).
- `grep -c "HugoUITests" Hugo.xcodeproj/project.pbxproj` prints a number greater than 5.

**STOP** if `HugoUITests` is not listed. Report "the owner has not created the UI test target (plan 139 Step 0)". Do not create it by editing the project file, and do not run `xcodegen`, `tuist` or similar. If the target exists but a build setting above is wrong, do not edit the project file; report which setting.

### Step 1: Make sure the Debug scheme runs the UI tests

Run:
`grep -n "HugoUITests" Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`

- If it prints a `BlueprintName = "HugoUITests"` line inside the `<Testables>` block: nothing to do.
- If it prints nothing: in `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`, inside `<Testables>` (it currently ends with the `HugoTests` `</TestableReference>` at about line 44), add a second block after it. Take `BlueprintIdentifier` from `grep -n "HugoUITests" Hugo.xcodeproj/project.pbxproj | grep "isa = PBXNativeTarget\|/\* HugoUITests \*/ = {"`: it is the 24-character hex id in front of the `PBXNativeTarget` entry named `HugoUITests`. This is an XML-only edit and is safe.

```xml
         <TestableReference
            skipped = "NO"
            parallelizable = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "<the id>"
               BuildableName = "HugoUITests.xctest"
               BlueprintName = "HugoUITests"
               ReferencedContainer = "container:Hugo.xcodeproj">
            </BuildableReference>
         </TestableReference>
```

**Verify**: `xcodebuild -list -project Hugo.xcodeproj | grep -A8 Schemes` still lists `Debug` (a malformed scheme would drop it); and `grep -c "HugoUITests" Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` prints at least `2`.

### Step 2: Add the UI test seed to the app

**2a. Create `Hugo/App/UITestSeed.swift`** (in `App`, which is "composition only, no reusable UI"; this is launch composition). Exact content:

```swift
import Foundation
import SwiftData

/// Data for the UI tests. It is inserted only when the app is running in test
/// mode (`HUGO_TEST_MODE=1`, which also selects the in-memory store) and was
/// launched with `-HugoUITestSeed`. A normal launch never sees it.
///
/// Entries are placed on today, a few hours after midnight, so they fall in the
/// current month and the current theocratic year whatever day the tests run.
@MainActor
enum UITestSeed {
    static let launchArgument = "-HugoUITestSeed"

    /// The name of the Field Service category in the seed. The tests look for it.
    static let fieldServiceName = "Field Service"
    /// The name of the Credit category in the seed.
    static let creditName = "Bethel"
    /// Total Bible studies across the seeded entries.
    static let totalBibleStudies = 2

    static func isRequested(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["HUGO_TEST_MODE"] == "1" && arguments.contains(launchArgument)
    }

    static func insert(into context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws {
        let field = Tracker(name: fieldServiceName, type: .main, isDefault: true, iconName: "figure.walk")
        let credit = Tracker(name: creditName, type: .separate, iconName: "building.2")
        context.insert(field)
        context.insert(credit)

        let midnight = calendar.startOfDay(for: now)
        let hour: TimeInterval = 3_600
        context.insert(Entry(date: midnight.addingTimeInterval(1 * hour), duration: 5_400, tracker: field, bibleStudies: 2))
        context.insert(Entry(date: midnight.addingTimeInterval(2 * hour), duration: 3_600, tracker: field))
        context.insert(Entry(date: midnight.addingTimeInterval(3 * hour), duration: 1_800, tracker: credit))
        try context.save()
    }
}
```

If a line exceeds 120 characters, wrap it the way `swift-format` wants (run `xcrun swift-format format -i Hugo/App/UITestSeed.swift`). If `Tracker(name:type:isDefault:iconName:)` does not compile (the initializer is at `Hugo/Persistence/SchemaVersions/V14/TrackerV14.swift` line 34, parameters `id, name, type, allowBibleStudies, isDefault, iconName`), STOP and report.

**2b. Edit `Hugo/App/HugoApp.swift`**: replace the `return try isRunningTests ? ... : ...` expression (lines 27 to 29) so the in-memory branch can seed. Result:

```swift
    private static func makeContainer() throws -> ModelContainer {
        if ProcessInfo.processInfo.arguments.contains("-HugoSimulateStoreLoadFailure") {
            throw SimulatedStoreLoadFailure()
        }
        guard isRunningTests else { return try ModelContainerFactory.makeProductionContainer() }
        let container = try ModelContainerFactory.makeInMemoryContainer()
        if UITestSeed.isRequested() {
            try UITestSeed.insert(into: container.mainContext)
        }
        return container
    }
```

Change nothing else in the file.

**Verify**:
- `xcrun swift-format lint --strict Hugo/App/HugoApp.swift Hugo/App/UITestSeed.swift` exits 0.
- `Scripts/check-layout.sh` exits 0.
- `git diff --stat` shows only `HugoApp.swift` modified and `UITestSeed.swift` added.

### Step 3: Unit test the seed, run the gate, commit

Create `HugoTests/App/UITestSeedTests.swift` (mirrors `Hugo/App/`), Swift Testing, with fixed `now` and `calendar`:

```swift
import Foundation
import SwiftData
import Testing

@testable import Hugo

@MainActor
struct UITestSeedTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    @Test
    func insertsThreeEntriesOnTheGivenDayWithTwoBibleStudies() throws {
        let context = ModelContext(try InMemoryModelContainer.make())
        let now = Date(timeIntervalSince1970: 1_795_000_000)  // 2026-11-17, midday UTC

        try UITestSeed.insert(into: context, now: now, calendar: calendar)

        let entries = try context.fetch(FetchDescriptor<Entry>())
        #expect(entries.count == 3)
        #expect(entries.map(\.bibleStudies).reduce(0, +) == UITestSeed.totalBibleStudies)
        #expect(entries.allSatisfy { calendar.isDate($0.date, inSameDayAs: now) })
        let names = Set(try context.fetch(FetchDescriptor<Tracker>()).map(\.name))
        #expect(names == [UITestSeed.fieldServiceName, UITestSeed.creditName])
    }

    @Test
    func isRequestedOnlyInTestModeWithTheArgument() {
        let argument = [UITestSeed.launchArgument]
        #expect(UITestSeed.isRequested(arguments: argument, environment: ["HUGO_TEST_MODE": "1"]))
        #expect(!UITestSeed.isRequested(arguments: argument, environment: [:]))
        #expect(!UITestSeed.isRequested(arguments: [], environment: ["HUGO_TEST_MODE": "1"]))
    }
}
```

Check the epoch value: `1_795_000_000` must land in the middle of a UTC day; if the first test fails only on the same-day assertion, compute a safer value with `Date(timeIntervalSince1970: 1_795_000_000 - 1_795_000_000 % 86_400 + 43_200)` instead. Do not otherwise change the test.

Then run `Scripts/verify.sh` (this is the first full run; if the owner already added the UI test bundle to the scheme, it will run an empty bundle or report no tests for it, which is acceptable; if `xcodebuild` fails because the empty `HugoUITests` bundle has no sources, STOP and report, do not work around it. As a fallback you may continue to Step 4 and run the gate at the end of Step 6 instead, and say so).

Commit with the message from "Git workflow" (commit 1), staging `Hugo/App/HugoApp.swift`, `Hugo/App/UITestSeed.swift`, `HugoTests/App/UITestSeedTests.swift` by path.

**Verify**: `Scripts/verify.sh` exits 0, log has `** TEST SUCCEEDED **` and `** ANALYZE SUCCEEDED **`. `git show --stat HEAD` lists exactly those three files.

### Step 4: Add the UI test helpers and a tree dump to calibrate locators

Create `HugoUITests/LaunchedApp.swift`:

```swift
import XCTest

/// Launches Hugo with seeded data in a fixed language, as the accessibility tests need it.
enum LaunchedApp {
    @MainActor
    static func launch(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["HUGO_TEST_MODE"] = "1"
        app.launchArguments = [
            "-HugoUITestSeed",
            "-isOnboarding", "NO",
            "-hasRunInitialSetup", "YES",
            "-publisherStatus", "regular-pioneer",
            "-overviewListStyle", "byDate",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ] + extraArguments
        app.launch()
        return app
    }
}

extension XCUIElementQuery {
    /// The elements whose accessibility label contains `text`.
    func labelContaining(_ text: String) -> XCUIElementQuery {
        matching(NSPredicate(format: "label CONTAINS %@", text))
    }
}
```

(`-overviewListStyle byDate` must match the raw value of `OverviewListStyle.byDate` in `Hugo/Features/Overview/Domain/OverviewListStyle.swift`; open that file and use the real raw value. If the enum is not `String` raw, drop that line, because the default is already `.byDate`.)

Create a **temporary** `HugoUITests/TreeDumpTests.swift`:

```swift
import XCTest

final class TreeDumpTests: XCTestCase {
    @MainActor
    func testDumpTrees() {
        let app = LaunchedApp.launch()
        print("TREE-OVERVIEW\n\(app.debugDescription)")
        app.tabBars.buttons["Year"].tap()
        print("TREE-YEAR\n\(app.debugDescription)")
    }
}
```

Run it on a throwaway simulator, output to a log:

`xcodebuild test -project Hugo.xcodeproj -scheme Debug -configuration Debug -destination "id=<scratch simulator id>" -derivedDataPath /tmp/HugoUITestDerivedData -only-testing:HugoUITests/TreeDumpTests -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO > <scratchpad>/uitest-dump.log 2>&1`

Read the two `TREE-` sections in the log. Confirm each of these exists, and note the real label text:

Overview: an element labeled `Month Progress` with a value ending in `this month`; a button `Add Entry`; a segmented control with `Sort by Entry` and `Sort by Date`; buttons whose label contains `Field Service`.
Year: tab bar buttons `Overview` and `Year`; a button whose label begins `Counted toward yearly goal`; a button (the current month) whose label contains `Field Service` and `Bible Studies`.

If a label differs only in wording or punctuation, adjust the `NSPredicate` text in Steps 5 and 6 to match what the tree shows, keeping what is being asserted (trait, selection, value, reachability) unchanged. If an element is **missing from the tree altogether** or has the wrong trait, that is a real finding: keep the assertion and wrap it per Step 6 rule "known gaps", do not delete it.

Delete `TreeDumpTests.swift` before moving on.

**Verify**: the dump test passes (`** TEST SUCCEEDED **`) and the log contains `TREE-OVERVIEW` and `TREE-YEAR`. The app did not crash at launch (if it did, STOP; see STOP conditions).

### Step 5: Add the audit helper with the explicit known-issue list

Create `HugoUITests/KnownAuditIssues.swift`:

```swift
import XCTest

/// Accessibility audit issues that already existed when plan 139 added the
/// audits. Each entry was recorded in the plan's notes and has a reason. The
/// audits ignore an issue only when both its type and its element label match
/// an entry; anything else fails the test. Remove an entry when its issue is
/// fixed, and never add one without a reason.
struct KnownAuditIssue {
    let auditType: XCUIAccessibilityAuditType
    /// The element's accessibility label, or `nil` when the element has none.
    let elementLabel: String?
    let reason: String
}

enum KnownAuditIssues {
    static let list: [KnownAuditIssue] = [
        // Filled in at Step 6 from the first unfiltered run. Empty on purpose until then.
    ]

    static func contains(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        list.contains { known in
            known.auditType == issue.auditType && known.elementLabel == issue.element?.label
        }
    }
}

extension XCUIApplication {
    /// Runs the full accessibility audit and fails on every issue not in `KnownAuditIssues`.
    @MainActor
    func auditAccessibility(for types: XCUIAccessibilityAuditType = .all) throws {
        try performAccessibilityAudit(for: types) { issue in
            // Always print what was found, so a new failure is easy to read in the log.
            print(
                "AUDIT type=\(issue.auditType.rawValue) label=\(issue.element?.label ?? "<none>") "
                    + "desc=\(issue.compactDescription)")
            return KnownAuditIssues.contains(issue)
        }
    }
}
```

If `XCUIAccessibilityAuditType` is not `Equatable`/`rawValue`-printable in the installed SDK (Xcode 27.2), fix the compile error minimally (it is an `OptionSet`, so `==` and `rawValue` exist); do not change what is matched.

**Verify**: it compiles: `xcodebuild build-for-testing -project Hugo.xcodeproj -scheme Debug -configuration Debug -destination "id=<scratch simulator id>" -derivedDataPath /tmp/HugoUITestDerivedData CODE_SIGNING_ALLOWED=NO` ends with `** TEST BUILD SUCCEEDED **`.

### Step 6: Write the tests

Create `HugoUITests/OverviewAccessibilityTests.swift`:

```swift
import XCTest

final class OverviewAccessibilityTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testProgressCardExposesLabelAndValue() {
        let app = LaunchedApp.launch()
        let card = app.descendants(matching: .any).matching(identifier: "Month Progress").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "The monthly progress card is not in the accessibility tree")
        let value = card.value as? String ?? ""
        XCTAssertTrue(value.contains("this month"), "Progress card value was: \(value)")
    }

    @MainActor
    func testAddEntryIsAButton() {
        let app = LaunchedApp.launch()
        XCTAssertTrue(app.buttons["Add Entry"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Add Entry"].isHittable)
    }

    @MainActor
    func testEntryRowIsAButtonWithBibleStudiesInItsValue() {
        let app = LaunchedApp.launch()
        let rows = app.buttons.labelContaining("Field Service")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "No entry row is exposed as a button")
        let values = (0..<rows.count).map { rows.element(boundBy: $0).value as? String ?? "" }
        XCTAssertTrue(
            values.contains { $0.contains("Bible Studies: 2") },
            "No entry row exposes the Bible study count. Values: \(values)")
    }

    @MainActor
    func testListStyleSelectionIsExposedAsSelected() {
        let app = LaunchedApp.launch()
        let byDate = app.segmentedControls.buttons["Sort by Date"]
        let byEntry = app.segmentedControls.buttons["Sort by Entry"]
        XCTAssertTrue(byDate.waitForExistence(timeout: 10))
        XCTAssertTrue(byDate.isSelected)
        XCTAssertFalse(byEntry.isSelected)
        byEntry.tap()
        XCTAssertTrue(byEntry.isSelected)
        XCTAssertFalse(byDate.isSelected)
    }

    @MainActor
    func testOverviewPassesAccessibilityAudit() throws {
        let app = LaunchedApp.launch()
        XCTAssertTrue(app.buttons["Add Entry"].waitForExistence(timeout: 10))
        try app.auditAccessibility()
    }
}
```

Create `HugoUITests/YearAccessibilityTests.swift`:

```swift
import XCTest

final class YearAccessibilityTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launchOnYearTab() -> XCUIApplication {
        let app = LaunchedApp.launch()
        let yearTab = app.tabBars.buttons["Year"]
        XCTAssertTrue(yearTab.waitForExistence(timeout: 10))
        yearTab.tap()
        return app
    }

    @MainActor
    func testTabSelectionIsExposedAsSelected() {
        let app = LaunchedApp.launch()
        let overview = app.tabBars.buttons["Overview"]
        let year = app.tabBars.buttons["Year"]
        XCTAssertTrue(overview.waitForExistence(timeout: 10))
        XCTAssertTrue(overview.isSelected)
        XCTAssertFalse(year.isSelected)
        year.tap()
        XCTAssertTrue(year.isSelected)
        XCTAssertFalse(overview.isSelected)
    }

    @MainActor
    func testYearTotalsCardIsAButtonWithProgressInItsLabel() {
        let app = launchOnYearTab()
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Counted toward yearly goal")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "The year totals card is not exposed as a button")
    }

    @MainActor
    func testMonthCardIsAButtonWithCategoriesAndBibleStudiesInItsLabel() {
        let app = launchOnYearTab()
        let card = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Field Service", "Bible Studies")
        ).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No month card exposes a category and Bible Studies as one button")
        XCTAssertTrue(
            card.label.range(of: "Bible Studies.*2", options: .regularExpression) != nil,
            "The Bible study count is missing from the month card label: \(card.label)")
    }

    @MainActor
    func testYearPassesAccessibilityAudit() throws {
        let app = launchOnYearTab()
        XCTAssertTrue(app.buttons.labelContaining("Counted toward yearly goal").firstMatch.waitForExistence(timeout: 10))
        try app.auditAccessibility()
    }
}
```

Rules for this step:

- Locators and label wording may be adjusted to match the Step 4 tree dump. Assertions about trait (found in `buttons`), selection (`isSelected`), value or label content, and reachability must stay.
- **Known gaps**: if an assertion fails because the app really lacks the behavior (for example the segmented control does not report `isSelected`, or the Bible study count is not in the label), do not delete the assertion and do not edit the app. Wrap that single assertion's test body in `XCTExpectFailure("Plan 139: <one line saying what is missing>")` so the suite stays green, and list it in the report. A later fix then makes the test report an unexpected pass, which tells the owner to remove the wrapper.
- **Audits**: run the two audit tests first with `KnownAuditIssues.list` empty. They will print `AUDIT type=... label=... desc=...` lines; collect all of them from the log. Write every one into `KnownAuditIssues.list` (type, label, reason `"pre-existing, found by plan 139"`) and copy the same table into the NOTES at the bottom of the final report. Then re-run; the audit tests must pass. Follow "Honest expectations" rules 2 to 5.
- If the audit itself throws or times out before reporting (not an issue list), run once more; if it still does, STOP.

Run only the UI tests during this step with:
`xcodebuild test -project Hugo.xcodeproj -scheme Debug -configuration Debug -destination "id=<scratch simulator id>" -derivedDataPath /tmp/HugoUITestDerivedData -only-testing:HugoUITests -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO > <scratchpad>/uitest.log 2>&1`

**Verify**: `** TEST SUCCEEDED **` in the log; `grep -c "Test Case .* passed" <scratchpad>/uitest.log` prints at least `9`; `grep "AUDIT type" <scratchpad>/uitest.log | wc -l` equals the number of entries in `KnownAuditIssues.list` (every printed issue is known and none is new).

### Step 7: Optional, Dynamic Type at the largest accessibility size

Do this only if Step 6 is green. Add to each test class one test that launches with the largest accessibility text size and audits only the layout checks:

```swift
    @MainActor
    func testPassesLayoutAuditAtLargestTextSize() throws {
        let app = LaunchedApp.launch(extraArguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        XCTAssertTrue(app.buttons["Add Entry"].waitForExistence(timeout: 10))
        try app.auditAccessibility(for: [.textClipped, .hitRegion, .dynamicType])
    }
```

(For the Year class, launch on the Year tab first, as `launchOnYearTab()` does, but pass the extra argument; add an optional `extraArguments` parameter to `launchOnYearTab`.) Handle findings with the same record-then-list rule. If the argument does not change the text size (the tree dump shows normal sizes), STOP this step and report it as not done; do not use `simctl ui` here, because it changes a shared simulator.

If Step 7 takes the run past the budget below, or produces more than five new known issues, drop Step 7 entirely (delete the two tests) and say so in the report.

**Verify**: same as Step 6.

### Step 8: Wire into `verify.sh`, run the gate, measure, commit

Edit `Scripts/verify.sh`:

1. Change the lint line to cover the new folder:
   `xcrun swift-format lint --strict --recursive Hugo HugoTests` to `xcrun swift-format lint --strict --recursive Hugo HugoTests HugoUITests`.
2. Directly before `Scripts/check-layout.sh`, add a guard so the UI tests cannot be dropped from the gate without notice:

```sh
grep -q 'BlueprintName = "HugoUITests"' Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme || {
    echo "verify: the Debug scheme does not run HugoUITests (see plan 139)" >&2
    exit 1
}
```

3. Update the header comment (lines 1 to 9) with one sentence: "The UI tests in HugoUITests run in the same `xcodebuild test` as the unit tests, because the Debug scheme lists both."

Do not change the `xcodebuild test` or `xcodebuild analyze` commands: the scheme already runs both bundles, serially, on the same lock-protected simulator.

Run `Scripts/verify.sh` with output to `<scratchpad>/verify-139.log` and note wall-clock time (`time`). For a baseline, take it from the log of the Step 3 run (record its duration the same way) or from an earlier run if you have it. Report both numbers.

Then update the plan README row and commit (commit 2) staging by explicit path: `HugoUITests/` files (`git add HugoUITests/LaunchedApp.swift ...` one by one), `Scripts/verify.sh`, `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` if changed, and `Hugo.xcodeproj/project.pbxproj` only if it still shows as modified from the owner's Step 0 and the owner has not committed it.

**Verify**: exit code 0; log contains `** TEST SUCCEEDED **` and `** ANALYZE SUCCEEDED **`; `grep -c "HugoUITests" <scratchpad>/verify-139.log` is greater than 0 (the UI bundle ran inside the gate); `Scripts/check-layout.sh` exits 0.

## Test plan

New tests, all in `HugoUITests` (XCTest, the only framework that can drive `XCUIApplication`):

| Test | Asserts |
|---|---|
| `OverviewAccessibilityTests.testProgressCardExposesLabelAndValue` | Progress card element "Month Progress" exists, value contains "this month" |
| `...testAddEntryIsAButton` | "Add Entry" is in `buttons` and hittable |
| `...testEntryRowIsAButtonWithBibleStudiesInItsValue` | entry rows are buttons; one value contains "Bible Studies: 2" |
| `...testListStyleSelectionIsExposedAsSelected` | `isSelected` true for "Sort by Date", flips on tap |
| `...testOverviewPassesAccessibilityAudit` | `performAccessibilityAudit` with only recorded known issues |
| `YearAccessibilityTests.testTabSelectionIsExposedAsSelected` | `isSelected` on the Overview and Year tab buttons, flips on tap |
| `...testYearTotalsCardIsAButtonWithProgressInItsLabel` | totals card is a button whose label starts "Counted toward yearly goal" |
| `...testMonthCardIsAButtonWithCategoriesAndBibleStudiesInItsLabel` | month card is a button with the category name and "Bible Studies ... 2" |
| `...testYearPassesAccessibilityAudit` | audit with only recorded known issues |
| Optional (Step 7) two layout audits at the largest text size | no clipped text or small hit areas beyond recorded issues |

Plus `HugoTests/App/UITestSeedTests.swift` (Swift Testing) for the seed and its launch gate. Not covered on purpose: the year picker (needs entries in two theocratic years), the plan pace button and report reminder card (need plans and an unreported past month), the carried-in button, VoiceOver gestures themselves (XCUITest reads the tree; it cannot drive VoiceOver), and the progress circle's drawing (it is hidden from accessibility by design; its value is carried by the "Month Progress" element).

## Done criteria

- [ ] `xcodebuild -list -project Hugo.xcodeproj` lists `HugoUITests`; the Debug scheme runs it.
- [ ] `Scripts/verify.sh` exits 0 and its log shows the UI tests ran.
- [ ] `grep -c 'BlueprintName = "HugoUITests"' Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` prints at least `1`, and `verify.sh` fails with a clear message if it does not.
- [ ] Every audit issue found is in `KnownAuditIssues.list` with a reason and appears in the final report; nothing is suppressed by type alone.
- [ ] No file under `Hugo/Features` or `Hugo/DesignSystem` changed; `project.pbxproj` has only the owner's Xcode-made changes.
- [ ] `plans/README.md` status row updated (unless the reviewer maintains it).

## STOP conditions

Stop and report back (do not improvise) if:

- Step 0 is not done (no `HugoUITests` target). Never create the target by editing `project.pbxproj` or with a generator.
- The code at "Current state" does not match, for example `HugoApp.makeContainer` or `MonthlyProgressCard` differ.
- The app crashes or shows the store-failure screen at launch under the UI test (check `app.debugDescription`; most likely the in-memory store or a CloudKit call). Do not add CloudKit workarounds; report the log.
- `performAccessibilityAudit` is unavailable or crashes the runner on this Xcode (27.2) and simulator (iOS 26.5).
- The first unfiltered audit run reports more than 15 distinct issues in total (that is a design discussion with the owner, not a list to paste in).
- Any issue of type `.sufficientElementDescription`, `.trait` or `.parentChild` appears on a control: finish the work, but flag it at the top of the report.
- `Scripts/verify.sh` takes more than 8 minutes longer than the baseline, or the UI tests are flaky (a test passes then fails with no code change in two runs). Report the timings and which tests.
- A step's verification fails twice.
- The change appears to need any file outside the scope list.

## Maintenance notes

- Every new screen with a custom `accessibilityElement`, `accessibilityValue` or selection state should get a line in these tests, using `LaunchedApp.launch()` and the seed.
- The seed is deliberately tiny (two categories, three entries on one day). Do not grow it into a fixture library; add data only when a test needs it. If a test needs plans, an unreported past month or two theocratic years, extend `UITestSeed` and its unit test together.
- When an audit issue is fixed in the app, delete its `KnownAuditIssues` entry in the same commit. When a `XCTExpectFailure` starts reporting an unexpected pass, remove the wrapper.
- The tests read English strings ("Add Entry", "Sort by Date"). They pin the language with `-AppleLanguages (en)`. If a string is reworded in `Localizable.xcstrings`, update the test text; do not loosen it to a regex that would also match a missing label.
- `HUGO_TEST_MODE=1` plus `-HugoUITestSeed` is the only way the seed runs. It does not ship as a feature flag; a production launch has neither.
- A reviewer should run the UI tests once on a physical device or the shared simulators with VoiceOver on and walk both screens by ear, because XCUITest checks the tree, not what a person hears.
- Notes the executor must append (in the final report, not a new file): the measured gate duration before and after, the full list of known audit issues, and each `XCTExpectFailure` gap.
