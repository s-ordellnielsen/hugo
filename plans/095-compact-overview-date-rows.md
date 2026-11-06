# Plan 095: Make the Overview date list compact again with touching tap areas

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 5b80c3a..HEAD -- Hugo/Features/Overview/Views/OverviewListView.swift HugoTests/Features/Overview`
> Expected: no output. If a file is listed, compare the "Current state" excerpts below with the live code. On any mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S (+ owner check on device)
- **Risk**: LOW (spacing in one private view; no data, string or accessibility change)
- **Depends on**: none (follow-up to plan 087, commit `a76ce93`)
- **Category**: direction (visual polish)
- **Planned at**: commit `5b80c3a`, 2026-11-06
- **Issue**: [SLN-302](https://linear.app/sebastianln/issue/SLN-302)

## Why this matters

Plan 087 made each entry in the Overview's "by date" list a button and gave each row `minHeight: 44`. With the 6 pt gap between rows, every entry now takes 50 pt. Before that change it took about 28 pt, so the day cards look loose. Part of each 50 pt is also a dead gap that can't be tapped.

The owner chose (2026-11-06) **touching rows sized by their content**. Remove the gap between rows and give each row 8 pt of padding above and below its text instead of a 44 pt minimum. A row is then about 38 pt at the default text size and grows with larger text. Rows touch, so the whole list can be tapped with no dead space. Everything plan 087 added stays: tapping opens the entry, the icon, the Bible studies count and the duration, one VoiceOver button per row, and the day header as a heading.

## Current state

- `Hugo/Features/Overview/Views/OverviewListView.swift` holds `OverviewDateList` with two private views.

  `DateListItem` (one day card) puts the rows in a `VStack` with a 6 pt gap (lines 174–179):

  ```swift
                  Divider()
                  VStack(spacing: HugoLayout.Spacing.small) {
                      ForEach(section.entries) { entry in
                          DateEntryRow(entry: entry, selectedEntry: $selectedEntry)
                      }
                  }
                  .padding(.top, HugoLayout.Spacing.small)
  ```

  `DateEntryRow` (one entry) gives its label a 44 pt minimum height (lines 197–218):

  ```swift
              Button {
                  selectedEntry = entry
              } label: {
                  HStack {
                      Image(systemName: category.iconName)
                      ...
                      Text(Duration.seconds(entry.duration).formatted(.time(pattern: .hourMinute)))
                          .monospacedDigit()
                  }
                  .frame(minHeight: HugoLayout.Size.minimumHitTarget)
                  .contentShape(.rect)
              }
              .buttonStyle(.plain)
              .accessibilityElement(children: .combine)
  ```

- `OverviewDateList` is `struct OverviewDateList: View { var entries: [Entry]; @Binding var selectedEntry: Entry? }`. It groups entries by `Calendar.current.startOfDay(for: entry.date)` and renders one `DateListItem(...).equatable()` per day.
- Theme tokens (`Hugo/DesignSystem/Theme/Theme.swift`): `HugoLayout.Spacing.tight` = 4, `.small` = 6, `.compact` = 8, `.regular` = 12. `HugoLayout.Size.minimumHitTarget` = 44.
- **Do not move per-entry reads into `DateListItem.body`.** It keeps `.equatable()` so the card only redraws when its section changes (plan 087's maintenance note).
- Render-test pattern: `HugoTests/DesignSystem/Components/MarkedProgressBarTests.swift:28-34` renders a view with `ImageRenderer` on the main actor and checks `renderer.uiImage?.size`. `Entry(date:duration:tracker:)` works in tests without a model container (see `HugoTests/Features/Planner/Domain/PlannerMonthTests.swift`).
- Project facts: Swift 6, default actor isolation `MainActor`; tests use Swift Testing (`import Testing`, `@Test`, `#expect`); tests mirror the source layout, so a test for `Hugo/Features/Overview/Views/OverviewListView.swift` goes in `HugoTests/Features/Overview/Views/`. 4-space indentation.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/OverviewDateListLayoutTests` | `** TEST SUCCEEDED **` |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Full gate | `Scripts/verify.sh` | exit 0 (several minutes) |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run the same command again.

## Scope

**In scope** (the only files you may modify or create):
- `Hugo/Features/Overview/Views/OverviewListView.swift` (only `DateListItem` and `DateEntryRow`)
- `HugoTests/Features/Overview/Views/OverviewDateListLayoutTests.swift` (create; the `Views` folder is new)

**Out of scope**:
- `OverviewEntryList` and `EntryRow` (the "by entry" list).
- The day header, the card padding, the divider and the `.padding(.top, HugoLayout.Spacing.small)` below it.
- `HugoLayout` tokens in `Theme.swift`. Do not add or change a token.
- Accessibility modifiers on `DateEntryRow` and `DateListItem`. Keep them exactly as they are.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- Never stage, edit, stash or discard files in `plans/` or `.claude/`. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage the two in-scope files by explicit path.
- One commit: `fix: make the Overview date list compact with touching tap areas`

## Steps

### Step 1: Write the failing layout test

Create `HugoTests/Features/Overview/Views/OverviewDateListLayoutTests.swift`:

```swift
import SwiftUI
import Testing

@testable import Hugo

/// The "by date" rows touch and are shorter than the 44 pt minimum at the
/// default text size, so the day cards stay compact (SLN-302).
@MainActor
struct OverviewDateListLayoutTests {
    @Test
    func entryRowsAreCompact() throws {
        let one = try renderedHeight(entryCount: 1)
        let three = try renderedHeight(entryCount: 3)
        let rowPitch = (three - one) / 2

        #expect(rowPitch < HugoLayout.Size.minimumHitTarget)
        #expect(rowPitch >= 30)
    }

    /// Height of one day card holding `entryCount` entries.
    private func renderedHeight(entryCount: Int) throws -> CGFloat {
        let start = Calendar.current.startOfDay(for: .now)
        let entries = (0..<entryCount).map { index in
            Entry(date: start.addingTimeInterval(TimeInterval(9 + index) * 3_600), duration: 1_800, tracker: nil)
        }
        let renderer = ImageRenderer(
            content: VStack { OverviewDateList(entries: entries, selectedEntry: .constant(nil)) }
                .frame(width: 390))
        let image = try #require(renderer.uiImage)
        return image.size.height
    }
}
```

`rowPitch` is the height one more entry adds to the card: row height plus the gap between rows. Today it is 44 + 6 = 50.

**Verify**: the focused tests → `** TEST FAILED **`, with `entryRowsAreCompact` failing on `rowPitch < HugoLayout.Size.minimumHitTarget` (the recorded value should be about 50). If it passes, STOP and report the measured `rowPitch`. If the render itself fails (`#require` fails), STOP and report.

### Step 2: Make the rows touch and size them by their content

In `OverviewListView.swift`:

1. In `DateListItem.body`, change `VStack(spacing: HugoLayout.Spacing.small) {` (the one holding `ForEach(section.entries)`) to `VStack(spacing: 0) {`. Leave the `.padding(.top, HugoLayout.Spacing.small)` after it unchanged.

2. In `DateEntryRow.body`, replace

   ```swift
                  .frame(minHeight: HugoLayout.Size.minimumHitTarget)
                  .contentShape(.rect)
   ```

   with

   ```swift
                  .padding(.vertical, HugoLayout.Spacing.compact)
                  .contentShape(.rect)
   ```

   `.contentShape(.rect)` must stay **after** the padding, so the padding is part of the tap area and neighboring rows' tap areas touch.

3. Update the comment, if any, that mentions the 44 pt minimum on these rows. Add this doc comment directly above `private struct DateEntryRow: View {`:

   ```swift
       /// One entry in a day card. Rows touch and their padding is part of the
       /// tap area, so the whole list is tappable while staying compact (SLN-302).
   ```

**Verify**:
- `grep -n "minimumHitTarget" Hugo/Features/Overview/Views/OverviewListView.swift` → no output.
- The focused tests → `** TEST SUCCEEDED **`. Record the measured row pitch in your report if the test log shows it. Otherwise say it was not shown.
- Lint → exit 0.

### Step 3: Run the gate and commit

Run `Scripts/verify.sh`. Stage the two in-scope files by path and commit with the message from "Git workflow".

**Verify**: `Scripts/verify.sh` exits 0. `git show --stat HEAD` lists only the two in-scope files.

## Test plan

- `entryRowsAreCompact`: one extra entry adds less than 44 pt and at least 30 pt to a day card at the default text size. It fails before the change (about 50 pt) and passes after (about 36–38 pt).
- Owner checks on device (the reviewer will relay these):
  1. Overview > "by date": the day cards look about as compact as before SLN-294.
  2. Tap anywhere on a row, including just above or below its text: the entry opens. Every tap opens the row you aimed at.
  3. Settings > Accessibility > Larger Text at a large size: rows grow with the text and nothing clips.
  4. VoiceOver: each row is still one button (category, then duration and Bible studies), and each day header is still a heading.

## Done criteria

- [ ] Step 1's test failed before the change (record the output).
- [ ] `Scripts/verify.sh` exits 0.
- [ ] `grep -c "minimumHitTarget" Hugo/Features/Overview/Views/OverviewListView.swift` → `0`.
- [ ] `grep -n "VStack(spacing: 0)" Hugo/Features/Overview/Views/OverviewListView.swift` → one line.
- [ ] `git show --stat HEAD` lists only the two in-scope files.

## STOP conditions

Stop and report back (do not improvise) if:

- The drift check shows changes and the excerpts above no longer match.
- Step 1's test passes before the change, or the render fails.
- After Step 2 the measured row pitch is under 30 pt or still 44 pt or more.
- The change seems to need edits to `Theme.swift`, `EntryRow.swift` or any accessibility modifier.
- A step's verification fails twice after a reasonable fix attempt.

## Maintenance notes

- The rows depend on `.contentShape(.rect)` coming after the padding. Moving it before the padding brings back dead gaps between rows.
- The rows no longer meet the 44 pt guideline at default text size (about 38 pt). The owner accepted this on 2026-11-06 because the rows touch and have no dead space. If testers mis-tap, the fallback is `.frame(minHeight: HugoLayout.Size.minimumHitTarget)` with `VStack(spacing: 0)` (44 pt per row), still shorter than today's 50 pt.
- `OverviewDateListLayoutTests` measures through `ImageRenderer` at the test's default text size. If the default body font changes, the 30–44 pt band may need adjusting.
