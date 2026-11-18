# Plan 127: Remove the "Current Month Calculation" setting and always spread the target across the month

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat c918888..HEAD -- Hugo/Features/ServiceYear Hugo/Features/Settings Hugo/Domain/UserDefaultsKeys.swift HugoTests/Features/ServiceYear HugoTests/Features/Settings CONTEXT.md`
> Expected: no output. If a file changed, compare the "Current state" excerpts
> with the live code. On a mismatch, STOP.
> Also run `git status --short -- Hugo/Resources/Localizable.xcstrings` → no output. If the catalog has uncommitted changes, STOP and ask the owner to commit or discard them first.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW. Removes a setting and two of its three options. The default option, which most users have, stays and keeps its numbers.
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `c918888`, 2026-11-18
- **Issue**: pending (to be created in Linear)

## Why this matters

Settings > General has a "Current Month Calculation" screen ("Beregning af nuværende måned") with three ways to work out the time expected by today for the yearly goal. A tester didn't understand it, and the owner decided (2026-11-18) that Hugo always uses the default, "Spread across the month": the current month's goal counts in proportion to the day of the month. One rule is simpler to explain, and plan 130 explains it in a help article.

After this plan:
- The Year tab always computes expected time with the current month spread by day (today's day number divided by the number of days in the month).
- The setting row, its screen, its preview view and its calculation type are gone, and so is the `YearlyGoalPacing` enum.
- The stored `yearlyGoalPacing` value in `UserDefaults` and iCloud key-value storage is left alone. Nothing reads it, so a stale value does nothing. Do not migrate or delete it.
- The 15 strings only that screen used are gone from the catalog, in English and Danish.

## Current state

### The enum (`Hugo/Features/ServiceYear/Domain/YearlyGoalPacing.swift`, whole file)

```swift
/// How much of the current month counts as "expected so far" on the yearly goal bar.
nonisolated enum YearlyGoalPacing: String, CaseIterable, Sendable {
    case proRated
    case completedMonths
    case includeCurrentMonth
}

nonisolated extension YearlyGoalPacing {
    func currentMonthFraction(now: Date = .now, calendar: Calendar = .current) -> Double {
        switch self {
        case .proRated:
            let current = now.yearMonth(using: calendar)
            let day = calendar.component(.day, from: now)
            return Double(day) / Double(current.lastDay(calendar: calendar))
        case .completedMonths:
            return 0
        case .includeCurrentMonth:
            return 1
        }
    }

    var explanation: LocalizedStringResource { ... }   // settings.yearlyGoal.pacing.*.description
    var label: LocalizedStringResource { ... }         // settings.yearlyGoal.pacing.proRated etc.
}
```

`YearlyGoalPacing` is persisted only as a `String` raw value in `UserDefaults` under the key `"yearlyGoalPacing"` (through `@AppStorage`) and synced through iCloud key-value storage. It is not in any SwiftData schema: `grep -rn "YearlyGoalPacing" Hugo/Persistence` finds nothing. AGENTS.md's rule that persisted code names stay applies to SwiftData types and stored raw values; nothing will read this raw value after this plan, so the type can go.

### The calculation (`Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift:41-81`)

```swift
    /// Nil when the status has no yearly goal.
    static func make(
        report: TheocraticYearReport,
        status: PublisherStatus,
        pacing: YearlyGoalPacing,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> YearlyGoalProgress? {
        guard let rule = status.yearlyGoalRule else { return nil }
        ...
        let current = now.yearMonth(using: calendar)
        let expectedSeconds: TimeInterval?
        if let first = report.months.first, first.id > current {
            expectedSeconds = nil
        } else {
            expectedSeconds = report.months.reduce(0) { total, month in
                if month.id < current {
                    return total + rule.monthlyGoalSeconds
                }
                guard month.id == current else { return total }
                return total + rule.monthlyGoalSeconds * pacing.currentMonthFraction(now: now, calendar: calendar)
            }
        }
        ...
```

### Callers of `make(...pacing:)`

- `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift:13` `@AppStorage(UserDefaultsKeys.yearlyGoalPacing) private var pacing: YearlyGoalPacing = .proRated` and line 44 `return YearlyGoalProgress.make(report: report, status: status, pacing: pacing)`.
- `Hugo/Features/ServiceYear/Screens/ServiceYearDetailView.swift:100` (in `#Preview`): `YearlyGoalProgress.make(report: report, status: $0, pacing: .proRated)`.
- `Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift:104` (in `#Preview("Yearly goal")`): same call.
- `Hugo/Features/Settings/Domain/CurrentMonthCalculation.swift:49-50` (deleted by this plan).

### The setting row (`Hugo/Features/Settings/Screens/GeneralSettingsView.swift`)

```swift
struct GeneralSettingsView: View {
    @AppStorage(UserDefaultsKeys.durationMinuteInterval) private var durationMinuteInterval = 1
    @AppStorage(UserDefaultsKeys.yearlyGoalPacing) private var pacing: YearlyGoalPacing = .proRated
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""
    ...
            if status?.yearlyGoalRule != nil {
                Section {
                    NavigationLink(destination: YearlyGoalPacingSettingsView()) {
                        LabeledContent {
                            Text(pacing.label).foregroundStyle(.secondary)
                        } label: {
                            Label("settings.yearlyGoal.pacing", systemImage: "chart.line.uptrend.xyaxis")
                        }
                    }
                } header: {
                    Text("year.subtitle")
                }
            }
```

`statusID` and `status` are still used by the Planner row above it, so they stay.

### Files that exist only for the setting

- `Hugo/Features/Settings/Screens/YearlyGoalPacingSettingsView.swift`: the settings screen.
- `Hugo/Features/Settings/Views/CurrentMonthCalculationPreview.swift`: the preview card on that screen.
- `Hugo/Features/Settings/Domain/CurrentMonthCalculation.swift`: the numbers for that card.
- `HugoTests/Features/Settings/Domain/CurrentMonthCalculationTests.swift`: its tests.
- `HugoTests/Features/ServiceYear/Domain/YearlyGoalPacingTests.swift`: tests of the enum. Its `proratedFractionUsesInclusiveCalendarDay` test must survive (moved in Step 4).

`grep -rln "CurrentMonthCalculation\|YearlyGoalPacingSettingsView" Hugo HugoTests` lists only these files and `GeneralSettingsView.swift`.

### The key (`Hugo/Domain/UserDefaultsKeys.swift:6` and `Hugo/Features/Settings/Domain/SyncedSettings.swift:11`)

```swift
    static let yearlyGoalPacing = "yearlyGoalPacing"
```

```swift
    static let keys: [String] = [
        UserDefaultsKeys.publisherStatus,
        UserDefaultsKeys.yearlyGoalPacing,
        UserDefaultsKeys.plannerTargetBase,
        ...
```

`SettingsSyncServiceTests` does not use this key (`grep -n yearlyGoalPacing HugoTests -r` finds nothing).

### Tests that use `pacing` (`HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift`)

- `completedMonthsPacingIgnoresTheCurrentMonth` (lines 34-39) and `includeCurrentMonthPacingExpectsTheWholeMonth` (lines 41-46) cover the removed options.
- `statusWithoutAYearlyGoalHasNoProgress` (line 138) passes `pacing: .proRated`.
- The helper `makeProgress(entries:submissions:pacing:now:)` (lines 167-188) has a `pacing: YearlyGoalPacing = .proRated` parameter.

`YearlyGoalPacingTests.swift` (to be merged into `YearlyGoalProgressTests`):

```swift
    @Test(arguments: [
        (2026, 11, 3, 30, 0.1),
        (2026, 11, 1, 30, 1.0 / 30.0),
        (2026, 11, 30, 30, 1.0),
        (2028, 2, 29, 29, 1.0),
        (2027, 2, 1, 28, 1.0 / 28.0),
    ])
    func proratedFractionUsesInclusiveCalendarDay(argument: (Int, Int, Int, Int, Double)) {
        let actual = YearlyGoalPacing.proRated.currentMonthFraction(
            now: date(argument.0, argument.1, argument.2), calendar: calendar)
        #expect(abs(actual - argument.4) < 1e-9)
    }
```

### Strings used only by the removed screen (in `Hugo/Resources/Localizable.xcstrings`)

| Key | English |
|---|---|
| `settings.yearlyGoal.pacing` | Current Month Calculation |
| `settings.yearlyGoal.pacing.accessibility` | %@. %@. Current month: %@ of %@. Expected by today: %@. |
| `settings.yearlyGoal.pacing.completedMonths` | Completed months only |
| `settings.yearlyGoal.pacing.completedMonths.description` | The current month counts only once it is over. |
| `settings.yearlyGoal.pacing.currentMonth` | Current month |
| `settings.yearlyGoal.pacing.expectedByToday` | Expected by today |
| `settings.yearlyGoal.pacing.includeCurrentMonth` | Include the whole month |
| `settings.yearlyGoal.pacing.includeCurrentMonth.description` | The whole monthly goal counts from the first day. |
| `settings.yearlyGoal.pacing.intro` | Choose how much of the current month's goal counts ... |
| `settings.yearlyGoal.pacing.monthContribution` | %@ of %@ |
| `settings.yearlyGoal.pacing.noGoal` | Your publisher status has no yearly goal. |
| `settings.yearlyGoal.pacing.options.caption` | (already marked stale) |
| `settings.yearlyGoal.pacing.proRated` | Spread across the month |
| `settings.yearlyGoal.pacing.proRated.description` | The part of the monthly goal that counts grows each day. |
| `year.subtitle` | Service Year (only used as the section header in `GeneralSettingsView`) |

Each has an English and a Danish value. `grep -rn '"year.subtitle"' Hugo --include='*.swift'` finds only `GeneralSettingsView.swift:40`.

### `CONTEXT.md` (Goals section)

```markdown
**Expected time**:
The credited time the user should have by now to reach the yearly goal at an even pace.

**Current month calculation**:
How expected time is worked out for the current month: in proportion to the inclusive day fraction, counting only completed months, or counting the whole current month. Settings calls this "Current Month Calculation" / "Beregning af nuværende måned". It changes expected time, not credited or logged time. Persisted code names remain `YearlyGoalPacing`.
```

### Conventions

- Swift 6, main-actor default isolation. Domain types are `nonisolated` (see `YearlyGoalProgress`).
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`) and fix `calendar` and `now`.
- 4-space indentation. `swift-format lint --strict` runs in `Scripts/verify.sh`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full gate | `Scripts/verify.sh` | exit 0 |
| Build | `xcodebuild build -project Hugo.xcodeproj -scheme Debug -destination 'generic/platform=iOS Simulator' -quiet 2>&1 \| grep -c "error:"` | `0` |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Debug -configuration Debug -destination 'platform=iOS Simulator,name=Hugo Verify iOS 26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/YearlyGoalProgressTests` | `** TEST SUCCEEDED **` |
| Lint only | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | no output |
| Catalog JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0 |

Do not run the focused tests while `Scripts/verify.sh` runs; both use the same simulator.

## Scope

**In scope:**
- `Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift`
- `Hugo/Features/ServiceYear/Domain/YearlyGoalPacing.swift` (delete)
- `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift`
- `Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift` (preview only)
- `Hugo/Features/ServiceYear/Screens/ServiceYearDetailView.swift` (preview only)
- `Hugo/Features/Settings/Screens/GeneralSettingsView.swift`
- `Hugo/Features/Settings/Screens/YearlyGoalPacingSettingsView.swift` (delete)
- `Hugo/Features/Settings/Views/CurrentMonthCalculationPreview.swift` (delete)
- `Hugo/Features/Settings/Domain/CurrentMonthCalculation.swift` (delete)
- `Hugo/Features/Settings/Domain/SyncedSettings.swift`
- `Hugo/Domain/UserDefaultsKeys.swift`
- `HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift`
- `HugoTests/Features/ServiceYear/Domain/YearlyGoalPacingTests.swift` (delete)
- `HugoTests/Features/Settings/Domain/CurrentMonthCalculationTests.swift` (delete)
- `Hugo/Resources/Localizable.xcstrings` (delete 15 keys, nothing else)
- `CONTEXT.md`

**Out of scope:**
- `CenteredProgressBar`, `barFraction` and the Year tab's look. Plan 131 replaces the bar.
- A help article about the calculation. Plan 130 writes it.
- Removing the old value from `UserDefaults` or iCloud key-value storage. It is harmless.
- `Hugo/Resources/Markdown/Legal/*/PrivacyPolicy.md`. It mentions "Service Year" under General; see Maintenance notes.
- `PlannerTargetSettingsView` and `SelectableOptionRow`. Both stay; the Planner still uses them.

## Git workflow

- Work on `main` directly. No branch, no worktree.
- One commit after `Scripts/verify.sh` exits 0: `refactor: always spread the yearly goal target across the current month`.
- Never stage `.claude/`, `plans/` or `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`. Do not push.

## Steps

### Step 1: Move the day fraction into `YearlyGoalProgress` and drop the `pacing` parameter

In `Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift`:

1. Remove the `pacing: YearlyGoalPacing,` parameter from `make`. The signature becomes:

```swift
    /// Nil when the status has no yearly goal.
    static func make(
        report: TheocraticYearReport,
        status: PublisherStatus,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> YearlyGoalProgress? {
```

2. Replace `pacing.currentMonthFraction(now: now, calendar: calendar)` with `currentMonthFraction(now: now, calendar: calendar)`.

3. Add this static function inside `struct YearlyGoalProgress`, right after `make`:

```swift
    /// How much of the current month's goal is expected by `now`: today's day
    /// number divided by the number of days in the month. Today counts as a
    /// whole day, so November 1 gives 1/30 and November 15 gives 15/30.
    static func currentMonthFraction(now: Date, calendar: Calendar) -> Double {
        let day = calendar.component(.day, from: now)
        return Double(day) / Double(now.yearMonth(using: calendar).lastDay(calendar: calendar))
    }
```

4. Update the doc comment on `expectedSeconds` to: `/// Seconds the user should have by now: the monthly goal for each month that is over, plus the current month's goal spread by day. Nil when the year has not started.`

### Step 2: Update the callers

1. `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift`: delete line 13 (`@AppStorage(UserDefaultsKeys.yearlyGoalPacing) private var pacing: YearlyGoalPacing = .proRated`) and change line 44 to `return YearlyGoalProgress.make(report: report, status: status)`.
2. `Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift` preview and `Hugo/Features/ServiceYear/Screens/ServiceYearDetailView.swift` preview: change `YearlyGoalProgress.make(report: report, status: $0, pacing: .proRated)` to `YearlyGoalProgress.make(report: report, status: $0)`.

### Step 3: Delete the setting

1. Delete these files:
   - `Hugo/Features/ServiceYear/Domain/YearlyGoalPacing.swift`
   - `Hugo/Features/Settings/Screens/YearlyGoalPacingSettingsView.swift`
   - `Hugo/Features/Settings/Views/CurrentMonthCalculationPreview.swift`
   - `Hugo/Features/Settings/Domain/CurrentMonthCalculation.swift`
   - `HugoTests/Features/Settings/Domain/CurrentMonthCalculationTests.swift`
2. In `GeneralSettingsView.swift`, delete the `@AppStorage(UserDefaultsKeys.yearlyGoalPacing) ...` line and the whole `if status?.yearlyGoalRule != nil { Section { ... } header: { Text("year.subtitle") } }` block. Keep `statusID`, `status`, the Planner section and the minute interval section.
3. In `SyncedSettings.swift`, delete the line `UserDefaultsKeys.yearlyGoalPacing,`.
4. In `UserDefaultsKeys.swift`, delete `static let yearlyGoalPacing = "yearlyGoalPacing"`.

The project uses synchronized folder groups (`PBXFileSystemSynchronizedRootGroup` in `Hugo.xcodeproj/project.pbxproj`), so deleting a file from disk removes it from the build. Do not edit `project.pbxproj`.

**Verify**: `grep -rn "YearlyGoalPacing\|yearlyGoalPacing\|CurrentMonthCalculation" Hugo --include='*.swift'` → no output. Then the build command → `0`.

### Step 4: Update the tests

In `HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift`:

1. Delete the tests `completedMonthsPacingIgnoresTheCurrentMonth` and `includeCurrentMonthPacingExpectsTheWholeMonth`.
2. In `statusWithoutAYearlyGoalHasNoProgress`, delete the line `pacing: .proRated,`.
3. In the helper `makeProgress`, delete the parameter `pacing: YearlyGoalPacing = .proRated,` and the argument `pacing: pacing,`.
4. Add these two tests (the first moves from `YearlyGoalPacingTests.swift`; the second pins the worked example that plan 130's help article uses):

```swift
    @Test(arguments: [
        (2026, 11, 3, 0.1),
        (2026, 11, 1, 1.0 / 30.0),
        (2026, 11, 30, 1.0),
        (2028, 2, 29, 1.0),
        (2027, 2, 1, 1.0 / 28.0),
    ])
    func currentMonthFractionCountsTodayAsAWholeDay(argument: (Int, Int, Int, Double)) {
        let actual = YearlyGoalProgress.currentMonthFraction(
            now: date(argument.0, argument.1, argument.2), calendar: calendar)
        #expect(abs(actual - argument.3) < 1e-9)
    }

    /// The example in the "Your target this month" help article: a regular
    /// pioneer (50 hours a month) on November 15 expects 2 x 50 + 50 x 15/30 = 125 hours.
    @Test
    func midNovemberExpectsOneHundredTwentyFiveHours() {
        let progress = makeProgress(entries: septemberAndOctober(), now: date(2026, 11, 15, hour: 12))
        #expect(progress.expectedSeconds == TimeInterval(125 * 3_600))
    }
```

The test struct's `date(_:_:_:hour:)` helper has a default `hour: Int = 0`, so `date(2026, 11, 3)` compiles.

5. Delete `HugoTests/Features/ServiceYear/Domain/YearlyGoalPacingTests.swift`.

**Verify**: focused tests command → `** TEST SUCCEEDED **`. The output lists `currentMonthFractionCountsTodayAsAWholeDay` with 5 arguments and `midNovemberExpectsOneHundredTwentyFiveHours` as passed.

### Step 5: Delete the 15 unused strings

Save this helper as `/tmp/xcstrings_edit.py` (outside the repo; do not commit it). It is the helper from plan 042, which writes the catalog back byte for byte:

```python
import json
import re

PATH = "Hugo/Resources/Localizable.xcstrings"


def load():
    with open(PATH, encoding="utf-8") as f:
        return json.loads(f.read())


def save(data):
    out = json.dumps(data, indent=2, separators=(",", " : "), ensure_ascii=False)
    out = re.sub(r"^( *)(.*)\{\}", lambda m: f"{m.group(1)}{m.group(2)}{{\n\n{m.group(1)}}}", out, flags=re.M)
    with open(PATH, "w", encoding="utf-8") as f:
        f.write(out)
```

First confirm it is lossless: `python3 -I -c "import sys; sys.path.insert(0, '/tmp'); import xcstrings_edit as x; x.save(x.load())"`, then `git diff --stat -- Hugo/Resources/Localizable.xcstrings` → prints nothing. If it prints a change, run `git checkout -- Hugo/Resources/Localizable.xcstrings` and STOP.

Then delete the keys:

```sh
python3 -I -c "
import sys; sys.path.insert(0, '/tmp'); import xcstrings_edit as x
d = x.load(); s = d['strings']
keys = [k for k in s if k == 'settings.yearlyGoal.pacing' or k.startswith('settings.yearlyGoal.pacing.')] + ['year.subtitle']
assert len(keys) == 15, keys
for k in keys: del s[k]
x.save(d)
print('deleted', len(keys))
"
```

**Verify**:
- The script prints `deleted 15`. If the `assert` fails, STOP and report the printed list.
- `git diff --numstat -- Hugo/Resources/Localizable.xcstrings` → `0` added lines and 256 removed lines (checked by the advisor on a copy of the catalog at `c918888`). Added lines mean something else changed: reset the file and STOP.
- `grep -rn "settings.yearlyGoal\|\"year.subtitle\"" Hugo --include='*.swift'` → no output.

### Step 6: Update `CONTEXT.md`

In the Goals section, replace the **Expected time** entry and delete the **Current month calculation** entry, so the two entries become this one:

```markdown
**Expected time**:
The credited time the user should have by now to reach the yearly goal at an even pace: the monthly goal for each month of the theocratic year that is over, plus the current month's goal spread across the month. The current month adds its monthly goal times today's day number divided by the number of days in the month, so today counts as a whole day. On November 15 a regular pioneer (50 hours a month) expects 2 x 50 + 50 x 15/30 = 125 hours. For a past year it is the whole yearly goal; before the year starts there is none.
```

**Verify**: `grep -n "Current month calculation\|YearlyGoalPacing" CONTEXT.md` → no output.

### Step 7: Full gate and commit

Run `Scripts/verify.sh`. After it, `git diff --numstat -- Hugo/Resources/Localizable.xcstrings` must still show `0` added lines (a build must not add or mark stale anything). Commit the in-scope files with the message from "Git workflow".

## Test plan

- Moved: `currentMonthFractionCountsTodayAsAWholeDay` (5 cases: day 3 of 30, first day, last day, February 29 in a leap year, February 1).
- New: `midNovemberExpectsOneHundredTwentyFiveHours` (the help article's example).
- Kept unchanged: `onPaceAtTheEndOfOctoberWhenProRated`, `proRatedExpectationGrowsWithTheDayOfTheMonth` (105 hours on November 3), `aPastYearExpectsTheFullYearlyGoal`, `aFutureYearHasNoExpectationAndNoBar` and the rest of `YearlyGoalProgressTests`.
- Deleted: the two tests of removed options, `YearlyGoalPacingTests` (fixed fractions) and `CurrentMonthCalculationTests`.
- `Scripts/verify.sh` → exit 0.

Owner check (optional, no device needed): Settings > General no longer shows a "Service Year" section; the Year tab shows the same pace sentence as before for a user who had the default option.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -rn "YearlyGoalPacing\|yearlyGoalPacing\|CurrentMonthCalculation" Hugo HugoTests` → no output
- [ ] `grep -c "settings.yearlyGoal" Hugo/Resources/Localizable.xcstrings` → `0`
- [ ] `test ! -e Hugo/Features/ServiceYear/Domain/YearlyGoalPacing.swift && test ! -e Hugo/Features/Settings/Screens/YearlyGoalPacingSettingsView.swift` → exit 0
- [ ] `grep -n "currentMonthFractionCountsTodayAsAWholeDay\|midNovemberExpectsOneHundredTwentyFiveHours" HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift` → 2 matches
- [ ] `git status --short` shows no modified files outside the in-scope list, except the owner's `Debug.xcscheme`

## STOP conditions

- The drift check shows changes and the excerpts above no longer match.
- `grep -rn "YearlyGoalPacing" Hugo/Persistence` finds a match (the enum is persisted in SwiftData after all; then it must stay).
- Something other than the files in "Current state" uses `CurrentMonthCalculation`, `YearlyGoalPacingSettingsView` or `UserDefaultsKeys.yearlyGoalPacing`.
- The catalog helper is not lossless, or Step 5 finds a number of keys other than 15.
- A test outside `YearlyGoalProgressTests` fails because of the removed parameter.

## Maintenance notes

- Plan 131 builds on the new `make(report:status:now:calendar:)` signature and checks for it in its drift check.
- Plan 130 writes the "Your target this month" help article with the November 15 example that `midNovemberExpectsOneHundredTwentyFiveHours` pins. If the rule ever changes, update the article in both languages and that test together.
- Owner follow-up: the privacy policy (app copies `Hugo/Resources/Markdown/Legal/*/PrivacyPolicy.md` line 29, and the website) says "your settings under General (Planner, Service Year and the minute interval)". Service Year is no longer under General. Change it to "(Planner and the minute interval)" / "(Planlæg og minutinterval)" the next time the policy is updated.
- Old builds on another device still sync the `yearlyGoalPacing` key through iCloud. That is harmless: this build never reads it.
