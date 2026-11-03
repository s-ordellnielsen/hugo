# Plan 063: Name the year total, take the publisher status in, and build the year detail rows in `YearlyGoalProgress`

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 26e63f4..HEAD -- Hugo/Features/ServiceYear HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift`
> Plan 061 changes `YearlyGoalProgress.swift` line 35 and
> `ServiceYearDetailView.swift` line 73 to read `month.contribution`; the
> excerpts below show those lines after plan 061. Any other difference from
> the excerpts is a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/061-service-month-record.md (`ServiceMonth.contribution`)
- **Category**: tech-debt
- **Planned at**: commit `26e63f4`, 2026-11-03

## Why this matters

`YearlyGoalProgress.actualSeconds` is not logged time. It is the year total: reported hours for submitted months plus logged time for the rest (a test expects 6 hours when 30 were logged). Elsewhere `ReportingLine.actualSeconds` *is* logged time, so the same word means two things. The year screens also redo goal work in their views: `ServiceYearPageView` converts the yearly goal from hours to seconds itself, and `ServiceYearDetailView` recomputes each month's total in `body` and repeats the 60-second "show the difference" threshold. After this plan, `YearlyGoalProgress` takes the `PublisherStatus`, returns `nil` when the status has no yearly goal, names the year total after the `CONTEXT.md` term, and hands the detail screen ready-made month rows. The UI does not change.

## Current state

- `Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift:3-70` (after plan 061):

  ```swift
  nonisolated struct YearlyGoalProgress: Equatable, Sendable {
      let creditedSeconds: TimeInterval
      let actualSeconds: TimeInterval
      /// Seconds the user should have by now. Nil when the year has not started.
      let expectedSeconds: TimeInterval?
      let yearlyGoalSeconds: TimeInterval
      let monthlyGoalSeconds: TimeInterval
      let creditedByMonth: [YearMonth: TimeInterval]

      var showsActualTotal: Bool { abs(actualSeconds - creditedSeconds) >= 60 }
      ...
      var isOnTrack: Bool { abs(differenceSeconds ?? 0) < 60 }

      static func make(
          report: TheocraticYearReport,
          rule: YearlyGoalRule,
          yearlyGoalSeconds: TimeInterval,
          pacing: YearlyGoalPacing,
          now: Date = .now,
          calendar: Calendar = .current
      ) -> YearlyGoalProgress {
          var creditedByMonth: [YearMonth: TimeInterval] = [:]
          for month in report.months {
              let contribution = month.contribution
              creditedByMonth[month.id] = rule.creditedSeconds(
                  main: contribution.main, separate: contribution.separate)
          }
          ... // expectedSeconds from pacing, unchanged by this plan
          return YearlyGoalProgress(
              creditedSeconds: creditedByMonth.values.reduce(0, +),
              actualSeconds: report.totalSeconds,
              expectedSeconds: expectedSeconds,
              yearlyGoalSeconds: yearlyGoalSeconds,
              monthlyGoalSeconds: rule.monthlyGoalSeconds,
              creditedByMonth: creditedByMonth)
      }
  }
  ```

  The file also has an extension with `paceSentence` (lines 73-92). Keep it unchanged.
- `Hugo/Features/PublisherStatus/Domain/PublisherStatus.swift`: `yearlyGoal: Int` (hours) and `yearlyGoalRule: YearlyGoalRule?` (nil unless the goal period is yearly and the goal is above 0). The regular pioneer status is `goal: 600`, `separateAllowanceHours: 5`, so its rule has a 50-hour monthly goal and a 5-hour allowance.
- `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift:38-46`:

  ```swift
  private func progress(for report: TheocraticYearReport) -> YearlyGoalProgress? {
      guard let status, let rule = status.yearlyGoalRule else { return nil }
      return YearlyGoalProgress.make(
          report: report,
          rule: rule,
          yearlyGoalSeconds: TimeInterval(status.yearlyGoal) * 3_600,
          pacing: pacing
      )
  }
  ```

- `Hugo/Features/ServiceYear/Screens/ServiceYearDetailView.swift:69-91` (after plan 061):

  ```swift
  private func monthsSection(_ progress: YearlyGoalProgress) -> some View {
      Section {
          ForEach(report.months.filter { !$0.isFuture }) { month in
              let credited = progress.creditedByMonth[month.id] ?? 0
              let actual = month.contribution.total
              LabeledContent {
                  VStack(alignment: .trailing) {
                      duration(credited)
                      if abs(actual - credited) >= 60 {
                          Text(ServiceDurationFormatter.hoursString(from: actual))
                              .font(.caption)
                              .monospacedDigit()
                              .foregroundStyle(.tertiary)
                      }
                  }
              } label: {
                  Text(month.displayName)
              }
          }
      } header: {
          Text("year.detail.section.months")
      }
  }
  ```

  Its `#Preview` (lines 100-111) and the "Yearly goal" `#Preview` in `Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift:89-99` both call `YearlyGoalProgress.make(report:rule:yearlyGoalSeconds: 600 * 3_600, pacing:)`.
- `TheocraticYearTotalsView.swift:33-45` reads `progress.showsActualTotal` and `progress.actualSeconds` for the "Actual total" caption. The string key `year.header.actual` and its texts stay as they are.
- `CONTEXT.md` (plan 060) defines **Year total** ("the reported hours of every submitted month plus the logged time of every month not yet submitted", _Avoid_: Actual total) and **Credited time**.
- Tests: `HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift` builds a report and calls `make` through `makeProgress(entries:submissions:pacing:now:)` (lines 125-147), with `rule` and `yearlyGoalSeconds` stored properties (lines 13-14) matching the regular pioneer values. Tests that use the renamed members: `creditDiffersFromActualWhenSeparateExceedsTheAllowance` (lines 60-70), `mainOnlyTimeDoesNotShowAnActualTotal` (72-78), `submittedMonthsUseSubmittedHoursNotRawSeconds` (93-108), `creditedByMonthHoldsOneEntryPerYearMonth` (110-116). Force unwraps are used in these tests already (`TimeZone(secondsFromGMT: 0)!`).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/YearlyGoalProgressTests -only-testing:HugoTests/YearlyGoalRuleTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:

- `Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift`
- `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift` (`progress(for:)` only)
- `Hugo/Features/ServiceYear/Views/TheocraticYearTotalsView.swift` (two member names and the preview)
- `Hugo/Features/ServiceYear/Screens/ServiceYearDetailView.swift` (`monthsSection` and the preview)
- `HugoTests/Features/ServiceYear/Domain/YearlyGoalProgressTests.swift`
- `plans/README.md` (status row)

**Out of scope**:

- Any UI string or layout. The "Actual total" caption keeps its text.
- `ReportingLine.actualSeconds` and `SubmittedCategory.actualSeconds`. Those really are logged time; the second is a persisted field.
- `YearlyGoalRule` and `PublisherStatus`.
- The pacing math in `make`.

## Git workflow

- Branch: `advisor/063-yearly-goal-rows`
- Conventional Commits, as in `git log`, for example `refactor: build the year detail rows in YearlyGoalProgress`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Reshape `YearlyGoalProgress`

In `YearlyGoalProgress.swift`:

1. Add a nested row type and a shared threshold:

   ```swift
   /// One month on the year detail screen.
   struct Month: Identifiable, Equatable, Sendable {
       let id: YearMonth
       let displayName: String
       let isFuture: Bool
       let creditedSeconds: TimeInterval
       /// What the month adds to the year total.
       let totalSeconds: TimeInterval

       var showsTotal: Bool { abs(totalSeconds - creditedSeconds) >= YearlyGoalProgress.differenceThreshold }
   }

   /// Differences smaller than a minute are shown as equal.
   static let differenceThreshold: TimeInterval = 60
   ```

2. Rename `actualSeconds` to `yearTotalSeconds` (doc comment: `/// The year total: reported hours of submitted months plus logged time of the rest.`) and `showsActualTotal` to `showsYearTotal`. Replace `creditedByMonth: [YearMonth: TimeInterval]` with `months: [Month]`. Use `Self.differenceThreshold` in `showsYearTotal` and in `isOnTrack` instead of the literal `60`.
3. Change `make` to:

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
       let months = report.months.map { month in
           let contribution = month.contribution
           return Month(
               id: month.id,
               displayName: month.displayName,
               isFuture: month.isFuture,
               creditedSeconds: rule.creditedSeconds(main: contribution.main, separate: contribution.separate),
               totalSeconds: contribution.total)
       }
       // expectedSeconds: unchanged code
       return YearlyGoalProgress(
           creditedSeconds: months.reduce(0) { $0 + $1.creditedSeconds },
           yearTotalSeconds: report.totalSeconds,
           expectedSeconds: expectedSeconds,
           yearlyGoalSeconds: TimeInterval(status.yearlyGoal) * 3_600,
           monthlyGoalSeconds: rule.monthlyGoalSeconds,
           months: months)
   }
   ```

**Verify**: `grep -n 'actualSeconds\|creditedByMonth\|>= 60\|< 60' Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift` → no output. (The app does not build until Step 2.)

### Step 2: Update the callers

1. `ServiceYearPageView.progress(for:)`:

   ```swift
   private func progress(for report: TheocraticYearReport) -> YearlyGoalProgress? {
       guard let status else { return nil }
       return YearlyGoalProgress.make(report: report, status: status, pacing: pacing)
   }
   ```

2. `TheocraticYearTotalsView.swift`: `progress.showsActualTotal` becomes `progress.showsYearTotal`, and `progress.actualSeconds` becomes `progress.yearTotalSeconds`. Its "Yearly goal" preview becomes:

   ```swift
   let report = ReportPreviewFixtures.yearReport
   let progress = PublisherStatus.status(for: "regular-pioneer").flatMap {
       YearlyGoalProgress.make(report: report, status: $0, pacing: .proRated)
   }
   ```

3. `ServiceYearDetailView.swift`: change the preview the same way, and replace the body of `monthsSection` with:

   ```swift
   Section {
       ForEach(progress.months.filter { !$0.isFuture }) { month in
           LabeledContent {
               VStack(alignment: .trailing) {
                   duration(month.creditedSeconds)
                   if month.showsTotal {
                       Text(ServiceDurationFormatter.hoursString(from: month.totalSeconds))
                           .font(.caption)
                           .monospacedDigit()
                           .foregroundStyle(.tertiary)
                   }
               }
           } label: {
               Text(month.displayName)
           }
       }
   } header: {
       Text("year.detail.section.months")
   }
   ```

**Verify**:

- `grep -rn 'creditedByMonth\|showsActualTotal\|yearlyGoalSeconds:' Hugo` → no output
- `grep -n 'contribution' Hugo/Features/ServiceYear/Screens/ServiceYearDetailView.swift` → no output

### Step 3: Update the tests

In `YearlyGoalProgressTests.swift`:

1. Replace the `rule` and `yearlyGoalSeconds` properties with `private let status = PublisherStatus.status(for: "regular-pioneer")!`, and make `makeProgress` call `YearlyGoalProgress.make(report: report, status: status, pacing: pacing, now: now, calendar: calendar)!`.
2. Rename members in the expectations: `actualSeconds` becomes `yearTotalSeconds`, `showsActualTotal` becomes `showsYearTotal`. Rename the tests `creditDiffersFromActualWhenSeparateExceedsTheAllowance` to `creditDiffersFromYearTotalWhenSeparateExceedsTheAllowance` and `mainOnlyTimeDoesNotShowAnActualTotal` to `mainOnlyTimeDoesNotShowAYearTotal`.
3. Replace `creditedByMonthHoldsOneEntryPerYearMonth` with `monthsHoldOneRowPerYearMonth`: `progress.months.map(\.id) == TheocraticYear(startYear: 2026).months`, and the September row's `creditedSeconds == 50 * 3_600`.
4. Add:
   - `statusWithoutAYearlyGoalHasNoProgress`: `YearlyGoalProgress.make(report:status: PublisherStatus.status(for: "auxiliary-pioneer")!, pacing: .proRated, now:calendar:)` returns `nil`.
   - `monthRowShowsItsTotalOnlyWhenItDiffersFromCredit`: with the entries from the "credit differs" test, the September row has `creditedSeconds == 55 * 3_600`, `totalSeconds == 60 * 3_600` and `showsTotal`; the October row has `!showsTotal`.

**Verify**: focused tests → `** TEST SUCCEEDED **`, with 2 more tests than before.

Commit: `refactor: build the year detail rows in YearlyGoalProgress`.

### Step 4: Run the gate

**Verify**: `Scripts/verify.sh` → exit 0.

### Step 5 [owner]: Compare the Year page

With a regular pioneer status and a month where separate time exceeds the allowance, the Year header still shows "Actual total" with the same number, and the year detail month rows show the same credited and total values as before.

## Test plan

- `YearlyGoalProgressTests`: 2 renamed, 1 replaced, 2 added.
- `YearlyGoalRuleTests`: unchanged.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -rn 'creditedByMonth\|showsActualTotal' Hugo HugoTests` prints nothing
- [ ] `grep -n 'yearTotalSeconds' Hugo/Features/ServiceYear/Domain/YearlyGoalProgress.swift` prints at least 2 lines
- [ ] `git status --porcelain` lists only files from the Scope list
- [ ] `plans/README.md` row for 063 updated

## STOP conditions

Stop and report back if:

- `month.contribution` does not exist on the months of `TheocraticYearReport` (plan 061 not done).
- `YearlyGoalProgress.make` or `creditedByMonth` is used in a file not listed in Scope.
- Any expected number in an existing test has to change. Only names may change.

## Maintenance notes

- If the app later shows credited time per month somewhere else (for example on the month card), read it from `YearlyGoalProgress.months`, not by calling `YearlyGoalRule` in a view.
- The UI still says "Actual total" for the year total. If the owner renames the caption, keep the code name `yearTotalSeconds` and update `CONTEXT.md` only if the domain word changes.
