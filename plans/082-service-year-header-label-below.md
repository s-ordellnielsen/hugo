# Plan 082: Label the Year page total below the number, like the Planner header

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 1432319..HEAD -- Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift`
> Expected: no output. `Hugo/Resources/Localizable.xcstrings` is expected to have changed, because plans 080 and 081 edit it. Run the key check in Step 2 anyway. If the view file is listed, compare the "Current state" excerpt with the live code. On a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2 (next external TestFlight build)
- **Effort**: S + owner
- **Risk**: LOW (one view and two renamed catalog keys)
- **Depends on**: plans/080-short-duration-format.md (DONE first). Run after plans/081-planner-header-declutter.md so both headers follow the same layout.
- **Category**: direction (owner request)
- **Planned at**: commit `1432319`, 2026-11-05
- **Issue**: [SLN-297](https://linear.app/sebastianln/issue/SLN-297)

## Why this matters

Plan 081 removes the small-caps eyebrow from the Planner header and puts the label under the big number instead. The owner wants the Year page header to match. Its eyebrow ("COUNTED TOWARD GOAL" or "TOTAL") moves under the number as a normal label. "Actual total 523 hours" moves onto that same line at the trailing edge, so the number stands alone. The Year header stays a link to the year details, so it keeps its chevron. The chevron moves onto the number's row. Both tabs then read the same way: number, then what the number is.

Glossary (`CONTEXT.md`): **credited time** is "the part of a month's time that counts toward the yearly goal … The app shows it as 'Counted toward goal'". **Year total** is the reported hours of submitted months plus the logged time of months not yet submitted. In this view, `progress.creditedSeconds` is the credited time and `progress.yearTotalSeconds` is the year total ("Actual total").

## Current state

- `Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift` (103 lines). `body` is lines 13–66 and `eyebrow` is lines 68–75:

  ```swift
      var body: some View {
          VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
              HStack {
                  eyebrow
                  Spacer(minLength: HugoLayout.Spacing.regular)
                  Image(systemName: "chevron.right")
                      .font(.footnote)
                      .fontWeight(.semibold)
                      .foregroundStyle(.secondary)
                      .accessibilityHidden(true)
              }

              Text(ServiceDurationFormatter.hoursString(from: primarySeconds))
                  .font(.system(.largeTitle, design: .serif, weight: .bold))
                  .monospacedDigit()
                  .minimumScaleFactor(0.6)
                  .lineLimit(1)
                  .contentTransition(.numericText())
                  .motion(Motion.value, value: primarySeconds)

              if let progress, progress.showsYearTotal {
                  Text(
                      String(
                          localized: "year.header.actual",
                          defaultValue:
                              "Actual total \(ServiceDurationFormatter.hoursString(from: progress.yearTotalSeconds))",
                          comment:
                              "Real total of the year, shown when it differs from the counted time. The argument is a duration."
                      )
                  )
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }

              if let fraction = progress?.barFraction, let paceSentence = progress?.paceSentence {
                  Text(paceSentence)
                      .font(.subheadline)
                      .fontWeight(.semibold)
                      .padding(.top, HugoLayout.Spacing.spacious)

                  CenteredProgressBar(
                      fraction: fraction,
                      accessibilityLabel: "year.header.counted.eyebrow",
                      accessibilityValue: paceSentence
                  )
              }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, HugoLayout.Spacing.card)
          .padding(.vertical, HugoLayout.Spacing.regular)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(accessibilityLabelText)
          .accessibilityHint("year.header.a11y.hint")
      }

      private var eyebrow: some View {
          Text(progress == nil ? "year.header.total.eyebrow" : "year.header.counted.eyebrow")
              .font(.caption)
              .textCase(.uppercase)
              .tracking(HugoLayout.Typography.eyebrowTracking)
              .fontWeight(.semibold)
              .foregroundStyle(.secondary)
      }
  ```

  `accessibilityLabelText` (lines 77–86) and the previews (lines 89–103) stay unchanged.

- The view is the label of a `NavigationLink` to `ServiceYearDetailView` in `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift:51-56`, styled `.buttonStyle(.card)`. That link does not change.

- After plan 081, the Planner header (`Hugo/Features/Planner/Views/PlannerStatusHeader.swift`) uses this layout, which this plan matches:
  - Outer `VStack` spacing `HugoLayout.Spacing.regular` (12).
  - An inner `VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight)` holding the hero number and a label row.
  - The label row is `HStack(alignment: .firstTextBaseline)` with the label, `Spacer(minLength: HugoLayout.Spacing.regular)` and the trailing text, styled `.font(.subheadline)` and `.foregroundStyle(.secondary)`.
  - Vertical padding `HugoLayout.Spacing.roomy` (20).

- String catalog `Hugo/Resources/Localizable.xcstrings` (Xcode JSON, keys sorted alphabetically). Two entries are renamed by this plan:

  ```json
      "year.header.counted.eyebrow" : {
        "comment" : "Small label above the year header total when a yearly goal applies.",
        "localizations" : {
          "da" : {
            "stringUnit" : {
              "state" : "translated",
              "value" : "Tæller med mod målet"
            }
          },
          "en" : {
            "stringUnit" : {
              "state" : "translated",
              "value" : "Counted toward goal"
            }
          }
        }
      },
  ```

  ```json
      "year.header.total.eyebrow" : {
        "comment" : "Small label above the year header total when no yearly goal applies.",
        ...  da "Total", en "Total"
      },
  ```

  `year.header.counted.eyebrow` is used twice in Swift, both in this view (lines 55 and 69). `year.header.total.eyebrow` is used once (line 69). Order of the `year.header.*` keys today: `a11y.hint`, `a11y.label`, `actual`, `ahead`, `behind`, `counted.eyebrow`, `onTrack`, `total.eyebrow`. The new names `counted.label` and `total.label` sort into the same places, so the entries are renamed in place without moving.

- **Key names.** The keys are renamed from `.eyebrow` to `.label` because the text is no longer an eyebrow, and plan 081 names the Planner's label `planner.header.projected.label`. The English and Danish values stay the same.

- `HugoLayout.Typography.eyebrowTracking` stays. `ServiceYearMonthRow.swift:76` still uses it.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| JSON is valid | `python3 -c "import json; json.load(open('Hugo/Resources/Localizable.xcstrings', encoding='utf-8'))"` | exit 0, no output |
| Build | `xcodebuild build -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/HugoVerifyDerivedData CODE_SIGNING_ALLOWED=NO` | ends with `** BUILD SUCCEEDED **` |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | no output, exit 0 |
| Full gate | `Scripts/verify.sh` | exit 0 (several minutes) |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run the same command again. That is not a failure.

## Scope

**In scope** (the only files you modify):
- `Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift`
- `Hugo/Resources/Localizable.xcstrings`: only the key name and the `comment` of the two entries in Step 2.

**Out of scope**:
- `ServiceYearPageView` and the `NavigationLink` around the header.
- `accessibilityLabelText`, `YearlyGoalProgress`, `CenteredProgressBar`.
- `ServiceYearMonthRow` (it keeps its own eyebrow style).
- `HugoLayout` tokens. Add none, remove none.
- Any English or Danish value.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- The working tree may hold uncommitted owner files in `plans/` and `.claude/`. Never stage, edit, stash or discard them. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage only the two in-scope files, by explicit path.
- One commit in Conventional Commits style: `feat: label the Year page total below the number`

## Steps

### Step 1: Rebuild the header layout

In `Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift`, replace `body` (lines 13–66) and delete the `eyebrow` property (lines 68–75). Use this code:

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                HStack(alignment: .center) {
                    Text(ServiceDurationFormatter.hoursString(from: primarySeconds))
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .motion(Motion.value, value: primarySeconds)
                    Spacer(minLength: HugoLayout.Spacing.regular)
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        label
                        Spacer(minLength: HugoLayout.Spacing.regular)
                        actualTotal
                    }
                    VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                        label
                        actualTotal
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if let fraction = progress?.barFraction, let paceSentence = progress?.paceSentence {
                Text(paceSentence)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.top, HugoLayout.Spacing.compact)

                CenteredProgressBar(
                    fraction: fraction,
                    accessibilityLabel: "year.header.counted.label",
                    accessibilityValue: paceSentence
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, HugoLayout.Spacing.card)
        .padding(.vertical, HugoLayout.Spacing.roomy)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint("year.header.a11y.hint")
    }

    /// What the big number is: credited time with a yearly goal, the year total without one.
    private var label: some View {
        Text(progress == nil ? "year.header.total.label" : "year.header.counted.label")
    }

    /// The year total, shown only when it differs from the credited time.
    @ViewBuilder
    private var actualTotal: some View {
        if let progress, progress.showsYearTotal {
            Text(
                String(
                    localized: "year.header.actual",
                    defaultValue:
                        "Actual total \(ServiceDurationFormatter.hoursString(from: progress.yearTotalSeconds))",
                    comment:
                        "Real total of the year, shown when it differs from the counted time. The argument is a duration."
                )
            )
        }
    }
```

Here is what changed and why:
- The eyebrow row is gone.
- The chevron sits on the number's row, vertically centered, because the header is still a link.
- The label and "Actual total" share one line under the number. `ViewThatFits` stacks them when one line is too narrow, for example in Danish ("Tæller med mod målet" next to "Faktisk total 523 timer 15 min") or at large Dynamic Type sizes.
- "Actual total" goes from `.caption` to `.subheadline`, matching the Planner's "Target".
- The outer spacing goes from `compact` (8) to `regular` (12) and the vertical padding from `regular` (12) to `roomy` (20). The pace sentence's extra top padding goes from `spacious` (16) to `compact` (8). Its distance from the label stays about the same (20 pt instead of 24 pt), because the outer spacing grew.

**Verify**: `grep -n "eyebrow" Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift` → no output.

### Step 2: Rename the two catalog keys in place

In `Hugo/Resources/Localizable.xcstrings`, change only these two key lines and their `comment` lines. Leave the localizations exactly as they are.

| Old line | New line |
|---|---|
| `    "year.header.counted.eyebrow" : {` | `    "year.header.counted.label" : {` |
| `      "comment" : "Small label above the year header total when a yearly goal applies.",` | `      "comment" : "Label under the year header total when a yearly goal applies: the time credited toward the goal.",` |
| `    "year.header.total.eyebrow" : {` | `    "year.header.total.label" : {` |
| `      "comment" : "Small label above the year header total when no yearly goal applies.",` | `      "comment" : "Label under the year header total when no yearly goal applies.",` |

**Verify**:
- The JSON check exits 0.
- `grep -rn "year.header.counted.eyebrow\|year.header.total.eyebrow" Hugo HugoTests` → no output.
- `grep -c '^    "year.header.counted.label" : {\|^    "year.header.total.label" : {' Hugo/Resources/Localizable.xcstrings` → `2`
- This prints `True`:

```bash
python3 -c "import json; k=[x for x in json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'] if x.startswith('year.header.')]; print(k == sorted(k))"
```

- `git diff --numstat Hugo/Resources/Localizable.xcstrings` → `4	4	Hugo/Resources/Localizable.xcstrings`

### Step 3: Build, run the gate and commit

Run the build command, then `Scripts/verify.sh`. Stage the two in-scope files by path and commit with the message from "Git workflow".

**Verify**: the build ends with `** BUILD SUCCEEDED **`. `Scripts/verify.sh` exits 0. `git show --stat HEAD` lists exactly the two in-scope files.

## Test plan

No automated test covers this layout, and none is added: the change is visual and moves no logic. The gate confirms that the build, lint and existing tests still pass. The owner checks the result by hand.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0.
- [ ] `grep -rn "eyebrow" Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift` → no output.
- [ ] `grep -rn "year.header.counted.eyebrow\|year.header.total.eyebrow" Hugo HugoTests` → no output.
- [ ] `git show --stat HEAD` lists only the two in-scope files.
- [ ] Owner check (by hand, Danish and English, as a regular pioneer and as a publisher without a yearly goal):
  - No small-caps eyebrow.
  - "Tæller med mod målet" / "Counted toward goal" (or "Total") sits under the number.
  - "Faktisk total …" sits on the same line when it fits and under the label when it does not.
  - The chevron sits on the number's row, and tapping the header still opens the year details.
  - The spacing matches the Planner header.
  - VoiceOver still reads "Counted toward yearly goal: …" with the hint "Opens the year details".

## STOP conditions

Stop and report back, do not improvise, if:

- Plan 080 is not DONE (`grep -c '^    "duration\.' Hugo/Resources/Localizable.xcstrings` is not `2`).
- The live `body` does not match the excerpt above.
- `year.header.counted.eyebrow` or `year.header.total.eyebrow` is used anywhere other than `TheocraticYearTotalsView.swift` (`grep -rn` shows more).
- `ViewThatFits` causes a build error or a layout loop warning. Report it. Do not swap in a `GeometryReader`.
- A verification fails twice after a reasonable fix attempt.

## Maintenance notes

- The Planner header (plan 081) and this header now share one layout: the number, then a secondary label row. Change both together, or factor the label row into a shared view if a third header appears.
- The accessibility label does not mention the actual total. That was true before this plan too. Add it if testers ask.
- `ViewThatFits` picks the first child that fits horizontally. If a future text is added to the label row, add it to both children.
