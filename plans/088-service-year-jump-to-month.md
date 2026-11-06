# Plan 088: Add navigation to a specific service year

> **Status**: CANCELLED 2026-11-06. The original month-jump idea did not match the owner's intent. The desired interaction is to jump to a specific theocratic year, not a month. Revisit and write a new plan tomorrow; no implementation changes were retained.

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 1432319..HEAD -- Hugo/Features/ServiceYear/Screens/ServiceYearView.swift Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift Hugo/Resources/Localizable.xcstrings`
> Expected: no output, or only `Localizable.xcstrings` (other plans add strings to it). If either Swift file is listed, compare the "Current state" excerpts against the live code; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S (+ owner check on device)
- **Risk**: LOW (one toolbar item and one scroll request; no data or schema change)
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `1432319`, 2026-11-05
- **Issue**: [SLN-295](https://linear.app/sebastianln/issue/SLN-295)

## Why this matters

The Year page shows one card per month of the theocratic year, from September at the top to August at the bottom. Late in the year, reaching a month such as June means scrolling past nine cards. The owner wants a button in the top-left corner, with a calendar symbol, that jumps straight to a month. A native menu that lists the twelve months of the year on screen keeps this simple and familiar for older users.

## Current state

- `Hugo/Features/ServiceYear/Screens/ServiceYearView.swift` is the Year tab. It pages horizontally between theocratic years, one `ServiceYearPageView` per year, and tracks the year on screen as `activeYear`. Its toolbar has a principal title and a trailing `SettingsButton` (lines 67–85):

  ```swift
              .toolbar {
                  ToolbarItem(placement: .principal) {
                      HStack(spacing: 0) {
                          Text(String(activeYear.startYear))
                          ...
                  }
                  ToolbarItem {
                      SettingsButton(sizeClass: .compact)
                  }
              }
  ```

  The pages are created at lines 47–55:

  ```swift
                      ForEach(years) { year in
                          ServiceYearPageView(
                              year: year,
                              onScrolledFromTopChange: { newValue in
                                  scrolledPages[year.id] = newValue
                              }
                          )
                          .containerRelativeFrame(.horizontal)
                      }
  ```

  `activeYear` (lines 35–37) is `displayedYear ?? currentYear`.

- `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift` is one year's page: a vertical `ScrollView` with the year header and one `ServiceYearMonthRow` per month. Every row already has an id (lines 61–64):

  ```swift
                  ForEach(report.months) { month in
                      ServiceYearMonthRow(month: month)
                          .id(month.id)
                  }
  ```

  `month.id` is a `YearMonth` (`Hugo/Features/Reports/Domain/ServiceMonth.swift:17`, `let id: YearMonth`). The body starts at line 45:

  ```swift
      var body: some View {
          let report = self.report
          let progress = progress(for: report)
          return ScrollView {
              VStack(spacing: HugoLayout.Spacing.card) {
  ```

  and the `ScrollView` ends with these modifiers (lines 68–73):

  ```swift
          .frame(maxWidth: .infinity)
          .onScrollGeometryChange(for: Bool.self) { geometry in
              geometry.contentOffset.y + geometry.contentInsets.top > 0
          } action: { _, isScrolledFromTop in
              onScrolledFromTopChange?(isScrolledFromTop)
          }
  ```

- **Every year page has all twelve month rows.** `TheocraticYearReportBuilder.report` builds `months` as `year.months.map { ... }` (`Hugo/Features/ServiceYear/Domain/TheocraticYearReportBuilder.swift:14`), and `TheocraticYear.months` is always September to August (`Hugo/Features/ServiceYear/Domain/TheocraticYear.swift:10-13`). The test `emptyEntriesProduceTwelveEmptyMonthsAndZeroTotals` in `HugoTests/Features/ServiceYear/Domain/TheocraticYearReportBuilderTests.swift` confirms this. The menu can therefore list `activeYear.months` directly.

- Month names: `YearMonth.monthYearString()` (`Hugo/Domain/YearMonth.swift:77`) gives "September 2026" ("september 2026" in Danish). The Planner uses the same helper for its title (`PlannerView.swift:104`), so use it here too. The year spans two calendar years, so the year number helps.

- iPad: in the regular width layout (`Hugo/App/AppRootView.swift:84-96`) the Year tab is the detail column of a `NavigationSplitView`, and `SettingsButton(sizeClass: .compact)` hides itself there. The new menu must show in both widths, so it gets no size-class condition.

- Motion: `Hugo/DesignSystem/Motion/Motion.swift` defines `Motion.presence` (`.smooth(duration: 0.3)`) for elements entering or leaving. The `.motion(_:value:)` modifier is for view animations and does not apply to scrolling. For the scroll, read `@Environment(\.accessibilityReduceMotion)` and animate only when it is false.

- Glossary (`CONTEXT.md`): **Theocratic year**: "The year from September 1 to August 31, written as both calendar years, for example 2026/2027." `TheocraticYear.displayName` gives that label.

- Conventions: SwiftUI only, Swift 6 strict concurrency with MainActor default isolation. Value types in a feature's `Domain` folder are `nonisolated` where possible (see `TheocraticYear.swift:3`). Tests use Swift Testing (`import Testing`, `@Test`, `#expect`).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| JSON is valid | `python3 -c "import json; json.load(open('Hugo/Resources/Localizable.xcstrings', encoding='utf-8'))"` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/MonthJumpRequestTests -only-testing:HugoTests/TheocraticYearReportBuilderTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 (takes several minutes) |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run the same command again; that is not a failure.

## Scope

**In scope** (the only files you modify or create):
- `Hugo/Features/ServiceYear/Domain/MonthJumpRequest.swift` (create)
- `HugoTests/Features/ServiceYear/Domain/MonthJumpRequestTests.swift` (create)
- `Hugo/Features/ServiceYear/Screens/ServiceYearView.swift`
- `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift`
- `Hugo/Resources/Localizable.xcstrings` (one new key)

**Out of scope**:
- `ServiceYearMonthRow.swift`, `TheocraticYearTotalsView.swift` and the year header. Other plans change the header.
- `SettingsButton`, `AppRootView` and the nested `NavigationStack` (tracked separately as SLN-200).
- Switching years from the menu. The menu lists only the months of the year on screen; users swipe to change years.
- Highlighting the current month in the menu, or disabling future months. Keep the menu a plain list.
- Do not open the string catalog in Xcode and save it; edit the text file directly.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- The working tree may hold uncommitted owner files in `plans/` and `.claude/`. Never stage, edit, stash or discard them. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage only the in-scope files, by explicit path.
- One commit, Conventional Commits style: `feat: add a jump-to-month menu to the Year page`

## Steps

### Step 1: Add the jump request type and its test

Create `Hugo/Features/ServiceYear/Domain/MonthJumpRequest.swift`:

```swift
import Foundation

/// A request to scroll a Year page so one month's card is at the top. Each
/// request has its own id, so asking for the same month twice scrolls again.
nonisolated struct MonthJumpRequest: Equatable {
    let month: YearMonth
    let id = UUID()
}
```

Create `HugoTests/Features/ServiceYear/Domain/MonthJumpRequestTests.swift`:

```swift
import Foundation
import Testing

@testable import Hugo

struct MonthJumpRequestTests {
    @Test
    func keepsTheRequestedMonth() {
        let request = MonthJumpRequest(month: YearMonth(year: 2027, month: 3))
        #expect(request.month == YearMonth(year: 2027, month: 3))
    }

    @Test
    func twoRequestsForTheSameMonthDiffer() {
        let month = YearMonth(year: 2027, month: 3)
        #expect(MonthJumpRequest(month: month) != MonthJumpRequest(month: month))
    }
}
```

**Verify**: the focused test command → `** TEST SUCCEEDED **`, and the output lists `keepsTheRequestedMonth` and `twoRequestsForTheSameMonthDiffer` as passed.

### Step 2: Let a year page scroll to a requested month

In `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift`:

1. Add a stored property after `onScrolledFromTopChange` (line 6):

   ```swift
       var jumpRequest: MonthJumpRequest? = nil
   ```

   and an environment value after the `@AppStorage` lines:

   ```swift
       @Environment(\.accessibilityReduceMotion) private var reduceMotion
   ```

2. Change the initializer (line 14) to take the request, keeping the existing parameters and their order:

   ```swift
       init(
           year: TheocraticYear, jumpRequest: MonthJumpRequest? = nil,
           onScrolledFromTopChange: ((Bool) -> Void)? = nil
       ) {
           self.year = year
           self.jumpRequest = jumpRequest
           self.onScrolledFromTopChange = onScrolledFromTopChange
           ...existing lines unchanged...
       }
   ```

3. In `body`, wrap the existing `ScrollView` and its modifiers in a `ScrollViewReader`, and add one `onChange` at the end. The result has this shape (the `VStack` content stays exactly as it is):

   ```swift
       var body: some View {
           let report = self.report
           let progress = progress(for: report)
           return ScrollViewReader { proxy in
               ScrollView {
                   VStack(spacing: HugoLayout.Spacing.card) {
                       ...unchanged...
                   }
                   .padding()
               }
               .frame(maxWidth: .infinity)
               .onScrollGeometryChange(for: Bool.self) { geometry in
                   geometry.contentOffset.y + geometry.contentInsets.top > 0
               } action: { _, isScrolledFromTop in
                   onScrolledFromTopChange?(isScrolledFromTop)
               }
               .onChange(of: jumpRequest) { _, request in
                   guard let request, year.contains(request.month) else { return }
                   withAnimation(reduceMotion ? nil : Motion.presence) {
                       proxy.scrollTo(request.month, anchor: .top)
                   }
               }
           }
       }
   ```

   The `year.contains` guard makes sure only the page of the requested year scrolls. The horizontal `LazyHStack` may keep neighboring year pages alive, and they must ignore the request. `proxy.scrollTo(request.month, ...)` matches the `.id(month.id)` on the rows because both are `YearMonth` values.

**Verify**: `xcodebuild build -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData CODE_SIGNING_ALLOWED=NO` → ends with `** BUILD SUCCEEDED **`. `grep -n "jumpRequest" Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift` → at least 4 lines.

### Step 3: Add the menu to the Year toolbar

In `Hugo/Features/ServiceYear/Screens/ServiceYearView.swift`:

1. Add state next to the other `@State` lines (after line 10):

   ```swift
       @State private var jumpRequest: MonthJumpRequest?
   ```

2. Pass it to every page (lines 48–53):

   ```swift
                          ServiceYearPageView(
                              year: year,
                              jumpRequest: jumpRequest,
                              onScrolledFromTopChange: { newValue in
                                  scrolledPages[year.id] = newValue
                              }
                          )
   ```

3. Add a leading toolbar item as the first item inside `.toolbar { ... }`, before the principal item:

   ```swift
                  ToolbarItem(placement: .topBarLeading) {
                      Menu {
                          Section(activeYear.displayName) {
                              ForEach(activeYear.months, id: \.self) { month in
                                  Button(month.monthYearString()) {
                                      jumpRequest = MonthJumpRequest(month: month)
                                  }
                              }
                          }
                      } label: {
                          Label("year.jump.label", systemImage: "calendar")
                      }
                  }
   ```

   Do not add a size-class condition: the menu shows on iPhone and iPad. Leave the trailing `SettingsButton(sizeClass: .compact)` item as it is.

**Verify**: the build command from Step 2 → `** BUILD SUCCEEDED **`. `grep -n "topBarLeading\|MonthJumpRequest(month:" Hugo/Features/ServiceYear/Screens/ServiceYearView.swift` → 2 lines.

### Step 4: Add the menu's label to the string catalog

The catalog `Hugo/Resources/Localizable.xcstrings` keeps its keys in alphabetical order. Find where the new key goes:

```bash
python3 -c "import json; ks=sorted(json.load(open('Hugo/Resources/Localizable.xcstrings', encoding='utf-8'))['strings']); print([k for k in ks if k > 'year.jump.label'][0])"
```

Insert this block directly before the key that command prints, using the same 4-space indentation as its neighbors (2-space steps, `" : "` between key and value, literal UTF-8 characters):

```json
    "year.jump.label" : {
      "comment" : "Toolbar menu on the Year page that lists the months of the theocratic year and scrolls to the one the user picks.",
      "localizations" : {
        "da" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Gå til måned"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Jump to Month"
          }
        }
      }
    },
```

The Danish value is a proposal; the owner reviews it before the build.

**Verify**: the JSON check → exit 0. `grep -c '"year.jump.label" : {' Hugo/Resources/Localizable.xcstrings` → `1`. `git diff --numstat Hugo/Resources/Localizable.xcstrings` → `17	0	...` (17 added lines, none removed).

### Step 5: Run the gate and commit

Run `Scripts/verify.sh`. Then stage the five in-scope files by path and commit with the message from "Git workflow".

**Verify**: `Scripts/verify.sh` exits 0. `git show --stat HEAD` lists exactly the five in-scope files.

## Test plan

- New: `MonthJumpRequestTests` (Step 1). Its second test covers the "pick the same month twice" case: the page reacts to a changed request, and two requests for the same month are never equal.
- Existing: `TheocraticYearReportBuilderTests.emptyEntriesProduceTwelveEmptyMonthsAndZeroTotals` guards the assumption that every page has twelve rows to jump to.
- The scroll itself is view wiring and has no automated test. The owner checks it on a device:
  1. On the Year tab, tap the calendar button at the top left. The menu shows the year (for example "2026/2027") and twelve months from September to August.
  2. Pick March. The March card scrolls to the top.
  3. Scroll back up by hand, then pick March again. It scrolls down again.
  4. Swipe to the previous year and open the menu. It lists that year's months, and picking one scrolls that page only.
  5. Turn on Reduce Motion (Settings > Accessibility > Motion). Picking a month jumps without the sliding animation.
  6. On an iPad (or the iPad simulator), the calendar button shows in the Year page's toolbar.
  7. VoiceOver reads the button as "Jump to Month" ("Gå til måned" in Danish).

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, including the 2 new tests in `MonthJumpRequestTests`.
- [ ] `grep -rn "MonthJumpRequest" Hugo` lists `MonthJumpRequest.swift`, `ServiceYearView.swift` and `ServiceYearPageView.swift`.
- [ ] `grep -c '"year.jump.label" : {' Hugo/Resources/Localizable.xcstrings` → `1`
- [ ] `git show --stat HEAD` lists only the five in-scope files.
- [ ] `plans/README.md` status row updated (unless a reviewer maintains it).

## STOP conditions

Stop and report back (do not improvise) if:

- `ServiceYearPageView` no longer gives each `ServiceYearMonthRow` an `.id(month.id)`, or `ServiceMonth.id` is no longer a `YearMonth`.
- `report.months` can hold fewer than twelve months (for example, the builder starts filtering months). The menu would then list months with no card.
- The build fails because `ServiceYearPageView` is created somewhere besides `ServiceYearView.swift` and its own preview with arguments that no longer fit the new initializer. Report the call site.
- A step's verification fails twice after a reasonable fix attempt.

## Maintenance notes

- The page reacts to *changes* of `jumpRequest`, not to its value on appear. A page that scrolls into view later does not replay an old request. Keep that behavior if the pager is rewritten.
- If month rows ever get a sticky header or the year header becomes pinned, `anchor: .top` may hide the target row's top edge under it. Revisit the anchor then.
- If the Year tab is restructured into one `NavigationStack` for the split view (SLN-200), keep the menu on the Year page's root, not on the pushed year detail.
- The menu label uses Title Case in English ("Jump to Month") to match other accessibility labels in the catalog ("Month Progress", "Sort by Date").
