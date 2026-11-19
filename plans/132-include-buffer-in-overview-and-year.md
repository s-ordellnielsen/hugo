# Plan 132: Let the Buffer count in Overview and on the Year tab, behind a switch

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 5af77c8..HEAD -- Hugo/Features/ServiceYear Hugo/Features/Overview Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift Hugo/Features/Settings Hugo/Domain/UserDefaultsKeys.swift Hugo/Resources CONTEXT.md HugoTests/Features/ServiceYear HugoTests/Features/Overview HugoTests/Features/Settings`
> Expected: no output. If any file changed, compare the "Current state"
> excerpts with the live code and STOP on a mismatch.
> Also run `git status --short` and expect only
> `M Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` (the owner's own
> edit; never touch or commit it) and this plan's own files.

## Status

- **Priority**: P2
- **Effort**: M + owner (device check of the switch and both screens, in English and Danish, largest text, VoiceOver)
- **Risk**: LOW. A new synced boolean setting and one optional parameter on two pure functions. No SwiftData change, so no schema version and no CloudKit deploy.
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `5af77c8`, 2026-11-19
- **Issue**: [SLN-315](https://linear.app/sebastianln/issue/SLN-315)

## Why this matters

The user can set a **Buffer** (extra hours on top of the monthly goal) under
Settings > General > Monthly Target. Today only the Planner uses it. Overview
and the Year tab still measure against the bare goal, so a user with a 5 hour
Buffer can look "done" in Overview while the Planner says they are short.

This plan adds one switch, off by default: **Include Buffer in Overview and
Year**. When it is on, the Overview circle fills against goal plus Buffer, and
the Year tab's goal bar adds the Buffer to every month's goal when it works out
"Target today" and the end of the bar's scale. Counted time, reports and
totals never change; only the target moves. It is off by default because a
regular pioneer with a 5 hour Buffer would no longer fill the Overview circle
at 50 hours.

Decisions already made by the owner (2026-11-19). Do not reopen them:

- **Buffer only.** The "Adjusted to yearly goal" base is not added to Overview
  or the Year tab.
- **One switch** controls both screens.
- **Current theocratic year only.** A finished year keeps its original goal,
  because the Buffer is today's preference and must not rewrite history.
- **Past months of the current year** use today's Buffer too. This is an accepted
  approximation: "Target today" is a pacing guide, not a record.

## Current state

### Vocabulary (`CONTEXT.md`, quoted; use these words in names and comments)

> **Monthly target**: The hours the Planner aims at for one month: the monthly goal, or an adjusted yearly-goal base, plus Buffer. Without a publisher-status goal, the selected duration is the personal monthly target.

> **Buffer**: The nonnegative hours added to the base monthly target. Without a publisher-status goal, the same preference sets the whole personal monthly target. Settings calls it "Buffer" / "Buffer". Historical storage and API names remain `plannerExtraHours` / `extraHours`. The Planner bar draws the base as a solid fill and Buffer as a separate faded extension.

> **Expected time**: The counted time the user should have by now to reach the yearly goal at an even pace: the monthly goal for each month of the theocratic year that is over, plus the current month's goal spread across the month. ... On November 15 a regular pioneer (50 hours a month) expects 2 x 50 + 50 x 15/30 = 125 hours. For a past year it is the whole yearly goal; before the year starts there is none. The Year tab's goal bar marks it as "Target today" / "Mål i dag", on a scale that ends at the monthly goal times the months so far.

### Settings storage

`Hugo/Domain/UserDefaultsKeys.swift`:

```swift
    static let publisherStatus = "publisherStatus"
    static let plannerTargetBase = "plannerTargetBase"
    static let plannerExtraHours = "plannerExtraHours"
```

`Hugo/Features/Settings/Domain/SyncedSettings.swift`:

```swift
    static let keys: [String] = [
        UserDefaultsKeys.publisherStatus,
        UserDefaultsKeys.plannerTargetBase,
        UserDefaultsKeys.plannerExtraHours,
        UserDefaultsKeys.durationMinuteInterval,
        ...
```

`SettingsSyncService` copies any key in that list between `UserDefaults` and
iCloud key-value storage and compares values through `NSObject.isEqual`, so a
`Bool` (stored as `NSNumber`) syncs without changes.

### The settings screen (`Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift`)

```swift
    @AppStorage(UserDefaultsKeys.plannerTargetBase) private var base: PlannerTargetBase = .monthlyGoal
    @AppStorage(UserDefaultsKeys.plannerExtraHours) private var extraHours = 0
    ...
            Section {
                Stepper(value: $extraHours, in: 0...30) {
                    LabeledContent(
                        hasGoal
                            ? LocalizedStringKey("planner.target.extra") : LocalizedStringKey("planner.target.title"),
                        value: ServiceDurationFormatter.hoursString(
                            from: TimeInterval(extraHours) * 3_600, locale: locale))
                }
            } footer: {
                Text(
                    hasGoal
                        ? LocalizedStringKey("planner.target.extra.footer")
                        : LocalizedStringKey("planner.target.extra.footer.noGoal"))
            }
        }
        .navigationTitle("planner.target.title")
```

The screen is reached from `Hugo/Features/Settings/Screens/GeneralSettingsView.swift`,
whose first section has a "Planner" header that no longer describes what the
setting does:

```swift
            Section {
                NavigationLink(destination: PlannerTargetSettingsView()) {
                    LabeledContent {
                        Text(PlannerTarget.settingSummary(base: base, extraHours: extraHours, status: status))
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("planner.target.title", systemImage: "calendar")
                    }
                }
            } header: {
                Text("tab.planner")
            }
```

`planner.target.title` is "Monthly Target" in English and "Mål for måneden" in
Danish. `tab.planner` is still used by `PlannerView.swift:105`; do not delete
that key.

### Year tab (`Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift`)

`make` today (the lines that matter):

```swift
    static func make(
        report: TheocraticYearReport,
        status: PublisherStatus,
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
                return total + rule.monthlyGoalSeconds * currentMonthFraction(now: now, calendar: calendar)
            }
        }

        let monthsSoFar = report.months.filter { $0.id <= current }
        let scaleEndMonth = monthsSoFar.last?.id
        let scaleEndSeconds = scaleEndMonth.map { _ in rule.monthlyGoalSeconds * Double(monthsSoFar.count) }
        let isYearOver = report.months.last.map { $0.id < current } ?? false

        return YearlyGoalProgress(
            creditedSeconds: months.reduce(0) { $0 + $1.creditedSeconds },
            ...
            monthlyGoalSeconds: rule.monthlyGoalSeconds,
            ...
```

Everything on the goal bar (`fillFraction`, `markerFraction`, `paceSentence`,
`scaleEndSeconds`, the caption "Goal by the end of November: 150 hours")
derives from `expectedSeconds` and `scaleEndSeconds`, so changing those two
values moves the whole card and the detail screen consistently.
`ServiceYearDetailView` and `TheocraticYearTotalsView` receive a finished
`YearlyGoalProgress`; they need no change.

The one place that builds it for the screen is
`Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift`:

```swift
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""
    ...
    private func progress(for report: TheocraticYearReport) -> YearlyGoalProgress? {
        guard let status else { return nil }
        return YearlyGoalProgress.make(report: report, status: status)
    }
```

The pager builds one page per theocratic year, so past years go through this
same function. The rule "current year only" therefore lives inside `make`
(see Step 2), not in the view.

### Overview (`Hugo/Features/Overview/Domain/OverviewMetrics.swift`)

```swift
    static func make(entries: [Entry], status: PublisherStatus?, now: Date, calendar: Calendar) -> OverviewMetrics {
        let totalHours = entries.reduce(0) { $0 + max($1.duration, 0) } / 3600
        let goal = Double(status?.monthlyGoal ?? 0)
        let days = Double(calendar.range(of: .day, in: .month, for: now)?.count ?? 0)
        let day = Double(calendar.component(.day, from: now))
        let expected = days > 0 ? day / days * goal : 0
        ...
```

`OverviewView.swift` (`OverviewDayView`) calls it and feeds `metrics.monthlyGoal`
to `MonthlyCircleFill.make(monthlyGoalHours:...)`, which fills the circle and
names the goal in the card's accessibility value. `MonthlyCircleFill` and
`MonthlyProgressCard` need no change.

```swift
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""
    ...
    private var metrics: OverviewMetrics {
        OverviewMetrics.make(
            entries: entries, status: PublisherStatus.status(for: statusID), now: .now, calendar: .current)
    }
```

Without a status goal, `monthlyGoal` is 0 and the circle falls back to plans.
With the switch on and a Buffer above 0, the goal becomes the Buffer, which
matches the glossary ("without a publisher-status goal, the same preference
sets the whole personal monthly target") and what the Planner already does.

### Conventions to match

- Pure value logic is `nonisolated` where the file already is, with defaults on
  new parameters so existing callers and tests compile unchanged. Exemplar:
  `YearlyGoalProgress.make`'s `now:` and `calendar:` defaults.
- Tests use Swift Testing. Exemplars: `HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift`
  (its `makeProgress` helper, fixed `calendar`, `status`, `septemberAndOctober()`)
  and `HugoTests/Features/Overview/Domain/OverviewMetricsTests.swift`.
- Strings live in `Hugo/Resources/Localizable.xcstrings`, English and Danish,
  every entry with a `comment`. Keys are sorted alphabetically.
- Indentation is 4 spaces (tabs fail lint). Views stay purely visual: no
  arithmetic in `body`.
- Danish tab names: Overview = "Overblik", Year = "Tjenesteår", Settings = "Indstillinger", General = "Generelt".

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint one file | `xcrun swift-format lint --strict <file>` | exit 0, no output |
| Whole gate | `Scripts/verify.sh` | exit 0 (lint, all tests, analyze). Takes several minutes. |
| JSON check | `python3 -c "import json,sys; json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0, no output |

`Scripts/verify.sh` takes no arguments and runs the whole suite. Run it once at
Step 7. For earlier steps, lint each file you touch.

## Scope

**In scope** (the only files you may modify):

- `Hugo/Domain/UserDefaultsKeys.swift`
- `Hugo/Features/Settings/Domain/SyncedSettings.swift`
- `Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift`
- `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift`
- `Hugo/Features/Overview/Domain/OverviewMetrics.swift`
- `Hugo/Features/Overview/Screens/OverviewView.swift`
- `Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift`
- `Hugo/Features/Settings/Screens/GeneralSettingsView.swift`
- `Hugo/Resources/Localizable.xcstrings`
- `Hugo/Resources/Markdown/Help/Base.lproj/TargetThisMonth.md`
- `Hugo/Resources/Markdown/Help/da.lproj/TargetThisMonth.md`
- `CONTEXT.md`
- `HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift`
- `HugoTests/Features/Overview/Domain/OverviewMetricsTests.swift`
- `HugoTests/Features/Settings/Services/SettingsSyncServiceTests.swift`
- `plans/README.md` (status row)

**Out of scope** (do NOT touch):

- `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`: the owner's uncommitted edit. Never stage it.
- `PlannerTarget`, `PlannerTargetBase`, `PlannerView` and the Planner's own target maths. The Planner already uses the Buffer.
- The "Adjusted to yearly goal" base. It is not added to Overview or the Year tab.
- `MonthlyCircleFill`, `MonthlyProgressCard`, `TheocraticYearTotalsView`, `ServiceYearDetailView`: they already follow the values they are given.
- Any SwiftData model, schema, migration or CloudKit file.
- Renaming `plannerExtraHours` or `extraHours`. Historical names stay.
- Report composition, rounding, credit rules and year totals.

## Git workflow

- Commit straight to `main` (the owner's convention for plan execution). Do not create a branch.
- One commit at the end, after `Scripts/verify.sh` exits 0. Conventional Commits, as in `git log`: `feat: let the Buffer count in Overview and the Year tab`.
- Stage by explicit path. Never `git add -A` or `git add .`, because the owner's `Debug.xcscheme` edit is unstaged.
- Do NOT push.

## Steps

### Step 1: Add the setting key and sync it

In `UserDefaultsKeys.swift`, add directly under `plannerExtraHours`:

```swift
    /// Whether Overview and the Year tab add the Buffer to the goal they show. Off by default.
    static let bufferInOverviewAndYear = "bufferInOverviewAndYear"
```

In `SyncedSettings.swift`, add `UserDefaultsKeys.bufferInOverviewAndYear,` to
`keys` right after `UserDefaultsKeys.plannerExtraHours,`.

In `SettingsSyncServiceTests.swift`, add a test next to
`aChangeFromAnotherDeviceIsWrittenToUserDefaults`, same structure:

```swift
    @Test
    func theBufferSwitchFromAnotherDeviceIsWrittenToUserDefaults() {
        service.start()
        cloud.values[UserDefaultsKeys.bufferInOverviewAndYear] = true

        service.pullFromCloud()

        #expect(defaults.bool(forKey: UserDefaultsKeys.bufferInOverviewAndYear))
    }
```

and one asserting `SyncedSettings.keys.contains(UserDefaultsKeys.bufferInOverviewAndYear)`.

**Verify**: `xcrun swift-format lint --strict Hugo/Domain/UserDefaultsKeys.swift Hugo/Features/Settings/Domain/SyncedSettings.swift HugoTests/Features/Settings/Services/SettingsSyncServiceTests.swift` → exit 0.

### Step 2: Let `YearlyGoalProgress.make` take a Buffer

Add a parameter `bufferSeconds: TimeInterval = 0` after `status:` and before
`now:`. Inside `make`:

1. Move the `isYearOver` line (`let isYearOver = report.months.last.map { $0.id < current } ?? false`) up, to just after `let current = ...`.
2. Add, with this doc comment:

```swift
        // The Buffer is today's preference, so it applies to the current
        // theocratic year only. A finished year keeps its original goal.
        let monthlyTargetSeconds = rule.monthlyGoalSeconds + (isYearOver ? 0 : max(0, bufferSeconds))
```

3. Replace `rule.monthlyGoalSeconds` with `monthlyTargetSeconds` in exactly three
   places: the two uses in the `expectedSeconds` reduce, and the `scaleEndSeconds`
   line.
4. Leave `monthlyGoalSeconds: rule.monthlyGoalSeconds` in the initializer call as it is,
   so `monthlyGoalSeconds` stays the plain goal. `creditedSeconds`,
   `yearlyGoalSeconds` and `yearTotalSeconds` also stay as they are.
5. Update the doc comments on `expectedSeconds` and `scaleEndSeconds` to say
   "the monthly goal, plus the Buffer when one is passed".

**Verify**: `xcrun swift-format lint --strict Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift` → exit 0. `grep -c "rule.monthlyGoalSeconds" Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift` → `2` (the new `monthlyTargetSeconds` line and the initializer argument).

### Step 3: Tests for the Year tab

In `YearlyGoalProgressTests.swift`, give the `makeProgress` helper a
`bufferSeconds: TimeInterval = 0` parameter that it passes to `make`, then add
these tests near `midNovemberScaleEndsAtThreeMonthlyGoals`. All use the
existing fixtures (`status` = regular pioneer, `septemberAndOctober()`,
`date(...)`), a Buffer of `5 * 3_600`, and `now` = `date(2026, 11, 15, hour: 12)`
unless stated:

1. `bufferAddsToEveryMonthsGoal`: `expectedSeconds == 137.5 * 3_600` (2 x 55 + 55 x 15/30), `scaleEndSeconds == 165 * 3_600`, `differenceSeconds == -37.5 * 3_600` (counted 100 h).
2. `bufferMovesTheMarkerAndNotTheFill`: `markerFraction` ≈ 137.5/165, `fillFraction` ≈ 100/165 (tolerance `1e-9`).
3. `aZeroBufferChangesNothing`: `makeProgress(..., bufferSeconds: 0)` equals `makeProgress(...)` with no argument (`YearlyGoalProgress` is `Equatable`).
4. `bufferDoesNotChangeCountedTime`: `creditedSeconds`, `yearTotalSeconds`, `yearlyGoalSeconds` and `monthlyGoalSeconds` are the same with and without a Buffer.
5. `aNegativeBufferIsIgnored`: `bufferSeconds: -3_600` equals no Buffer.
6. `aFinishedYearIgnoresTheBuffer`: `now` = `date(2028, 1, 15)`, Buffer 5 h → `scaleEndSeconds == 600 * 3_600`, `markerFraction == nil`, and the whole value equals the no-Buffer result.
7. `bufferShiftsTheFirstMonthScale`: `now` = `date(2026, 9, 10, hour: 12)`, Buffer 5 h → `scaleEndSeconds == 55 * 3_600`, `markerFraction` ≈ 1/3 (it is a share of the scale, so unchanged).

**Verify**: `xcrun swift-format lint --strict HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift` → exit 0. (The tests run in Step 7.)

### Step 4: Let `OverviewMetrics.make` take a Buffer

Add `bufferHours: Int = 0` after `status:` (before `now:`). Replace the goal line:

```swift
        let goal = Double((status?.monthlyGoal ?? 0) + max(0, bufferHours))
```

Add a doc comment on `make`: "`bufferHours` is the Buffer to add to the goal, or 0. Without a status goal it is the whole goal." Nothing else changes.

In `OverviewMetricsTests.swift` add:

1. `bufferAddsToTheMonthlyGoal`: auxiliary pioneer (30), `bufferHours: 5`, now Jan 15 → `monthlyGoal == 35` and `expectedProgress` ≈ 15/31 x 35.
2. `bufferIsTheWholeGoalWithoutAStatus`: `status: nil`, `bufferHours: 5` → `monthlyGoal == 5`.
3. `aNegativeBufferIsIgnored`: `bufferHours: -2` → same goal as without.
4. `aZeroBufferChangesNothing`: `bufferHours: 0` gives `monthlyGoal == 30` for the auxiliary pioneer.

**Verify**: `xcrun swift-format lint --strict Hugo/Features/Overview/Domain/OverviewMetrics.swift HugoTests/Features/Overview/Domain/OverviewMetricsTests.swift` → exit 0.

### Step 5: Wire the two screens

`OverviewView.swift`, in `OverviewDayView`, next to the `statusID` property add:

```swift
    @AppStorage(UserDefaultsKeys.plannerExtraHours) private var extraHours = 0
    @AppStorage(UserDefaultsKeys.bufferInOverviewAndYear) private var includeBuffer = false
```

and pass `bufferHours: includeBuffer ? extraHours : 0` in the `OverviewMetrics.make` call.

`ServiceYearPageView.swift`, next to `statusID` add the same two properties, and
in `progress(for:)` pass
`bufferSeconds: includeBuffer ? TimeInterval(extraHours) * 3_600 : 0`.

Do not touch any other call to `YearlyGoalProgress.make` (the previews in
`TheocraticYearTotalsView` and `ServiceYearDetailView` rely on the default `0`).

**Verify**: `xcrun swift-format lint --strict Hugo/Features/Overview/Screens/OverviewView.swift Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift` → exit 0. `grep -rn "bufferInOverviewAndYear" Hugo` → matches in `UserDefaultsKeys.swift`, `SyncedSettings.swift`, `OverviewView.swift`, `ServiceYearPageView.swift` (the settings view is added in Step 6).

### Step 6: The switch, the section header, strings and docs

**Settings screen.** In `PlannerTargetSettingsView.swift` add
`@AppStorage(UserDefaultsKeys.bufferInOverviewAndYear) private var includeBuffer = false`
and, as a new `Section` directly after the Buffer stepper section:

```swift
            Section {
                Toggle("planner.target.includeBuffer", isOn: $includeBuffer)
            } footer: {
                Text("planner.target.includeBuffer.footer")
            }
```

Show it always, even when the Buffer is 0. A row that appears and disappears is
harder to find.

**General section header.** In `GeneralSettingsView.swift`, remove the
`header: { Text("tab.planner") }` from the first section (keep the `Section { ... }`
content as it is, so the closure becomes a plain `Section { ... }`). The row
already says "Monthly Target", and a header with the same words would repeat it.
Keep the `tab.planner` string; `PlannerView` uses it.

**Strings.** In `Localizable.xcstrings`, insert two entries between
`planner.target.extra.footer.noGoal` and `planner.target.none`, in the same
JSON style as their neighbours (2-space indent, ` : ` separators, `"state" : "translated"`):

| Key | Comment | en | da |
|---|---|---|---|
| `planner.target.includeBuffer` | Label of the switch that makes Overview and the Year tab count the Buffer. | Include Buffer in Overview and Year | Medregn buffer i Overblik og Tjenesteår |
| `planner.target.includeBuffer.footer` | Footer under the switch that makes Overview and the Year tab count the Buffer. | Overview and Year add your Buffer to the goal they show. Turn off to see your goal alone. | Overblik og Tjenesteår lægger din buffer til det mål, de viser. Slå fra for kun at se dit mål. |

**Help article.** Append this section at the end of
`Hugo/Resources/Markdown/Help/Base.lproj/TargetThisMonth.md`, after a blank line:

```markdown

## If you set a Buffer

Under Settings > General > Monthly Target you can set a Buffer, extra hours on top of your goal. The Planner always counts it. You can also turn on "Include Buffer in Overview and Year". Each month's goal then grows by your Buffer.

A regular pioneer with a 5 hour Buffer has a target of 55 hours a month. On November 15, the target today is 2 × 55 + 55 × 15 ÷ 30 = **137 hours and 30 minutes**. The hours that count toward your goal do not change, only the target.

The Buffer only applies to the current theocratic year. A finished year keeps its original goal.
```

and the Danish equivalent at the end of `da.lproj/TargetThisMonth.md`:

```markdown

## Hvis du sætter en buffer

Under Indstillinger > Generelt > Mål for måneden kan du sætte en buffer, ekstra timer oven på dit mål. Planlæg medregner den altid. Du kan også slå "Medregn buffer i Overblik og Tjenesteår" til. Hver måneds mål bliver så større med din buffer.

En almindelig pioner med 5 timers buffer har et mål på 55 timer om måneden. Den 15. november er målet i dag 2 × 55 + 55 × 15 ÷ 30 = **137 timer og 30 minutter**. De timer, der tæller med mod målet, ændrer sig ikke, kun målet.

Bufferen gælder kun for det nuværende tjenesteår. Et afsluttet år beholder sit oprindelige mål.
```

**CONTEXT.md.** Replace the **Buffer** paragraph's last sentence and add to it, so it reads:

> The nonnegative hours added to the base monthly target. Without a publisher-status goal, the same preference sets the whole personal monthly target. Settings calls it "Buffer" / "Buffer". Historical storage and API names remain `plannerExtraHours` / `extraHours`. The Planner bar draws the base as a solid fill and Buffer as a separate faded extension. The Planner always counts it. Overview and the Year tab count it only when the user turns on "Include Buffer in Overview and Year" / "Medregn buffer i Overblik og Tjenesteår" (`bufferInOverviewAndYear`, off by default, synced). The Year tab adds it only in the current theocratic year, and never adds the adjusted target.

and append to the end of the **Expected time** paragraph: "With the Buffer switch on, each month's goal in this sum, and in the scale, is the monthly goal plus Buffer (current theocratic year only)."

In the **Synced setting** entry, add "the Buffer switch" to the list of examples if the sentence lists them; otherwise leave it.

**Verify**:
- `python3 -c "import json; json.load(open('Hugo/Resources/Localizable.xcstrings'))"` → exit 0.
- `grep -c "planner.target.includeBuffer" Hugo/Resources/Localizable.xcstrings` → `2`.
- `git diff --stat Hugo/Resources/Localizable.xcstrings` → only added lines (no deletions).
- `xcrun swift-format lint --strict Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift Hugo/Features/Settings/Screens/GeneralSettingsView.swift` → exit 0.

### Step 7: Run the gate and commit

Run `Scripts/verify.sh`. Fix failures that come from your own changes. Then
stage the in-scope files by explicit path (never `Debug.xcscheme`) and commit
with the message from "Git workflow".

**Verify**: `Scripts/verify.sh` → exit 0. `git status --short` → only the owner's `Debug.xcscheme` edit remains (and `plans/README.md` if you have not committed it yet).

## Test plan

New tests are listed in Steps 1, 3 and 4: 2 in `SettingsSyncServiceTests`, 7 in
`YearlyGoalProgressTests`, 4 in `OverviewMetricsTests` (13 in all).
Every existing test must still pass unchanged, which proves the default `0`
keeps current behaviour. No UI test is added. The owner checks the switch on a
device.

## Done criteria

All must hold:

- [ ] `Scripts/verify.sh` exits 0, and the new tests run and pass (13 of them).
- [ ] `grep -rn "bufferInOverviewAndYear" Hugo` matches in `UserDefaultsKeys.swift`, `SyncedSettings.swift`, `OverviewView.swift`, `ServiceYearPageView.swift` and `PlannerTargetSettingsView.swift`.
- [ ] `grep -rn "plannerExtraHours" Hugo` shows no new key name (only the existing storage key and the new `@AppStorage` reads).
- [ ] `grep -n "tab.planner" Hugo/Features/Settings/Screens/GeneralSettingsView.swift` returns nothing, and `PlannerView.swift` still uses `tab.planner`.
- [ ] No SwiftData model, schema or migration file is modified.
- [ ] `git status --short` shows no modification to files outside the in-scope list, and `Debug.xcscheme` is not in the commit.
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report back (do not improvise) if:

- The code at the locations in "Current state" does not match the excerpts.
- `YearlyGoalProgress.make` or `OverviewMetrics.make` has another caller with positional arguments that the new defaulted parameter breaks. (There should be none; `grep -rn "YearlyGoalProgress.make\|OverviewMetrics.make" Hugo HugoTests` shows labeled calls only.)
- The strings catalog diff shows any deleted or reordered line, which would mean the file was reformatted.
- A step's verification fails twice after a reasonable fix attempt.
- The fix appears to need a SwiftData change or an out-of-scope file.
- A help-article test or a string-catalog test fails and the cause is not your new text.

## Maintenance notes

- The Year tab's "Target today" now depends on a preference. If the publisher status timeline (SLN-226 to SLN-231) later gives each month its own goal, the Buffer should still add on top of each month's goal in `YearlyGoalProgress.make`.
- If a per-month Buffer history is ever wanted, "past months use today's Buffer" is the approximation to revisit.
- A reviewer should check that the rule "current year only" lives in `make` and not in the views, and that a Buffer of 0 gives identical output (test 3).
- Deferred on purpose: adding the adjusted-target base to the Year tab (it would feed the user's own progress back into their pace), and showing the Buffer as a faded extension on the Year bar or Overview circle.

---

## Revision 1 (2026-11-19): two switches instead of one, and no footer under them

> **Executor instructions for this revision**: Plan 132 is already committed
> as `8ce2448`. Apply only the changes below on top of it. Everything above
> still describes the code you start from. Follow "Git workflow" (work on
> `main`, stage by explicit path, never stage `Debug.xcscheme`, do not push)
> and the "STOP conditions". Skip `plans/README.md`; the reviewer maintains it.
>
> **Drift check (run first)**: `git log --oneline -3` shows `8ce2448` (or a
> later commit on top of it) and `git status --short` shows only
> `M Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`. Also
> `grep -rn "bufferInOverviewAndYear" Hugo HugoTests CONTEXT.md` must match
> the files listed in "Done criteria" above. If not, STOP.

### Why

The owner tried the single switch and wants to choose Overview and the Year
tab separately, and wants less explanatory text on the settings screen. The
Buffer is a nonnegative whole number, and each screen already takes it as a
plain value, so only the settings, the two call sites, the strings and the
docs change. `YearlyGoalProgress.make` and `OverviewMetrics.make` stay as they
are.

The single-switch key has only ever been installed on the owner's own
devices (a Debug build), so it is renamed without a migration. A leftover value
under the old key is never read.

### Changes

1. **Keys** (`Hugo/Domain/UserDefaultsKeys.swift`). Replace `bufferInOverviewAndYear` with two keys, each with a one-line doc comment, both off by default:

```swift
    /// Whether Overview adds the Buffer to the monthly goal it shows. Off by default.
    static let bufferInOverview = "bufferInOverview"
    /// Whether the Year tab adds the Buffer to the monthly goal it uses. Off by default.
    static let bufferInYear = "bufferInYear"
```

2. **Synced list** (`SyncedSettings.swift`). Replace the one entry with `UserDefaultsKeys.bufferInOverview,` and `UserDefaultsKeys.bufferInYear,` in that order, still right after `plannerExtraHours`.

3. **Settings screen** (`PlannerTargetSettingsView.swift`). Replace the `includeBuffer` property with `includeInOverview` (`@AppStorage(UserDefaultsKeys.bufferInOverview)`) and `includeInYear` (`@AppStorage(UserDefaultsKeys.bufferInYear)`), both `= false`. Replace the switch section with one section that has no header and **no footer**:

```swift
            Section {
                Toggle("planner.target.includeBuffer.overview", isOn: $includeInOverview)
                Toggle("planner.target.includeBuffer.year", isOn: $includeInYear)
            }
```

   Leave the Buffer stepper section and its existing footer exactly as they are.

4. **Call sites.** `OverviewView.swift` (`OverviewDayView`) reads `UserDefaultsKeys.bufferInOverview` into `includeBuffer` and keeps passing `bufferHours: includeBuffer ? extraHours : 0`. `ServiceYearPageView.swift` reads `UserDefaultsKeys.bufferInYear` into `includeBuffer` and keeps passing `bufferSeconds: includeBuffer ? TimeInterval(extraHours) * 3_600 : 0`. Only the key changes in each file.

5. **Strings** (`Localizable.xcstrings`). Delete the two entries `planner.target.includeBuffer` and `planner.target.includeBuffer.footer`. Add, in the same place (between `planner.target.extra.footer.noGoal` and `planner.target.none`, alphabetical), with a `comment` each:

| Key | Comment | en | da |
|---|---|---|---|
| `planner.target.includeBuffer.overview` | Label of the switch that makes Overview count the Buffer. | Include Buffer in Overview | Medregn buffer i Overblik |
| `planner.target.includeBuffer.year` | Label of the switch that makes the Year tab count the Buffer. | Include Buffer in Year | Medregn buffer i Tjenesteår |

6. **Help article** (`Base.lproj/TargetThisMonth.md` and `da.lproj/TargetThisMonth.md`). In the "If you set a Buffer" / "Hvis du sætter en buffer" section, change the second sentence of the first paragraph so it names both switches. English: `You can also turn on "Include Buffer in Overview", "Include Buffer in Year", or both. A month's goal there then grows by your Buffer.` Danish: `Du kan også slå "Medregn buffer i Overblik" og "Medregn buffer i Tjenesteår" til, en af dem eller begge. Månedens mål bliver så større med din buffer dér.` In the second paragraph, start the sentence with `With the Year switch on, a regular pioneer ...` / `Med Tjenesteår-kontakten slået til har en almindelig pioner ...` (it describes the Year tab's "target today"). Leave the example numbers and the third paragraph as they are.

7. **CONTEXT.md.** In **Buffer**, replace the sentence beginning `Overview and the Year tab count it only when the user turns on ...` with: `Overview and the Year tab each count it only when the user turns on their own switch, "Include Buffer in Overview" / "Medregn buffer i Overblik" (`bufferInOverview`) and "Include Buffer in Year" / "Medregn buffer i Tjenesteår" (`bufferInYear`), both off by default and synced. The Year tab adds it only in the current theocratic year, and never adds the adjusted target.` In **Expected time**, change `With the Buffer switch on,` to `With the Year switch on,`. In **Synced setting**, change `the Buffer switch` to `the Buffer switches`.

8. **Tests** (`SettingsSyncServiceTests.swift`). Replace the two tests added in Step 1 with: one that pulls `bufferInOverview = true` and `bufferInYear = true` from `cloud.values` and expects `defaults.bool(forKey:)` to be true for each, and one asserting `SyncedSettings.keys` contains both keys. No other test changes: `YearlyGoalProgressTests` and `OverviewMetricsTests` do not touch the keys.

### Verify and finish

- `grep -rn "bufferInOverviewAndYear" Hugo HugoTests CONTEXT.md` → no output.
- `grep -rn "includeBuffer.footer" Hugo` → no output.
- `python3 -c "import json; json.load(open('Hugo/Resources/Localizable.xcstrings'))"` → exit 0, and `git diff --stat Hugo/Resources/Localizable.xcstrings` shows only the two removed and two added entries.
- `xcrun swift-format lint --strict` on each Swift file you changed → exit 0.
- `Scripts/verify.sh` → exit 0. Keep the full output in a file under `/private/tmp/claude-501/-Users-sebastiannielsen-Documents-Areas-Personal-Apps-Hugo/aac047fd-971a-4205-b00b-3f151b982d7b/scratchpad/` and report the exit code from the file, not from a wrapper.
- One commit: `feat: choose Overview and the Year tab separately for the Buffer`. Do not push.

### Done criteria

- [ ] `Scripts/verify.sh` exits 0 and the two new sync tests pass.
- [ ] `grep -rn "bufferInOverview\b" Hugo` matches `UserDefaultsKeys.swift`, `SyncedSettings.swift`, `OverviewView.swift`, `PlannerTargetSettingsView.swift`; `grep -rn "bufferInYear\b" Hugo` matches `UserDefaultsKeys.swift`, `SyncedSettings.swift`, `ServiceYearPageView.swift`, `PlannerTargetSettingsView.swift`.
- [ ] The settings screen has no footer under the two switches, and the Buffer stepper's footer is unchanged.
- [ ] Only these files changed: `UserDefaultsKeys.swift`, `SyncedSettings.swift`, `PlannerTargetSettingsView.swift`, `OverviewView.swift`, `ServiceYearPageView.swift`, `Localizable.xcstrings`, both `TargetThisMonth.md`, `CONTEXT.md`, `SettingsSyncServiceTests.swift`.

### Revision STOP conditions

Stop and report if `YearlyGoalProgress.make` or `OverviewMetrics.make` would need to change, if the strings diff shows any other deleted or reordered line, or if a verification fails twice.

---

## Revision 2 (2026-11-19): one "Counts in" row that opens a page with the choices

> **Executor instructions for this revision**: Plan 132 and Revision 1 are
> already committed (`8ce2448`, `0bc313a`). Apply only the changes below on top
> of them. The earlier text still describes the code you start from, and the
> "Git workflow" and "STOP conditions" sections still apply (work on `main`,
> stage by explicit path, never stage `Debug.xcscheme`, do not push, skip
> `plans/README.md`).
>
> **Drift check (run first)**: `git log --oneline -3` shows `0bc313a` (or a
> later commit on top of it), `git status --short` shows only
> `M Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`, and
> `grep -n "bufferInOverview\|bufferInYear" Hugo/Features/Planner/Screens/PlannerTargetSettingsView.swift` matches the two `@AppStorage` lines and the two `Toggle` lines. If not, STOP.

### Why

After Revision 1 the Monthly Target screen shows the Buffer stepper and then a
separate section with two switches whose labels repeat "Include Buffer in". The
owner wants the Buffer and where it counts to read as one section, without the
repeated wording. The agreed design (Option A) is:

- The Buffer section holds the stepper and one navigation row, "Counts in",
  that shows the current choice on the right and opens a page.
- The page, titled "Count Buffer in" / "Medregn buffer i", lists three rows
  named after the tabs: Planner (a fixed "Always" with no switch), Overview and
  Year (switches). The title carries the context, so the rows are just names.
- The "Counts in" row appears only while the Buffer is above 0 hours, because
  the switches do nothing at 0.
- No footer on the new page. The existing footer under the stepper stays.

The two keys, the call sites and all the maths stay exactly as they are.

### Changes

1. **A summary function** in `Hugo/Features/Planner/Domain/PlannerTarget.swift`, next to `settingSummary`. Follow how `settingSummary` builds localized strings with a `locale` parameter (the `planner.target.none` and `planner.target.summary.withExtra` code there):

```swift
    /// The screens that count the Buffer, as shown on the "Counts in" row.
    /// The Planner always counts it.
    static func bufferScopeSummary(
        inOverview: Bool, inYear: Bool, locale: Locale = .current
    ) -> String
```

   It returns one of four whole strings (never built from parts, so Danish stays correct): Planner only, Planner and Overview, Planner and Year, all three. See the string keys in change 4.

2. **A new screen** `Hugo/Features/Planner/Screens/BufferScopeSettingsView.swift` (it belongs to the same feature as `PlannerTargetSettingsView`; `Screens` is the right role folder). Code shape:

```swift
import SwiftUI

/// Where the Buffer counts besides the Planner, which always counts it.
struct BufferScopeSettingsView: View {
    @AppStorage(UserDefaultsKeys.bufferInOverview) private var includeInOverview = false
    @AppStorage(UserDefaultsKeys.bufferInYear) private var includeInYear = false

    var body: some View {
        List {
            Section {
                LabeledContent {
                    Text("planner.target.countsIn.always")
                } label: {
                    Text("tab.planner")
                }
                Toggle(isOn: $includeInOverview) { Text("tab.overview") }
                    .accessibilityLabel("planner.target.includeBuffer.overview")
                Toggle(isOn: $includeInYear) { Text("tab.year") }
                    .accessibilityLabel("planner.target.includeBuffer.year")
            }
        }
        .navigationTitle("planner.target.countsIn.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

   The `accessibilityLabel` calls keep VoiceOver reading the full "Include Buffer in Overview" even though the visible label is just "Overview". Add two previews following the pattern at the bottom of `PlannerTargetSettingsView.swift` (a `UserDefaults(suiteName:)` with `.defaultAppStorage`): one default, one with `.dynamicTypeSize(.accessibility5)`. Put each in a `NavigationStack`.

3. **The settings screen** (`PlannerTargetSettingsView.swift`).
   - Remove the `includeInOverview` and `includeInYear` properties and the whole second section (the two `Toggle`s).
   - Add the two `@AppStorage` properties back under the same names only if the new row needs them for its summary. It does, so keep them, but read-only: `@AppStorage(UserDefaultsKeys.bufferInOverview) private var includeInOverview = false` and the same for the year.
   - Inside the existing Buffer `Section` (the one with the `Stepper` and the footer), after the `Stepper`, add:

```swift
                if extraHours > 0 {
                    NavigationLink {
                        BufferScopeSettingsView()
                    } label: {
                        LabeledContent(
                            "planner.target.countsIn",
                            value: PlannerTarget.bufferScopeSummary(
                                inOverview: includeInOverview, inYear: includeInYear, locale: locale))
                    }
                }
```

   - Animate the row in and out: add `.motion(Motion.presence, value: extraHours > 0)` to that `Section`. If this does not compile or the row does not animate, drop the animation line and say so in NOTES. The animation is optional; the hiding is not.
   - Do not touch the stepper, its labels or its footer.

4. **Strings** (`Localizable.xcstrings`). Keep `planner.target.includeBuffer.overview` and `planner.target.includeBuffer.year` exactly as they are (they are now VoiceOver labels; update only their `comment` to say "Spoken label of the Overview switch on the Count Buffer in page." and the same for Year). Add these seven entries, alphabetically after `planner.target.base...`/before `planner.target.extra` as the sort order requires (`planner.target.countsIn*` sorts between `planner.target.base.yearlyGoalShare.description` and `planner.target.extra`), each with a `comment`:

| Key | Comment | en | da |
|---|---|---|---|
| `planner.target.countsIn` | Label of the row that opens the page choosing which screens count the Buffer. | Counts in | Tæller i |
| `planner.target.countsIn.title` | Title of the page where the user chooses which screens count the Buffer. | Count Buffer in | Medregn buffer i |
| `planner.target.countsIn.always` | Value shown for the Planner row, which always counts the Buffer. | Always | Altid |
| `planner.target.countsIn.plannerOnly` | Summary on the Counts in row when only the Planner counts the Buffer. | Planner | Planlæg |
| `planner.target.countsIn.plannerOverview` | Summary on the Counts in row when the Planner and Overview count the Buffer. | Planner, Overview | Planlæg, Overblik |
| `planner.target.countsIn.plannerYear` | Summary on the Counts in row when the Planner and the Year tab count the Buffer. | Planner, Year | Planlæg, Tjenesteår |
| `planner.target.countsIn.all` | Summary on the Counts in row when the Planner, Overview and the Year tab count the Buffer. | Planner, Overview, Year | Planlæg, Overblik, Tjenesteår |

   Do not add or change any other entry. `tab.planner`, `tab.overview` and `tab.year` already exist.

5. **Help article** (`Base.lproj/TargetThisMonth.md`, `da.lproj/TargetThisMonth.md`). In the "If you set a Buffer" / "Hvis du sætter en buffer" section, replace the sentence that begins `You can also turn on "Include Buffer in Overview", ...` with: `Tap "Counts in" to also use it in Overview, in Year, or in both. A month's goal there then grows by your Buffer.` Danish: `Tryk på "Tæller i" for også at bruge den i Overblik, i Tjenesteår eller i begge. Månedens mål bliver så større med din buffer dér.` Leave the other paragraphs as they are.

6. **CONTEXT.md.** In **Buffer**, replace the sentence beginning `Overview and the Year tab each count it only when ...` with: `Overview and the Year tab each count it only when the user turns on their own switch (`bufferInOverview` and `bufferInYear`, both off by default and synced). The switches live on a page titled "Count Buffer in" / "Medregn buffer i", opened from the "Counts in" / "Tæller i" row under the Buffer stepper, which shows only while the Buffer is above 0 hours. The Planner always counts it. The Year tab adds it only in the current theocratic year, and never adds the adjusted target.` Do not change the other entries.

7. **Tests** in `HugoTests/Features/Planner/Domain/PlannerTargetTests.swift`, modeled on the `settingSummary...` tests there (same `locale`): one test with the four combinations of `(inOverview, inYear)` expecting exactly `"Planner"`, `"Planner, Overview"`, `"Planner, Year"` and `"Planner, Overview, Year"`.

### Verify and finish

- `grep -rn "Toggle(\"planner.target.includeBuffer" Hugo` → no output.
- `grep -c "planner.target.countsIn" Hugo/Resources/Localizable.xcstrings` → `7`.
- `python3 -c "import json; json.load(open('Hugo/Resources/Localizable.xcstrings'))"` → exit 0, and `git diff --stat Hugo/Resources/Localizable.xcstrings` shows added lines plus only the two changed `comment` lines.
- `xcrun swift-format lint --strict` on every Swift file you changed or created → exit 0.
- `Scripts/verify.sh` → exit 0. Redirect its full output to a file under `/private/tmp/claude-501/-Users-sebastiannielsen-Documents-Areas-Personal-Apps-Hugo/aac047fd-971a-4205-b00b-3f151b982d7b/scratchpad/` (for example `verify-132r2.log`), take the exit code from the script itself, and confirm `** TEST SUCCEEDED **`.
- One commit: `feat: choose where the Buffer counts on its own page`. Do not push.

### Done criteria

- [ ] `Scripts/verify.sh` exits 0 and the new summary test passes.
- [ ] The Monthly Target screen has one section for the Buffer (stepper plus the "Counts in" row when the Buffer is above 0) and no separate switch section.
- [ ] `BufferScopeSettingsView.swift` exists in `Hugo/Features/Planner/Screens/` and no other new file was added except the two previews it contains.
- [ ] Only these files changed: `PlannerTarget.swift`, `PlannerTargetSettingsView.swift`, `BufferScopeSettingsView.swift` (new), `Localizable.xcstrings`, both `TargetThisMonth.md`, `CONTEXT.md`, `PlannerTargetTests.swift`.
- [ ] `YearlyGoalProgress.swift`, `OverviewMetrics.swift`, `OverviewView.swift`, `ServiceYearPageView.swift`, `UserDefaultsKeys.swift` and `SyncedSettings.swift` are unchanged.

### Revision STOP conditions

Stop and report if any of the files listed as unchanged would need to change, if the strings diff shows any other deleted or reordered line, if the new file needs a folder other than `Screens`, or if a verification fails twice.
