# Plan 084: Show this month's target next to each option on the monthly target page

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 1432319..HEAD -- Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift Hugo/Features/Planner/Screens/PlannerView.swift Hugo/Features/Planner/Domain/PlannerTarget.swift HugoTests/Features/Planner/Domain/PlannerTargetTests.swift`
> Expected: `PlannerTarget.swift` and `PlannerTargetTests.swift` changed (plan
> 083 added `settingSummary` and its tests). `PlannerTargetSettingsView.swift`
> and `PlannerView.swift` should be unchanged. If they changed, compare the
> "Current state" excerpts with the live code; on a mismatch, treat it as a
> STOP condition. Plans 081 and 083 must be DONE first (see Step 0).

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW (one settings page and one moved calculation; stored settings keep their keys and values)
- **Depends on**: plans/083-settings-root-and-pacing-page.md (adds `SelectableOptionRow` and the `planner.target.none` string), plans/081 (removes the Planner header's tap and the sheet that opens this page with `showsDone: true`)
- **Category**: direction
- **Planned at**: commit `1432319`, 2026-11-05
- **Issue**: [SLN-298](https://linear.app/sebastianln/issue/SLN-298)

## Why this matters

The monthly target page is where a user decides what the Planner aims at. Today it shows a plain inline picker with two abstract options ("Monthly goal" and "Share of what's left of the yearly goal") and a stepper. The user has to guess what each option means in hours. The owner wants Settings pages that explain themselves with live examples.

After this plan, each option shows the target it gives this month (for example "Monthly goal, 50 hours" and "Share of what's left of the yearly goal, 47 hours"). Under the extra-hours stepper, a "This month" line shows the total the Planner will use. The page now opens only from Settings (plan 081 removed the Planner header's shortcut), so the "Done" button for the sheet goes away.

To show real numbers, the page needs the same "credited time before the current month" that the Planner computes. This plan moves that computation from the Planner screen into `PlannerTarget`, so both screens use one function and it gets a test.

## Current state

### Files

- `Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift` is the monthly target page. Settings pushes it, and before plan 081 the Planner header also showed it in a sheet.
- `Hugo/Features/Planner/Screens/PlannerView.swift` holds `PlannerPager`, which computes the target for each month page.
- `Hugo/Features/Planner/Domain/PlannerTarget.swift` holds the target math: `PlannerTarget.seconds(...)`, `PlannerTarget.creditedSeconds(before:in:rule:)` and, after plan 083, `PlannerTarget.settingSummary(...)`.
- `HugoTests/Features/Planner/Domain/PlannerTargetTests.swift` holds the target tests.
- `Hugo/DesignSystem/Components/SelectableOptionRow.swift` (added by plan 083) is a list row with a title, an optional description, an optional value, a checkmark and the `.isSelected` trait. Its initializer is `SelectableOptionRow(title: Text, description: Text? = nil, value: Text? = nil, isSelected: Bool, action: () -> Void)`.

### Excerpts

`PlannerTargetSettingsView.swift` (whole file at `1432319`):

```swift
import SwiftUI

struct PlannerTargetSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UserDefaultsKeys.plannerTargetBase) private var base: PlannerTargetBase = .monthlyGoal
    @AppStorage(UserDefaultsKeys.plannerExtraHours) private var extraHours = 0
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""

    var showsDone = false

    private var status: PublisherStatus? { PublisherStatus.status(for: statusID) }
    private var hasGoal: Bool { (status?.monthlyGoal ?? 0) > 0 }

    var body: some View {
        List {
            if status?.yearlyGoalRule != nil {
                Section {
                    Picker(selection: $base) {
                        ForEach(PlannerTargetBase.allCases, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    } label: {
                        Text("planner.target.base")
                    }
                    .pickerStyle(.inline)
                } footer: {
                    Text("planner.target.base.footer")
                }
            }
            Section {
                Stepper(value: $extraHours, in: 0...30) {
                    LabeledContent(
                        "planner.target.extra",
                        value: ServiceDurationFormatter.hoursString(from: TimeInterval(extraHours) * 3_600))
                }
            } footer: {
                Text(
                    hasGoal
                        ? LocalizedStringKey("planner.target.extra.footer")
                        : LocalizedStringKey("planner.target.extra.footer.noGoal"))
            }
        }
        .navigationTitle("planner.target.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("navigation.done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PlannerTargetSettingsView()
    }
}
```

`PlannerView.swift:37-79` (the parts of `PlannerPager` this plan touches):

```swift
private struct PlannerPager: View {
    let today: Date
    let resetToken: UUID

    @Query private var yearEntries: [Entry]
    @Query private var submissions: [SubmittedReport]
    @Query private var trackers: [Tracker]
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""
    @AppStorage(UserDefaultsKeys.plannerTargetBase) private var targetBase: PlannerTargetBase = .monthlyGoal
    @AppStorage(UserDefaultsKeys.plannerExtraHours) private var extraHours = 0
    ...
    init(today: Date, resetToken: UUID) {
        self.today = today
        self.resetToken = resetToken
        let range = TheocraticYear.containing(today).dateRange()
        let start = range.lowerBound
        let end = range.upperBound
        _yearEntries = Query(
            filter: #Predicate<Entry> { $0.date >= start && $0.date < end },
            sort: \Entry.date
        )
        _submissions = Query(sort: \SubmittedReport.year)
    }
    ...
    /// Credited time of this theocratic year's months before the current month.
    /// Built only when the target needs it.
    private var creditedBeforeCurrentMonth: TimeInterval {
        guard targetBase == .yearlyGoalShare, let rule = status?.yearlyGoalRule else { return 0 }
        let report = TheocraticYearReportBuilder.report(
            for: TheocraticYear.containing(today), entries: yearEntries, submissions: submissions,
            trackers: trackers, now: today)
        return PlannerTarget.creditedSeconds(before: today.yearMonth(), in: report, rule: rule)
    }
```

`PlannerTarget.swift:21-51` (the target function; it returns nil when the total would be zero, and reads `creditedBeforeCurrentMonth` only for `.yearlyGoalShare`):

```swift
nonisolated enum PlannerTarget {
    /// The monthly target for `month` in seconds, or nil when it would be zero.
    /// `creditedBeforeCurrentMonth` is the credited time of the current
    /// theocratic year's months before the current month; it is read only for
    /// `.yearlyGoalShare`.
    static func seconds(
        for month: YearMonth,
        base: PlannerTargetBase,
        extraHours: Int,
        status: PublisherStatus?,
        creditedBeforeCurrentMonth: TimeInterval,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TimeInterval? {
```

`PlannerTarget.swift:53-62`:

```swift
    /// Credited time of the months in `report` before `month`, with the same
    /// formula as `YearlyGoalProgress`.
    static func creditedSeconds(
        before month: YearMonth, in report: TheocraticYearReport, rule: YearlyGoalRule
    ) -> TimeInterval {
```

`PlannerTargetTests.swift:79-98` is the existing credited-time test, which this plan copies (entries in September to November 2026; credited time before November is 95 hours for a regular pioneer):

```swift
    @Test
    func creditedBeforeMonthUsesTheYearlyGoalCreditRule() throws {
        let entries = [
            Entry(date: date(2026, 9, 10, hour: 10), duration: 40 * 3_600, tracker: main),
            Entry(date: date(2026, 10, 10, hour: 10), duration: 30 * 3_600, tracker: main),
            Entry(date: date(2026, 10, 11, hour: 10), duration: 30 * 3_600, tracker: separate),
            Entry(date: date(2026, 11, 2, hour: 10), duration: 10 * 3_600, tracker: main),
        ]
        let report = TheocraticYearReportBuilder.report(
            for: TheocraticYear(startYear: 2026),
            entries: entries,
            now: date(2026, 11, 3, hour: 12),
            calendar: calendar,
            locale: locale)
        let rule = try #require(regular.yearlyGoalRule)

        let credited = PlannerTarget.creditedSeconds(before: november, in: report, rule: rule)

        #expect(credited == TimeInterval(95 * 3_600))
    }
```

Current strings this page uses (English / Danish): `planner.target.title` "Monthly Target" / "Mål for måneden"; `planner.target.base` "Start From" / "Udgangspunkt"; `planner.target.base.footer` explains the share option; `planner.target.extra` "Extra Hours" / "Ekstra timer"; `planner.target.extra.footer` "Added to your target every month, for example to keep a buffer." / "Lægges til dit mål hver måned, for eksempel for at have lidt luft."; `planner.target.extra.footer.noGoal` "Your publisher status has no goal, so extra hours become your monthly target." / "Din forkynderstatus har intet mål, så de ekstra timer bliver dit mål for måneden."; `planner.target.none` "Not set" / "Ikke valgt" (added by plan 083).

### Conventions to follow

- **Vocabulary (CONTEXT.md).** "Monthly target: the hours the Planner aims at for one month: the monthly goal, or an even share of what is left of the yearly goal, plus extra hours." "Extra hours: hours the user adds to the monthly target each month, as a buffer, or as a personal target when the publisher status has no goal." "Credited time: the part of a month's time that counts toward the yearly goal." Use these words in names and comments.
- **Pure logic** stays in `Planner/Domain`, `nonisolated`, with `now`, `calendar` and `locale` parameters that default to production values (see `PlannerTarget.seconds`). Views stay visual: they hold `@Query` results and call domain functions.
- **Queries.** Pages that need a theocratic year's entries query them with a date-range predicate in `init`, as `PlannerPager.init` does above. Match it.
- **Layout tokens** come from `HugoLayout` in `Hugo/DesignSystem/Theme/Theme.swift`. Use no literal spacing.
- **Swift.** Swift 6, MainActor default isolation, 4-space indentation, `swift-format lint --strict` must pass.
- **Principles (AGENTS.md section 6).** A plain native `List`, one footer tip, no illustrations.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/PlannerTargetTests` | `** TEST SUCCEEDED **` |
| Format check | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Strings valid JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | no output |
| Full gate | `Scripts/verify.sh` | exit 0 (several minutes) |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run the same command again; that is not a failure.

## Scope

**In scope** (the only files you modify):
- `Hugo/Features/Planner/Domain/PlannerTarget.swift` (add one static function)
- `Hugo/Features/Planner/Screens/PlannerView.swift` (`PlannerPager.creditedBeforeCurrentMonth` only)
- `Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift` (rewrite)
- `HugoTests/Features/Planner/Domain/PlannerTargetTests.swift` (add tests only)
- `Hugo/Resources/Localizable.xcstrings` (the keys in Step 4 only)

**Out of scope** (do NOT touch):
- `PlannerTarget.seconds` and `PlannerTarget.creditedSeconds(before:in:rule:)`. Their behavior and signatures stay the same.
- `SettingsView`, `SelectableOptionRow` and `PlannerTarget.settingSummary` (plan 083). Use them, do not change them.
- `PlannerMonthPage`, `PlannerStatusHeader` and the rest of the Planner header (plan 081).
- `UserDefaultsKeys` and stored values.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- The working tree may hold uncommitted owner files in `plans/` and `.claude/`. Never stage, edit, stash or discard them. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage only the in-scope files, by explicit path.
- One commit, Conventional Commits style like the rest of the log. Use: `feat: show this month's target on the monthly target settings page`

## Steps

### Step 0: Confirm plans 081 and 083 are in

Run:

```bash
grep -rn "showsDone" Hugo
test -f Hugo/DesignSystem/Components/SelectableOptionRow.swift && echo row-ok
grep -c "func settingSummary" Hugo/Features/Planner/Domain/PlannerTarget.swift
```

**Verify**: the first command prints only lines from `Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift` (no line from `PlannerMonthPage.swift` or any other file). The second prints `row-ok`. The third prints `1`. If any of these fails, STOP: plan 081 or 083 has not landed.

### Step 1: Move the credited-time computation into `PlannerTarget`

In `Hugo/Features/Planner/Domain/PlannerTarget.swift`, add this function inside `nonisolated enum PlannerTarget`, directly after `creditedSeconds(before:in:rule:)`:

```swift
    /// Credited time of the current theocratic year's months before the
    /// current month, which `seconds(for:...)` needs for `.yearlyGoalShare`.
    /// 0 when the publisher status has no yearly goal.
    static func creditedBeforeCurrentMonth(
        entries: [Entry],
        submissions: [SubmittedReport],
        trackers: [Tracker],
        status: PublisherStatus?,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> TimeInterval {
        guard let rule = status?.yearlyGoalRule else { return 0 }
        let report = TheocraticYearReportBuilder.report(
            for: TheocraticYear.containing(now, calendar: calendar), entries: entries, submissions: submissions,
            trackers: trackers, now: now, calendar: calendar, locale: locale)
        return creditedSeconds(before: now.yearMonth(using: calendar), in: report, rule: rule)
    }
```

Then in `PlannerView.swift`, replace the body of `PlannerPager.creditedBeforeCurrentMonth` (keep the property, its doc comment and its early return for other bases):

```swift
    private var creditedBeforeCurrentMonth: TimeInterval {
        guard targetBase == .yearlyGoalShare else { return 0 }
        return PlannerTarget.creditedBeforeCurrentMonth(
            entries: yearEntries, submissions: submissions, trackers: trackers, status: status, now: today)
    }
```

Behavior is the same as before: the old code returned 0 without a yearly goal rule, and so does the new function.

**Verify**: `grep -n "TheocraticYearReportBuilder" Hugo/Features/Planner/Screens/PlannerView.swift` → no output. The focused test command → `** TEST SUCCEEDED **`.

### Step 2: Test the moved computation

Add these tests to `PlannerTargetTests.swift`, before the `private var november` line. They reuse the file's `regular`, `auxiliary`, `main`, `separate`, `calendar`, `locale` and `date(...)` members.

```swift
    @Test
    func creditedBeforeCurrentMonthBuildsTheYearFromEntries() {
        let entries = [
            Entry(date: date(2026, 9, 10, hour: 10), duration: 40 * 3_600, tracker: main),
            Entry(date: date(2026, 10, 10, hour: 10), duration: 30 * 3_600, tracker: main),
            Entry(date: date(2026, 10, 11, hour: 10), duration: 30 * 3_600, tracker: separate),
            Entry(date: date(2026, 11, 2, hour: 10), duration: 10 * 3_600, tracker: main),
        ]
        let credited = PlannerTarget.creditedBeforeCurrentMonth(
            entries: entries, submissions: [], trackers: [main, separate], status: regular,
            now: date(2026, 11, 3, hour: 12), calendar: calendar, locale: locale)
        #expect(credited == TimeInterval(95 * 3_600))
    }

    @Test
    func creditedBeforeCurrentMonthIsZeroWithoutAYearlyGoal() {
        let entries = [Entry(date: date(2026, 9, 10, hour: 10), duration: 40 * 3_600, tracker: main)]
        let now = date(2026, 11, 3, hour: 12)
        #expect(
            PlannerTarget.creditedBeforeCurrentMonth(
                entries: entries, submissions: [], trackers: [main], status: auxiliary, now: now,
                calendar: calendar, locale: locale) == 0)
        #expect(
            PlannerTarget.creditedBeforeCurrentMonth(
                entries: entries, submissions: [], trackers: [main], status: nil, now: now,
                calendar: calendar, locale: locale) == 0)
    }
```

**Verify**: the focused test command → `** TEST SUCCEEDED **`, with both new tests listed as passed.

### Step 3: Rebuild the page

Replace the whole content of `PlannerTargetSettingsView.swift` with:

```swift
import SwiftData
import SwiftUI

/// Chooses what the monthly target starts from and how many extra hours it
/// adds. Each option shows the target it gives this month.
struct PlannerTargetSettingsView: View {
    @AppStorage(UserDefaultsKeys.plannerTargetBase) private var base: PlannerTargetBase = .monthlyGoal
    @AppStorage(UserDefaultsKeys.plannerExtraHours) private var extraHours = 0
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""

    @Query private var yearEntries: [Entry]
    @Query private var submissions: [SubmittedReport]
    @Query private var trackers: [Tracker]

    private let now: Date

    init(now: Date = .now) {
        self.now = now
        let range = TheocraticYear.containing(now).dateRange()
        let start = range.lowerBound
        let end = range.upperBound
        _yearEntries = Query(filter: #Predicate<Entry> { $0.date >= start && $0.date < end }, sort: \Entry.date)
        _submissions = Query(sort: \SubmittedReport.year)
    }

    private var status: PublisherStatus? { PublisherStatus.status(for: statusID) }
    private var hasGoal: Bool { (status?.monthlyGoal ?? 0) > 0 }

    /// This month's target for `base` plus `extraHours`, or nil when it is zero.
    private func target(base: PlannerTargetBase, extraHours: Int, credited: TimeInterval) -> TimeInterval? {
        PlannerTarget.seconds(
            for: now.yearMonth(), base: base, extraHours: extraHours, status: status,
            creditedBeforeCurrentMonth: credited, now: now)
    }

    private func hoursText(_ seconds: TimeInterval?) -> Text {
        Text(ServiceDurationFormatter.hoursString(from: seconds ?? 0))
    }

    var body: some View {
        let credited = PlannerTarget.creditedBeforeCurrentMonth(
            entries: yearEntries, submissions: submissions, trackers: trackers, status: status, now: now)
        List {
            if status?.yearlyGoalRule != nil {
                Section {
                    ForEach(PlannerTargetBase.allCases, id: \.self) { option in
                        SelectableOptionRow(
                            title: Text(option.label),
                            value: hoursText(target(base: option, extraHours: 0, credited: credited)),
                            isSelected: base == option
                        ) {
                            base = option
                        }
                    }
                } header: {
                    Text("planner.target.base")
                } footer: {
                    Text("planner.target.base.footer")
                }
            }
            Section {
                Stepper(value: $extraHours, in: 0...30) {
                    LabeledContent(
                        "planner.target.extra",
                        value: ServiceDurationFormatter.hoursString(from: TimeInterval(extraHours) * 3_600))
                }
                LabeledContent("planner.target.thisMonth") {
                    if let total = target(base: base, extraHours: extraHours, credited: credited) {
                        Text(ServiceDurationFormatter.hoursString(from: total))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    } else {
                        Text("planner.target.none")
                    }
                }
            } footer: {
                Text(
                    hasGoal
                        ? LocalizedStringKey("planner.target.extra.footer")
                        : LocalizedStringKey("planner.target.extra.footer.noGoal"))
            }
        }
        .navigationTitle("planner.target.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PlannerTargetSettingsView()
    }
    .modelContainer(.preview)
}
```

Notes:
- Option rows show the base without extra hours (`extraHours: 0`), so the user compares the two starting points. The "This month" line shows the total the Planner uses.
- Without a yearly goal, the base section stays hidden, as before. "This month" then shows the monthly goal plus extra hours, or "Not set" for a publisher with no extra hours.
- `showsDone`, `@Environment(\.dismiss)` and the toolbar are gone. Step 0 confirmed that no caller passes `showsDone`.
- If `.modelContainer(.preview)` does not compile in the preview, check how `PlannerView.swift`'s `#Preview` does it and copy that.

**Verify**: `grep -rn "showsDone" Hugo` → no output. `grep -c "Picker" Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift` → `0`. The focused test command → `** TEST SUCCEEDED **`.

### Step 4: Add the "This month" string

Edit `Hugo/Resources/Localizable.xcstrings` (Xcode JSON: 2-space indent, `" : "` between key and value, literal UTF-8 characters, keys in alphabetical order; copy the shape of the neighbouring `planner.target.*` entries, each with a `comment` and `en` and `da` `stringUnit`s with `"state" : "translated"`). Do not reformat the rest of the file.

| Change | Key | English | Danish (owner reviews) |
|---|---|---|---|
| Add | `planner.target.thisMonth` | This Month | Denne måned |

Comment: "Label in the monthly target settings for the target the Planner uses this month, including extra hours."

Do not change any other key. Check that `navigation.done` is still used elsewhere (`grep -rn '"navigation.done"' Hugo | grep -v xcstrings` lists other files) and keep it.

**Verify**:
- The JSON check → no output.
- `python3 -I -c "import json; s=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings']; print(all(k in s and 'da' in s[k]['localizations'] for k in ['planner.target.thisMonth','planner.target.none']))"` → `True`

### Step 5: Full gate and commit

Run `Scripts/verify.sh`. Then stage the in-scope files by path and commit with the message from "Git workflow".

**Verify**: `Scripts/verify.sh` exits 0. `git show --stat HEAD` lists only in-scope files.

## Test plan

- `PlannerTargetTests` (2 new tests): `creditedBeforeCurrentMonth` gives 95 hours for the existing fixture, and 0 without a yearly goal. All existing `PlannerTargetTests`, including plan 083's `settingSummary` tests, must still pass.
- The page itself has no unit test. Its numbers come from `PlannerTarget.seconds` and `creditedBeforeCurrentMonth`, which are tested.
- Manual (owner, simulator or device, English and Danish):
  - As a regular pioneer, Settings, then Monthly Target shows two options with hours. The selected one has a checkmark. The share option's hours match what the Planner header shows as the target for this month when that option is chosen and extra hours are 0.
  - Changing extra hours updates "This Month" at once, and the Planner header's target matches it.
  - As an auxiliary pioneer the options are hidden and "This Month" shows 30 hours plus extra hours. As a publisher with 0 extra hours it shows "Not set".
  - VoiceOver reads each option with its hours and says "Selected" on the chosen one.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] The 2 new `PlannerTargetTests` exist and pass
- [ ] `grep -rn "showsDone" Hugo` → no output
- [ ] `grep -n "TheocraticYearReportBuilder" Hugo/Features/Planner/Screens/PlannerView.swift` → no output
- [ ] `grep -c "SelectableOptionRow" Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift` → `1`
- [ ] The catalog check in Step 4 prints `True`
- [ ] `git status --short` shows no modified files outside the in-scope list (owner files in `plans/` and `.claude/` may remain)
- [ ] `plans/README.md` status row updated (unless a reviewer maintains it)

## STOP conditions

Stop and report back (do not improvise) if:

- Step 0 fails: a file other than `PlannerTargetSettingsView.swift` still mentions `showsDone`, `SelectableOptionRow.swift` is missing, or `settingSummary` is missing.
- The excerpts in "Current state" don't match the live code (for example, `PlannerPager.creditedBeforeCurrentMonth` already looks different).
- `creditedBeforeCurrentMonthBuildsTheYearFromEntries` gives something other than 95 hours. Do not change the expected value.
- `SelectableOptionRow`'s initializer differs from the one in "Current state". Report it; do not change the DesignSystem file.
- Any step's verification fails twice after a reasonable fix attempt.

## Maintenance notes

- `PlannerTarget.creditedBeforeCurrentMonth` is now the only place that builds the year report for the target. If the target ever needs more than the current theocratic year (for example a target for next year's September), change it here and both screens follow.
- The page builds the year report on every render. The settings page is small and opened rarely, so this is acceptable. If it ever feels slow, cache `credited` in `@State` and refresh it on `.task(id: yearEntries.count)`.
- `PlannerTarget.settingSummary` (plan 083) describes the setting without hours. If the owner later wants the Settings root row to show this month's hours instead, it can call `creditedBeforeCurrentMonth` and `seconds` the same way this page does.
- Review: compare the page's numbers with the Planner header for the same settings. They must match, because both now call the same two functions.
