# Plan 113: Give the plan pace sheet the same look as the carried-in breakdown sheet

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat d631e6c..HEAD -- Hugo/Features/Overview/Screens/PlanPaceSheet.swift Hugo/Features/Overview/Screens/OverviewView.swift Hugo/Features/Overview/Screens/CarriedInBreakdownSheet.swift`
> Expected: no output. If a file is listed, compare the excerpts below with the
> live code. A mismatch is a STOP condition. Changes to
> `Localizable.xcstrings` from other plans are fine as long as the
> `overview.pace.*` keys named below are unchanged.

## Status

- **Priority**: P3
- **Effort**: S + owner (look at it on a device, in English and Danish)
- **Risk**: LOW. One sheet's layout and two strings. No logic, no data.
- **Depends on**: plan 111 Revision 2 (the carried-in breakdown sheet this plan copies; done as `1bb4e58`)
- **Category**: direction (UI consistency)
- **Planned at**: commit `d631e6c`, 2026-11-14
- **Issue**: [SLN-311](https://linear.app/sebastianln/issue/SLN-311)

## Why this matters

The Overview has two small sheets. Tapping the carried-in line opens the carried-in breakdown, and tapping the status line under the monthly circle ("You're 3 hours behind your plan") opens the plan pace sheet. On 2026-11-14 the owner settled the look of the carried-in sheet (plan 111, Revisions 1 and 2): the sentence is the heading at the very top in large serif type, there is no navigation bar and no Done button, the list has a section header, and a drag indicator shows that the sheet closes with a swipe down. The owner asked for the plan pace sheet to get the same makeover, so the two sheets look and behave alike.

## Current state

### The sheet to change

`Hugo/Features/Overview/Screens/PlanPaceSheet.swift` (whole file at `d631e6c`):

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

Its heading (status label with icon, in `.title2` serif bold, plus the difference sentence) already matches the target style. What differs from the carried-in sheet: the `NavigationStack` with the title "Your plan" / "Din plan" (`overview.pace.title`) and a Done button, no section header, and no drag indicator.

### Where it is opened

`Hugo/Features/Overview/Screens/OverviewView.swift`, around line 110 (inside `OverviewDayView`):

```swift
            .sheet(isPresented: $showingPlanPace) {
                if let pace {
                    PlanPaceSheet(pace: pace)
                        .presentationDetents([.medium])
                }
            }
```

### The pattern to copy

`Hugo/Features/Overview/Screens/CarriedInBreakdownSheet.swift` after plan 111 Revision 2 (`1bb4e58`): a bare `List` (no `NavigationStack`), a first `Section` with the heading row (`.listRowBackground(Color.clear)`, `.accessibilityAddTraits(.isHeader)`), and a second `Section` with `header: { Text("overview.carried.breakdown.header") }`. It is shown from `OverviewListView.swift` with:

```swift
            CarriedInBreakdownSheet(carriedIn: carriedIn, entries: entries)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
```

### Strings

In `Hugo/Resources/Localizable.xcstrings`:

| Key | English | Danish | After this plan |
|---|---|---|---|
| `overview.pace.title` | Your plan | Din plan | removed (only `PlanPaceSheet` uses it) |
| `overview.pace.planned` | Planned until today | Planlagt indtil i dag | unchanged |
| `overview.pace.logged` | Logged | Udført | unchanged |
| `overview.pace.footer` | Today's plans count only as far as you have logged them, so today never counts against you. | Dagens planer tæller kun med, så langt du har udført dem. Derfor tæller i dag aldrig imod dig. | unchanged (see Owner decisions) |
| `overview.pace.breakdown.header` | So far this month | Indtil videre i denne måned | new |

`navigation.done` stays: many other screens use it.

## Owner decisions (recommended defaults, change before executing if wanted)

1. **Keep the footer.** The carried-in sheet lost its footer because it repeated what the heading already said. This footer explains a rule users can't see anywhere else ("today never counts against you"), and Hugo's users need the app to explain itself. Alternative: remove it too, for a sheet that matches the carried-in sheet exactly. If the owner picks that, also delete `Text("overview.pace.footer")` in Step 1 and remove the `overview.pace.footer` key in Step 3.
2. **Section header "So far this month" / "Indtil videre i denne måned".** It names what both rows measure. Alternative: "Breakdown" / "Fordeling", the carried-in sheet's word.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Catalog is valid JSON | `python3 -I -c "import json; json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0, no output |
| Full gate (before the commit) | `Scripts/verify.sh` | exit 0 |
| Whitespace | `git diff --check` | exit 0 |

Use 4-space indentation. Tabs fail the lint.

## Scope

**In scope** (the only files you may change):

- `Hugo/Features/Overview/Screens/PlanPaceSheet.swift`
- `Hugo/Features/Overview/Screens/OverviewView.swift` (the `PlanPaceSheet` `.sheet` modifier only)
- `Hugo/Resources/Localizable.xcstrings` (remove one key, add one key)

**Out of scope**:

- `CarriedInBreakdownSheet.swift` and `OverviewListView.swift`. They are the pattern, not the target.
- `PlanPace`, `MonthlyProgressStatus`, `PlanPaceSentence` and the status line in `MonthlyProgressCard`. Nothing about how pace is computed or worded changes.
- `Hugo.xcodeproj/project.pbxproj`, `.claude/`, `Changelog/` and `plans/` (except this plan's README row). Never stage them.

## Git workflow

- Work on `main`. No branch, no worktree, no push. Stage files by path.
- One commit after `Scripts/verify.sh` exits 0: `feat: give the plan pace sheet the same layout as the carried-in sheet`.

## Steps

### Step 1: Drop the navigation bar and add the section header

In `PlanPaceSheet.swift`, replace the `@Environment(\.dismiss)` line and the whole `body` with:

```swift
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                    Label(status.label, systemImage: status.icon)
                        .font(.system(.title2, design: .serif, weight: .bold))
                    Text(pace.differenceSentence)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                .listRowBackground(Color.clear)
            }
            Section {
                LabeledContent(
                    "overview.pace.planned",
                    value: ServiceDurationFormatter.hoursString(from: pace.expectedSeconds))
                LabeledContent(
                    "overview.pace.logged",
                    value: ServiceDurationFormatter.hoursString(from: pace.loggedSeconds))
            } header: {
                Text("overview.pace.breakdown.header")
            } footer: {
                Text("overview.pace.footer")
            }
        }
    }
```

Keep the doc comment, `let pace`, `private var status` and both previews as they are.

**Verify**: lint exits 0. `grep -n "NavigationStack\|navigationTitle\|navigation.done\|dismiss" Hugo/Features/Overview/Screens/PlanPaceSheet.swift` prints nothing.

### Step 2: Show the drag indicator

In `OverviewView.swift`, in the `.sheet(isPresented: $showingPlanPace)` modifier, add `.presentationDragIndicator(.visible)` after `.presentationDetents([.medium])`. Change nothing else in that file.

**Verify**: `grep -n "presentationDragIndicator" Hugo/Features/Overview/Screens/OverviewView.swift` prints one line.

### Step 3: Strings

In `Hugo/Resources/Localizable.xcstrings` (keep the file's formatting: two-space JSON indentation, `" : "` spacing, keys in sorted order, `"state" : "translated"` for `da` and `en`; copy the shape of `overview.pace.logged`):

1. Remove `overview.pace.title`.
2. Add `overview.pace.breakdown.header` in sorted position (after `overview.pace.behind`): English "So far this month", Danish "Indtil videre i denne måned". Comment: "Section header above the planned and logged time in the plan pace sheet."

**Verify**:
- The JSON check exits 0.
- `python3 -I -c "import json; d=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings']; print('overview.pace.breakdown.header' in d, 'overview.pace.title' in d)"` prints `True False`.
- `grep -rn "overview.pace.title" Hugo` prints nothing.

### Step 4: Gate and commit

**Verify**: `Scripts/verify.sh` exits 0. After it, `git diff -- Hugo/Resources/Localizable.xcstrings` shows only the removed and the added key. `git status --short` lists only the three in-scope files (plus files the owner changed, which you must not stage). `git diff --check` exits 0. Commit.

## Test plan

Layout and strings only, no logic, so no unit test fits. The full suite must stay green. The owner checks it on a device.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -n "NavigationStack" Hugo/Features/Overview/Screens/PlanPaceSheet.swift` prints nothing
- [ ] `grep -n "overview.pace.breakdown.header" Hugo/Features/Overview/Screens/PlanPaceSheet.swift` prints one line
- [ ] `grep -n "presentationDragIndicator" Hugo/Features/Overview/Screens/OverviewView.swift` prints one line
- [ ] `git show --stat HEAD` lists only the three in-scope files
- [ ] `plans/README.md` row for 113 updated

## STOP conditions

- The drift check shows changes and the excerpts no longer match.
- A build adds, removes or marks stale any key in `Localizable.xcstrings` other than the two this plan changes.
- The change seems to need a file outside the in-scope list.

## Maintenance notes

- **Owner device check**, in English and Danish: make a plan for today or earlier this month so the status line appears under the Overview circle. Tap it. The sheet opens at half height with a drag indicator, the status ("Behind plan" and the sentence) at the very top in large serif type, then "So far this month" above "Planned until today" and "Logged", then the footer. There is no title bar and no Done button; swiping down closes it. With VoiceOver, the heading is announced as a heading.
- New small sheets on the Overview should follow the same layout: heading row at the top of a bare `List`, section headers, medium detent, visible drag indicator, no navigation bar.
