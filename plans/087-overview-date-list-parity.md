# Plan 087: Make the Overview date list as useful as the entry list

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 1432319..HEAD -- Hugo/Features/Overview/Views/OverviewListView.swift Hugo/Features/Entries/Views/EntryRow.swift Hugo/Features/Entries/Domain HugoTests/Features/Entries/Domain`
> Expected: no output. If a file is listed, compare the "Current state" excerpts below with the live code. On any mismatch, treat it as a STOP condition. (Plans 085 and 086 touch other Overview files, not these.)

## Status

- **Priority**: P1 (scheduled for the next external TestFlight build)
- **Effort**: S + owner
- **Risk**: LOW (one view file plus a small shared helper; no data changes)
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `1432319`, 2026-11-05
- **Issue**: [SLN-294](https://linear.app/sebastianln/issue/SLN-294)

## Why this matters

The Overview lists this month's entries in one of two styles, picked with a small segmented control: one card per entry ("by entry"), or one card per day with the day's entries inside ("by date", the default). The owner likes the date style but it lacks what the entry style has:

- Tapping an entry does nothing. In the entry style it opens the entry for editing. This is the most important gap: in the default style, users cannot fix a mistake from the Overview.
- No category icon and no Bible studies count.
- VoiceOver reads each line as loose text instead of one entry with its duration.

Each line also starts with a time of day. Add Entry records only a date, and entries logged from a plan are dated at midday, so most lines show a meaningless time such as "12:00". This plan drops the time column.

## Current state

Files and their roles:

- `Hugo/Features/Overview/Views/OverviewListView.swift` holds the whole list. `OverviewListView` already owns the selection and the edit sheet, and passes the binding to the entry style but not to the date style:

  ```swift
  // OverviewListView.swift:16-17
      @State var selectedEntry: Entry? = nil
      @State var showAddEntrySheet: Bool = false
  ```

  ```swift
  // OverviewListView.swift:47-51
                  if listStyle == .byEntry {
                      OverviewEntryList(entries: groups.regular, selectedEntry: $selectedEntry)
                  } else if listStyle == .byDate {
                      OverviewDateList(entries: groups.regular, selectedEntry: $selectedEntry)
                  }
  ```

  ```swift
  // OverviewListView.swift:59-62
          .sheet(item: $selectedEntry) { entry in
              EntryDetailView(entry: entry)
                  .presentationDetents([.medium, .large])
          }
  ```

- `OverviewDateList` (same file) receives the binding but never passes it on:

  ```swift
  // OverviewListView.swift:103-114
  struct OverviewDateList: View {
      var entries: [Entry]

      @Binding var selectedEntry: Entry?

      var body: some View {
          ForEach(dates) { date in
              DateListItem(section: date)
                  .equatable()
                  .transition(.move(edge: .top).combined(with: .opacity))
          }
      }
  ```

  ```swift
  // OverviewListView.swift:129-141
      private struct DateSection: Identifiable, Equatable {
          var date: Date
          var entries: [Entry]

          var id: Date { date }

          static func == (lhs: DateSection, rhs: DateSection) -> Bool {
              lhs.date == rhs.date
                  && lhs.entries.map(\.id) == rhs.entries.map(\.id)
                  && lhs.entries.map(\.duration) == rhs.entries.map(\.duration)
                  && lhs.entries.map(\.date) == rhs.entries.map(\.date)
          }
      }
  ```

  ```swift
  // OverviewListView.swift:143-177 (DateListItem, shortened)
      private struct DateListItem: View, Equatable {
          var section: DateSection

          var body: some View {
              VStack {
                  HStack(alignment: .bottom) {
                      HStack(alignment: .firstTextBaseline) {
                          Text(section.date, format: .dateTime.day())
                              ...
                          Text(section.date, format: .dateTime.month())
                      }
                      Spacer()
                      VStack(alignment: .trailing) {
                          Text("overview.day.total")
                              ...
                          Text(duration.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                              ...
                      }
                  }
                  Divider()
                  VStack(spacing: HugoLayout.Spacing.small) {
                      ForEach(section.entries) { entry in
                          DateEntryRow(entry: entry)
                      }
                  }
                  .padding(.top, HugoLayout.Spacing.small)
              }
              .padding(HugoLayout.Spacing.card)
              .background(Color(.secondarySystemGroupedBackground))
              .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
          }
  ```

  ```swift
  // OverviewListView.swift:184-198
      private struct DateEntryRow: View {
          var entry: Entry

          var body: some View {
              HStack {
                  Text(entry.date, format: .dateTime.hour().minute())
                      .monospacedDigit()
                      .foregroundStyle(.secondary)
                  Text(entry.resolvedCategory().name)
                  Spacer()
                  Text(Duration.seconds(entry.duration).formatted(.time(pattern: .hourMinute)))
                      .monospacedDigit()
              }
          }
      }
  ```

- `Hugo/Features/Entries/Views/EntryRow.swift` is the entry-style row and the model to match. It is a button that sets the binding, and it builds its VoiceOver value like this:

  ```swift
  // EntryRow.swift:9-19
      private var accessibilityValue: Text {
          let duration = ServiceDurationFormatter.accessibilityString(from: entry.duration)

          guard entry.bibleStudies != 0 else {
              return Text(verbatim: duration)
          }

          let bibleStudies = String(localized: "entry.bibelstudies.count.accessibility.\(entry.bibleStudies)")

          return Text(String("\(duration), \(bibleStudies)"))
      }
  ```

  ```swift
  // EntryRow.swift:24-26 and 81-84
          Button {
              selectedEntry = entry
          } label: {
          ...
          .accessibilityElement(children: .combine)
          .accessibilityLabel(Text(category.name))
          .accessibilityValue(accessibilityValue)
          .buttonStyle(.plain)
  ```

  Its Bible studies display (lines 62–70) is an `Image(systemName: "book")` with the count, in `.secondary`.
- Redraws: plan 052 (commit `125b949`) removed the custom equality from `DateEntryRow`, so each row reads its `Entry` in its own `body` and redraws when that entry changes (SwiftData models are observable). The day card keeps `.equatable()` and `DateSection.==`. That comparison only decides whether the card re-runs its own `body` when the parent pushes a new section. It does not block the rows' own observation. **Rule for this plan:** everything shown for one entry (icon, category, Bible studies, duration) is read inside `DateEntryRow.body`, never in `DateListItem.body`. Then keeping `.equatable()` is safe.
- `HugoLayout` tokens (`Hugo/DesignSystem/Theme/Theme.swift`): `Spacing.tight` = 4, `Spacing.small` = 6, `Size.labelReservedIconWidth` = 24, `Size.minimumHitTarget` = 44.
- Project facts: synchronized folders (new files join their targets on their own), `MainActor` default isolation (pure helpers in `Domain` are `nonisolated`), Swift Testing, tests mirror the source path.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/EntryAccessibilityValueTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 (several minutes) |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run the same command again.

## Scope

**In scope**:
- `Hugo/Features/Overview/Views/OverviewListView.swift` (only `OverviewDateList` and its nested types)
- `Hugo/Features/Entries/Views/EntryRow.swift` (only `accessibilityValue`)
- `Hugo/Features/Entries/Domain/EntryAccessibilityValue.swift` (create)
- `HugoTests/Features/Entries/Domain/EntryAccessibilityValueTests.swift` (create)

**Out of scope**:
- `OverviewListView`'s own body, `OverviewEntryList`, `OverviewCarriedEntriesView`, `OverviewListStyleControl`. Carried-in entries stay in their summary pill and are not tappable.
- `EntryDetailView` and how editing or deleting works.
- Swipe actions or a long-press menu on rows (SLN-216). The owner declined them for this build.
- The day card's layout, its header and its total. Only add the accessibility grouping in Step 2.
- The duration format inside the rows (`.time(pattern: .hourMinute)`, for example "1:30").
- No new strings. Reuse `entry.bibelstudies.count.accessibility.%lld`.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- Never stage, edit, stash or discard files in `plans/` or `.claude/`. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage in-scope files by explicit path.
- One commit. Use: `feat: open, label and show Bible studies for entries in the Overview date list`

## Steps

### Step 1: Share the entry row's VoiceOver value

Create `Hugo/Features/Entries/Domain/EntryAccessibilityValue.swift`:

```swift
import Foundation

/// What VoiceOver reads as the value of an entry row: the duration, then the
/// number of Bible studies when there are any.
nonisolated enum EntryAccessibilityValue {
    static func text(duration: TimeInterval, bibleStudies: Int) -> String {
        let spokenDuration = ServiceDurationFormatter.accessibilityString(from: duration)
        guard bibleStudies != 0 else { return spokenDuration }
        let studies = String(localized: "entry.bibelstudies.count.accessibility.\(bibleStudies)")
        return "\(spokenDuration), \(studies)"
    }
}
```

In `EntryRow.swift`, replace the body of `accessibilityValue` (lines 9–19) with:

```swift
private var accessibilityValue: Text {
    Text(verbatim: EntryAccessibilityValue.text(duration: entry.duration, bibleStudies: entry.bibleStudies))
}
```

Create `HugoTests/Features/Entries/Domain/EntryAccessibilityValueTests.swift`:

```swift
import Testing

@testable import Hugo

struct EntryAccessibilityValueTests {
    @Test
    func withoutBibleStudiesItIsTheSpokenDuration() {
        #expect(
            EntryAccessibilityValue.text(duration: 5_400, bibleStudies: 0)
                == ServiceDurationFormatter.accessibilityString(from: 5_400))
    }

    @Test
    func bibleStudiesFollowTheDuration() {
        let spoken = ServiceDurationFormatter.accessibilityString(from: 5_400)
        let text = EntryAccessibilityValue.text(duration: 5_400, bibleStudies: 2)
        #expect(text.hasPrefix(spoken + ", "))
        #expect(text.contains("2"))
    }
}
```

**Verify**: the focused tests → `** TEST SUCCEEDED **`.

### Step 2: Pass the selection into the day cards and make rows tappable

In `OverviewListView.swift`:

1. In `OverviewDateList.body`, create each card with the binding:

   ```swift
   DateListItem(section: date, selectedEntry: $selectedEntry)
       .equatable()
       .transition(.move(edge: .top).combined(with: .opacity))
   ```

2. In `DateListItem`, add `@Binding var selectedEntry: Entry?` after `var section: DateSection`. A `Binding` is not `Equatable`, so add an explicit comparison inside `DateListItem` that compares only the section:

   ```swift
   static func == (lhs: Self, rhs: Self) -> Bool {
       lhs.section == rhs.section
   }
   ```

3. In `DateListItem.body`, give the day header one VoiceOver element marked as a heading. Add these modifiers to the outer `HStack(alignment: .bottom) { ... }`:

   ```swift
   .accessibilityElement(children: .combine)
   .accessibilityAddTraits(.isHeader)
   ```

   Then pass the binding to each row: `DateEntryRow(entry: entry, selectedEntry: $selectedEntry)`.

4. Replace `DateEntryRow` with:

   ```swift
   private struct DateEntryRow: View {
       var entry: Entry
       @Binding var selectedEntry: Entry?

       var body: some View {
           let category = entry.resolvedCategory()
           Button {
               selectedEntry = entry
           } label: {
               HStack {
                   Image(systemName: category.iconName)
                       .frame(width: HugoLayout.Size.labelReservedIconWidth)
                       .foregroundStyle(.secondary)
                   Text(category.name)
                   Spacer()
                   if entry.bibleStudies != 0 {
                       HStack(spacing: HugoLayout.Spacing.tight) {
                           Image(systemName: "book")
                           Text(String("\(entry.bibleStudies)"))
                       }
                       .foregroundStyle(.secondary)
                   }
                   Text(Duration.seconds(entry.duration).formatted(.time(pattern: .hourMinute)))
                       .monospacedDigit()
               }
               .frame(minHeight: HugoLayout.Size.minimumHitTarget)
               .contentShape(.rect)
           }
           .buttonStyle(.plain)
           .accessibilityElement(children: .combine)
           .accessibilityLabel(Text(category.name))
           .accessibilityValue(
               Text(verbatim: EntryAccessibilityValue.text(duration: entry.duration, bibleStudies: entry.bibleStudies))
           )
       }
   }
   ```

   The time-of-day `Text` is gone on purpose. Every value the row shows is read in this `body` (see the rule in "Current state"). The `minHeight` gives each row a 44-point tap target. If that makes the card look too loose on device, the owner may lower it, but not below the 44-point minimum for the whole row.

**Verify**:
- `grep -n "hour().minute()" Hugo/Features/Overview/Views/OverviewListView.swift` → no output.
- `grep -c "selectedEntry" Hugo/Features/Overview/Views/OverviewListView.swift` → at least `10`.
- The focused tests → `** TEST SUCCEEDED **` (this also builds the app).

### Step 3: Run the gate and commit

Run `Scripts/verify.sh`. Stage the four in-scope files by path and commit with the message from "Git workflow".

**Verify**: `Scripts/verify.sh` exits 0. `git show --stat HEAD` lists only in-scope files.

## Test plan

- `EntryAccessibilityValueTests` (new, 2 tests). The helper is the one piece of logic, and both row styles now use it.
- The rest is view wiring, checked by the owner on device (below). There are no UI tests in this repo.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0.
- [ ] `grep -rn "EntryAccessibilityValue.text" Hugo` → two matches (`EntryRow.swift`, `OverviewListView.swift`).
- [ ] `grep -n "hour().minute()" Hugo/Features/Overview/Views/OverviewListView.swift` → no output.
- [ ] `git show --stat HEAD` lists only in-scope files.
- [ ] Owner check on device, in the "by date" style:
  - Tapping an entry opens the same edit sheet as in the "by entry" style.
  - Each line shows the category icon and name, the book icon with a count when the entry has Bible studies, and the duration, with no time of day.
  - Change an entry's category and its Bible studies in the sheet, close it, and confirm the line updates immediately. Change its duration and confirm the day total updates.
  - With VoiceOver, the day header reads as a heading ("5 November, Total, 2 hr 30 min" or similar), and each line reads as one button: the category name, then the duration and Bible studies.

## STOP conditions

Stop and report back (do not improvise) if:

- The "Current state" excerpts don't match the live code.
- During the owner check, a line does not update after its category or Bible studies change. Do not add a custom equality or an `.id` hack. Report it, because the redraw rule above was wrong.
- The build fails because `DateListItem` cannot keep `.equatable()` with the binding, and the explicit `==` from Step 2 does not fix it.
- A step's verification fails twice after a reasonable fix attempt.

## Maintenance notes

- If SLN-216 (swipe actions and a long-press menu) is picked up later, add the menu to both `EntryRow` and `DateEntryRow`. The rows sit in a `ScrollView`, not a `List`, so `.swipeActions` will not work without moving to a `List`. A `.contextMenu` will.
- Keep every per-entry value inside `DateEntryRow.body`. Reading entry fields in `DateListItem.body` (beyond the day total, which `DateSection.==` covers through `duration`) would let `.equatable()` hide changes.
- The two row styles still format durations differently ("01:30" in `EntryRow`, "1:30" here). Unify them only together with the duration-format work, not here.
