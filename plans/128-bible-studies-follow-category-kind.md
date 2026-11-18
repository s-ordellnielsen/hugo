# Plan 128: Allow Bible studies in main categories only, and remove the "Can add Bible Studies" toggle

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat c918888..HEAD -- Hugo/Features/Categories Hugo/Features/Entries HugoTests/Features/Entries HugoTests/Features/Reports/Domain/MonthlyReportBuilderTests.swift`
> Expected: no output. If a file changed, compare the "Current state" excerpts
> with the live code. On a mismatch, STOP. Plan 127 may already have changed
> `CONTEXT.md` and the catalog; that is expected.
> Also run `git status --short -- Hugo/Resources/Localizable.xcstrings` → no output. If the catalog has uncommitted changes, STOP.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: MED. Changes what existing data allows: a main category whose toggle was off now allows Bible studies, and a separate category whose toggle was on no longer offers them on new entries. No count is ever deleted.
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `c918888`, 2026-11-18
- **Issue**: pending (to be created in Linear)

## Why this matters

Today every category has a "Can add Bible Studies" toggle (`Tracker.allowBibleStudies`), on by default, in the Add Category sheet and on a separate "Advanced Options" screen. The owner decided (2026-11-18) that the category's kind decides it instead: Bible studies belong to field service, so a main category allows them and a separate category (Bethel, LDC and similar) does not. One less setting, and the rule is the same for everyone.

After this plan:
- The Add Category sheet has no Bible studies toggle. The category detail screen has no "Advanced Options" row, and that screen is deleted.
- Add Entry shows the Bible studies stepper for a main category and hides it for a separate category, unless the count is already above zero (the existing `BibleStudiesRule`).
- An existing entry in a separate category that already has Bible studies keeps them. Its detail screen still shows the stepper (because the count is above zero), and the month's report still counts them.
- Untracked entries (no category, no snapshot) and entries whose category was deleted (snapshot only) keep allowing Bible studies, as today (owner decision: they count as main).
- `Tracker.allowBibleStudies` stays in the SwiftData schema, unread and unwritten by app code. No schema change.

Plan 129 then explains this rule in the new kind picker.

## Current state

### Where the setting is read and written

`grep -rn "allowBibleStudies\|allowsBibleStudies\|AllowsBibleStudies" Hugo HugoTests --include='*.swift' | grep -v "Persistence/SchemaVersions"` lists exactly:

```
Hugo/Features/Entries/State/AddEntryFormModel.swift:20:            if !categoryAllowsBibleStudies { bibleStudies = 0 }
Hugo/Features/Entries/State/AddEntryFormModel.swift:59:    var categoryAllowsBibleStudies: Bool {
Hugo/Features/Entries/State/AddEntryFormModel.swift:60:        selectedTracker?.allowBibleStudies ?? true
Hugo/Features/Entries/State/AddEntryFormModel.swift:64:        BibleStudiesRule.showsControl(categoryAllows: categoryAllowsBibleStudies, count: bibleStudies)
Hugo/Features/Entries/State/AddEntryFormModel.swift:109:            bibleStudies: BibleStudiesRule.savedCount(bibleStudies, categoryAllows: categoryAllowsBibleStudies))
Hugo/Features/Entries/Screens/EntryDetailView.swift:35:                    categoryAllows: category.allowsBibleStudies, count: entry.bibleStudies)
Hugo/Features/Entries/Domain/EntryCategory.swift:22:    let allowsBibleStudies: Bool
Hugo/Features/Entries/Domain/EntryCategory.swift:30:                type: tracker.type, trackerID: tracker.id, allowsBibleStudies: tracker.allowBibleStudies)
Hugo/Features/Entries/Domain/EntryCategory.swift:36:                allowsBibleStudies: true)
Hugo/Features/Entries/Domain/EntryCategory.swift:40:            iconName: "questionmark.circle", type: nil, trackerID: nil, allowsBibleStudies: true)
Hugo/Features/Categories/Screens/AddCategoryView.swift:15:    @State private var allowBibleStudies = true
Hugo/Features/Categories/Screens/AddCategoryView.swift:77:                    Toggle("tracker.options.allow-bible-studies", isOn: $allowBibleStudies)
Hugo/Features/Categories/Screens/AddCategoryView.swift:109:            allowBibleStudies: allowBibleStudies,
Hugo/Features/Categories/Views/CategoryAdvancedOptionsView.swift:9:            Toggle("tracker.options.allow-bible-studies", isOn: $tracker.allowBibleStudies)
HugoTests/Features/Entries/State/AddEntryFormModelTests.swift:72:        model.selectedTracker = Tracker(name: "LDC", type: .separate, allowBibleStudies: false)
HugoTests/Features/Entries/State/AddEntryFormModelTests.swift:93:        model.selectedTracker = Tracker(name: "LDC", type: .separate, allowBibleStudies: false)
HugoTests/Features/Entries/Domain/EntryCategoryTests.swift:52:        let tracker = Tracker(name: "LDC", type: .separate, allowBibleStudies: false)
HugoTests/Features/Entries/Domain/EntryCategoryTests.swift:58:    func snapshotAllowsBibleStudies() {
HugoTests/Features/Entries/Domain/EntryCategoryTests.swift:61:        #expect(entry.resolvedCategory().allowsBibleStudies)
HugoTests/Features/Entries/Domain/EntryCategoryTests.swift:65:    func untrackedEntryAllowsBibleStudies() {
HugoTests/Features/Entries/Domain/EntryCategoryTests.swift:67:        #expect(entry.resolvedCategory().allowsBibleStudies)
```

Nothing in `Hugo/Persistence` outside the schema version files reads it (no migration, no `SyncDeduplicator` use).

### The model (`Hugo/Persistence/SchemaVersions/V14/TrackerV14.swift`, the current `Tracker`)

```swift
        var type: TrackerType = TrackerType.main

        var allowBibleStudies: Bool = true
        ...
        init(
            id: UUID = UUID(), name: String? = nil, type: TrackerType? = nil, allowBibleStudies: Bool? = nil,
            isDefault: Bool? = nil, iconName: String? = nil
        ) {
```

The `allowBibleStudies:` init parameter is optional with a `nil` default, so callers can simply stop passing it. Do not edit this file: AGENTS.md says "Never edit a shipped schema version", and CloudKit cannot drop a field safely. Do not add a schema version.

### `EntryCategory` (`Hugo/Features/Entries/Domain/EntryCategory.swift:20-41`)

```swift
    /// False only when the live category turned Bible studies off. A
    /// category snapshot and an untracked entry allow them.
    let allowsBibleStudies: Bool
}

extension Entry {
    nonisolated func resolvedCategory(locale: Locale = .current) -> EntryCategory {
        if let tracker {
            return EntryCategory(
                key: tracker.id.uuidString, name: tracker.name, iconName: tracker.iconName,
                type: tracker.type, trackerID: tracker.id, allowsBibleStudies: tracker.allowBibleStudies)
        }
        if let snapshot = storedTracker {
            return EntryCategory(
                key: "stored:\(snapshot.name)|\(snapshot.icon)|\(snapshot.type.rawValue)",
                name: snapshot.name, iconName: snapshot.icon, type: snapshot.type, trackerID: nil,
                allowsBibleStudies: true)
        }
        return EntryCategory(
            key: "untracked", name: String(localized: "entry.untracked", locale: locale),
            iconName: "questionmark.circle", type: nil, trackerID: nil, allowsBibleStudies: true)
    }
}
```

A snapshot does carry its kind (`snapshot.type`), but the owner decided that snapshots and untracked entries count as main for Bible studies, so both keep `allowsBibleStudies: true`. Only the live-tracker branch changes.

### `BibleStudiesRule` (`Hugo/Features/Entries/Domain/BibleStudiesRule.swift`, whole file)

```swift
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

`savedCount` is called only from `AddEntryFormModel.draft()`, which builds a **new** entry. `EntryDetailView` edits an existing entry's `bibleStudies` directly with its stepper and never calls `savedCount`; changing an existing entry's category there (`entry.tracker = newValue`, around line 92) leaves `bibleStudies` untouched. So no existing count is zeroed by this plan.

### Reports

`MonthlyReportBuilder.summaries` (`Hugo/Features/Reports/Domain/MonthlyReportBuilder.swift:21-24`) adds `entry.bibleStudies` for every entry of the month, whatever its category:

```swift
            for entry in monthEntries {
                totalSeconds += entry.duration
                bibleStudies += entry.bibleStudies
```

`ServiceMonth` and `SubmitReportFormModel` use that total (`summary.totalBibleStudies`), and `ReportComposer.message` writes it once as `Bible studies: n`. `ReportingLineCalculator` handles durations only. So the report total stays correct for entries of either kind; this plan changes no report code.

### The toggle UI

`Hugo/Features/Categories/Screens/AddCategoryView.swift:76-79`:

```swift
                Section("tracker.options.label") {
                    Toggle("tracker.options.allow-bible-studies", isOn: $allowBibleStudies)
                    Toggle("tracker.options.use-as-default", isOn: $isDefault)
                }
```

and in `submit()` (lines 106-112):

```swift
        let tracker = Tracker(
            name: trimmedName,
            type: type,
            allowBibleStudies: allowBibleStudies,
            isDefault: false,
            iconName: iconName
        )
```

`Hugo/Features/Categories/Views/CategoryAdvancedOptionsView.swift` holds only the toggle:

```swift
struct CategoryAdvancedOptionsView: View {
    var tracker: Tracker

    var body: some View {
        @Bindable var tracker = tracker
        Form {
            Toggle("tracker.options.allow-bible-studies", isOn: $tracker.allowBibleStudies)
        }
    }
}
```

Its only link is `Hugo/Features/Categories/Screens/CategoryDetailView.swift:77-81`:

```swift
            Section {
                NavigationLink(destination: CategoryAdvancedOptionsView(tracker: tracker)) {
                    Text("tracker.settings.advancedOptions.label")
                }
            }
```

### Strings that become unused

| Key | English | Danish |
|---|---|---|
| `tracker.options.allow-bible-studies` | Can add Bible Studies | Kan tilføje bibelstudier |
| `tracker.settings.advancedOptions.label` | Advanced Options | Avancerede indstillinger |

`tracker.options.label` ("Options" / "Indstillinger") stays: the "Use as Default" toggle still uses it.

### Vocabulary (`CONTEXT.md`)

```markdown
**Main category**:
A category whose time is reported together on the Field Service line.
_Avoid_: Primary category

**Separate category**:
A category whose time is reported on its own line, apart from Field Service, such as Bethel or LDC.
_Avoid_: Other, secondary category
```

The code calls these `TrackerType.main` and `TrackerType.separate`. Plan 129 renames them in the UI and in `CONTEXT.md`; this plan keeps "main" and "separate".

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full gate | `Scripts/verify.sh` | exit 0 |
| Build | `xcodebuild build -project Hugo.xcodeproj -scheme Debug -destination 'generic/platform=iOS Simulator' -quiet 2>&1 \| grep -c "error:"` | `0` |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Debug -configuration Debug -destination 'platform=iOS Simulator,name=Hugo Verify iOS 26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/EntryCategoryTests -only-testing:HugoTests/AddEntryFormModelTests -only-testing:HugoTests/MonthlyReportBuilderTests -only-testing:HugoTests/BibleStudiesRuleTests` | `** TEST SUCCEEDED **` |
| Catalog JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0 |

Do not run the focused tests while `Scripts/verify.sh` runs; both use the same simulator.

## Scope

**In scope:**
- `Hugo/Features/Entries/Domain/EntryCategory.swift`
- `Hugo/Features/Entries/Domain/BibleStudiesRule.swift` (doc comments only)
- `Hugo/Features/Entries/State/AddEntryFormModel.swift`
- `Hugo/Features/Categories/Screens/AddCategoryView.swift`
- `Hugo/Features/Categories/Screens/CategoryDetailView.swift` (remove the Advanced Options section)
- `Hugo/Features/Categories/Views/CategoryAdvancedOptionsView.swift` (delete)
- `HugoTests/Features/Entries/Domain/EntryCategoryTests.swift`
- `HugoTests/Features/Entries/State/AddEntryFormModelTests.swift`
- `HugoTests/Features/Reports/Domain/MonthlyReportBuilderTests.swift`
- `Hugo/Resources/Localizable.xcstrings` (delete 2 keys)
- `CONTEXT.md`

**Out of scope:**
- `Hugo/Persistence/**`, including `TrackerV14.swift` and its `init`. No schema version, no migration.
- The kind picker and its wording. Plan 129 replaces the `Picker` with cards that explain this rule.
- Report code (`ReportComposer`, `MonthlyReportBuilder`, `ReportingLineCalculator`). They already count Bible studies from every entry.
- `EntryDetailView`. It already reads `category.allowsBibleStudies` through `BibleStudiesRule.showsControl`, so it follows the new rule without edits.

## Git workflow

- Work on `main` directly. No branch, no worktree.
- One commit after `Scripts/verify.sh` exits 0: `feat: allow Bible studies in main categories only`.
- Never stage `.claude/`, `plans/` or `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`. Do not push.

## Steps

### Step 1: Derive the rule from the kind

1. `EntryCategory.swift`: in the live-tracker branch, replace `allowsBibleStudies: tracker.allowBibleStudies` with `allowsBibleStudies: tracker.type == .main`. Leave the snapshot and untracked branches at `true`. Replace the doc comment on `allowsBibleStudies` with:

```swift
    /// True for a main category. A separate category doesn't take new Bible
    /// studies. A category snapshot and an untracked entry count as main and
    /// allow them. `Tracker.allowBibleStudies` is no longer read.
```

2. `AddEntryFormModel.swift` lines 58-61: replace the property with:

```swift
    /// True unless the chosen category is a separate category. Bible studies
    /// belong to main (field service) time.
    var categoryAllowsBibleStudies: Bool {
        (selectedTracker?.type ?? .main) == .main
    }
```

   Keep the `didSet` on `selectedTracker` as it is: picking a separate category for a new entry clears the count, as today.

3. `BibleStudiesRule.swift`: change only the comments. The type comment becomes `/// When an entry offers Bible studies. A separate category doesn't take new ones, but an entry that already has Bible studies keeps its control, so Hugo never hides a count the user entered.` and the `savedCount` comment becomes `/// The count to save for a new entry: 0 in a separate category.`

**Verify**: build → `0`.

### Step 2: Remove the toggle and the Advanced Options screen

1. `AddCategoryView.swift`: delete `@State private var allowBibleStudies = true`, delete the line `Toggle("tracker.options.allow-bible-studies", isOn: $allowBibleStudies)` (the `Section("tracker.options.label")` keeps the "Use as Default" toggle), and delete the argument line `allowBibleStudies: allowBibleStudies,` in `submit()`.
2. `CategoryDetailView.swift`: delete the whole `Section { NavigationLink(destination: CategoryAdvancedOptionsView(tracker: tracker)) { ... } }` block (lines 77-81).
3. Delete `Hugo/Features/Categories/Views/CategoryAdvancedOptionsView.swift`. The `Views` folder keeps `CategoryColorPicker.swift` and `DefaultCategoryButton.swift`, so it is not left empty. The project uses synchronized folders; do not edit `project.pbxproj`.

**Verify**: `grep -rn "allowBibleStudies\|CategoryAdvancedOptionsView\|allow-bible-studies\|advancedOptions" Hugo --include='*.swift' | grep -v "Persistence/SchemaVersions"` → no output. Build → `0`.

### Step 3: Update and add tests

In `HugoTests/Features/Entries/Domain/EntryCategoryTests.swift`, replace the test `liveTrackerCarriesItsBibleStudiesSetting` with these two (keep `snapshotAllowsBibleStudies` and `untrackedEntryAllowsBibleStudies` unchanged):

```swift
    @Test
    func liveSeparateCategoryDoesNotAllowBibleStudies() {
        let entry = Entry(date: .now, duration: 1_800, tracker: Tracker(name: "LDC", type: .separate))
        #expect(entry.resolvedCategory().allowsBibleStudies == false)
    }

    /// Existing data: a main category whose old toggle was off now allows Bible studies.
    @Test
    func liveMainCategoryAllowsBibleStudiesWhateverTheOldToggleSaid() {
        let tracker = Tracker(name: "Field Service", type: .main, allowBibleStudies: false)
        let entry = Entry(date: .now, duration: 1_800, tracker: tracker)
        #expect(entry.resolvedCategory().allowsBibleStudies)
    }

    /// Existing data: an entry in a separate category keeps the studies it already has.
    @Test
    func separateCategoryEntryKeepsItsExistingBibleStudies() {
        let entry = Entry(date: .now, duration: 1_800, tracker: Tracker(name: "Bethel", type: .separate))
        entry.bibleStudies = 2
        let category = entry.resolvedCategory()
        #expect(BibleStudiesRule.showsControl(categoryAllows: category.allowsBibleStudies, count: entry.bibleStudies))
        #expect(entry.bibleStudies == 2)
    }
```

In `HugoTests/Features/Entries/State/AddEntryFormModelTests.swift`:

1. `choosingACategoryWithoutBibleStudiesClearsTheCount`: change `Tracker(name: "LDC", type: .separate, allowBibleStudies: false)` to `Tracker(name: "LDC", type: .separate)`.
2. `draftSavesNoBibleStudiesForACategoryWithoutThem`: same change.
3. Rename `categoryWithBibleStudiesKeepsTheCount` to `switchingBetweenMainCategoriesKeepsTheCount` and change its second tracker from `Tracker(name: "Bethel", type: .separate)` to `Tracker(name: "Public Witnessing", type: .main)`. The expectations (`bibleStudies == 1`, `showsBibleStudies`) stay.
4. Add:

```swift
    @Test
    func mainCategoryAllowsBibleStudiesEvenIfTheOldToggleWasOff() {
        let model = AddEntryFormModel(calendar: calendar, now: date(2026, 1, 1))
        model.selectedTracker = Tracker(name: "Field Service", type: .main, allowBibleStudies: false)
        #expect(model.categoryAllowsBibleStudies)
        #expect(model.showsBibleStudies)
    }
```

   Check first that the test struct has a `date(_:_:_:)` helper (`grep -n "func date" HugoTests/Features/Entries/State/AddEntryFormModelTests.swift`); the existing tests call `date(2026, 1, 1)`.

In `HugoTests/Features/Reports/Domain/MonthlyReportBuilderTests.swift`, add after `aggregatesCategoryAndBibleStudyTotals`:

```swift
    /// Bible studies already saved on a separate-category entry still count on the report.
    @Test
    func bibleStudiesFromBothKindsAddUp() throws {
        let main = Tracker(name: "Field Service", type: .main, iconName: "figure.walk")
        let separate = Tracker(name: "Bethel", type: .separate, iconName: "building")
        let entries = [
            Entry(date: date(2026, 1, 1), duration: 3_600, tracker: main, bibleStudies: 1),
            Entry(date: date(2026, 1, 2), duration: 1_800, tracker: separate, bibleStudies: 2),
        ]
        let summary = try #require(
            MonthlyReportBuilder.summaries(from: entries, calendar: calendar, locale: locale).first)
        #expect(summary.totalBibleStudies == 3)
    }
```

**Verify**: focused tests command → `** TEST SUCCEEDED **`.

### Step 4: Delete the two unused strings

Save the catalog helper from plan 127 Step 5 as `/tmp/xcstrings_edit.py` if it is not there yet (the `load()` and `save()` functions; it writes the catalog back byte for byte), and confirm it is lossless: `python3 -I -c "import sys; sys.path.insert(0, '/tmp'); import xcstrings_edit as x; x.save(x.load())"` then `git diff --stat -- Hugo/Resources/Localizable.xcstrings` → nothing. Then, from the repo root:

```sh
python3 -I -c "
import sys; sys.path.insert(0, '/tmp'); import xcstrings_edit as x
d = x.load(); s = d['strings']
for k in ['tracker.options.allow-bible-studies', 'tracker.settings.advancedOptions.label']: del s[k]
x.save(d)
"
```

If the helper file is missing, this is the whole of it:

```python
import json
import re

PATH = "Hugo/Resources/Localizable.xcstrings"


def load():
    with open(PATH, encoding="utf-8") as f:
        return json.loads(f.read())


def save(data):
    out = json.dumps(data, indent=2, separators=(",", " : "), ensure_ascii=False)
    out = re.sub(r"^( *)(.*)\{\}", lambda m: f"{m.group(1)}{m.group(2)}{{\n\n{m.group(1)}}}", out, flags=re.M)
    with open(PATH, "w", encoding="utf-8") as f:
        f.write(out)
```

**Verify**: `git diff --numstat -- Hugo/Resources/Localizable.xcstrings` → `0` added lines and 36 removed lines (18 per key).

### Step 5: Update `CONTEXT.md`

Replace the **Main category** and **Separate category** entries with:

```markdown
**Main category**:
A category whose time is reported together on the Field Service line. Its entries can have Bible studies.
_Avoid_: Primary category

**Separate category**:
A category whose time is reported on its own line, apart from Field Service, such as Bethel or LDC. New entries in it get no Bible studies; an entry that already has some keeps them. Whether a category allows Bible studies follows from its kind; the old per-category setting (`Tracker.allowBibleStudies`) is no longer read.
_Avoid_: Other, secondary category
```

### Step 6: Full gate and commit

Run `Scripts/verify.sh`. After it, `git diff --numstat -- Hugo/Resources/Localizable.xcstrings` must still show `0` added lines. Commit the in-scope files with the message from "Git workflow".

## Test plan

- `EntryCategoryTests`: a live separate category disallows; a live main category with the old flag off allows; a separate-category entry with 2 studies still shows its control and keeps the 2; snapshot and untracked entries allow (existing tests).
- `AddEntryFormModelTests`: picking a separate category clears a new entry's count; a draft in a separate category saves 0; switching between two main categories keeps the count; a main category with the old flag off allows studies.
- `MonthlyReportBuilderTests.bibleStudiesFromBothKindsAddUp`: 1 + 2 = 3 on the month's report.
- `BibleStudiesRuleTests`: unchanged, must still pass.
- `Scripts/verify.sh` → exit 0.

Owner checks on a device (record results in the plan's status row):
1. Add Category: no Bible studies toggle; "Use as Default" is still there.
2. Category detail: no "Advanced Options" row.
3. Add Entry with a separate category (for example Bethel): no Bible studies stepper. With Field Service: the stepper shows.
4. An old entry in a separate category with Bible studies: its detail screen still shows the stepper with the count; the month's report message shows the same Bible studies total as before.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -rn "allowBibleStudies" Hugo --include='*.swift' | grep -v "Persistence/SchemaVersions"` → no output
- [ ] `grep -rn "allowBibleStudies" HugoTests` → exactly 2 matches (the two "old toggle" tests, which set the legacy field on purpose)
- [ ] `test ! -e Hugo/Features/Categories/Views/CategoryAdvancedOptionsView.swift` → exit 0
- [ ] `grep -c "tracker.options.allow-bible-studies\|tracker.settings.advancedOptions.label" Hugo/Resources/Localizable.xcstrings` → `0`
- [ ] `git diff --stat c918888..HEAD -- Hugo/Persistence` shows no change from this plan
- [ ] `git status --short` shows no modified files outside the in-scope list, except the owner's `Debug.xcscheme`

## STOP conditions

- The grep in "Current state" lists more places than shown (something else reads or writes `allowBibleStudies`).
- `CategoryAdvancedOptionsView` is linked from somewhere other than `CategoryDetailView`.
- A step seems to need a change in `Hugo/Persistence` or a new schema version.
- Any existing test outside the ones named here fails because of the new rule.

## Maintenance notes

- `Tracker.allowBibleStudies` stays in every schema version from now on and is never read. If a later schema version copies `Tracker`, keep the property with its default (`true`) so CloudKit records still decode; do not try to drop it.
- If the owner later wants snapshots to follow their stored kind instead of counting as main, change the snapshot branch in `EntryCategory.resolvedCategory` to `snapshot.type == .main` and flip `snapshotAllowsBibleStudies`.
- Plan 129 adds the kind picker that tells users which kind allows Bible studies, and renames the kinds to Field Service and Credit.
