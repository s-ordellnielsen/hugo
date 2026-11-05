# Plan 080: Show durations as "23 hours, 15 min" (Danish "23 timer 15 min")

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 1432319..HEAD -- Hugo/Domain/ServiceDurationFormatter.swift HugoTests/Domain/ServiceDurationFormatterTests.swift Hugo/Resources/Localizable.xcstrings`
> Expected: no output. If a file is listed, compare the "Current state" excerpts below with the live code. On a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1 (next external TestFlight build)
- **Effort**: S + owner
- **Risk**: LOW (one formatter function and two new catalog keys; every caller keeps its signature)
- **Depends on**: none
- **Category**: direction (owner request)
- **Planned at**: commit `1432319`, 2026-11-05
- **Issue**: [SLN-291](https://linear.app/sebastianln/issue/SLN-291)

## Why this matters

The big numbers at the top of the Planner and the Year page use `ServiceDurationFormatter.hoursString`. It writes both units in full: "23 hours, 15 minutes" in English and "23 timer og 15 minutter" in Danish. In the large serif font that takes almost the whole width of an iPhone 16 Pro Max, worst in Danish. The owner chose a shorter form everywhere: hours stay a full word, minutes become "min". After this plan, 23 h 15 min reads "23 hours, 15 min" in English and "23 timer 15 min" in Danish. Every screen that shows a duration with words picks this up, because they all call the same function.

## Current state

- `Hugo/Domain/ServiceDurationFormatter.swift` holds the formatter. `hoursString` is lines 39–52:

  ```swift
      /// "152 hours" or "152 hours, 30 minutes". Seconds are dropped and zero minutes are omitted.
      static func hoursString(from duration: TimeInterval, locale: Locale = .current) -> String {
          let clamped = max(duration, 0)
          let wholeMinutes = Int(clamped / 60)
          let allowedUnits: Set<Duration.UnitsFormatStyle.Unit> =
              wholeMinutes == 0 ? [.hours] : [.hours, .minutes]
          var style = Duration.UnitsFormatStyle(
              allowedUnits: allowedUnits,
              width: .wide,
              zeroValueUnits: wholeMinutes == 0 ? .show(length: 1) : .hide
          )
          style.locale = locale
          return Duration.seconds(wholeMinutes * 60).formatted(style)
      }
  ```

  The enum is declared `nonisolated enum ServiceDurationFormatter` (line 3). The project builds with Swift 6 and MainActor default isolation, so the function must stay inside this `nonisolated` enum.

- `accessibilityString(from:locale:)` (lines 25–37) and `string(from:)` (lines 19–23, "01:30") are **not** changed. VoiceOver keeps full words.

- Callers of `hoursString` (none of them changes; listed so you know the reach): `PlannerStatusHeader`, `PlannerMonthStatus` (summary sentences), `PlannerTargetSettingsView`, `PlannerLoggedEntryList`, `PlannedCategoryCard`, `ServiceYearDetailView`, `TheocraticYearTotalsView`, `ServiceYearMonthRow`, `YearlyGoalProgress.paceSentence`, `MonthlyReportTotalsView`.

- Tests that assert on `hoursString` output are only in `HugoTests/Domain/ServiceDurationFormatterTests.swift` (struct name `DurationFormattingTests`). Lines 26–44:

  ```swift
      @Test func hoursStringFormatsWholeHours() {
          let us = Locale(identifier: "en_US")
          #expect(ServiceDurationFormatter.hoursString(from: 0, locale: us) == "0 hours")
          #expect(ServiceDurationFormatter.hoursString(from: 3_600, locale: us) == "1 hour")
          #expect(ServiceDurationFormatter.hoursString(from: 7_200, locale: us) == "2 hours")
          #expect(ServiceDurationFormatter.hoursString(from: 90_000, locale: us) == "25 hours")
      }

      @Test func hoursStringAddsMinutesOnlyWhenPresent() {
          let us = Locale(identifier: "en_US")
          let withMinutes = ServiceDurationFormatter.hoursString(from: 5_400, locale: us)
          #expect(withMinutes.contains("1 hour"))
          #expect(withMinutes.contains("30 minutes"))
          #expect(ServiceDurationFormatter.hoursString(from: 3_659, locale: us) == "1 hour")
      }

      @Test func hoursStringClampsNegativeToZero() {
          #expect(ServiceDurationFormatter.hoursString(from: -5, locale: Locale(identifier: "en_US")) == "0 hours")
      }
  ```

  `grep` over `HugoTests` finds no other test that compares text containing "minutes" or "minutter". `PlannerMonthStatusTests` only checks `.contains("4")` and inequality.

- **How the language is chosen (verified on 2026-11-05 with a test bundle holding `en.lproj` and `da.lproj`):**
  - `LocalizedStringResource` with its `locale` property set to `da_DK`, passed to `String(localized:)`, returns the **Danish** value.
  - `String(localized: "key", bundle:, locale: da_DK)` returns the **English** value. Its `locale` only formats arguments. Do not use it here.
  - `Duration.UnitsFormatStyle(allowedUnits: [.hours], width: .wide)` with `locale` set gives "0 hours", "1 hour", "23 hours" in `en_US` and "0 timer", "1 time", "23 timer" in `da_DK`.
  - The style's abbreviated minutes give "15 min." in Danish, with a period. The owner wants no period, so the "min" text comes from the string catalog.
  - Tests run hosted in `Hugo.app` (`TEST_HOST` in the project), so `Bundle.main` holds the compiled catalog during tests.

- `Hugo/Resources/Localizable.xcstrings` is the app's string catalog. It is one JSON file written by Xcode: 2-space indentation, `" : "` between key and value, keys sorted alphabetically, literal UTF-8. The source language is `en`. An interpolated `Int` is written `%lld` in values and an interpolated `String` is `%@`. Positional forms are `%1$@`, `%2$@`. Example entry (lines 1378–1394):

  ```json
      "planner.header.target" : {
        "comment" : "The monthly target. The argument is a duration such as 50 hours.",
        "localizations" : {
          "da" : {
            "stringUnit" : {
              "state" : "translated",
              "value" : "Mål %@"
            }
          },
          "en" : {
            "stringUnit" : {
              "state" : "translated",
              "value" : "Target %@"
            }
          }
        }
      },
  ```

  Keys starting with `duration.` belong between `"default.tracker"` (line 430) and `"entries.list.this_month.header"` (line 448). No `duration.` keys exist yet.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| JSON is valid | `python3 -c "import json; json.load(open('Hugo/Resources/Localizable.xcstrings', encoding='utf-8'))"` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/DurationFormattingTests -only-testing:HugoTests/PlannerMonthStatusTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 (several minutes) |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run the same command again. That is not a failure.

## Scope

**In scope** (the only files you modify):
- `Hugo/Domain/ServiceDurationFormatter.swift`: only `hoursString` and its doc comment.
- `HugoTests/Domain/ServiceDurationFormatterTests.swift`
- `Hugo/Resources/Localizable.xcstrings`: add the two keys from Step 1. Change nothing else.

**Out of scope**:
- `accessibilityString` and `string(from:)`. VoiceOver text keeps "hours" and "minutes".
- Any caller of `hoursString`. No view or sentence changes in this plan. Plans 081 and 082 change the headers.
- `DateListItem` in `OverviewListView.swift` and `OverviewCarriedEntriesView`. They format with `.units(... width: .abbreviated)` directly, not with `hoursString`.
- `ReportComposer`. It uses `String(localized:locale:)`, which has the language problem described above. That is Linear issue SLN-205 and not part of this plan.
- Do not open the catalog in Xcode and save it, because Xcode may rewrite unrelated parts. Edit the text file directly.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- The working tree may hold uncommitted owner files in `plans/` and `.claude/`. Never stage, edit, stash or discard them. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage only the three in-scope files, by explicit path.
- One commit in Conventional Commits style: `feat: shorten minutes in durations to "min"`

## Steps

### Step 1: Add the two catalog keys

Insert these two entries into `Hugo/Resources/Localizable.xcstrings` directly before the line `    "entries.list.this_month.header" : {`. Keep the 4-space indent before each key, exactly as shown. `duration.hoursAndMinutes` sorts before `duration.minutesShort`, so add it first.

```json
    "duration.hoursAndMinutes" : {
      "comment" : "A duration with hours and minutes, such as 23 hours, 15 min. The first argument is the hours (23 hours), the second the minutes (15 min).",
      "localizations" : {
        "da" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "%1$@ %2$@"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "%1$@, %2$@"
          }
        }
      }
    },
    "duration.minutesShort" : {
      "comment" : "Minutes in a short duration, such as the 15 min in 23 hours, 15 min. No period after min.",
      "localizations" : {
        "da" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "%lld min"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "%lld min"
          }
        }
      }
    },
```

The Danish values follow the owner's example ("23 timer 15 min"). The owner reviews them in the build.

**Verify**:
- The JSON check exits 0.
- `grep -c '^    "duration\.' Hugo/Resources/Localizable.xcstrings` → `2`
- `git diff --numstat Hugo/Resources/Localizable.xcstrings` → `34	0	Hugo/Resources/Localizable.xcstrings`

### Step 2: Rewrite `hoursString`

Replace lines 39–52 of `Hugo/Domain/ServiceDurationFormatter.swift` (the doc comment and the whole function) with:

```swift
    /// "23 hours", "23 hours, 15 min" or "45 min" (Danish: "23 timer 15 min").
    /// Hours are a full word and minutes are always "min". Seconds are dropped,
    /// zero minutes are left out, and zero is "0 hours". Negative values count as zero.
    static func hoursString(from duration: TimeInterval, locale: Locale = .current) -> String {
        let wholeMinutes = Int(max(duration, 0) / 60)
        let hours = wholeMinutes / 60
        let minutes = wholeMinutes % 60

        var hoursStyle = Duration.UnitsFormatStyle(
            allowedUnits: [.hours], width: .wide, zeroValueUnits: .show(length: 1))
        hoursStyle.locale = locale
        let hoursText = Duration.seconds(hours * 3_600).formatted(hoursStyle)
        guard minutes > 0 else { return hoursText }

        // LocalizedStringResource picks the catalog language from `locale`;
        // String(localized:locale:) would not.
        let minutesText = String(
            localized: LocalizedStringResource(
                "duration.minutesShort", defaultValue: "\(minutes) min", locale: locale,
                comment: "Minutes in a short duration, such as the 15 min in 23 hours, 15 min. No period after min."))
        guard hours > 0 else { return minutesText }

        return String(
            localized: LocalizedStringResource(
                "duration.hoursAndMinutes", defaultValue: "\(hoursText), \(minutesText)", locale: locale,
                comment:
                    "A duration with hours and minutes, such as 23 hours, 15 min. The first argument is the hours (23 hours), the second the minutes (15 min)."
            ))
    }
```

Keep 4-space indentation. Do not use tabs. Do not change any other function in the file.

**Verify**: `xcrun swift-format lint --strict Hugo/Domain/ServiceDurationFormatter.swift` → no output, exit 0. If it reports a line-length problem, wrap the line the way the lint message suggests (the pre-commit hook would also do this) and run the lint again.

### Step 3: Update and extend the tests

In `HugoTests/Domain/ServiceDurationFormatterTests.swift`:

1. Keep `hoursStringFormatsWholeHours` and `hoursStringClampsNegativeToZero` as they are.
2. Replace `hoursStringAddsMinutesOnlyWhenPresent` (lines 34–40) with:

```swift
    @Test func hoursStringShortensMinutesInEnglish() {
        let us = Locale(identifier: "en_US")
        #expect(ServiceDurationFormatter.hoursString(from: 23 * 3_600 + 15 * 60, locale: us) == "23 hours, 15 min")
        #expect(ServiceDurationFormatter.hoursString(from: 5_400, locale: us) == "1 hour, 30 min")
        #expect(ServiceDurationFormatter.hoursString(from: 45 * 60, locale: us) == "45 min")
        #expect(ServiceDurationFormatter.hoursString(from: 3_659, locale: us) == "1 hour")
    }

    @Test func hoursStringShortensMinutesInDanish() {
        let da = Locale(identifier: "da_DK")
        #expect(ServiceDurationFormatter.hoursString(from: 23 * 3_600 + 15 * 60, locale: da) == "23 timer 15 min")
        #expect(ServiceDurationFormatter.hoursString(from: 3_600 + 60, locale: da) == "1 time 1 min")
        #expect(ServiceDurationFormatter.hoursString(from: 45 * 60, locale: da) == "45 min")
        #expect(ServiceDurationFormatter.hoursString(from: 2 * 3_600, locale: da) == "2 timer")
        #expect(ServiceDurationFormatter.hoursString(from: 0, locale: da) == "0 timer")
    }
```

**Verify**: run the focused tests from "Commands you will need" → `** TEST SUCCEEDED **`. The output lists `hoursStringShortensMinutesInEnglish` and `hoursStringShortensMinutesInDanish` as passed.

### Step 4: Run the gate and commit

Run `Scripts/verify.sh`. Then stage the three in-scope files by path and commit with the message from "Git workflow".

**Verify**: `Scripts/verify.sh` exits 0. `git show --stat HEAD` lists exactly `Hugo/Domain/ServiceDurationFormatter.swift`, `HugoTests/Domain/ServiceDurationFormatterTests.swift` and `Hugo/Resources/Localizable.xcstrings`.

## Test plan

- The two new tests in `DurationFormattingTests` cover hours with minutes, minutes only, whole hours, seconds dropped, and zero, in English and Danish. The Danish test also proves that the catalog lookup follows the passed locale.
- Existing whole-hour and negative-value tests stay and must still pass.
- Model: the existing tests in the same file.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0.
- [ ] `hoursStringShortensMinutesInEnglish` and `hoursStringShortensMinutesInDanish` exist and pass.
- [ ] `grep -n '30 minutes' HugoTests/Domain/ServiceDurationFormatterTests.swift` → no output.
- [ ] `grep -c '^    "duration\.' Hugo/Resources/Localizable.xcstrings` → `2`
- [ ] `git show --stat HEAD` lists only the three in-scope files.
- [ ] Owner check (by hand, in the build): in Danish and in English, the Planner header, the Year page header and the Submit Report totals show minutes as "min" ("23 timer 15 min", "23 hours, 15 min"). With VoiceOver on, the Year page header still reads a sensible duration.

## STOP conditions

Stop and report back, do not improvise, if:

- The Danish test returns English text (for example "23 timer, 15 min" or "15 min" joined with a comma), or returns the raw key `duration.minutesShort` or the text `%lld min`. That means the catalog lookup does not follow `locale` in the test host. Do **not** work around it with `if locale.language...` branches or hard-coded strings. Report what the test returned.
- `Duration.UnitsFormatStyle` gives a different hours text than "23 timer" / "1 time" / "0 timer" in `da_DK`.
- Any other test fails because of the new wording. The plan found no such test, so this means something else changed.
- The fix seems to need changes to a caller of `hoursString`.

## Maintenance notes

- Every on-screen duration with words now shows "min". A future caller that needs full words for speech must use `accessibilityString`, not `hoursString`.
- The minutes text comes from the catalog. A new language needs `duration.minutesShort` and `duration.hoursAndMinutes` translated, or it falls back to the English pattern.
- Plans 081 (Planner header) and 082 (Year page header) build on this format and move the "Target" and "Actual total" texts.
- Related: SLN-205 (`ReportComposer` uses `String(localized:locale:)`, which does not choose the language from `locale`). The 2026-11-05 check confirmed that behavior.
