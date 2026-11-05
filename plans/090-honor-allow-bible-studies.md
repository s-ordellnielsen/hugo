# Plan 090: Hide Bible studies for categories that turn them off

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 1432319..HEAD -- Hugo/Features/Entries HugoTests/Features/Entries`
> Expected: no output, or only `DurationWheelPicker.swift` and `DurationWheelAccessibility*` files (plan 089 touches them). If any other file is listed, compare the "Current state" excerpts against the live code; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S (+ owner check on device)
- **Risk**: LOW (no schema change; report totals unchanged)
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `1432319`, 2026-11-05
- **Issue**: [SLN-169](https://linear.app/sebastianln/issue/SLN-169)

## Why this matters

Every category has a "Can add Bible Studies" toggle ("Kan tilføje bibelstudier"), in Add Category and in the category's options. Hugo saves it but never reads it, so turning it off does nothing: the Bible studies stepper still shows for every entry. A setting that does nothing confuses users and makes them distrust the other settings. After this plan, Add Entry and Entry Detail hide the stepper for a category that turns Bible studies off. An entry that already has Bible studies keeps its stepper, so Hugo never hides a count the user entered.

## Current state

- **The setting.** `Tracker.allowBibleStudies` (`Hugo/Persistence/SchemaVersions/V11/TrackerV11.swift:18`, `var allowBibleStudies: Bool = true`) is the stored flag. `Tracker` is a typealias for `SchemaV11.Tracker` (`Hugo/Persistence/AppSchema.swift:121,135`). Its initializer takes `allowBibleStudies: Bool? = nil` (line 33). It is written in two places and read nowhere:
  - `Hugo/Features/Categories/Screens/AddCategoryView.swift:63`: `Toggle("tracker.options.allow-bible-studies", isOn: $allowBibleStudies)`
  - `Hugo/Features/Categories/Views/CategoryAdvancedOptionsView.swift:9`: `Toggle("tracker.options.allow-bible-studies", isOn: $tracker.allowBibleStudies)`

- **Add Entry.** `Hugo/Features/Entries/Screens/AddEntryView.swift` always shows the stepper (lines 60–64):

  ```swift
                  Section {
                      Stepper(onIncrement: form.incrementBibleStudies, onDecrement: form.decrementBibleStudies) {
                          bibleStudiesLabel
                      }
                  }
  ```

  Its state lives in `Hugo/Features/Entries/State/AddEntryFormModel.swift` (`@MainActor @Observable final class AddEntryFormModel`). Relevant parts:

  ```swift
      var bibleStudies = 0
      var selectedTracker: Tracker?
  ```
  (lines 17–18) and `draft()` (lines 88–96):

  ```swift
      func draft() -> EntryDraft? {
          guard let combinedDate, let selectedTracker, durationInSeconds > 0 else {
              validationMessage = String(localized: "entry.add.validation.invalid")
              return nil
          }
          validationMessage = nil
          return EntryDraft(
              date: combinedDate, duration: durationInSeconds, tracker: selectedTracker, bibleStudies: bibleStudies)
      }
  ```

  The selected category in Add Entry is always a live `Tracker` (picked with `CategoryPicker`, or set by `reconcileSelection(with:)`).

- **Entry Detail.** `Hugo/Features/Entries/Screens/EntryDetailView.swift` edits an existing entry and always shows the stepper (lines 34–44):

  ```swift
                  Section {
                      Stepper(
                          onIncrement: incrementBibleStudies,
                          onDecrement: decrementBibleStudies
                      ) {
                          Label(
                              "entry.biblestudies.count.label.\(entry.bibleStudies)",
                              systemImage: "book"
                          )
                      }
                  }
  ```

  It already resolves the category once: `private var category: EntryCategory { entry.resolvedCategory() }` (line 14).

- **Project rule (AGENTS.md):** "Get an entry's category with `entry.resolvedCategory()`, never from `entry.tracker` directly." So Entry Detail must learn the flag from `EntryCategory`, not from `entry.tracker`. `Hugo/Features/Entries/Domain/EntryCategory.swift` today:

  ```swift
  nonisolated struct EntryCategory: Hashable {
      let key: String
      let name: String
      let iconName: String
      /// `nil` only for an untracked entry.
      let type: TrackerType?
      /// Set only when the live tracker is attached.
      let trackerID: UUID?
  }
  ```

  `resolvedCategory(locale:)` (lines 19–33) builds it in three ways: from the live tracker, from the `storedTracker` snapshot, or as "untracked". `EntryCategory(...)` is constructed only in that function (`grep -rn "EntryCategory(" Hugo HugoTests` finds no other construction). No code uses `EntryCategory` as a dictionary key or in a `Set`; `CategoryTotals` groups by `category.key` (a `String`).

- **Glossary (`CONTEXT.md`):** **Category snapshot**: "The name, icon and kind of an entry's category, copied onto the entry so the entry keeps its category if the category is renamed or deleted." A snapshot has no Bible studies flag, so an entry known only by its snapshot (its category was deleted) counts as allowing Bible studies. An **untracked entry** (no category, no snapshot) also counts as allowing them.

- **Unaffected:** report totals, submitted reports and the yearly goal read `entry.bibleStudies` directly and do not change. `Hugo/Features/Planner/Domain/PlanLogSeed.swift` (logging a plan opens Add Entry) has no Bible studies field and needs nothing. Add Entry applies the rule when the seeded category is selected.

- **No schema change.** The flag already exists and syncs through CloudKit.

- Conventions: pure logic in `Domain`, `nonisolated` (see `EntryCategory.swift`); screen workflow state in `State` as `@MainActor @Observable`; Swift Testing. Model tests after `HugoTests/Features/Entries/State/AddEntryFormModelTests.swift` (it builds `AddEntryFormModel(calendar: calendar, now: date(2026, 1, 1))` and sets `model.selectedTracker = Tracker(name: "Field Service")`) and `HugoTests/Features/Entries/Domain/EntryCategoryTests.swift`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Build | `xcodebuild build -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData CODE_SIGNING_ALLOWED=NO` | ends with `** BUILD SUCCEEDED **` |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/BibleStudiesRuleTests -only-testing:HugoTests/EntryCategoryTests -only-testing:HugoTests/AddEntryFormModelTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 (takes several minutes) |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run the same command again; that is not a failure.

## Scope

**In scope** (the only files you modify or create):
- `Hugo/Features/Entries/Domain/BibleStudiesRule.swift` (create)
- `HugoTests/Features/Entries/Domain/BibleStudiesRuleTests.swift` (create)
- `Hugo/Features/Entries/Domain/EntryCategory.swift`
- `HugoTests/Features/Entries/Domain/EntryCategoryTests.swift`
- `Hugo/Features/Entries/State/AddEntryFormModel.swift`
- `HugoTests/Features/Entries/State/AddEntryFormModelTests.swift`
- `Hugo/Features/Entries/Screens/AddEntryView.swift`
- `Hugo/Features/Entries/Screens/EntryDetailView.swift`

**Out of scope**:
- Any file under `Hugo/Persistence` (no schema change, no migration).
- `AddCategoryView.swift`, `CategoryAdvancedOptionsView.swift` and the toggle's wording.
- Reports, the Year page, the Overview rows (`EntryRow` shows a count only when it is not 0, which stays correct) and the Planner.
- Clearing Bible studies on existing entries when a category's toggle is turned off. Existing counts stay.
- `DurationWheelPicker.swift` (plan 089 changes it).

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- The working tree may hold uncommitted owner files in `plans/` and `.claude/`. Never stage, edit, stash or discard them. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage only the in-scope files, by explicit path.
- One commit, Conventional Commits style: `fix: hide Bible studies for categories that turn them off`

## Steps

### Step 1: Add the rule and its tests

Create `Hugo/Features/Entries/Domain/BibleStudiesRule.swift`:

```swift
import Foundation

/// When an entry offers Bible studies. A category can turn them off, but an
/// entry that already has Bible studies keeps its control, so Hugo never hides
/// a count the user entered.
nonisolated enum BibleStudiesRule {
    static func showsControl(categoryAllows: Bool, count: Int) -> Bool {
        categoryAllows || count > 0
    }

    /// The count to save for a new entry: 0 when its category turns Bible studies off.
    static func savedCount(_ count: Int, categoryAllows: Bool) -> Int {
        categoryAllows ? max(0, count) : 0
    }
}
```

Create `HugoTests/Features/Entries/Domain/BibleStudiesRuleTests.swift`:

```swift
import Testing

@testable import Hugo

struct BibleStudiesRuleTests {
    @Test
    func allowedCategoryAlwaysShowsTheControl() {
        #expect(BibleStudiesRule.showsControl(categoryAllows: true, count: 0))
        #expect(BibleStudiesRule.showsControl(categoryAllows: true, count: 2))
    }

    @Test
    func disallowedCategoryHidesTheControlOnlyWithoutStudies() {
        #expect(!BibleStudiesRule.showsControl(categoryAllows: false, count: 0))
        #expect(BibleStudiesRule.showsControl(categoryAllows: false, count: 1))
    }

    @Test
    func savedCountIsZeroWhenTheCategoryTurnsStudiesOff() {
        #expect(BibleStudiesRule.savedCount(3, categoryAllows: true) == 3)
        #expect(BibleStudiesRule.savedCount(3, categoryAllows: false) == 0)
        #expect(BibleStudiesRule.savedCount(-1, categoryAllows: true) == 0)
    }
}
```

**Verify**: the focused test command → `** TEST SUCCEEDED **`; the 3 `BibleStudiesRuleTests` tests pass.

### Step 2: Carry the flag on `EntryCategory`

In `Hugo/Features/Entries/Domain/EntryCategory.swift`:

1. Add a last stored property to `EntryCategory`, after `trackerID`:

   ```swift
       /// False only when the live category turned Bible studies off. A
       /// category snapshot and an untracked entry allow them.
       let allowsBibleStudies: Bool
   ```

2. In `resolvedCategory(locale:)`, pass the new argument in all three constructions:
   - live tracker: `trackerID: tracker.id, allowsBibleStudies: tracker.allowBibleStudies)`
   - snapshot: `trackerID: nil, allowsBibleStudies: true)`
   - untracked: `trackerID: nil, allowsBibleStudies: true)`

Then add three tests to `HugoTests/Features/Entries/Domain/EntryCategoryTests.swift`, inside the existing `EntryCategoryTests` struct:

```swift
    @Test
    func liveTrackerCarriesItsBibleStudiesSetting() {
        let tracker = Tracker(name: "LDC", type: .separate, allowBibleStudies: false)
        let entry = Entry(date: .now, duration: 1_800, tracker: tracker)
        #expect(entry.resolvedCategory().allowsBibleStudies == false)
    }

    @Test
    func snapshotAllowsBibleStudies() {
        let entry = Entry(date: .now, duration: 1_800, tracker: nil)
        entry.storedTracker = Entry.EntryTracker(name: "LDC", icon: "hammer", type: .separate)
        #expect(entry.resolvedCategory().allowsBibleStudies)
    }

    @Test
    func untrackedEntryAllowsBibleStudies() {
        let entry = Entry(date: .now, duration: 1_800, tracker: nil)
        #expect(entry.resolvedCategory().allowsBibleStudies)
    }
```

**Verify**: `grep -c "allowsBibleStudies:" Hugo/Features/Entries/Domain/EntryCategory.swift` → `3`. The focused test command → `** TEST SUCCEEDED **`.

### Step 3: Apply the rule in the Add Entry form model

In `Hugo/Features/Entries/State/AddEntryFormModel.swift`:

1. Replace `var selectedTracker: Tracker?` (line 18) with:

   ```swift
       var selectedTracker: Tracker? {
           didSet {
               if !categoryAllowsBibleStudies { bibleStudies = 0 }
           }
       }
   ```

2. Add two computed properties after `isSubmitDisabled`:

   ```swift
       /// False when the chosen category turned Bible studies off.
       var categoryAllowsBibleStudies: Bool {
           selectedTracker?.allowBibleStudies ?? true
       }

       var showsBibleStudies: Bool {
           BibleStudiesRule.showsControl(categoryAllows: categoryAllowsBibleStudies, count: bibleStudies)
       }
   ```

3. In `draft()`, save the rule's count:

   ```swift
           return EntryDraft(
               date: combinedDate, duration: durationInSeconds, tracker: selectedTracker,
               bibleStudies: BibleStudiesRule.savedCount(bibleStudies, categoryAllows: categoryAllowsBibleStudies))
   ```

Add three tests to `HugoTests/Features/Entries/State/AddEntryFormModelTests.swift`, inside the existing struct, using its `calendar` property and `date(...)` helper:

```swift
    @Test
    func choosingACategoryWithoutBibleStudiesClearsTheCount() {
        let model = AddEntryFormModel(calendar: calendar, now: date(2026, 1, 1))
        model.selectedTracker = Tracker(name: "Field Service")
        model.incrementBibleStudies()
        model.incrementBibleStudies()

        model.selectedTracker = Tracker(name: "LDC", type: .separate, allowBibleStudies: false)

        #expect(model.bibleStudies == 0)
        #expect(model.showsBibleStudies == false)
    }

    @Test
    func categoryWithBibleStudiesKeepsTheCount() {
        let model = AddEntryFormModel(calendar: calendar, now: date(2026, 1, 1))
        model.selectedTracker = Tracker(name: "Field Service")
        model.incrementBibleStudies()

        model.selectedTracker = Tracker(name: "Bethel", type: .separate)

        #expect(model.bibleStudies == 1)
        #expect(model.showsBibleStudies)
    }

    @Test
    func draftSavesNoBibleStudiesForACategoryWithoutThem() throws {
        let model = AddEntryFormModel(calendar: calendar, now: date(2026, 1, 1))
        model.selectedTracker = Tracker(name: "LDC", type: .separate, allowBibleStudies: false)
        model.durationInSeconds = 3_600
        model.incrementBibleStudies()

        let draft = try #require(model.draft())

        #expect(draft.bibleStudies == 0)
    }
```

The third test covers the case where the count changes after the category was chosen (the view hides the stepper, but the model must not trust the view).

**Verify**: the focused test command → `** TEST SUCCEEDED **`; the 3 new `AddEntryFormModelTests` tests pass, and the existing `bibleStudiesNeverBecomeNegative` still passes.

### Step 4: Hide the stepper in Add Entry and Entry Detail

1. In `AddEntryView.swift`, wrap the Bible studies section (lines 60–64) in a condition:

   ```swift
                  if form.showsBibleStudies {
                      Section {
                          Stepper(onIncrement: form.incrementBibleStudies, onDecrement: form.decrementBibleStudies) {
                              bibleStudiesLabel
                          }
                      }
                  }
   ```

2. In `EntryDetailView.swift`, wrap the Bible studies section (lines 34–44) the same way, using the resolved category:

   ```swift
                  if BibleStudiesRule.showsControl(
                      categoryAllows: category.allowsBibleStudies, count: entry.bibleStudies)
                  {
                      Section {
                          ...existing Stepper unchanged...
                      }
                  }
   ```

   Do not read `entry.tracker` for this (AGENTS.md rule). Entry Detail never resets an existing count: when the user moves an entry with Bible studies to a category without them, the count and its stepper stay.

**Verify**: the build command → `** BUILD SUCCEEDED **`. `grep -n "entry.tracker" Hugo/Features/Entries/Screens/EntryDetailView.swift` → only the existing lines inside the `CategoryPicker` binding (lines 87 and 89 today), no new ones.

### Step 5: Run the gate and commit

Run `Scripts/verify.sh`. Then stage the eight in-scope files by path and commit with the message from "Git workflow".

**Verify**: `Scripts/verify.sh` exits 0. `git show --stat HEAD` lists exactly the eight in-scope files.

## Test plan

- New: `BibleStudiesRuleTests` (3 tests), 3 new `EntryCategoryTests`, 3 new `AddEntryFormModelTests`. Together they cover: allowed category, disallowed category with and without existing studies, snapshot and untracked entries, switching categories in Add Entry, and the saved count.
- Patterns: `EntryCategoryTests.swift` and `AddEntryFormModelTests.swift` (in-memory `Tracker` and `Entry` objects, no model container).
- The owner checks on a device:
  1. In Settings > Categories, open a category such as LDC, open its options and turn off "Can add Bible Studies".
  2. Add Entry with Field Service: the Bible studies stepper shows. Set 2 studies, then switch to LDC: the stepper disappears. Save; the entry has no Bible studies (no book icon on its row).
  3. Add Entry with LDC from the start: no stepper.
  4. An older LDC entry that has Bible studies: Entry Detail still shows the stepper with its count.
  5. Turn the toggle back on: the stepper shows again for LDC.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, including the 9 new tests.
- [ ] `grep -rn "allowBibleStudies" Hugo/Features/Entries` → at least 1 line (the form model now reads the flag).
- [ ] `grep -rn "BibleStudiesRule\." Hugo/Features` lists `AddEntryFormModel.swift` and `EntryDetailView.swift`.
- [ ] `git show --stat HEAD` lists only the eight in-scope files; nothing under `Hugo/Persistence`.
- [ ] `plans/README.md` status row updated (unless a reviewer maintains it).

## STOP conditions

Stop and report back (do not improvise) if:

- `Tracker` no longer has `allowBibleStudies`, or its initializer no longer accepts `allowBibleStudies:`.
- Adding `allowsBibleStudies` to `EntryCategory` breaks a construction outside `EntryCategory.swift`, or a compile error shows `EntryCategory` is used as a dictionary key or `Set` element whose grouping would change.
- `@Observable` rejects the `didSet` on `selectedTracker` (compile error). Report the error rather than moving the reset into the view.
- The change appears to need a schema change or an edit under `Hugo/Persistence`.

## Maintenance notes

- The rule lives in one place (`BibleStudiesRule`). If another screen ever edits Bible studies (for example a quick-add widget or the Planner), use `showsControl` and `savedCount` there too.
- In Entry Detail, lowering the count to 0 in a category without Bible studies makes the stepper disappear right away. That follows the rule and is expected; the owner may revisit if testers find it surprising.
- The flag syncs through CloudKit with the category. A device running an older build ignores it, which matches today's behavior.
- If category snapshots ever store the flag, change the snapshot branch in `resolvedCategory` to use it.
