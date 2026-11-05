# Plan 081: Declutter the Planner header and stop it opening the target settings

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 1432319..HEAD -- Hugo/Features/Planner/Views/PlannerStatusHeader.swift Hugo/Features/Planner/Domain/PlannerMonthStatus.swift Hugo/Features/Planner/Views/PlannerMonthPage.swift HugoTests/Features/Planner/Domain/PlannerMonthStatusTests.swift`
> Expected: no output. `Hugo/Resources/Localizable.xcstrings` is expected to have changed, because plan 080 adds two `duration.` keys. If any other listed file changed, compare the "Current state" excerpts with the live code. On a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1 (next external TestFlight build)
- **Effort**: M + owner
- **Risk**: LOW (one view, one value type, one page; no persistence)
- **Depends on**: plans/080-short-duration-format.md (must be DONE first: the header relies on the short "23 hours, 15 min" format)
- **Category**: direction (owner request)
- **Planned at**: commit `1432319`, 2026-11-05
- **Issue**: [SLN-296](https://linear.app/sebastianln/issue/SLN-296)

## Why this matters

The owner finds the Planner header too cluttered and asked for these changes:

1. **Remove the eyebrow** ("WITH YOUR PLAN" in small capitals above the number) and the chevron next to it.
2. **Stop tapping the header to open the target settings.** Settings already has a Planner page (Settings → Planner), so a second, hidden route is unnecessary.
3. **Label the number below it** with "With your plan", and **move "Target 50 hours" down onto that same line**, trailing. The hero row then holds only the number, so long values such as "23 timer 15 min" have room.
4. **Add more spacing** between the parts of the header.
5. **Drop the confusing "16 hours left · about 1 hour, 10 min a day" line.** It counts what is missing from *logged* time, while the header and the line above it talk about the *plan*. Two different "missing" numbers on a planning screen confuse users. The owner liked the per-day idea, so it returns in planning terms: the amount still missing from the plan, spread over the days left. For example: "Plan 4 hours more to reach your target" followed by "About 20 min more a day for the rest of the month".

Glossary terms (`CONTEXT.md`) to use in names and comments: **projected time** ("A month's logged time plus its still-planned time. The Planner shows it as 'With your plan'"), **monthly target**, **still planned**, **logged time**.

## Current state

- `Hugo/Features/Planner/Views/PlannerStatusHeader.swift` (125 lines) draws the header. Lines 7–95:

  ```swift
      var body: some View {
          VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
              HStack {
                  Text("planner.header.eyebrow")
                      .font(.caption)
                      .textCase(.uppercase)
                      .tracking(HugoLayout.Typography.eyebrowTracking)
                      .fontWeight(.semibold)
                      .foregroundStyle(.secondary)
                  Spacer(minLength: HugoLayout.Spacing.regular)
                  Image(systemName: "chevron.right")
                      .font(.footnote)
                      .fontWeight(.semibold)
                      .foregroundStyle(.secondary)
                      .accessibilityHidden(true)
              }

              HStack(alignment: .firstTextBaseline) {
                  Text(ServiceDurationFormatter.hoursString(from: status.projectedSeconds))
                      .font(.system(.largeTitle, design: .serif, weight: .bold))
                      .monospacedDigit()
                      .minimumScaleFactor(0.6)
                      .lineLimit(1)
                      .contentTransition(.numericText())
                      .motion(Motion.value, value: status.projectedSeconds)
                  Spacer()
                  if let targetSeconds = status.targetSeconds {
                      Text(
                          String(
                              localized: "planner.header.target",
                              defaultValue: "Target \(ServiceDurationFormatter.hoursString(from: targetSeconds))",
                              comment: "The monthly target. The argument is a duration such as 50 hours.")
                      )
                      .font(.subheadline)
                      .foregroundStyle(.secondary)
                  }
              }

              if let targetSeconds = status.targetSeconds {
                  PlannerProgressBar(
                      loggedSeconds: status.loggedSeconds,
                      stillPlannedSeconds: status.stillPlannedSeconds,
                      targetSeconds: targetSeconds
                  )
                  .padding(.vertical, HugoLayout.Spacing.tight)
              }

              HStack(spacing: HugoLayout.Spacing.spacious) {
                  legendItem(
                      fraction: 1,
                      text: String(
                          localized: "planner.header.logged",
                          defaultValue: "Logged \(ServiceDurationFormatter.hoursString(from: status.loggedSeconds))",
                          comment: "Time already logged this month. The argument is a duration."))
                  legendItem(
                      fraction: 0,
                      text: String(
                          localized: "planner.header.stillPlanned",
                          defaultValue:
                              "Still planned \(ServiceDurationFormatter.hoursString(from: status.stillPlannedSeconds))",
                          comment: "Time planned but not logged yet this month. The argument is a duration."))
              }

              Text(status.summarySentence)
                  .font(.subheadline)
                  .fontWeight(.semibold)
                  .fixedSize(horizontal: false, vertical: true)
                  .padding(.top, HugoLayout.Spacing.compact)

              if let perDaySentence = status.perDaySentence {
                  Text(perDaySentence)
                      .font(.footnote)
                      .foregroundStyle(.secondary)
                      .fixedSize(horizontal: false, vertical: true)
              }

              if let uncountedSentence = status.uncountedSentence {
                  Text(uncountedSentence)
                      .font(.footnote)
                      .foregroundStyle(.secondary)
                      .fixedSize(horizontal: false, vertical: true)
              }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, HugoLayout.Spacing.card)
          .padding(.vertical, HugoLayout.Spacing.regular)
          .accessibilityElement(children: .combine)
          .accessibilityHint(Text("planner.header.a11y.hint"))
      }
  ```

  Lines 97–106 (`legendItem`) and the two previews (lines 109–125) stay as they are.

- `Hugo/Features/Planner/Domain/PlannerMonthStatus.swift` (98 lines) holds the header's numbers and sentences. Relevant parts:

  ```swift
  // lines 22–33
      /// Target minus projected time. Positive when the plan falls short. Nil without a target.
      var shortfallSeconds: TimeInterval? { targetSeconds.map { $0 - projectedSeconds } }

      /// Target minus logged time, never below zero. Nil without a target.
      var leftSeconds: TimeInterval? { targetSeconds.map { max(0, $0 - loggedSeconds) } }

      /// `leftSeconds` spread evenly over `daysLeft`. Nil without a target, when
      /// nothing is left, or when no days are left.
      var perDaySeconds: TimeInterval? {
          guard let leftSeconds, leftSeconds >= Self.differenceThreshold, daysLeft > 0 else { return nil }
          return leftSeconds / TimeInterval(daysLeft)
      }
  ```

  ```swift
  // lines 78–87
      /// "16 hours left · about 1 hour, 10 minutes a day", or nil.
      nonisolated var perDaySentence: String? {
          guard let leftSeconds, let perDaySeconds else { return nil }
          let left = ServiceDurationFormatter.hoursString(from: leftSeconds)
          let perDay = ServiceDurationFormatter.hoursString(from: perDaySeconds)
          return String(
              localized: "planner.header.perDay", defaultValue: "\(left) left · about \(perDay) a day",
              comment:
                  "Time still needed this month and that time spread over the days left. Both arguments are durations.")
      }
  ```

  `static let differenceThreshold: TimeInterval = 60` is at line 18. `daysLeft` (line 15) counts today. It counts from the 1st for a future month and is 0 for a past month. `grep` shows `leftSeconds` and `perDaySeconds` are used only in this file and in `PlannerMonthStatusTests`.

- `Hugo/Features/Planner/Views/PlannerMonthPage.swift` wraps the header in a button that opens the target sheet:

  ```swift
  // line 15
      @State private var isShowingTarget = false
  ```

  ```swift
  // lines 43–50
                  Button {
                      isShowingTarget = true
                  } label: {
                      PlannerStatusHeader(
                          status: PlannerMonthStatus.make(
                              month: plannerMonth, targetSeconds: targetSeconds, rule: rule))
                  }
                  .buttonStyle(.card)
  ```

  ```swift
  // lines 68–73
          .sheet(isPresented: $isShowingTarget) {
              NavigationStack {
                  PlannerTargetSettingsView(showsDone: true)
              }
              .presentationDetents([.medium, .large])
          }
  ```

  `.buttonStyle(.card)` (`Hugo/DesignSystem/Styles/CardButtonStyle.swift`) only adds a press scale and a content shape. It draws no background, so removing the button changes nothing visually except the press effect.

- Settings already links to the target settings: `Hugo/Features/Settings/Screens/SettingsView.swift:65`, `NavigationLink(destination: PlannerTargetSettingsView())`. After this plan, the `showsDone: true` call in `PlannerMonthPage` is gone and nothing passes `showsDone: true` any more. **Leave `PlannerTargetSettingsView` alone.** A later Settings plan (084) rewrites it and removes the parameter.

- Spacing tokens (`Hugo/DesignSystem/Theme/Theme.swift`, `HugoLayout.Spacing`): `tight` 4, `small` 6, `compact` 8, `regular` 12, `spacious` 16, `roomy` 20, `card` 24, `section` 32. `HugoLayout.Typography.eyebrowTracking` is still used by `ServiceYearMonthRow` and `TheocraticYearTotalsView`. Keep the token.

- String catalog `Hugo/Resources/Localizable.xcstrings`: an Xcode-written JSON file, 2-space indentation, `" : "` separators, keys sorted alphabetically. See plan 077 for the shape. Current Planner header keys, in file order: `planner.header.a11y.hint`, `planner.header.eyebrow` ("With your plan" / "Med din plan"), `planner.header.logged`, `planner.header.noTarget`, `planner.header.over`, `planner.header.perDay`, `planner.header.reached`, `planner.header.short`, `planner.header.stillPlanned`, `planner.header.target`, `planner.header.uncounted`. Each is used exactly once in Swift.

- Tests: `HugoTests/Features/Planner/Domain/PlannerMonthStatusTests.swift` (struct `PlannerMonthStatusTests`). Lines that use the removed properties: 29 (`status.leftSeconds`), 48 (`novemberStatus.perDaySeconds`), 51–62 (test `noTargetMeansNoShortfallLeftOrPerDay`, uses `leftSeconds` and `perDaySeconds`), 88–89 (`leftSeconds`, `perDaySeconds`). The test style is Swift Testing (`@Test`, `#expect`) with a fixed GMT Gregorian calendar.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| JSON is valid | `python3 -c "import json; json.load(open('Hugo/Resources/Localizable.xcstrings', encoding='utf-8'))"` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/PlannerMonthStatusTests -only-testing:HugoTests/DurationFormattingTests` | `** TEST SUCCEEDED **` |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | no output, exit 0 |
| Full gate | `Scripts/verify.sh` | exit 0 (several minutes) |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run the same command again. That is not a failure.

## Scope

**In scope** (the only files you modify):
- `Hugo/Features/Planner/Views/PlannerStatusHeader.swift`
- `Hugo/Features/Planner/Domain/PlannerMonthStatus.swift`
- `Hugo/Features/Planner/Views/PlannerMonthPage.swift`
- `HugoTests/Features/Planner/Domain/PlannerMonthStatusTests.swift`
- `Hugo/Resources/Localizable.xcstrings`: only the five `planner.header.*` keys named in Step 4.

**Out of scope**:
- `PlannerTargetSettingsView.swift`, `SettingsView.swift` (plan 084 owns them).
- `PlannerProgressBar`, `PlannerBarShape`, the legend (`legendItem`), `summarySentence`, `uncountedSentence`, `PlannerMonthStatus.make`.
- The Year page header (`TheocraticYearTotalsView`). Plan 082 gives it the same treatment.
- `HugoLayout` tokens. Use the existing ones; add none.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- The working tree may hold uncommitted owner files in `plans/` and `.claude/`. Never stage, edit, stash or discard them. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage only the five in-scope files, by explicit path.
- One commit in Conventional Commits style: `feat: declutter the Planner header`

## Steps

### Step 1: Replace the logged-gap numbers with a per-day share of the shortfall

In `Hugo/Features/Planner/Domain/PlannerMonthStatus.swift`:

1. Delete `leftSeconds` and `perDaySeconds` with their doc comments (lines 25–33).
2. In their place, directly after `shortfallSeconds`, add:

```swift
    /// The shortfall spread evenly over `daysLeft`: how much more to plan each
    /// day to reach the monthly target. Nil without a target, when the plan
    /// reaches the target, when no days are left, or when the daily share is
    /// under a minute.
    var shortfallPerDaySeconds: TimeInterval? {
        guard let shortfallSeconds, shortfallSeconds >= Self.differenceThreshold, daysLeft > 0 else { return nil }
        let perDay = shortfallSeconds / TimeInterval(daysLeft)
        return perDay >= Self.differenceThreshold ? perDay : nil
    }
```

3. Replace `perDaySentence` (lines 78–87, with its doc comment) with:

```swift
    /// "About 20 min more a day for the rest of the month", or nil.
    nonisolated var perDaySentence: String? {
        guard let shortfallPerDaySeconds else { return nil }
        let perDay = ServiceDurationFormatter.hoursString(from: shortfallPerDaySeconds)
        return String(
            localized: "planner.header.shortfallPerDay",
            defaultValue: "About \(perDay) more a day for the rest of the month",
            comment:
                "How much more to plan each day to reach the monthly target, spread over the days left. The argument is a duration such as 20 min."
        )
    }
```

**Verify**: `grep -n "leftSeconds\|perDaySeconds\|planner.header.perDay\"" Hugo/Features/Planner/Domain/PlannerMonthStatus.swift` → no output. (The test file still uses them until Step 3. Do not build yet.)

### Step 2: Rebuild the header layout

In `Hugo/Features/Planner/Views/PlannerStatusHeader.swift`, replace the whole `body` (lines 7–95) with the code below. These are the changes:

- The eyebrow row (eyebrow text and chevron) is gone.
- The hero row holds only the projected time.
- A new label row sits under the number, 4 pt below it (`tight`): "With your plan" leading, "Target …" trailing, both `.subheadline` and `.secondary`.
- The outer spacing goes from `compact` (8) to `regular` (12).
- The sentences are grouped with `tight` (4) spacing and keep `compact` (8) extra space above them.
- The vertical padding goes from `regular` (12) to `roomy` (20).
- The accessibility hint is gone, because the header is no longer a button.

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                Text(ServiceDurationFormatter.hoursString(from: status.projectedSeconds))
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .motion(Motion.value, value: status.projectedSeconds)

                HStack(alignment: .firstTextBaseline) {
                    Text("planner.header.projected.label")
                    Spacer(minLength: HugoLayout.Spacing.regular)
                    if let targetSeconds = status.targetSeconds {
                        Text(
                            String(
                                localized: "planner.header.target",
                                defaultValue: "Target \(ServiceDurationFormatter.hoursString(from: targetSeconds))",
                                comment: "The monthly target. The argument is a duration such as 50 hours.")
                        )
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if let targetSeconds = status.targetSeconds {
                PlannerProgressBar(
                    loggedSeconds: status.loggedSeconds,
                    stillPlannedSeconds: status.stillPlannedSeconds,
                    targetSeconds: targetSeconds
                )
                .padding(.vertical, HugoLayout.Spacing.tight)
            }

            HStack(spacing: HugoLayout.Spacing.spacious) {
                legendItem(
                    fraction: 1,
                    text: String(
                        localized: "planner.header.logged",
                        defaultValue: "Logged \(ServiceDurationFormatter.hoursString(from: status.loggedSeconds))",
                        comment: "Time already logged this month. The argument is a duration."))
                legendItem(
                    fraction: 0,
                    text: String(
                        localized: "planner.header.stillPlanned",
                        defaultValue:
                            "Still planned \(ServiceDurationFormatter.hoursString(from: status.stillPlannedSeconds))",
                        comment: "Time planned but not logged yet this month. The argument is a duration."))
            }

            VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                Text(status.summarySentence)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)

                if let perDaySentence = status.perDaySentence {
                    Text(perDaySentence)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let uncountedSentence = status.uncountedSentence {
                    Text(uncountedSentence)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, HugoLayout.Spacing.compact)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, HugoLayout.Spacing.card)
        .padding(.vertical, HugoLayout.Spacing.roomy)
        .accessibilityElement(children: .combine)
    }
```

Also update the doc comment on line 3 to: `/// The month's numbers above the Planner calendar: projected time, the monthly target, and how the plan compares.`

**Verify**: `grep -n "eyebrow\|chevron\|accessibilityHint" Hugo/Features/Planner/Views/PlannerStatusHeader.swift` → no output.

### Step 3: Make the header plain content in `PlannerMonthPage`

In `Hugo/Features/Planner/Views/PlannerMonthPage.swift`:

1. Delete line 15, `@State private var isShowingTarget = false`.
2. Replace lines 43–50 (the `Button { … } label: { … }` and `.buttonStyle(.card)`) with:

```swift
                PlannerStatusHeader(
                    status: PlannerMonthStatus.make(
                        month: plannerMonth, targetSeconds: targetSeconds, rule: rule))
```

3. Delete the second `.sheet` modifier (lines 68–73, the one that shows `PlannerTargetSettingsView(showsDone: true)`). Keep the first `.sheet(item: $selectedDay)`.

**Verify**: `grep -n "isShowingTarget\|PlannerTargetSettingsView\|buttonStyle" Hugo/Features/Planner/Views/PlannerMonthPage.swift` → no output.

### Step 4: Update the string catalog

In `Hugo/Resources/Localizable.xcstrings`:

1. **Delete** three whole entries (from the `"key" : {` line through its closing `},`): `planner.header.a11y.hint`, `planner.header.eyebrow`, `planner.header.perDay`.
2. **Add** `planner.header.projected.label` directly before the line `    "planner.header.reached" : {`:

```json
    "planner.header.projected.label" : {
      "comment" : "Label under the projected time in the Planner header: logged time plus time still planned this month.",
      "localizations" : {
        "da" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Med din plan"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "With your plan"
          }
        }
      }
    },
```

3. **Add** `planner.header.shortfallPerDay` directly before the line `    "planner.header.stillPlanned" : {`:

```json
    "planner.header.shortfallPerDay" : {
      "comment" : "How much more to plan each day to reach the monthly target, spread over the days left. The argument is a duration such as 20 min.",
      "localizations" : {
        "da" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Cirka %@ mere om dagen resten af måneden"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "About %@ more a day for the rest of the month"
          }
        }
      }
    },
```

The Danish values are proposals for the owner to review in the build.

**Verify**:
- The JSON check exits 0.
- `grep -c '^    "planner.header.a11y.hint"\|^    "planner.header.eyebrow"\|^    "planner.header.perDay"' Hugo/Resources/Localizable.xcstrings` → `0`
- `grep -c '^    "planner.header.projected.label"\|^    "planner.header.shortfallPerDay"' Hugo/Resources/Localizable.xcstrings` → `2`
- This prints `True`, which means the keys are still sorted:

```bash
python3 -c "import json; k=[x for x in json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'] if x.startswith('planner.header.')]; print(k == sorted(k))"
```

### Step 5: Update the tests

In `HugoTests/Features/Planner/Domain/PlannerMonthStatusTests.swift`:

1. Line 29: delete `#expect(status.leftSeconds == TimeInterval(40 * 3_600))`.
2. Line 48: change `novemberStatus.perDaySeconds` to `novemberStatus.shortfallPerDaySeconds`. The value stays `TimeInterval(40 * 3_600) / 28`, because November has 10 h logged, nothing planned and a 50 h target, so the shortfall is 40 h.
3. Test `noTargetMeansNoShortfallLeftOrPerDay` (lines 51–62): rename it to `noTargetMeansNoShortfallOrPerDay`, delete the `leftSeconds` line, and change `perDaySeconds` to `shortfallPerDaySeconds`.
4. Test `loggedTimeAboveTheTargetLeavesNothingToPlan` (lines 80–91): delete the `leftSeconds` line and change `perDaySeconds` to `shortfallPerDaySeconds`.
5. Add these tests after `perDaySentenceNeedsATarget`:

```swift
    @Test
    func perDayShareSpreadsTheShortfallOfThePlanNotOfLoggedTime() {
        // 10 h logged + 30 h still planned = 40 h projected; target 50 h; 10 days left.
        let status = PlannerMonthStatus(
            targetSeconds: 50 * 3_600, loggedSeconds: 10 * 3_600, stillPlannedSeconds: 30 * 3_600,
            uncountedSeconds: 0, daysLeft: 10)

        #expect(status.shortfallPerDaySeconds == TimeInterval(3_600))
        #expect(status.perDaySentence != nil)
        #expect(status.perDaySentence?.contains("1") == true)
    }

    @Test
    func perDayShareIsHiddenWhenThePlanReachesTheTargetOrNoDaysAreLeft() {
        let reached = PlannerMonthStatus(
            targetSeconds: 50 * 3_600, loggedSeconds: 10 * 3_600, stillPlannedSeconds: 40 * 3_600,
            uncountedSeconds: 0, daysLeft: 10)
        let pastMonth = PlannerMonthStatus(
            targetSeconds: 50 * 3_600, loggedSeconds: 10 * 3_600, stillPlannedSeconds: 0,
            uncountedSeconds: 0, daysLeft: 0)
        // 5 minutes short over 10 days is 30 seconds a day: too small to show.
        let tiny = PlannerMonthStatus(
            targetSeconds: 50 * 3_600, loggedSeconds: 0, stillPlannedSeconds: 50 * 3_600 - 300,
            uncountedSeconds: 0, daysLeft: 10)

        #expect(reached.shortfallPerDaySeconds == nil)
        #expect(reached.perDaySentence == nil)
        #expect(pastMonth.shortfallPerDaySeconds == nil)
        #expect(tiny.shortfallPerDaySeconds == nil)
        #expect(tiny.perDaySentence == nil)
    }
```

**Verify**:
- `grep -n "leftSeconds\|\.perDaySeconds" HugoTests/Features/Planner/Domain/PlannerMonthStatusTests.swift` → no output.
- Focused tests → `** TEST SUCCEEDED **`, including the two new tests.

### Step 6: Run the gate and commit

Run `Scripts/verify.sh`. Then stage the five in-scope files by path and commit with the message from "Git workflow".

**Verify**: `Scripts/verify.sh` exits 0. `git show --stat HEAD` lists exactly the five in-scope files.

## Test plan

- `PlannerMonthStatusTests` keeps its existing coverage. It gains two tests: the per-day share uses the plan's shortfall (target minus projected time), not target minus logged time. The share is hidden when the plan reaches the target, when no days are left, and when it is under a minute a day.
- The layout has no automated test. The owner checks it by hand (see Done criteria).

## Done criteria

- [ ] `Scripts/verify.sh` exits 0.
- [ ] `grep -rn "leftSeconds\|perDaySeconds\|planner.header.eyebrow\|planner.header.a11y.hint\|\"planner.header.perDay\"" Hugo HugoTests` → no output.
- [ ] `grep -n "isShowingTarget" Hugo/Features/Planner/Views/PlannerMonthPage.swift` → no output.
- [ ] `git show --stat HEAD` lists only the five in-scope files.
- [ ] Owner check (by hand, iPhone 16 Pro Max, Danish and English):
  - The header shows no small-caps eyebrow and no chevron.
  - "Med din plan" / "With your plan" sits under the number, with "Mål 50 timer" / "Target 50 hours" on the same line at the trailing edge.
  - A value such as "23 timer 15 min" no longer fills the width.
  - Tapping the header does nothing. Settings → Planner still opens the target settings.
  - With a plan short of the target, the line under "Planlæg … mere for at nå dit mål" reads "Cirka … mere om dagen resten af måneden". It disappears once the plan reaches the target.
  - The spacing feels calmer. Judge whether `roomy` vertical padding is right.

## STOP conditions

Stop and report back, do not improvise, if:

- Plan 080 is not DONE (`grep -c '^    "duration\.' Hugo/Resources/Localizable.xcstrings` is not `2`).
- The excerpts above do not match the live files.
- Any file other than `PlannerMonthStatus.swift` and `PlannerMonthStatusTests.swift` uses `leftSeconds`, `perDaySeconds` or `perDaySentence` (`grep -rn` shows more).
- Removing the button or the sheet seems to need a change in `PlannerTargetSettingsView` or `SettingsView`.
- A verification fails twice after a reasonable fix attempt.

## Maintenance notes

- The header is now plain content. If a tap target comes back, give it an accessibility hint again.
- `PlannerTargetSettingsView(showsDone:)` has no caller with `true` after this plan. Plan 084 (Settings) removes the parameter.
- The per-day line is planning advice and depends on `daysLeft`, which includes today. If users read "the rest of the month" as "from tomorrow", change `daysLeft` in `PlannerMonthStatus.make`, not the sentence.
- Plan 082 gives the Year page header the same label-under-number layout and spacing. Keep the two in step when either changes.
