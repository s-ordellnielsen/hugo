# Plan 085: Replace the Overview month details with a plan pace sheet opened from the status line

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 1432319..HEAD -- Hugo/Features/Overview Hugo/DesignSystem/Theme/Theme.swift Hugo/Resources/Localizable.xcstrings HugoTests/Features/Overview HugoTests/Domain`
> Expected: no output. If a file is listed, compare the "Current state" excerpts below with the live code. On any mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1 (scheduled for the next external TestFlight build)
- **Effort**: M
- **Risk**: LOW (UI only; no schema change, no change to how time is counted)
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `1432319`, 2026-11-05
- **Issue**: [SLN-293](https://linear.app/sebastianln/issue/SLN-293)

## Why this matters

Tapping the big circle on the Overview opens a "Detailed Report" sheet with a bar of category colors and a list of category totals. The owner reports that almost nobody uses it, and the Year tab already shows the same totals per month. It goes away.

In its place, the small status line under the hours ("Behind Schedule", "Foran planen" and so on) becomes tappable. It shows only when the month has plans, and it compares logged time with the plan, but today it gives no numbers. The new sheet says how far ahead or behind the plan the user is, with the two numbers behind that verdict. It is deliberately small; later builds may add to it.

## Current state

Glossary terms to use in names and comments (from `CONTEXT.md`):

- **Plan**: "Time the user intends to spend in service on one day."
- **Logged time**: "The sum of entry durations, before any rounding."
- **Plan pace**: "How the current month's logged time compares with the time planned up to now. Today's plan counts only as far as it has been logged."

Files and their roles:

- `Hugo/Features/Overview/Screens/OverviewView.swift` is the Overview tab. `OverviewDayView` (private, same file) builds the plan pace and opens the details sheet:

  ```swift
  // OverviewView.swift:41-42
      @State private var showingAddEntry = false
      @State private var showingDetails = false
  ```

  ```swift
  // OverviewView.swift:59-66
      /// Nil unless the current month has plans.
      private var planStatus: MonthlyProgressStatus? {
          let month = PlannerMonth.make(
              month: today.yearMonth(using: .current),
              items: plans.map { PlannedItem($0, trackers: trackers) },
              entries: entries, trackers: trackers, now: .now, calendar: .current)
          return PlanPace.make(month: month).map(MonthlyProgressStatus.make(pace:))
      }
  ```

  ```swift
  // OverviewView.swift:82-85
                      MonthlyProgressCard(
                          value: metrics.progress, monthlyGoal: metrics.monthlyGoal,
                          planStatus: planStatus, onAddEntry: { showingAddEntry = true },
                          onShowDetails: { showingDetails = true })
  ```

  ```swift
  // OverviewView.swift:101-106
              .sheet(isPresented: $showingAddEntry) {
                  AddEntryView()
              }
              .sheet(isPresented: $showingDetails) {
                  MonthlyProgressDetailView(month: Date.now.yearMonth())
              }
  ```

- `Hugo/Features/Overview/Views/MonthlyProgressCard.swift` is the circle card. The whole circle is one button (lines 14–40), and the status line sits inside it:

  ```swift
  // MonthlyProgressCard.swift:3-8
  struct MonthlyProgressCard: View {
      let value: Double
      let monthlyGoal: Double
      var planStatus: MonthlyProgressStatus? = nil
      let onAddEntry: () -> Void
      let onShowDetails: () -> Void
  ```

  ```swift
  // MonthlyProgressCard.swift:13-40
          ZStack(alignment: .bottomTrailing) {
              Button(action: onShowDetails) {
                  ZStack {
                      MonthlyProgressCircle(progress: value, maxValue: monthlyGoal)
                      VStack {
                          Text(Date.now, format: .dateTime.month(.wide))
                              .font(.caption)
                              .fontWeight(.semibold)
                              .foregroundStyle(.secondary)
                          Text(String("\(Int(value))"))
                              .font(.system(size: heroSize, weight: .bold, design: .serif))
                              .minimumScaleFactor(0.5)
                              .lineLimit(1)
                              .contentTransition(.numericText())
                              .motion(Motion.value, value: value)
                          if let planStatus {
                              MonthlyProgressStatusView(status: planStatus)
                                  .font(.caption)
                                  .foregroundStyle(.secondary)
                                  .transition(.opacity)
                          }
                      }
                  }
              }
              .buttonStyle(.card)
              .accessibilityElement(children: .combine)
              .accessibilityLabel(Text("a11y.monthly_progress_card.label"))
              .accessibilityValue(Text(verbatim: accessibilityValueText))
  ```

  ```swift
  // MonthlyProgressCard.swift:56-63
      private var accessibilityValueText: String {
          let amount =
              monthlyGoal > 0
              ? String(localized: "a11y.monthly_progress_card.value.\(Int(value)).\(Int(monthlyGoal))")
              : String(localized: "a11y.monthly_progress_card.value.\(Int(value))")
          guard let planStatus else { return amount }
          return "\(amount), \(planStatus.label)"
      }
  ```

- `Hugo/Features/Overview/Views/MonthlyProgressStatusView.swift` (11 lines) draws the status icon and label. Its only user is `MonthlyProgressCard`. Keep it unchanged.
- `Hugo/Features/Overview/Domain/MonthlyProgressStatus.swift` has `label`, `icon` and `static func make(pace: PlanPace) -> Self` (lines 35–40). Keep it unchanged.
- `Hugo/Features/Planner/Domain/PlanPace.swift` (Planner feature, do not edit):

  ```swift
  // PlanPace.swift:4-22
  nonisolated struct PlanPace: Equatable, Sendable {
      /// Planned time on days before today, plus today's planned time as far as
      /// it has been logged. A planned day never counts against the user until it is over.
      let expectedSeconds: TimeInterval
      let loggedSeconds: TimeInterval

      /// Positive when ahead of the plan.
      var differenceSeconds: TimeInterval { loggedSeconds - expectedSeconds }

      /// Nil when the month has no plans.
      static func make(month: PlannerMonth) -> PlanPace? { ... }
  }
  ```

- To be deleted:
  - `Hugo/Features/Overview/Screens/MonthlyProgressDetailView.swift` (15 lines), the sheet. Its only use is `OverviewView.swift:105`.
  - `Hugo/Features/Overview/Views/CategoryProgressBreakdownView.swift` (51 lines). Its only use is `MonthlyProgressDetailView`.
  - `CategoryProgressRow` and `CategoryProgressAggregator` in `Hugo/Features/Overview/Domain/OverviewMetrics.swift:20-53`. Their only users are `CategoryProgressBreakdownView` and the tests. `OverviewMetrics` itself (lines 3–18) stays.
  - The string `monthlyReport.detailView.title` (`Hugo/Resources/Localizable.xcstrings:926-943`), used only by `MonthlyProgressDetailView`.
  - The token `static let categoryProgressHeight: CGFloat = 56` (`Hugo/DesignSystem/Theme/Theme.swift:32`), used only by `CategoryProgressBreakdownView`.
- **Keep** `Hugo/Domain/CategoryProgressColor.swift`. The Planner uses it (`PlanMatcher.swift:11,28`, `PlannedItem.swift:19,43`, `PlannerMonth.swift:63`).
- `HugoTests/Features/Overview/Domain/OverviewMetricsTests.swift` holds two `OverviewMetrics` tests (lines 14–33) and nine aggregator tests (lines 35–128). Three of the aggregator tests are the only tests of `CategoryProgressColor`'s validation (lines 35–57). They move to a new `CategoryProgressColorTests`, rewritten against `CategoryProgressColor` directly:

  ```swift
  // Hugo/Domain/CategoryProgressColor.swift:5-17
  nonisolated struct CategoryProgressColor: Equatable, Sendable {
      let hue: Double
      let saturation: Double
      let brightness: Double

      init?(hue: Double, saturation: Double, brightness: Double) {
          guard (0...1).contains(hue), (0...1).contains(saturation), (0...1).contains(brightness),
              brightness > 0
          else { return nil }
          ...
  ```

- Sentence pattern to copy: `Hugo/Features/Planner/Domain/PlannerMonthStatus.swift:55-76`. A `nonisolated var` in an extension returns `String(localized:defaultValue:comment:)`, and differences under 60 seconds count as equal:

  ```swift
  extension PlannerMonthStatus {
      nonisolated var summarySentence: String {
          ...
          let amount = ServiceDurationFormatter.hoursString(from: abs(shortfall))
          if shortfall >= Self.differenceThreshold {
              return String(
                  localized: "planner.header.short", defaultValue: "Plan \(amount) more to reach your target",
                  comment: "The plan falls short of the monthly target. The argument is a duration such as 4 hours.")
          }
  ```

- String catalog: `Hugo/Resources/Localizable.xcstrings`. It is JSON written by Xcode with 2-space indentation, `" : "` between key and value, literal UTF-8 (æ, ø, å unescaped), and keys in alphabetical order. A code-defined string looks like this (the `planner.header.short` entry):

  ```json
      "planner.header.short" : {
        "comment" : "The plan falls short of the monthly target. The argument is a duration such as 4 hours.",
        "localizations" : {
          "da" : {
            "stringUnit" : {
              "state" : "translated",
              "value" : "Planlæg %@ mere for at nå dit mål"
            }
          },
          "en" : {
            "stringUnit" : {
              "state" : "translated",
              "value" : "Plan %@ more to reach your target"
            }
          }
        }
      },
  ```

  `navigation.done` already exists (used by `PlannerTargetSettingsView`). Reuse it for the Done button.
- Project facts: Xcode uses synchronized folders, so new `.swift` files in `Hugo/` and `HugoTests/` join their targets without editing `project.pbxproj`. Default actor isolation is `MainActor`, so value-type logic in `Domain` folders is marked `nonisolated`. Feature files live in role folders (`Screens`, `Views`, `State`, `Domain`, `Services`). Tests mirror the source path.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/OverviewMetricsTests -only-testing:HugoTests/MonthlyProgressStatusTests -only-testing:HugoTests/PlanPaceSentenceTests -only-testing:HugoTests/CategoryProgressColorTests` | `** TEST SUCCEEDED **` |
| JSON is valid | `python3 -c "import json; json.load(open('Hugo/Resources/Localizable.xcstrings', encoding='utf-8'))"` | exit 0, no output |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Full gate | `Scripts/verify.sh` | exit 0 (several minutes) |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run the same command again. That is not a failure.

## Scope

**In scope** (the only files you may modify, create or delete):
- `Hugo/Features/Overview/Screens/OverviewView.swift`
- `Hugo/Features/Overview/Screens/MonthlyProgressDetailView.swift` (delete)
- `Hugo/Features/Overview/Screens/PlanPaceSheet.swift` (create)
- `Hugo/Features/Overview/Views/MonthlyProgressCard.swift`
- `Hugo/Features/Overview/Views/CategoryProgressBreakdownView.swift` (delete)
- `Hugo/Features/Overview/Domain/OverviewMetrics.swift`
- `Hugo/Features/Overview/Domain/PlanPaceSentence.swift` (create)
- `Hugo/DesignSystem/Theme/Theme.swift` (remove one line)
- `Hugo/Resources/Localizable.xcstrings`
- `HugoTests/Features/Overview/Domain/OverviewMetricsTests.swift`
- `HugoTests/Features/Overview/Domain/PlanPaceSentenceTests.swift` (create)
- `HugoTests/Domain/CategoryProgressColorTests.swift` (create)

**Out of scope** (do not touch):
- `Hugo/Features/Overview/Views/MonthlyProgressCircle.swift`. Plan 086 changes how the circle fills. Here the card keeps calling `MonthlyProgressCircle(progress: value, maxValue: monthlyGoal)` exactly as today.
- `Hugo/Features/Overview/Views/MonthlyProgressStatusView.swift`, `MonthlyProgressStatus.swift`, and every file in `Hugo/Features/Planner/` (including `PlanPace.swift`).
- `Hugo/Domain/CategoryProgressColor.swift`. The Planner uses it.
- `OverviewListView.swift` and the entry list. Plan 087 changes those.
- `MonthlyProgressStatus` thresholds and the existing `month.progress.status.*` strings.
- Do not add an "Open Planner" button or any navigation from the sheet. The owner chose a small sheet.
- Do not open the string catalog in Xcode and save it. Edit the text file directly.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- The working tree may hold uncommitted owner files in `plans/` and `.claude/`. Never stage, edit, stash or discard them. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage only the in-scope files, by explicit path (use `git rm` for the two deleted files).
- One commit, Conventional Commits style like the rest of the log. Use: `feat: replace the Overview month details with a plan pace sheet`

## Steps

### Step 1: Remove the details sheet, the breakdown view and the aggregator

1. Delete `Hugo/Features/Overview/Screens/MonthlyProgressDetailView.swift` and `Hugo/Features/Overview/Views/CategoryProgressBreakdownView.swift`.
2. In `Hugo/Features/Overview/Domain/OverviewMetrics.swift`, delete everything from `struct CategoryProgressRow: Identifiable {` (line 20) to the end of the file. Keep `import Foundation` and `struct OverviewMetrics` (lines 1–18) unchanged.
3. In `Hugo/DesignSystem/Theme/Theme.swift`, delete line 32: `        static let categoryProgressHeight: CGFloat = 56`.
4. In `Hugo/Resources/Localizable.xcstrings`, delete the whole `"monthlyReport.detailView.title" : { ... },` entry (lines 926–943, 18 lines, from the key line through its closing `},`).
5. In `HugoTests/Features/Overview/Domain/OverviewMetricsTests.swift`, delete every test from `validTrackerColorIsPreserved` (line 35) through `snapshotWithDifferentTypeDoesNotMerge` (ending line 128). Keep `metricsCalculateGoalAndExpectedProgress`, `missingStatusAndNegativeDurationsAreSafe` and the `date(_:_:_:)` helper.
6. Create `HugoTests/Domain/CategoryProgressColorTests.swift`:

   ```swift
   import Testing

   @testable import Hugo

   struct CategoryProgressColorTests {
       @Test
       func validChannelsArePreserved() {
           let color = CategoryProgressColor(hue: 0.25, saturation: 0.5, brightness: 0.75)
           #expect(color?.hue == 0.25)
           #expect(color?.saturation == 0.5)
           #expect(color?.brightness == 0.75)
       }

       @Test
       func zeroBrightnessMeansNoColor() {
           #expect(CategoryProgressColor(hue: 0.25, saturation: 0.5, brightness: 0) == nil)
       }

       @Test
       func outOfRangeChannelMeansNoColor() {
           #expect(CategoryProgressColor(hue: 1.5, saturation: 0.5, brightness: 0.5) == nil)
       }
   }
   ```

   The app does not build yet: `OverviewView` still references `MonthlyProgressDetailView`. Step 3 fixes that.

**Verify**:
- `grep -rn "MonthlyProgressDetailView\|CategoryProgressBreakdownView\|CategoryProgressAggregator\|CategoryProgressRow\|categoryProgressHeight\|monthlyReport.detailView" Hugo HugoTests` lists only `Hugo/Features/Overview/Screens/OverviewView.swift` (one line, the sheet).
- The JSON check exits 0.

### Step 2: Add the plan pace sentence

Create `Hugo/Features/Overview/Domain/PlanPaceSentence.swift`:

```swift
import Foundation

extension PlanPace {
    /// Differences smaller than a minute count as on plan.
    nonisolated static let onPlanThreshold: TimeInterval = 60

    /// "You're 3 hours ahead of your plan", "You're 2 hours behind your plan"
    /// or "You're right on your plan".
    nonisolated var differenceSentence: String {
        let difference = differenceSeconds
        guard abs(difference) >= Self.onPlanThreshold else {
            return String(
                localized: "overview.pace.onPlan", defaultValue: "You're right on your plan",
                comment: "Plan pace sheet: logged time matches the time planned up to now.")
        }
        let amount = ServiceDurationFormatter.hoursString(from: abs(difference))
        if difference > 0 {
            return String(
                localized: "overview.pace.ahead", defaultValue: "You're \(amount) ahead of your plan",
                comment: "Plan pace sheet: logged time is ahead of the plan. The argument is a duration such as 3 hours.")
        }
        return String(
            localized: "overview.pace.behind", defaultValue: "You're \(amount) behind your plan",
            comment: "Plan pace sheet: logged time is behind the plan. The argument is a duration such as 3 hours.")
    }
}
```

Create `HugoTests/Features/Overview/Domain/PlanPaceSentenceTests.swift`. It follows the style of `PlannerMonthStatusTests.summarySentenceNamesTheShortfallAndTreatsSmallDifferencesAsEqual`: compare sentences with each other and check for the number, never against fixed English text.

```swift
import Testing

@testable import Hugo

struct PlanPaceSentenceTests {
    private let onPlan = PlanPace(expectedSeconds: 10 * 3_600, loggedSeconds: 10 * 3_600)
    private let nearlyOnPlan = PlanPace(expectedSeconds: 10 * 3_600, loggedSeconds: 10 * 3_600 - 59)
    private let ahead = PlanPace(expectedSeconds: 10 * 3_600, loggedSeconds: 13 * 3_600)
    private let behind = PlanPace(expectedSeconds: 10 * 3_600, loggedSeconds: 6 * 3_600)

    @Test
    func smallDifferencesReadAsOnPlan() {
        #expect(nearlyOnPlan.differenceSentence == onPlan.differenceSentence)
    }

    @Test
    func aheadAndBehindNameTheDifference() {
        #expect(ahead.differenceSentence.contains("3"))
        #expect(behind.differenceSentence.contains("4"))
        #expect(ahead.differenceSentence != behind.differenceSentence)
        #expect(ahead.differenceSentence != onPlan.differenceSentence)
        #expect(behind.differenceSentence != onPlan.differenceSentence)
    }
}
```

**Verify**: run the focused tests. Expected: the build fails only because of the `MonthlyProgressDetailView` reference in `OverviewView.swift`. If any other compile error appears, fix it before going on. Do not run tests yet; Step 3 makes the build pass.

### Step 3: Make the status line a button and remove the circle's button

**`MonthlyProgressCard.swift`**: replace the properties and `body` so that:

- The properties are:

  ```swift
  let value: Double
  let monthlyGoal: Double
  var planStatus: MonthlyProgressStatus? = nil
  let onAddEntry: () -> Void
  let onShowPlanPace: () -> Void
  ```

  `onShowDetails` is gone.
- The circle is no longer wrapped in a `Button`. The month text and the hero number form one accessibility element. The status line becomes its own button. Replace the `Button(action: onShowDetails) { ... }` block and its three modifiers (lines 14–40) with:

  ```swift
  ZStack {
      MonthlyProgressCircle(progress: value, maxValue: monthlyGoal)
          .accessibilityHidden(true)
      VStack {
          VStack {
              Text(Date.now, format: .dateTime.month(.wide))
                  .font(.caption)
                  .fontWeight(.semibold)
                  .foregroundStyle(.secondary)
              Text(String("\(Int(value))"))
                  .font(.system(size: heroSize, weight: .bold, design: .serif))
                  .minimumScaleFactor(0.5)
                  .lineLimit(1)
                  .contentTransition(.numericText())
                  .motion(Motion.value, value: value)
          }
          .accessibilityElement(children: .combine)
          .accessibilityLabel(Text("a11y.monthly_progress_card.label"))
          .accessibilityValue(Text(verbatim: accessibilityValueText))

          if let planStatus {
              Button(action: onShowPlanPace) {
                  HStack(spacing: HugoLayout.Spacing.tight) {
                      MonthlyProgressStatusView(status: planStatus)
                      Image(systemName: "chevron.right")
                          .font(.caption2)
                          .fontWeight(.semibold)
                          .accessibilityHidden(true)
                  }
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .frame(minHeight: HugoLayout.Size.minimumHitTarget)
                  .contentShape(.rect)
              }
              .buttonStyle(.card)
              .accessibilityLabel(Text(verbatim: planStatus.label))
              .accessibilityHint(Text("overview.pace.a11y.hint"))
              .transition(.opacity)
          }
      }
  }
  ```

  The hero number's modifiers are copied unchanged from today's code.

- `accessibilityValueText` no longer appends the status, because the status button now reads it. It becomes:

  ```swift
  private var accessibilityValueText: String {
      monthlyGoal > 0
          ? String(localized: "a11y.monthly_progress_card.value.\(Int(value)).\(Int(monthlyGoal))")
          : String(localized: "a11y.monthly_progress_card.value.\(Int(value))")
  }
  ```

- The add button (lines 42–52) is unchanged.

**`OverviewView.swift`** (`OverviewDayView`):

- Rename `@State private var showingDetails = false` to `@State private var showingPlanPace = false`.
- Replace `planStatus` (lines 59–66) with two computed properties, so 086 can reuse the month:

  ```swift
  /// The current month in Planner terms: its plans and logged time per day.
  private var plannerMonth: PlannerMonth {
      PlannerMonth.make(
          month: today.yearMonth(using: .current),
          items: plans.map { PlannedItem($0, trackers: trackers) },
          entries: entries, trackers: trackers, now: .now, calendar: .current)
  }
  ```

- At the top of `body`, compute once: `let pace = PlanPace.make(month: plannerMonth)`. Pass `planStatus: pace.map(MonthlyProgressStatus.make(pace:))` and `onShowPlanPace: { showingPlanPace = true }` to `MonthlyProgressCard`.
- Replace the details sheet (lines 104–106) with:

  ```swift
  .sheet(isPresented: $showingPlanPace) {
      if let pace {
          PlanPaceSheet(pace: pace)
              .presentationDetents([.medium])
      }
  }
  .onChange(of: pace == nil) { _, hasNoPlans in
      if hasNoPlans { showingPlanPace = false }
  }
  ```

  The sheet's content closure reads the `pace` constant, so it shows live numbers whenever the Overview redraws. The `onChange` closes the sheet if the last plan of the month is deleted on another device while the sheet is open.

**Create `Hugo/Features/Overview/Screens/PlanPaceSheet.swift`**:

```swift
import SwiftUI

/// The plan pace of the current month in numbers. Opened from the status line
/// under the Overview circle.
struct PlanPaceSheet: View {
    let pace: PlanPace

    @Environment(\.dismiss) private var dismiss

    private var status: MonthlyProgressStatus { .make(pace: pace) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                        Label(status.label, systemImage: status.icon)
                            .font(.system(.title2, design: .serif, weight: .bold))
                        Text(pace.differenceSentence)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .listRowBackground(Color.clear)
                }
                Section {
                    LabeledContent(
                        "overview.pace.planned",
                        value: ServiceDurationFormatter.hoursString(from: pace.expectedSeconds))
                    LabeledContent(
                        "overview.pace.logged",
                        value: ServiceDurationFormatter.hoursString(from: pace.loggedSeconds))
                } footer: {
                    Text("overview.pace.footer")
                }
            }
            .navigationTitle("overview.pace.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("navigation.done") { dismiss() }
                }
            }
        }
    }
}

#Preview("Behind") {
    PlanPaceSheet(pace: PlanPace(expectedSeconds: 15 * 3_600, loggedSeconds: 11 * 3_600 + 30 * 60))
}

#Preview("Ahead") {
    PlanPaceSheet(pace: PlanPace(expectedSeconds: 8 * 3_600, loggedSeconds: 12 * 3_600))
}
```

**Verify**:
- `grep -rn "onShowDetails\|showingDetails" Hugo` → no output.
- The focused tests → `** TEST SUCCEEDED **`.

### Step 4: Add the new strings

Insert these entries into `Hugo/Resources/Localizable.xcstrings` in alphabetical position. All `overview.pace.*` keys go directly after the `"overview.list-style.label"` entry and before `"planner.bar.a11y.plan"`, in this order: `overview.pace.a11y.hint`, `overview.pace.ahead`, `overview.pace.behind`, `overview.pace.footer`, `overview.pace.logged`, `overview.pace.onPlan`, `overview.pace.planned`, `overview.pace.title`. Use exactly the JSON shape of the `planner.header.short` example above (a `"comment"`, then `"localizations"` with `"da"` before `"en"`, each `"state" : "translated"`).

| Key | Comment | English | Danish (owner reviews) |
|---|---|---|---|
| `overview.pace.a11y.hint` | VoiceOver hint on the Overview status line. | `Shows how you're doing against your plan` | `Viser, hvordan det går i forhold til din plan` |
| `overview.pace.ahead` | Plan pace sheet: logged time is ahead of the plan. The argument is a duration such as 3 hours. | `You're %@ ahead of your plan` | `Du er %@ foran din plan` |
| `overview.pace.behind` | Plan pace sheet: logged time is behind the plan. The argument is a duration such as 3 hours. | `You're %@ behind your plan` | `Du er %@ bagud i forhold til din plan` |
| `overview.pace.footer` | Plan pace sheet footer explaining how today's plans count. | `Today's plans count only as far as you have logged them, so today never counts against you.` | `Dagens planer tæller kun med, så langt du har udført dem. Derfor tæller i dag aldrig imod dig.` |
| `overview.pace.logged` | Plan pace sheet row: time logged this month. | `Logged` | `Udført` |
| `overview.pace.onPlan` | Plan pace sheet: logged time matches the time planned up to now. | `You're right on your plan` | `Du følger din plan` |
| `overview.pace.planned` | Plan pace sheet row: time planned on the days up to today. | `Planned until today` | `Planlagt indtil i dag` |
| `overview.pace.title` | Title of the plan pace sheet on the Overview. | `Your plan` | `Din plan` |

The comments in the catalog must match the `comment:` arguments in `PlanPaceSentence.swift` for the three keys defined there. Copy them from that file.

**Verify**:
- The JSON check exits 0.
- `grep -c '^    "overview.pace\.' Hugo/Resources/Localizable.xcstrings` → `8`
- `python3 -c "import json; k=list(json.load(open('Hugo/Resources/Localizable.xcstrings', encoding='utf-8'))['strings']); print(k == sorted(k))"` → `True`. If it prints `False` and the same check also printed `False` at `1432319` (`git show 1432319:Hugo/Resources/Localizable.xcstrings > /tmp/old.xcstrings` then the same command on `/tmp/old.xcstrings`), ignore it. Otherwise move your entries.

### Step 5: Run the gate and commit

Run `Scripts/verify.sh`. Stage the in-scope files by path (`git rm` for the two deleted files) and commit with the message from "Git workflow".

**Verify**: `Scripts/verify.sh` exits 0. `git show --stat HEAD` lists only in-scope files.

## Test plan

- `PlanPaceSentenceTests` (new, 2 tests): the sentence treats differences under a minute as on plan, and names the amount when ahead or behind.
- `CategoryProgressColorTests` (new, 3 tests): keeps the coverage of the color validation that the deleted aggregator tests used to provide.
- `OverviewMetricsTests` keeps its two `OverviewMetrics` tests.
- No UI test. The owner checks the sheet by hand (see Done criteria).

## Done criteria

- [ ] `Scripts/verify.sh` exits 0.
- [ ] `grep -rn "MonthlyProgressDetailView\|CategoryProgressBreakdownView\|CategoryProgressAggregator\|CategoryProgressRow\|categoryProgressHeight\|monthlyReport.detailView\|onShowDetails" Hugo HugoTests` → no output.
- [ ] `ls Hugo/Features/Overview/Screens` lists `OverviewView.swift` and `PlanPaceSheet.swift` only.
- [ ] `grep -c '^    "overview.pace\.' Hugo/Resources/Localizable.xcstrings` → `8`.
- [ ] `git show --stat HEAD` lists only in-scope files.
- [ ] Owner check (on device, English and Danish): with plans this month, the status line under the hours shows a small chevron, tapping it opens a half-height "Your plan" sheet with the verdict, the two numbers and the footer, and Done closes it. Tapping the circle does nothing. With no plans this month, there is no status line. With VoiceOver, the circle reads as "Month Progress, N hours this month", and the status line is a separate button that reads its label and the hint.

## STOP conditions

Stop and report back (do not improvise) if:

- Any "Current state" excerpt doesn't match the live code.
- `grep` finds another user of `MonthlyProgressDetailView`, `CategoryProgressBreakdownView`, `CategoryProgressAggregator`, `CategoryProgressRow`, `categoryProgressHeight` or `monthlyReport.detailView.title` besides those listed above.
- Removing the outer `Button` changes the layout of the add button (it no longer sits at the bottom trailing edge of the circle) and one attempt to fix it fails.
- A step's verification fails twice after a reasonable fix attempt.
- The fix appears to need a change to `PlanPace`, `MonthlyProgressStatus` or `MonthlyProgressCircle`.

## Maintenance notes

- This covers the monthly half of SLN-82 ("Show Monthly and Service Year Status Details", that is, ahead/behind in numbers). The Year page already shows its pace in numbers. Once this ships, SLN-82 can close.
- SLN-183 ("Two hero visualisations have no accessible representation") becomes obsolete. The category bar is deleted here, and the circle's card already has a label and value. Cancel it after this ships.
- Plan 086 changes what the circle fills against and how. It builds on the `plannerMonth` property added here, and changes the card's `value`/`monthlyGoal` inputs and `accessibilityValueText`.
- The sheet's verdict (icon and label) uses `MonthlyProgressStatus` thresholds (±2 hours count as on target), while the sentence uses the exact difference. So "On Schedule" can appear above "You're 1 hour, 30 minutes behind your plan". This is intended: the label is the coarse verdict and the sentence gives the precise number. If testers find it confusing, align the two in one place (`MonthlyProgressStatus.make(pace:)`).
- The sheet is the place to grow this feature later (for example, the rest of the month's plan or a per-day suggestion). Keep any new numbers in `PlanPace` or an Overview `Domain` type, not in the view.
