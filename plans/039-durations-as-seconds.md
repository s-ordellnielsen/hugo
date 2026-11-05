# Plan 039: Store entry durations as seconds and use the wheel picker when editing

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 3f8d48b..HEAD -- Hugo/Features/Entries Hugo/Features/Overview/Views/OverviewListView.swift HugoTests/Features/Entries`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding. On a
> mismatch, treat it as a STOP condition. (Plan 037 changes only whitespace
> in `OverviewListView.swift`. That is expected.)

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/037-green-gate-and-serial-tests.md
- **Category**: bug
- **Planned at**: commit `3f8d48b`, 2026-10-12
- **Issue**: [SLN-248](https://linear.app/sebastianln/issue/SLN-248)

## Why this matters

Hugo stores a duration (for example 2 h 30 min) by building a clock time on today's date (02:30) and reading the hour and minute back. That round trip is wrong in two cases, both confirmed with a script against Foundation:

- On the daylight-saving spring-forward day (last Sunday of March in Denmark, second Sunday of March in the US), 02:00–02:59 does not exist. `Calendar.date(from:)` moves it to 03:xx, so a 2 h 30 min entry saves as 3 h 30 min. Field service is often done on Sundays, and the extra hour flows into the report sent to the overseer.
- The add-entry wheel offers 0–24 hours. Picking 24 h builds "24:00", which is midnight of the next day, so it reads back as 0 and the Add button disables itself.

Editing an existing entry uses a different control: a `DatePicker` showing hours and minutes as a clock time. In 12-hour locales a 1 h 30 min entry shows and is spoken by VoiceOver as "1:30 AM". It also ignores the user's minute-interval setting. After this plan, durations are plain `TimeInterval` seconds end to end, and adding and editing use the same `DurationWheelPicker`.

## Current state

- `Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift`: the add-entry state. Relevant lines:

  ```swift
  // :11-21
  @MainActor
  @Observable
  final class AddEntryFormModel {
      var date: Date
      var time: Date?
      var durationDate: Date
      var bibleStudies = 0
      ...
  // :30-40
      init(calendar: Calendar = .current, now: Date = .now, seededDate: Date? = nil) {
          self.calendar = calendar
          self.now = now
          self.date = calendar.startOfDay(for: seededDate ?? now)
          self.durationDate = calendar.startOfDay(for: now)
      }

      var durationInSeconds: TimeInterval {
          get { EntryDurationConversion.seconds(from: durationDate, calendar: calendar) }
          set { durationDate = EntryDurationConversion.date(from: newValue, calendar: calendar, reference: durationDate) }
      }
  // :113-127
  enum EntryDurationConversion {
      static func seconds(from date: Date, calendar: Calendar) -> TimeInterval { ... }
      static func date(from seconds: TimeInterval, calendar: Calendar, reference: Date) -> Date { ... }
  }
  ```

  `durationInSeconds` is also read by `isSubmitDisabled`, `draft()` and `inferredTime()`. Those stay as they are.

- `Hugo/Features/Entries/AddEntry/AddEntryView.swift:5,21-27`: the add screen already uses the wheel and binds to `durationInSeconds`:

  ```swift
  @AppStorage(UserDefaultsKeys.durationMinuteInterval) private var durationMinuteInterval = 1
  ...
  Section("entry.duration.label") {
      DurationWheelPicker(
          duration: $form.durationInSeconds,
          minuteInterval: durationMinuteInterval,
          maxDuration: 24 * 60 * 60
      )
  }
  ```

- `Hugo/Features/Entries/DurationWheelPicker.swift`: the wheel (`UIPickerView` with hours and minutes). Its signature is `DurationWheelPicker(duration: Binding<TimeInterval>, minuteInterval: Int, maxDuration: TimeInterval)`. It offers `Int(maxDuration / 3600) + 1` hour rows. Do not modify it.

- `Hugo/Features/Entries/EntryDetailView.swift:14-23`: the edit screen.

  ```swift
  var body: some View {
      @Bindable var entry = entry
      NavigationStack {
          Form {
              Section {
                  EntryDurationPicker(duration: $entry.duration)
                  DatePicker(selection: $entry.date) {
                      Label("entry.date.label", systemImage: "calendar")
                  }
              }
  ```

- `Hugo/Features/Entries/EntryDurationPicker.swift` (49 lines): a `DatePicker(displayedComponents: .hourAndMinute)` that packs the duration into today's date with `Calendar.current`. `EntryDetailView` is its only user.

- `Hugo/Features/Overview/Views/OverviewListView.swift:57-60` presents the edit screen in a medium-height sheet:

  ```swift
  .sheet(item: $selectedEntry) { entry in
      EntryDetailView(entry: entry)
          .presentationDetents([.medium])
  }
  ```

  `Hugo/Features/Reports/MonthlyReportEntryListView.swift:17` also pushes `EntryDetailView` inside a navigation stack.

- Existing entries can be longer than 24 hours. The V7→V8 migration turned each old monthly report category into one entry holding the whole month's time (`HugoMigrationPlan.swift:136-147`). The edit wheel must not cap those at 24 h, or touching it would silently cut a month's total.

- Tests: `HugoTests/Features/Entries/AddEntryFormModelTests.swift` uses Swift Testing and a fixed UTC Gregorian calendar:

  ```swift
  @MainActor
  struct AddEntryFormModelTests {
      private let calendar: Calendar = {
          var calendar = Calendar(identifier: .gregorian)
          calendar.timeZone = TimeZone(secondsFromGMT: 0)!
          return calendar
      }()

      @Test
      func convertsDurationToSeconds() {
          let model = AddEntryFormModel(calendar: calendar, now: date(2026, 1, 1))
          model.durationDate = date(2026, 1, 1, hour: 1, minute: 30)
          #expect(model.durationInSeconds == 5_400)
      }
  ```

  `durationDate` is also set at lines 59 and 67 (`model.durationDate = date(2026, 1, 1, hour: 1)`). Lines 89-94 hold the parameterized `durationRoundTrips` test of `EntryDurationConversion`.

- The project uses Xcode filesystem-synchronized groups (`PBXFileSystemSynchronizedRootGroup` in `project.pbxproj`). Deleting a Swift file needs no project-file edit.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Entry tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/AddEntryFormModelTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:

- `Hugo/Features/Entries/AddEntry/AddEntryFormModel.swift`
- `Hugo/Features/Entries/EntryDetailView.swift`
- `Hugo/Features/Entries/EntryDurationPicker.swift` (delete)
- `Hugo/Features/Overview/Views/OverviewListView.swift` (the one `.presentationDetents` line)
- `HugoTests/Features/Entries/AddEntryFormModelTests.swift`
- `plans/README.md` (status row)

**Out of scope**:

- `DurationWheelPicker.swift`. Its accessibility gaps (no spoken units) are a separate finding.
- `Entry` / any file under `Hugo/Persistence`. `Entry.duration` is already a `TimeInterval`.
- The time-of-day logic in `AddEntryFormModel` (`time`, `combinedDate`, `inferredTime`, `snapped`). It works on real clock times and is correct to use the calendar.

## Git workflow

- Branch: `advisor/039-durations-as-seconds`
- Commit message style: short imperative sentence, for example `Store add-entry duration as seconds`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Make `durationInSeconds` a stored property

In `AddEntryFormModel`:

1. Delete `var durationDate: Date` and the line `self.durationDate = calendar.startOfDay(for: now)` in `init`.
2. Replace the computed `durationInSeconds` with a stored property next to the other state: `var durationInSeconds: TimeInterval = 0`.
3. Delete the whole `enum EntryDurationConversion` at the bottom of the file.

**Verify**: `grep -rn 'durationDate\|EntryDurationConversion' Hugo` → no matches. (Tests still reference them until Step 2, so do not build yet.)

### Step 2: Update the tests

In `AddEntryFormModelTests.swift`:

1. Replace `convertsDurationToSeconds` with a test that proves no clock conversion happens on a spring-forward day:

   ```swift
   @Test(arguments: [9_000.0, 86_400.0])
   func durationIsStoredWithoutClockConversion(seconds: TimeInterval) throws {
       var copenhagen = Calendar(identifier: .gregorian)
       copenhagen.timeZone = try #require(TimeZone(identifier: "Europe/Copenhagen"))
       // 2027-03-28 is the EU spring-forward Sunday; 02:00-02:59 does not exist.
       let springForward = try #require(
           copenhagen.date(from: DateComponents(year: 2027, month: 3, day: 28, hour: 12)))
       let model = AddEntryFormModel(calendar: copenhagen, now: springForward)
       model.selectedTracker = Tracker(name: "Field Service")

       model.durationInSeconds = seconds

       #expect(model.durationInSeconds == seconds)
       #expect(model.isSubmitDisabled == false)
   }
   ```

   `9_000` is 2 h 30 min, which the old code turned into 3 h 30 min. `86_400` is 24 h, which the old code turned into 0.

2. At the two places that set `model.durationDate = date(2026, 1, 1, hour: 1)` (currently lines 59 and 67), write `model.durationInSeconds = 3_600` instead.
3. Delete the `durationRoundTrips` test (the type it tested is gone).

**Verify**:

- `grep -rn 'durationDate\|EntryDurationConversion' Hugo HugoTests` → no matches.
- The "Entry tests" command → `** TEST SUCCEEDED **`.

Commit steps 1 and 2: `Store add-entry duration as seconds`.

### Step 3: Use the wheel picker on the edit screen

In `EntryDetailView`:

1. Add `@AppStorage(UserDefaultsKeys.durationMinuteInterval) private var durationMinuteInterval = 1` (same default as `AddEntryView`).
2. Replace the first `Section` so the wheel gets its own section, matching `AddEntryView`:

   ```swift
   Section("entry.duration.label") {
       DurationWheelPicker(
           duration: $entry.duration,
           minuteInterval: durationMinuteInterval,
           maxDuration: max(24 * 60 * 60, entry.duration)
       )
   }

   Section {
       DatePicker(selection: $entry.date) {
           Label("entry.date.label", systemImage: "calendar")
       }
   }
   ```

   The `max(...)` keeps migrated month-sized entries editable without capping them.
3. Delete `Hugo/Features/Entries/EntryDurationPicker.swift`.
4. In `OverviewListView.swift`, change the edit sheet's `.presentationDetents([.medium])` (inside `.sheet(item: $selectedEntry)`) to `.presentationDetents([.medium, .large])`, so the taller form can be expanded.

**Verify**:

- `grep -rn 'EntryDurationPicker' Hugo HugoTests` → no matches.
- `xcrun swift-format lint --strict --recursive Hugo HugoTests` → exit 0.
- `Scripts/verify.sh` → exit 0.

Commit: `Edit entry durations with the wheel picker`.

### Step 4 [owner]: Check on a simulator

1. Settings → set the minute interval to 15. Open an existing entry from Overview. The wheel shows hours and minutes in 15-minute steps, with no AM/PM.
2. Set the simulator's region to United States (12-hour clock). The edit screen still shows a wheel, not "1:30 AM".
3. Add an entry with 24 h 00 min. The Add button stays enabled and the saved entry shows 24:00.

## Test plan

- `durationIsStoredWithoutClockConversion` (two arguments) in `AddEntryFormModelTests.swift`, written in Step 2. It fails on the old code for both arguments.
- The existing tests `emptyCategoryPreventsDraftCreation` and `draftWithoutTrackerProducesLocalizedValidationMessage` keep passing with `durationInSeconds = 3_600`.
- Net test count: one parameterized test with 2 cases replaces `convertsDurationToSeconds` (1) and `durationRoundTrips` (4 cases), so the reported total drops by 3.

## Done criteria

- [ ] `grep -rn 'durationDate\|EntryDurationConversion\|EntryDurationPicker' Hugo HugoTests` prints nothing
- [ ] `Scripts/verify.sh` exits 0
- [ ] `git status --porcelain` lists only files from the Scope list
- [ ] `plans/README.md` row for 039 updated

## STOP conditions

Stop and report back if:

- `durationDate` or `EntryDurationConversion` is used anywhere other than `AddEntryFormModel.swift` and `AddEntryFormModelTests.swift`.
- `DurationWheelPicker`'s initializer differs from `(duration:minuteInterval:maxDuration:)`.
- Deleting `EntryDurationPicker.swift` breaks the build with a "file not found" error from the project file. That would mean the target does not use synchronized groups after all.
- The Copenhagen test still fails after Step 1. That would mean another conversion remains somewhere.

## Maintenance notes

- Never represent a duration as a `Date`. Clock times skip and repeat hours. Keep durations as `TimeInterval` or `Duration`.
- `EntryDetailView` edits the model live through bindings with no explicit save. That is existing behavior. Plan 040 also touches this file (category snapshot), so run 039 first to keep diffs small.
- `DurationWheelPicker` still has accessibility gaps: the wheels show "01" / "30" without units, and VoiceOver reads them without units. That is listed as an unplanned finding in `plans/README.md`.
