# Plan 083: Group the goal settings at the top of Settings and give yearly goal pacing its own page

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 1432319..HEAD -- Hugo/Features/Settings Hugo/Features/ServiceYear/Domain/YearlyGoalPacing.swift Hugo/Features/Planner/Domain/PlannerTarget.swift Hugo/DesignSystem/Components HugoTests/Features/Planner/Domain/PlannerTargetTests.swift HugoTests/Features/ServiceYear/Domain`
> Expected: no output. `Hugo/Resources/Localizable.xcstrings` will have
> changed if plans 080 to 082 ran first; that is fine, because this plan only
> adds and removes the keys named in Step 6. If any other listed file changed,
> compare the "Current state" excerpts with the live code; on a mismatch,
> treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW (UI and settings layout; no schema change; stored settings keep their keys and values)
- **Depends on**: none. Plan 084 builds on the row component added here.
- **Category**: direction
- **Planned at**: commit `1432319`, 2026-11-05
- **Issue**: [SLN-292](https://linear.app/sebastianln/issue/SLN-292)

## Why this matters

The owner wants Settings to explain itself better, without overdoing it. The Settings root today is one flat list. Publisher status sits alone at the top, while the two other goal settings are hidden elsewhere: the monthly target as a "Planner" row, and the yearly goal pacing as a plain picker inside General. Categories opens a page that holds a single link to the real category list.

After this plan, the first section holds everything about the user's goal: publisher status, monthly target and (for statuses with a yearly goal) pacing. Each row shows its current value under its title. Pacing gets its own page. Each option has a one-line explanation and the expected time it gives today ("152 hours"), so a user can see what the choice does before making it. Categories opens the category list directly. General keeps only the duration step.

This plan also adds a small, generic selectable row that plan 084 reuses for the monthly target page.

## Current state

### Files

- `Hugo/Features/Settings/Screens/SettingsView.swift` is the Settings root, presented as a sheet by `SettingsButton`.
- `Hugo/Features/Settings/Screens/GeneralSettingsView.swift` holds the duration step picker and the pacing picker.
- `Hugo/Features/Settings/Screens/CategorySettingsView.swift` is a page with one link to `CategoryListView`. Nothing else uses it (checked with `grep -rn CategorySettingsView Hugo HugoTests` at `1432319`: only `SettingsView.swift:59` and the file itself).
- `Hugo/Features/ServiceYear/Domain/YearlyGoalPacing.swift` is the pacing enum and its option labels.
- `Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift` computes `expectedSeconds` for a pacing.
- `Hugo/Features/Planner/Domain/PlannerTarget.swift` holds the monthly target math and `PlannerTargetBase` (with its `label`).
- `Hugo/DesignSystem/Components/Checkmark.swift` is the existing animated checkmark.

### Excerpts

`SettingsView.swift:35-68` (the two sections this plan rebuilds):

```swift
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: PublisherStatusSelectionView()) {
                        Label {
                            Text("account.group.main.item.publisher.status")
                            Text(
                                PublisherStatus.status(for: publisherStatus)?
                                    .nameKey
                                    ?? "account.group.main.item.publisher.status.empty"
                            )
                        } icon: {
                            Image(
                                systemName: publisherStatus != ""
                                    ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                        }
                    }
                }

                Section {
                    NavigationLink(destination: ReportSettingsView()) {
                        Label("settings.group.settings.report", systemImage: "doc.text")
                    }
                    NavigationLink(destination: CategorySettingsView()) {
                        Label("settings.group.settings.category", systemImage: "square.grid.2x2")
                    }
                    NavigationLink(destination: GeneralSettingsView()) {
                        Label("settings.group.settings.general", systemImage: "gearshape")
                    }
                    NavigationLink(destination: PlannerTargetSettingsView()) {
                        Label("tab.planner", systemImage: "calendar")
                    }
                }
```

Lines 70-98 hold the TestFlight, support email and Debug sections. They stay exactly as they are.

`GeneralSettingsView.swift:10-45`:

```swift
struct GeneralSettingsView: View {
    @AppStorage(UserDefaultsKeys.durationMinuteInterval) private var durationMinuteInterval = 1
    @AppStorage(UserDefaultsKeys.yearlyGoalPacing) private var pacing: YearlyGoalPacing = .proRated
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""

    var body: some View {
        List {
            Section {
                Picker(selection: $durationMinuteInterval) {
                    ...
                }
                .pickerStyle(.navigationLink)
            }

            if PublisherStatus.status(for: statusID)?.yearlyGoalRule != nil {
                Section {
                    Picker(selection: $pacing) {
                        ForEach(YearlyGoalPacing.allCases, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    } label: {
                        Label("settings.yearlyGoal.pacing", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .pickerStyle(.navigationLink)
                } footer: {
                    Text("settings.yearlyGoal.pacing.footer")
                }
            }
        }
        .navigationTitle("settings.group.settings.general")
    }
}
```

`CategorySettingsView.swift:10-19`:

```swift
struct CategorySettingsView: View {
    var body: some View {
        List {
            NavigationLink(destination: CategoryListView()) {
                Label("settings.screens.categories.items.list", systemImage: "list.bullet")
            }
        }
        .navigationTitle("settings.group.settings.category")
    }
}
```

`CategoryListView` (`Hugo/Features/Categories/Screens/CategoryListView.swift:40`) sets its own title, `.navigationTitle("screen.category-list.title")`, and its own add button, so it works as a pushed page directly.

`YearlyGoalPacing.swift` (whole file):

```swift
import Foundation

/// How much of the current month counts as "expected so far" on the yearly goal bar.
nonisolated enum YearlyGoalPacing: String, CaseIterable, Sendable {
    case proRated
    case completedMonths
    case includeCurrentMonth
}

extension YearlyGoalPacing {
    var label: LocalizedStringResource {
        switch self {
        case .proRated: "settings.yearlyGoal.pacing.proRated"
        case .completedMonths: "settings.yearlyGoal.pacing.completedMonths"
        case .includeCurrentMonth: "settings.yearlyGoal.pacing.includeCurrentMonth"
        }
    }
}
```

`YearlyGoalProgress.swift:42-48` is the factory signature. Its `expectedSeconds` depends only on the months of the report, the pacing and `now`, never on logged time (lines 60-81). It is nil when the year has not started, and `make` returns nil when the status has no `yearlyGoalRule`:

```swift
    static func make(
        report: TheocraticYearReport,
        status: PublisherStatus,
        pacing: YearlyGoalPacing,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> YearlyGoalProgress? {
```

`TheocraticYearReportBuilder.report(for:entries:submissions:trackers:now:calendar:locale:)` (`Hugo/Features/ServiceYear/Domain/TheocraticYearReportBuilder.swift:4-12`) builds a report. With `entries: []` it still holds all twelve months, which is all `expectedSeconds` needs.

`PlannerTarget.swift:3-19` (the base enum and labels; the rest of the file is the target math, unchanged here):

```swift
nonisolated enum PlannerTargetBase: String, CaseIterable, Sendable {
    case monthlyGoal
    case yearlyGoalShare
}

extension PlannerTargetBase {
    var label: LocalizedStringResource {
        switch self {
        case .monthlyGoal: "planner.target.base.monthlyGoal"
        case .yearlyGoalShare: "planner.target.base.yearlyGoalShare"
        }
    }
}
```

`PublisherStatus` (`Hugo/Features/PublisherStatus/Domain/PublisherStatus.swift`): `monthlyGoal` is 50 for "regular-pioneer" (600 a year), 30 for "auxiliary-pioneer" and 0 for "publisher". Only "regular-pioneer" has a `yearlyGoalRule`.

`Checkmark.swift:10-23`:

```swift
struct Checkmark: View {
    let checked: Bool

    var body: some View {
        Image(systemName: "checkmark")
            .imageScale(.medium)
            .foregroundStyle(checked ? .hugoAccent : .clear)
            .fontWeight(.semibold)
            .opacity(checked ? 1 : 0)
            .scaleEffect(checked ? 1 : 0.8)
            .accessibilityHidden(!checked)
            .motion(Motion.feedback, value: checked)
    }
}
```

### Conventions to follow

- **Folders (AGENTS.md section 7).** A file belongs in `Hugo/DesignSystem` only if it names no feature type, imports nothing from a feature, and either two or more features use it or it was written to be used anywhere. The new row qualifies: it takes `Text` values and a `Bool`, names no feature type, and Settings (this plan) and Planner (plan 084) both use it. `Scripts/check-layout.sh` fails the build if any file in `Hugo/DesignSystem` contains the words `Entry`, `Tracker`, `SubmittedReport`, `TheocraticYear` or `PublisherStatus`, **including in comments**.
- **Where the pacing page lives.** `YearlyGoalPacingSettingsView` goes in `Hugo/Features/Settings/Screens/`. The pacing picker lives in Settings today. The page only reads ServiceYear domain types, and features may use other features' types. ServiceYear has no settings screens of its own.
- **Pure logic.** Pure logic goes in a feature's `Domain` folder, `nonisolated`, with `now` and `calendar` parameters that default to production values, so tests can pass fixed ones (see `YearlyGoalProgress.make`).
- **Layout tokens.** Use `HugoLayout.Spacing.*` from `Hugo/DesignSystem/Theme/Theme.swift` (`tight` 4, `small` 6, `compact` 8, `regular` 12). Use no literal spacing numbers.
- **Settings rows** use the two-`Text` `Label` pattern for a title with its current value underneath (see the publisher status row above). Match it.
- **Vocabulary (CONTEXT.md).** "Monthly target: the hours the Planner aims at for one month: the monthly goal, or an even share of what is left of the yearly goal, plus extra hours." "Expected time: the credited time the user should have by now to reach the yearly goal at an even pace." "Pacing: how expected time is worked out for the current month." Use these words in names and comments.
- **Swift.** Swift 6, MainActor default isolation, 4-space indentation, `swift-format lint --strict` must pass. New files are picked up automatically (the project uses synchronized folders); do not edit `project.pbxproj`.
- **Principles (AGENTS.md section 6).** Keep it simple and native: a plain `List`, no illustrations, no custom backgrounds, at most one tip per page.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/YearlyGoalPacingTests -only-testing:HugoTests/PlannerTargetTests -only-testing:HugoTests/YearlyGoalProgressTests` | `** TEST SUCCEEDED **` |
| Layout check | `Scripts/check-layout.sh` | exit 0, no output |
| Format check | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Strings valid JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | no output |
| Full gate | `Scripts/verify.sh` | exit 0 (several minutes) |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run the same command again; that is not a failure.

## Scope

**In scope** (the only files you modify, create or delete):
- `Hugo/DesignSystem/Components/SelectableOptionRow.swift` (create)
- `Hugo/Features/ServiceYear/Domain/YearlyGoalPacing.swift`
- `Hugo/Features/Planner/Domain/PlannerTarget.swift` (add one static function only)
- `Hugo/Features/Settings/Screens/YearlyGoalPacingSettingsView.swift` (create)
- `Hugo/Features/Settings/Screens/SettingsView.swift`
- `Hugo/Features/Settings/Screens/GeneralSettingsView.swift`
- `Hugo/Features/Settings/Screens/CategorySettingsView.swift` (delete)
- `HugoTests/Features/ServiceYear/Domain/YearlyGoalPacingTests.swift` (create)
- `HugoTests/Features/Planner/Domain/PlannerTargetTests.swift` (add tests only)
- `Hugo/Resources/Localizable.xcstrings` (only the keys in Step 6)

**Out of scope** (do NOT touch):
- `Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift`. Plan 084 rebuilds it. Here it only moves to a new row in `SettingsView`.
- The TestFlight, support email and Debug sections of `SettingsView`. The owner keeps the Debug row for testers.
- `UserDefaultsKeys` and every stored value. Keys and raw values stay the same, so existing users keep their choices.
- `YearlyGoalProgress`, `TheocraticYearReportBuilder`, `ServiceYearPageView` and the Year page. Pacing math does not change.
- `ReportSettingsView`, `PublisherStatusSelectionView`, `CategoryListView`.
- The existing `Checkmark` component. Use it, do not change it.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- The working tree may hold uncommitted owner files in `plans/` and `.claude/`. Never stage, edit, stash or discard them. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage only the in-scope files, by explicit path (use `git rm` for `CategorySettingsView.swift`).
- One commit, Conventional Commits style like the rest of the log. Use: `feat: group goal settings and add a yearly goal pacing page`

## Steps

### Step 1: Add the selectable option row

Create `Hugo/DesignSystem/Components/SelectableOptionRow.swift`:

```swift
import SwiftUI

/// One choice in a settings list: a title, an optional one-line explanation,
/// an optional value such as "50 hours", and a checkmark when selected.
/// The whole row is the tap target.
struct SelectableOptionRow: View {
    let title: Text
    var description: Text? = nil
    var value: Text? = nil
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.regular) {
                VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                    title
                        .foregroundStyle(.primary)
                    if let description {
                        description
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if dynamicTypeSize.isAccessibilitySize, let value {
                        value
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: HugoLayout.Spacing.regular)
                if !dynamicTypeSize.isAccessibilitySize, let value {
                    value
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Checkmark(checked: isSelected)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var selection = 0

    List {
        SelectableOptionRow(
            title: Text(verbatim: "First option"), description: Text(verbatim: "A short explanation."),
            value: Text(verbatim: "50 hours"), isSelected: selection == 0
        ) { selection = 0 }
        SelectableOptionRow(title: Text(verbatim: "Second option"), isSelected: selection == 1) {
            selection = 1
        }
    }
}
```

Why these choices: `.buttonStyle(.plain)` keeps the title in the primary color instead of the tint. The checkmark is hidden from VoiceOver because the `.isSelected` trait already says "Selected". At accessibility text sizes the value moves under the title so nothing is squeezed.

**Verify**: `Scripts/check-layout.sh` → exit 0, no output. `grep -nwE 'Entry|Tracker|SubmittedReport|TheocraticYear|PublisherStatus' Hugo/DesignSystem/Components/SelectableOptionRow.swift` → no output.

### Step 2: Add pacing explanations and the expected-time helper

In `Hugo/Features/ServiceYear/Domain/YearlyGoalPacing.swift`, extend the existing `extension YearlyGoalPacing` with an `explanation` property, and add a static helper below it. Keep `label` unchanged.

```swift
    /// One line that says what the option does, shown under its label in Settings.
    var explanation: LocalizedStringResource {
        switch self {
        case .proRated: "settings.yearlyGoal.pacing.proRated.description"
        case .completedMonths: "settings.yearlyGoal.pacing.completedMonths.description"
        case .includeCurrentMonth: "settings.yearlyGoal.pacing.includeCurrentMonth.description"
        }
    }

    /// The expected time by `now` that each pacing gives for `year`. Expected
    /// time does not depend on logged time, so no entries are needed. Empty
    /// when `status` has no yearly goal or `year` has not started yet.
    static func expectedSeconds(
        in year: TheocraticYear,
        status: PublisherStatus?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [YearlyGoalPacing: TimeInterval] {
        guard let status else { return [:] }
        let report = TheocraticYearReportBuilder.report(for: year, entries: [], now: now, calendar: calendar)
        var result: [YearlyGoalPacing: TimeInterval] = [:]
        for pacing in allCases {
            let progress = YearlyGoalProgress.make(
                report: report, status: status, pacing: pacing, now: now, calendar: calendar)
            if let expected = progress?.expectedSeconds {
                result[pacing] = expected
            }
        }
        return result
    }
```

The file starts with `import Foundation`; keep it. The enum is `nonisolated`, and so are `TheocraticYearReportBuilder` and `YearlyGoalProgress`, so no isolation changes are needed. If the compiler reports an isolation error on this function, mark it `nonisolated static func` and continue.

**Verify**: the focused test command builds. New tests come in Step 7, so `** TEST SUCCEEDED **` is expected.

### Step 3: Add the monthly target summary for the Settings row

In `Hugo/Features/Planner/Domain/PlannerTarget.swift`, add this function inside `nonisolated enum PlannerTarget`, after `creditedSeconds(before:in:rule:)`. Change nothing else in the file.

```swift
    /// How the Settings root describes the target setting, for example
    /// "Monthly goal" or "Monthly goal + 5 hours". Statuses without a yearly
    /// goal always start from the monthly goal; statuses without any goal show
    /// only the extra hours, or "Not set".
    static func settingSummary(base: PlannerTargetBase, extraHours: Int, status: PublisherStatus?) -> String {
        let extra = max(0, extraHours)
        let extraText = ServiceDurationFormatter.hoursString(from: TimeInterval(extra) * 3_600)
        guard let status, status.monthlyGoal > 0 else {
            return extra > 0
                ? extraText
                : String(
                    localized: "planner.target.none", defaultValue: "Not set",
                    comment: "Shown when there is no monthly target: no goal and no extra hours.")
        }
        let effectiveBase: PlannerTargetBase = status.yearlyGoalRule != nil ? base : .monthlyGoal
        let baseText = String(localized: effectiveBase.label)
        guard extra > 0 else { return baseText }
        return String(
            localized: "planner.target.summary.withExtra", defaultValue: "\(baseText) + \(extraText)",
            comment: "Settings summary of the monthly target. The first argument is where the target starts, such as Monthly goal; the second is the extra hours.")
    }
```

**Verify**: the focused test command → `** TEST SUCCEEDED **`.

### Step 4: Add the pacing page

Create `Hugo/Features/Settings/Screens/YearlyGoalPacingSettingsView.swift`:

```swift
import SwiftUI

/// Chooses how expected time is worked out for the current month. Each option
/// shows the expected time it gives today.
struct YearlyGoalPacingSettingsView: View {
    @AppStorage(UserDefaultsKeys.yearlyGoalPacing) private var pacing: YearlyGoalPacing = .proRated
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""

    private var expectedSeconds: [YearlyGoalPacing: TimeInterval] {
        YearlyGoalPacing.expectedSeconds(
            in: TheocraticYear.containing(.now), status: PublisherStatus.status(for: statusID))
    }

    var body: some View {
        let expected = expectedSeconds
        List {
            Section {
                ForEach(YearlyGoalPacing.allCases, id: \.self) { option in
                    SelectableOptionRow(
                        title: Text(option.label),
                        description: Text(option.explanation),
                        value: expected[option].map { Text(ServiceDurationFormatter.hoursString(from: $0)) },
                        isSelected: pacing == option
                    ) {
                        pacing = option
                    }
                }
            } header: {
                Text("settings.yearlyGoal.pacing.intro")
                    .textCase(nil)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, HugoLayout.Spacing.compact)
            } footer: {
                Text("settings.yearlyGoal.pacing.tip")
            }
        }
        .navigationTitle("settings.yearlyGoal.pacing")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        YearlyGoalPacingSettingsView()
    }
    .defaultAppStorage({
        let defaults = UserDefaults(suiteName: "preview.pacing")!
        defaults.set("regular-pioneer", forKey: UserDefaultsKeys.publisherStatus)
        return defaults
    }())
}
```

Notes:
- The header holds the short intro, so the page explains itself before the options. `.textCase(nil)` keeps it in sentence case instead of the default uppercase header.
- If `.defaultAppStorage` in the preview does not compile, replace the whole `#Preview` with `#Preview { NavigationStack { YearlyGoalPacingSettingsView() } }` and continue.

**Verify**: the focused test command → `** TEST SUCCEEDED **` (it builds the app target).

### Step 5: Rebuild the Settings root and trim General

1. In `GeneralSettingsView.swift`, delete the `@AppStorage(UserDefaultsKeys.yearlyGoalPacing)` and `@AppStorage(UserDefaultsKeys.publisherStatus)` lines and the whole `if PublisherStatus.status(for: statusID)?.yearlyGoalRule != nil { ... }` block (lines 12-13 and 28-41 at `1432319`). The duration step `Section` and the `.navigationTitle` stay.

2. Delete `Hugo/Features/Settings/Screens/CategorySettingsView.swift` with `git rm`.

3. In `SettingsView.swift`, add three properties next to the existing `@AppStorage(UserDefaultsKeys.publisherStatus) var publisherStatus = ""`:

```swift
    @AppStorage(UserDefaultsKeys.plannerTargetBase) private var targetBase: PlannerTargetBase = .monthlyGoal
    @AppStorage(UserDefaultsKeys.plannerExtraHours) private var extraHours = 0
    @AppStorage(UserDefaultsKeys.yearlyGoalPacing) private var pacing: YearlyGoalPacing = .proRated
```

4. Replace the first two `Section`s (the excerpt from line 38 to line 68) with:

```swift
                Section {
                    NavigationLink(destination: PublisherStatusSelectionView()) {
                        Label {
                            Text("account.group.main.item.publisher.status")
                            Text(
                                PublisherStatus.status(for: publisherStatus)?
                                    .nameKey
                                    ?? "account.group.main.item.publisher.status.empty"
                            )
                        } icon: {
                            Image(
                                systemName: publisherStatus != ""
                                    ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                        }
                    }
                    NavigationLink(destination: PlannerTargetSettingsView()) {
                        Label {
                            Text("planner.target.title")
                            Text(
                                PlannerTarget.settingSummary(
                                    base: targetBase, extraHours: extraHours,
                                    status: PublisherStatus.status(for: publisherStatus)))
                        } icon: {
                            Image(systemName: "target")
                        }
                    }
                    if PublisherStatus.status(for: publisherStatus)?.yearlyGoalRule != nil {
                        NavigationLink(destination: YearlyGoalPacingSettingsView()) {
                            Label {
                                Text("settings.yearlyGoal.pacing")
                                Text(pacing.label)
                            } icon: {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                            }
                        }
                    }
                }

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

The publisher status row is unchanged. Leave everything from `if let testFlightURL = Self.testFlightURL {` to the end of the file as it is.

**Verify**:
- `grep -rn "CategorySettingsView" Hugo HugoTests` → no output.
- `grep -n "yearlyGoalPacing\|PublisherStatus" Hugo/Features/Settings/Screens/GeneralSettingsView.swift` → no output.
- `grep -c "NavigationLink" Hugo/Features/Settings/Screens/SettingsView.swift` → `7`.
- The focused test command → `** TEST SUCCEEDED **`.

### Step 6: Update the string catalog

Edit `Hugo/Resources/Localizable.xcstrings` (Xcode JSON: 2-space indent, `" : "` between key and value, literal UTF-8 characters). Copy the shape of the neighbouring `settings.yearlyGoal.*` entries: each entry has a `comment`, plus `en` and `da` `stringUnit`s with `"state" : "translated"`. Insert new keys next to their neighbours in alphabetical order. Edit with careful insertions or a small script that changes only these keys; do not reformat the rest of the file. In JSON, write a straight double quote inside a value as `\"`.

| Change | Key | English | Danish (owner reviews) |
|---|---|---|---|
| Add | `settings.yearlyGoal.pacing.intro` | Hugo compares the time that counts toward your yearly goal with the time you should have by today. Choose how this month counts. The hours show the expected time today. | Hugo sammenligner den tid, der tæller med mod dit årsmål, med den tid, du burde have nået i dag. Vælg, hvordan denne måned tæller med. Timerne viser, hvad du burde have nået i dag. |
| Add | `settings.yearlyGoal.pacing.tip` | Tip: Do most of your service late in the month? "Completed months only" won't show you as behind in the first weeks. | Tip: Bruger du mest tid i tjenesten sidst på måneden? Med "Kun afsluttede måneder" står du ikke bagud i månedens første uger. |
| Add | `settings.yearlyGoal.pacing.proRated.description` | This month's goal grows a little every day. | Månedens mål vokser lidt hver dag. |
| Add | `settings.yearlyGoal.pacing.completedMonths.description` | This month counts once it is over. | Denne måned tæller først med, når den er slut. |
| Add | `settings.yearlyGoal.pacing.includeCurrentMonth.description` | The whole month's goal counts from the 1st. | Hele månedens mål tæller med fra den 1. |
| Add | `planner.target.none` | Not set | Ikke valgt |
| Add | `planner.target.summary.withExtra` | %1$@ + %2$@ | %1$@ + %2$@ |
| Delete the whole entry | `settings.yearlyGoal.pacing.footer` | | |
| Delete the whole entry | `settings.screens.categories.items.list` | | |

Comments for the new keys:
- `...pacing.intro`: "Intro above the pacing options in Settings."
- `...pacing.tip`: "Tip under the pacing options in Settings. The quoted text is the label of the Completed months only option."
- the three `.description` keys: "Explains the pacing option of the same name in one line."
- `planner.target.none` and `planner.target.summary.withExtra`: copy the comments from the `String(localized:)` calls in Step 3.

The quoted option names in the tip must match the option labels: English "Completed months only", Danish "Kun afsluttede måneder" (the current values of `settings.yearlyGoal.pacing.completedMonths`). Check them before saving.

Do not change any other key. `settings.yearlyGoal.pacing` (the row and page title), the three option labels, `settings.group.settings.category` (the Categories row) and `planner.target.title` are still used; keep them.

**Verify**:
- The JSON check → no output.
- `python3 -I -c "import json; s=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings']; new=['settings.yearlyGoal.pacing.intro','settings.yearlyGoal.pacing.tip','settings.yearlyGoal.pacing.proRated.description','settings.yearlyGoal.pacing.completedMonths.description','settings.yearlyGoal.pacing.includeCurrentMonth.description','planner.target.none','planner.target.summary.withExtra']; print(all(k in s and 'da' in s[k]['localizations'] and 'en' in s[k]['localizations'] for k in new), 'settings.yearlyGoal.pacing.footer' in s, 'settings.screens.categories.items.list' in s)"` → `True False False`
- `grep -rn "settings.yearlyGoal.pacing.footer\|settings.screens.categories.items.list" Hugo HugoTests | grep -v xcstrings` → no output.

### Step 7: Tests

Create `HugoTests/Features/ServiceYear/Domain/YearlyGoalPacingTests.swift`. Model it on `HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift` (fixed UTC Gregorian calendar, `date(_:_:_:hour:)` helper). The expected numbers come from that file's existing tests for a regular pioneer on 2026-11-03 at noon: 105 hours pro rated, 100 hours completed months, 150 hours whole month.

```swift
import Foundation
import Testing

@testable import Hugo

struct YearlyGoalPacingTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let year = TheocraticYear(startYear: 2026)

    @Test
    func eachPacingGivesItsExpectedTimeForARegularPioneer() {
        let expected = YearlyGoalPacing.expectedSeconds(
            in: year, status: PublisherStatus.status(for: "regular-pioneer"),
            now: date(2026, 11, 3, hour: 12), calendar: calendar)
        #expect(expected[.proRated] == TimeInterval(105 * 3_600))
        #expect(expected[.completedMonths] == TimeInterval(100 * 3_600))
        #expect(expected[.includeCurrentMonth] == TimeInterval(150 * 3_600))
    }

    @Test
    func statusWithoutAYearlyGoalHasNoExamples() {
        let auxiliary = YearlyGoalPacing.expectedSeconds(
            in: year, status: PublisherStatus.status(for: "auxiliary-pioneer"),
            now: date(2026, 11, 3, hour: 12), calendar: calendar)
        #expect(auxiliary.isEmpty)
        #expect(
            YearlyGoalPacing.expectedSeconds(in: year, status: nil, now: date(2026, 11, 3), calendar: calendar)
                .isEmpty)
    }

    @Test
    func aYearThatHasNotStartedHasNoExamples() {
        let expected = YearlyGoalPacing.expectedSeconds(
            in: year, status: PublisherStatus.status(for: "regular-pioneer"),
            now: date(2026, 8, 15), calendar: calendar)
        #expect(expected.isEmpty)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
```

Add these tests to `HugoTests/Features/Planner/Domain/PlannerTargetTests.swift`, before the `private var november` line. They reuse the file's `regular`, `auxiliary` and `publisher` properties. The strings come from the catalog, so compare with `String(localized:)` instead of English text:

```swift
    @Test
    func settingSummaryNamesTheBaseForAYearlyGoal() {
        #expect(
            PlannerTarget.settingSummary(base: .monthlyGoal, extraHours: 0, status: regular)
                == String(localized: PlannerTargetBase.monthlyGoal.label))
        #expect(
            PlannerTarget.settingSummary(base: .yearlyGoalShare, extraHours: 0, status: regular)
                == String(localized: PlannerTargetBase.yearlyGoalShare.label))
    }

    @Test
    func settingSummaryUsesTheMonthlyGoalWithoutAYearlyGoal() {
        #expect(
            PlannerTarget.settingSummary(base: .yearlyGoalShare, extraHours: 0, status: auxiliary)
                == String(localized: PlannerTargetBase.monthlyGoal.label))
    }

    @Test
    func settingSummaryAddsExtraHours() {
        let summary = PlannerTarget.settingSummary(base: .monthlyGoal, extraHours: 5, status: regular)
        #expect(summary.hasPrefix(String(localized: PlannerTargetBase.monthlyGoal.label)))
        #expect(summary.contains("5"))
    }

    @Test
    func settingSummaryWithoutAGoalShowsExtraHoursOrNotSet() {
        let notSet = PlannerTarget.settingSummary(base: .monthlyGoal, extraHours: 0, status: publisher)
        #expect(notSet == String(localized: "planner.target.none"))
        #expect(PlannerTarget.settingSummary(base: .monthlyGoal, extraHours: 0, status: nil) == notSet)
        let extra = PlannerTarget.settingSummary(base: .monthlyGoal, extraHours: 10, status: publisher)
        #expect(extra.contains("10"))
        #expect(extra != notSet)
    }
```

**Verify**: the focused test command → `** TEST SUCCEEDED **`, and the output lists the 3 `YearlyGoalPacingTests` and the 4 new `PlannerTargetTests` as passed.

### Step 8: Full gate and commit

Run `Scripts/verify.sh`. Then stage the in-scope files by path and commit with the message from "Git workflow".

**Verify**: `Scripts/verify.sh` exits 0. `git show --stat HEAD` lists only in-scope files.

## Test plan

- `YearlyGoalPacingTests` (new, 3 tests): expected time per pacing for a regular pioneer, empty for statuses without a yearly goal, empty before the year starts.
- `PlannerTargetTests` (4 new tests): the Settings summary for each kind of status, with and without extra hours.
- Existing `YearlyGoalProgressTests` must still pass (pacing math is unchanged).
- Manual (owner, simulator or device, English and Danish):
  - Settings shows Publisher status, Monthly target and (regular pioneer only) Pace for the current month in the first section, each with its current value underneath.
  - Switching the publisher status to auxiliary pioneer hides the pace row.
  - The pace page shows three options with explanations and hour numbers. Tapping one moves the checkmark. The Year page's pace line changes to match.
  - Categories opens the category list directly, and its + button still adds a category.
  - At the largest accessibility text size, the hour numbers move under the option text. VoiceOver reads each option as one element, says "Selected" on the chosen one, and does not say "checkmark".

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `YearlyGoalPacingTests` (3) and the 4 new `PlannerTargetTests` exist and pass
- [ ] `grep -rn "CategorySettingsView" Hugo HugoTests` → no output
- [ ] `grep -rn "pickerStyle(.navigationLink)" Hugo/Features/Settings/Screens/GeneralSettingsView.swift` → exactly 1 match (the duration step)
- [ ] `test -f Hugo/DesignSystem/Components/SelectableOptionRow.swift && test -f Hugo/Features/Settings/Screens/YearlyGoalPacingSettingsView.swift` → exit 0
- [ ] The catalog check in Step 6 prints `True False False`
- [ ] `git status --short` shows no modified files outside the in-scope list (owner files in `plans/` and `.claude/` may remain)
- [ ] `plans/README.md` status row updated (unless a reviewer maintains it)

## STOP conditions

Stop and report back (do not improvise) if:

- The excerpts in "Current state" don't match the live code (for example, `SettingsView` already has a different first section, or `CategorySettingsView` is used somewhere else).
- `YearlyGoalPacingTests.eachPacingGivesItsExpectedTimeForARegularPioneer` fails with different numbers. That means pacing math changed since this plan was written. Do not change the expected values to make the test pass.
- `Scripts/check-layout.sh` reports the new DesignSystem file. Do not move it into a feature folder without reporting.
- A string key you are told to delete is still used in Swift code.
- Any step's verification fails twice after a reasonable fix attempt.

## Maintenance notes

- `SelectableOptionRow` is the pattern for future option pages (for example the duration step, if the owner wants it later). Keep it generic. A feature-specific option row belongs in that feature's `Views` folder, not here.
- Plan 084 rebuilds `PlannerTargetSettingsView` with `SelectableOptionRow` and reuses `planner.target.none`. Run it after this plan.
- `PlannerTarget.settingSummary` reads only settings, not logged time. If the owner later wants the row to show this month's target in hours, use the shared credited-time helper that plan 084 adds to `PlannerTarget`.
- `YearlyGoalPacing.expectedSeconds` relies on expected time not depending on logged time. If `YearlyGoalProgress` ever folds logged time into `expectedSeconds`, pass real entries here.
- Review: check the Danish texts in Step 6 (the owner writes the final Danish), and confirm the root sections read well at large text sizes.
