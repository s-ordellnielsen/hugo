# Plan 135: Keep extra time in its own category in the Planner

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 0af2e24..HEAD -- Hugo/Features/Planner/Domain/PlanMatcher.swift Hugo/Features/Planner/Domain/PlannerMonth.swift HugoTests/Features/Planner/Domain/PlanMatcherTests.swift HugoTests/Features/Planner/Domain/PlannerMonthTests.swift CONTEXT.md`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> Also `git status --short` must show only
> `M Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` (the owner's own
> edit; never touch or commit it) and untracked plan files.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW. Pure value logic in two Domain files, covered by tests. It changes the Planner's bars, the Planner header's "still planned" figure and the Overview plan status, all deliberately, in the same way.
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `0af2e24`, 2026-11-23
- **Issue**: [SLN-318](https://linear.app/sebastianln/issue/SLN-318)

## Why this matters

Owner report: plan 2 hours of Field Service (X) and 1 hour of Phone (Y) on one
day, then log 2h15 of X. X's bar is full, which is right. Y's bar shows a quarter
filled, which is wrong: Y has no logged time. The extra 15 minutes of X must stay
on X.

Cause: `PlanMatcher.bars` has a second pass, "other time of the same kind". After
each category has taken its own logged time, any leftover time of another
category with the same kind (main or separate) fills this category's plan. X's
leftover 15 minutes is main time, Y is a main plan, so Y fills 15 of 60 minutes.
Plan 068 added the pass on purpose, so that all main categories behave like one
pool, matching the header. The owner now wants the opposite rule: time logged in
one category fills only that category's plans.

The header must not disagree with the bars. Today the header's "still planned"
figure is computed per kind, not per category
(`PlannerMonth.stillPlanned` = `planned.remaining(after: logged)` per day). If
only the matcher changed, the bars would say Y has 1h left while the header said
0h45 left. So the fix has two parts: remove the cross-category pass from the
matcher, and compute the day's still-planned time from the plan bars instead of
from the per-kind totals. Then the bars and the header are the same numbers by
construction. Worked example (2h X plan, 1h Y plan, 2h15 X logged): X bar full,
Y bar empty with 1h left, day still planned 1h, month logged 2h15, projected
3h15. Before the fix the projected time was 3h.

Not changed on purpose:

- The yearly report line. All main categories still land on the same report
  line and `PlannerMonthStatus` still applies the credit rule to `projected`
  per kind. Only how much of the plan counts as "still planned" changes, not how
  main and separate time are credited.
- Logged time beyond a category's plans stays on that category's plan bar
  (third pass, unchanged). Logged time in a category with no plan that day keeps
  its own unplanned bar (unchanged).
- Time in a different category no longer covers a plan, even for a category with
  no plan that day. Example: a Field Service plan of 2h and 2h of Phone logged
  now leaves the plan empty and shows a full unplanned Phone bar. This is the
  owner's rule ("only fill that category's plans") and keeps the matching key
  simple: the category key.

Matching key check: `PlanMatcher` already groups and fills by
`categoryKey`/`LoggedCategoryTime.key` (an `EntryCategory.key`), not by kind.
Kind is only used by the second pass being removed and by `TimeSplit` for the
header's credit rule. No key change is needed.

## Current state

`Hugo/Features/Planner/Domain/PlanMatcher.swift`, lines 46 to 53 (doc comment)
and 85 to 99 (the passes). Verify these match before editing:

```swift
/// Matches one day's logged time to its plans, per category. Start times are
/// ignored: an entry does not record whether its time was picked or guessed.
/// Each category's plans share one bar. A bar takes time from its own category
/// first, then other time of the same kind (main or separate). Time beyond a
/// category's plans stays on that category's bar. Logged time left over in a
/// category with no plan becomes an unplanned bar.
```

```swift
        for key in groupKeys {
            fill(key, from: key, upTo: plannedSeconds[key] ?? 0)
        }
        for key in groupKeys {
            let type = groupItems[key]?.first?.categoryType ?? .main
            for category in categories where (category.type ?? .main) == type {
                fill(key, from: category.key, upTo: plannedSeconds[key] ?? 0)
            }
        }
        for key in groupKeys {
            fill(key, from: key, upTo: .infinity)
        }
```

The first pass fills each category's plans from its own time up to the planned
amount. The second pass is the bug. The third pass puts a category's extra time
on its own bar. After the second pass is removed, the first and third pass could
be one pass (`upTo: .infinity`), but keep both unchanged to keep the diff small.

`Hugo/Features/Planner/Domain/PlannerMonth.swift`:

- Lines 14 to 20, `TimeSplit.remaining(after:)`, used only by `stillPlanned` and by one test:

```swift
    /// What is left of `self` once `covered` is taken off, per kind, never below zero.
    func remaining(after covered: TimeSplit) -> TimeSplit {
        TimeSplit(main: max(0, main - covered.main), separate: max(0, separate - covered.separate))
    }
```

- Lines 28 to 37, the `PlannerDay` stored properties (the `bars` doc comment is on lines 33 to 34):

```swift
nonisolated struct PlannerDay: Identifiable, Equatable, Sendable {
    let id: CalendarDay
    let logged: TimeSplit
    let planned: TimeSplit
    /// Plan bars, one per category in the order of each category's first plan,
    /// then unplanned bars.
    let bars: [PlannerBar]
    let isToday: Bool
    let isPast: Bool
```

- Lines 90 to 94, `PlannerMonth.stillPlanned`:

```swift
    /// Planned time on today and later days that logged time has not yet covered.
    var stillPlanned: TimeSplit {
        days.filter { $0.id >= today }.reduce(.zero) { $0 + $1.planned.remaining(after: $1.logged) }
    }
```

`PlannerMonthStatus.swift` (lines 41 to 50) reads `month.projected`
(`logged + stillPlanned`) and needs no change. `PlanPace.swift` uses
`day.planned.total` and `day.logged.total` only and needs no change.
`PlanLogSeed.swift` uses `bar.filledSeconds` and `bar.remainingSeconds` and needs
no change.

Tests that matter in `HugoTests/Features/Planner/Domain/`:

- `PlanMatcherTests.swift` has three tests that describe the old rule and must change: `secondPassLetsAnotherMainCategoryFillThePlan` (lines 33 to 43), `secondPassRespectsTheKindOfTime` (lines 45 to 59) and `extraTimeFillsAnotherPlanOfTheSameKindFirst` (lines 142 to 156). The file's helpers `plan(_:_:type:hours:startMinute:)`, `time(_:name:type:hours:)`, `time(_:name:type:seconds:)` and `barID(_:)` are private at the bottom and are reused.
- `PlannerMonthTests.swift` test `planBarsAgreeWithStillPlannedTimePerKind` (lines 138 to 160) uses `planned.planned.remaining(after: planned.logged)` and expects `mainRemaining == 1_800`. Under the new rule that figure is 3_600 (the Phone plan stays unfilled). The other `stillPlanned` tests (lines 47 to 87, 188 to 196) keep passing: each logs in the same category it plans, or in a different kind, or plans nothing logged. Re-check by running them.
- `PlanLogSeedTests.swift` is unaffected (it only logs in the planned category).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint one file | `xcrun swift-format lint --strict <file>` | exit 0, no output |
| Whole gate | `Scripts/verify.sh` | exit 0 (lint, all tests, analyze). Takes several minutes. |

Run the gate with Rex, as the owner's `CLAUDE.md` says, or with its output
redirected to a file under
`/private/tmp/claude-501/-Users-sebastiannielsen-Documents-Areas-Personal-Apps-Hugo/e838d7fa-4b4b-47a9-b236-f61a2004ed12/scratchpad/`
(for example `verify-135.log`), and take the exit code from the script itself.

## Scope

**In scope** (the only files you may modify):

- `Hugo/Features/Planner/Domain/PlanMatcher.swift`
- `Hugo/Features/Planner/Domain/PlannerMonth.swift`
- `HugoTests/Features/Planner/Domain/PlanMatcherTests.swift`
- `HugoTests/Features/Planner/Domain/PlannerMonthTests.swift`
- `CONTEXT.md` (the "Covered time" definition)
- `plans/README.md` (status row, and the "Strict per-category bar filling" note)

**Out of scope** (do NOT touch):

- `PlannerMonthStatus.swift`, `PlanPace.swift`, `PlanLogSeed.swift`, `PlannedItem.swift` and every view: they need no change.
- The Overview and Year tab calculations, the report credit rule, and the `Plan` schema.
- Localized strings and help articles: none describes the cross-category pass (checked `Hugo/Resources/Markdown/Help/Base.lproj/TargetThisMonth.md` and `Localizable.xcstrings`).
- `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`: the owner's uncommitted edit. Never stage it.

## Git workflow

- Commit straight to `main`. Do not create a branch or a worktree.
- One commit after `Scripts/verify.sh` exits 0, Conventional Commits: `fix: keep extra logged time on its own category's plan bar`.
- Stage by explicit path only (the six files above, plus `plans/135-keep-extra-time-in-its-own-category.md` if it is still untracked). Never `git add -A` or `git add .`. Do not push.

## Steps

### Step 1: Write the failing regression tests first

In `HugoTests/Features/Planner/Domain/PlanMatcherTests.swift`, add this test
directly after `ownersExampleFillsEachPlanFromItsOwnCategory` (after line 31):

```swift
    @Test
    func extraTimeInOneCategoryDoesNotFillAnotherCategorysPlan() throws {
        let plans = [
            plan("fs", fieldServiceID, type: .main, hours: 2),
            plan("phone", phoneID, type: .main, hours: 1),
        ]
        let logged = [time(fieldServiceID, name: "Field Service", type: .main, hours: 2.25)]

        let bars = PlanMatcher.bars(plans: plans, logged: logged)

        #expect(bars.count == 2)
        let fieldService = try #require(bars.first { $0.id == barID(fieldServiceID) })
        #expect(fieldService.filledSeconds == 8_100)
        #expect(fieldService.fraction == 1)
        #expect(fieldService.isFull)
        let phone = try #require(bars.first { $0.id == barID(phoneID) })
        #expect(phone.filledSeconds == 0)
        #expect(phone.fraction == 0)
        #expect(phone.remainingSeconds == 3_600)
        #expect(!bars.contains { $0.kind == .unplanned })
    }
```

In `HugoTests/Features/Planner/Domain/PlannerMonthTests.swift`, add this test
after `separateAndMainAreKeptApartWhenStillPlanned` (after line 75):

```swift
    @Test
    func extraTimeInOneCategoryDoesNotReduceAnotherCategorysStillPlannedTime() {
        let day = CalendarDay(year: 2026, month: 11, day: 5)
        let items = [
            item(day, hours: 2, tracker: main),
            item(day, hours: 1, tracker: phone),
        ]
        let entries = [Entry(date: date(2026, 11, 5, hour: 10), duration: 2.25 * 3_600, tracker: main)]
        let month = makeMonth(items: items, entries: entries)

        #expect(month.stillPlanned == TimeSplit(main: 3_600, separate: 0))
        #expect(month.projected == TimeSplit(main: 11_700, separate: 0))
    }
```

Do not run the tests yet (the gate runs them all at the end). Both fail against
the current code: the bar test gets `filledSeconds == 900` for Phone, and the
month test gets `stillPlanned.main == 2_700`.

**Verify**: `grep -c "extraTimeInOneCategoryDoesNot" HugoTests/Features/Planner/Domain/PlanMatcherTests.swift HugoTests/Features/Planner/Domain/PlannerMonthTests.swift` prints `...PlanMatcherTests.swift:1` and `...PlannerMonthTests.swift:1`.

### Step 2: Remove the cross-category pass from `PlanMatcher`

In `Hugo/Features/Planner/Domain/PlanMatcher.swift`:

1. Delete exactly these lines (the second pass):

```swift
        for key in groupKeys {
            let type = groupItems[key]?.first?.categoryType ?? .main
            for category in categories where (category.type ?? .main) == type {
                fill(key, from: category.key, upTo: plannedSeconds[key] ?? 0)
            }
        }
```

2. Replace the type's doc comment (lines 46 to 52) with:

```swift
/// Matches one day's logged time to its plans, per category. Start times are
/// ignored: an entry does not record whether its time was picked or guessed.
/// Each category's plans share one bar. A bar is filled only by time logged in
/// its own category, so extra time in one category never fills another
/// category's plans. Time beyond a category's plans stays on that category's
/// bar. Logged time in a category with no plan becomes an unplanned bar.
```

3. Do not change any other line. `categories` is still used by the unplanned bars below, so the compiler stays quiet.

**Verify**:
- `grep -n "categoryType" Hugo/Features/Planner/Domain/PlanMatcher.swift` prints nothing.
- `xcrun swift-format lint --strict Hugo/Features/Planner/Domain/PlanMatcher.swift` exits 0.

### Step 3: Compute a day's still-planned time from its bars

In `Hugo/Features/Planner/Domain/PlannerMonth.swift`:

1. Delete `TimeSplit.remaining(after:)` (the doc comment and the function, lines 17 to 20, plus the blank line before `static func +`  must remain single). After the edit the `TimeSplit` body is `main`, `separate`, `zero`, `total`, `add`, then `static func +`, each separated by one blank line.

2. In `PlannerDay`, directly after the stored properties (after `let isPast: Bool`, line 37) and before the `/// \`items\` and \`entries\`` doc comment of `make`, insert:

```swift

    /// Planned time that logged time in the same category has not covered yet:
    /// what the plan bars still have left. The month's still-planned time adds
    /// this up, so the header always agrees with the bars.
    var stillPlanned: TimeSplit {
        var split = TimeSplit.zero
        for bar in bars where bar.kind == .plan {
            split.add(bar.remainingSeconds, type: bar.items.first?.categoryType)
        }
        return split
    }
```

3. Replace the body of `PlannerMonth.stillPlanned` (lines 91 to 94) with:

```swift
    /// Planned time on today and later days that logged time in the same
    /// category has not yet covered.
    var stillPlanned: TimeSplit {
        days.filter { $0.id >= today }.reduce(.zero) { $0 + $1.stillPlanned }
    }
```

**Verify**:
- `grep -rn "remaining(after" Hugo HugoTests --include='*.swift'` prints only the line in `PlannerMonthTests.swift` that Step 4 rewrites.
- `xcrun swift-format lint --strict Hugo/Features/Planner/Domain/PlannerMonth.swift` exits 0.

### Step 4: Update the tests that described the old rule

In `HugoTests/Features/Planner/Domain/PlanMatcherTests.swift`:

1. Replace `secondPassLetsAnotherMainCategoryFillThePlan` (lines 33 to 43) with:

```swift
    @Test
    func anotherMainCategoryDoesNotFillThePlan() throws {
        let plans = [plan("fs", fieldServiceID, type: .main, hours: 2)]
        let logged = [time(phoneID, name: "Phone", type: .main, hours: 2)]

        let bars = PlanMatcher.bars(plans: plans, logged: logged)

        #expect(bars.count == 2)
        let planBar = try #require(bars.first { $0.id == barID(fieldServiceID) })
        #expect(planBar.filledSeconds == 0)
        #expect(planBar.remainingSeconds == 7_200)
        let unplanned = try #require(bars.first { $0.kind == .unplanned })
        #expect(unplanned.id == "unplanned:\(phoneID.uuidString)")
        #expect(unplanned.seconds == 7_200)
    }
```

2. Rename `secondPassRespectsTheKindOfTime` (line 45) to `timeOfAnotherKindDoesNotFillThePlan`. Leave its body as it is (it still passes).

3. Replace `extraTimeFillsAnotherPlanOfTheSameKindFirst` (lines 142 to 156) with:

```swift
    @Test
    func extraTimeStaysOnItsOwnBarWhenAnotherPlanOfTheSameKindIsEmpty() throws {
        let plans = [
            plan("fs", fieldServiceID, type: .main, hours: 1),
            plan("phone", phoneID, type: .main, hours: 1),
        ]
        let logged = [time(fieldServiceID, name: "Field Service", type: .main, hours: 2)]

        let bars = PlanMatcher.bars(plans: plans, logged: logged)

        #expect(bars.count == 2)
        let fieldService = try #require(bars.first { $0.id == barID(fieldServiceID) })
        #expect(fieldService.filledSeconds == 7_200)
        #expect(fieldService.isFull)
        let phone = try #require(bars.first { $0.id == barID(phoneID) })
        #expect(phone.filledSeconds == 0)
        #expect(!phone.isFull)
        #expect(!bars.contains { $0.kind == .unplanned })
    }
```

In `HugoTests/Features/Planner/Domain/PlannerMonthTests.swift`, replace
`planBarsAgreeWithStillPlannedTimePerKind` (lines 138 to 160) with the version
below. Keep the first part (the `day`, three items, two entries and the
`PlannerDay.make` call) exactly as it is and change only the name and the last
block:

```swift
    @Test
    func planBarsAgreeWithTheDaysStillPlannedTime() {
        let day = CalendarDay(year: 2026, month: 11, day: 5)
        let fieldService = item(day, hours: 2, tracker: main, id: "fs")
        let phoneItem = item(day, hours: 1, tracker: phone, id: "phone")
        let ldc = item(day, hours: 1, tracker: separate, id: "ldc")
        let entries = [
            Entry(date: date(2026, 11, 5, hour: 9), duration: 2.5 * 3_600, tracker: main),
            Entry(date: date(2026, 11, 5, hour: 13), duration: 2 * 3_600, tracker: separate),
        ]

        let planned = PlannerDay.make(
            day: day, items: [fieldService, phoneItem, ldc], entries: entries,
            trackers: [main, phone, separate], today: CalendarDay(year: 2026, month: 11, day: 3))

        let mainRemaining = planned.bars.filter { $0.items.first?.categoryType == .main }
            .reduce(0) { $0 + $1.remainingSeconds }
        let separateRemaining = planned.bars.filter { $0.items.first?.categoryType == .separate }
            .reduce(0) { $0 + $1.remainingSeconds }

        #expect(mainRemaining == 3_600)
        #expect(separateRemaining == 0)
        #expect(planned.stillPlanned == TimeSplit(main: mainRemaining, separate: separateRemaining))
    }
```

**Verify**: `grep -rn "secondPass\|remaining(after\|SameKindFirst" HugoTests` prints nothing. `xcrun swift-format lint --strict` exits 0 on both test files.

### Step 5: Update the domain text

In `CONTEXT.md`, replace the whole "**Covered time**" definition (the paragraph
starting `The part of a category's planned time on a day that logged time accounts for`) with:

```
The part of a category's planned time on a day that time logged in that same category accounts for. Hugo matches per category, not per plan, and ignores start times, because an entry does not record whether its time was picked or guessed. Time in one category never covers another category's plans, even of the same kind (Field Service or Credit). The Planner draws each category's plans on a day as one bar, filled as far as the covered time goes. Time beyond the plans stays on that bar. The day's still-planned time is the sum of what its bars have left, so the Planner header agrees with the bars.
```

Also in the "**Unplanned time**" definition, replace
`and that no plan of the same kind took` with nothing, so it reads:
`Logged time in a category that has no plan on that day. It gets its own bar.`

In `plans/README.md`, in the bullet starting `* **Strict per-category bar filling** (2026-11-04)`, append the sentence
` Reversed 2026-11-23 (plan 135): the owner wanted extra time in one category to stay on that category, and the Planner header's still-planned time now comes from the bars.`

**Verify**: `grep -n "same kind" CONTEXT.md` prints nothing, and `grep -n "plan 135" plans/README.md` prints the note.

### Step 6: Run the gate and commit

Run `Scripts/verify.sh` as described in "Commands you will need". Then stage
the explicit paths from "Git workflow" and commit with the message given there.

**Verify**: exit code 0, and the log contains `** TEST SUCCEEDED **` and `** ANALYZE SUCCEEDED **`. The two new tests, `extraTimeInOneCategoryDoesNotFillAnotherCategorysPlan` and `extraTimeInOneCategoryDoesNotReduceAnotherCategorysStillPlannedTime`, appear as passed.

## Test plan

- `PlanMatcherTests.extraTimeInOneCategoryDoesNotFillAnotherCategorysPlan`: the owner's exact case (2h X, 1h Y, 2h15 X logged). X full, Y empty with 3,600 seconds left, no unplanned bar.
- `PlanMatcherTests.anotherMainCategoryDoesNotFillThePlan` and `extraTimeStaysOnItsOwnBarWhenAnotherPlanOfTheSameKindIsEmpty`: the old second-pass behavior, inverted.
- `PlanMatcherTests.timeOfAnotherKindDoesNotFillThePlan`: unchanged behavior, renamed.
- `PlannerMonthTests.extraTimeInOneCategoryDoesNotReduceAnotherCategorysStillPlannedTime`: the header side. Still planned 3,600 (not 2,700) and projected 11,700 seconds (2h15 logged plus 1h).
- `PlannerMonthTests.planBarsAgreeWithTheDaysStillPlannedTime`: the bars' remaining time per kind equals `PlannerDay.stillPlanned`, with a main and a separate plan and a main and a separate entry.
- The existing `stillPlannedCountsOnlyTodayAndLaterDays`, `loggedAbovePlanTodayAddsNothingAndNeverGoesNegative`, `separateAndMainAreKeptApartWhenStillPlanned`, `futureMonthLeavesEveryPlannedSecondStillPlanned`, `carriedInEntryDoesNotCoverAPlanOnTheFirst`, `PlanLogSeedTests` and `PlannerMonthStatusTests` keep passing unchanged.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0.
- [ ] `grep -rn "remaining(after" Hugo HugoTests --include='*.swift'` prints nothing.
- [ ] `PlanMatcher.swift` contains no `categoryType` and no second pass.
- [ ] Only the six in-scope files (plus this plan file) changed in the commit.
- [ ] `plans/README.md` status row added or updated (unless the reviewer maintains it).

## STOP conditions

Stop and report back (do not improvise) if:

- The code at "Current state" does not match, for example the matcher no longer has a pass keyed by kind.
- A test other than the ones named in Step 4 fails after the change (for example in `PlannerMonthStatusTests`, `PlanPaceTests` or `PlanLogSeedTests`). Report which one and its output instead of editing it.
- `PlannerDay` cannot compile with the new `stillPlanned` property (for example a name clash). Do not rename existing members.
- A step's verification fails twice.
- The change appears to need any file outside the scope list.

## Maintenance notes

- Behavior change to know about: the Planner header's "Still planned" and the projected time can now be larger than before when a user logs more than planned in one category and has another plan that day. That is intended: the other plan is still undone. A reviewer should check this on the Planner tab with the owner's case (plan 2h Field Service and 1h another main category, log 2h15 Field Service): first bar full, second bar empty, header still planned 1h.
- The month-level credit rule is untouched. `PlannerMonthStatus` still gets `projected` split by kind and credits it per the yearly goal rule.
- If users later want "extra time helps another plan", do it as an explicit user action (move time between plans), not as a hidden matcher pass.
- Out-of-scope observation: after this change `PlanMatcher`'s first and third pass could merge into one (`upTo: .infinity`). It was left alone to keep the fix small.
