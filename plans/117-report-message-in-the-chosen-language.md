# Plan 117: Build the report message in the language Hugo is given, and test it in Danish

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 7e3c4e9..HEAD -- Hugo/Features/Reports/Domain/ReportComposer.swift Hugo/Features/Reports/State/SubmitReportFormModel.swift HugoTests/Features/Reports/Domain/ReportComposerTests.swift HugoTests/Features/Reports/State/SubmitReportFormModelTests.swift`
> Expected: no output. Otherwise compare the excerpts below with the live
> files. A mismatch is a STOP condition. (Plan 116 removes one line from
> `SubmitReportFormModelTests.swift`, `#expect(report.carriedOutSeconds == 1_800)`.
> That change is expected. Any other change to that file is a mismatch.)

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW. Three string lookups and tests. The app's own language doesn't change.
- **Depends on**: 114 (the gate), after 116 (both touch `SubmitReportFormModelTests.swift`)
- **Category**: bug
- **Planned at**: commit `7e3c4e9`, 2026-11-14
- **Issue**: [SLN-205](https://linear.app/sebastianln/issue/SLN-205)

## Why this matters

The report message is the text Hugo sends to the group overseer. It is the most visible text the app produces. `ReportComposer.message` and `SubmitReportFormModel` take a `locale` parameter so tests and future callers can choose the language. But the three labels and the default greeting are looked up with `String(localized: "key", locale: locale)`, and that initializer **ignores `locale` when it picks the language**. It only uses `locale` to format interpolated values. The language always comes from the app's preferred localization.

The advisor checked this on 2026-11-14 against the built app's string tables, with the locale `da_DK`:

| Lookup | Result for `report.compose.field-service` |
|---|---|
| `String(localized: "report.compose.field-service", locale: da)` | `Field Service` (wrong) |
| `String(localized: LocalizedStringResource("report.compose.field-service", locale: da))` | `Timer` (right) |

Inside the app today, both give the same result, because `locale` is `.current` and the app runs in the user's language. The bug shows in tests and in any future caller, such as a widget or an App Intent, and the existing tests can't catch it: they compute their expected labels with the same broken lookup. After this plan, the message really uses the language it is given, and a Danish test proves it.

## Current state

`Hugo/Features/Reports/Domain/ReportComposer.swift:33-67`:

```swift
    static func message(
        month: YearMonth,
        results: [ReportingLineResult],
        bibleStudies: Int,
        template: String,
        firstName: String,
        lastName: String,
        locale: Locale = .current,
        calendar: Calendar = .current
    ) -> ReportMessageContent {
        let hoursUnit = String(localized: "report.hours.unit", locale: locale)
        let greeting = render(
            template: template,
            firstName: firstName,
            lastName: lastName,
            month: month.monthName(locale: locale, calendar: calendar),
            year: String(month.year)
        )
        var lines: [String] = [greeting, ""]

        for result in results {
            let label =
                if result.line.type == .main {
                    String(localized: "report.compose.field-service", locale: locale)
                } else {
                    result.line.name
                }
            lines.append("\(label): \(result.submittedHours) \(hoursUnit)")
        }

        let studiesLabel = String(localized: "report.compose.bible-studies", locale: locale)
        lines.append("\(studiesLabel): \(bibleStudies)")

        return ReportMessageContent(recipient: nil, body: lines.joined(separator: "\n"))
    }
```

`Hugo/Features/Reports/State/SubmitReportFormModel.swift:187-193`:

```swift
    private var greetingTemplate: String {
        let stored = userDefaults.string(forKey: UserDefaultsKeys.overseerGreetingTemplate)

        return stored?.isEmpty == false
            ? stored!
            : String(localized: "report.greeting.default", locale: locale)
    }
```

The month name already respects `locale`: `YearMonthTests` checks `month.monthName(locale: Locale(identifier: "da_DK"), calendar: calendar) == "juni"` for June.

Catalog values in `Hugo/Resources/Localizable.xcstrings`:

| Key | English | Danish |
|---|---|---|
| `report.hours.unit` | `h` | `t` |
| `report.compose.field-service` | `Field Service` | `Timer` |
| `report.compose.bible-studies` | `Bible studies` | `Bibelstudier` |
| `report.greeting.default` | `Hi {first}!` + newline + `Here is my report for {month}.` | `Hej {first}!` + newline + `Her er min rapport for {month}.` |

The repo already uses the correct pattern, in `Hugo/Features/Planner/Domain/PlannerTargetPreview.swift:56`:

```swift
            ?? String(localized: LocalizedStringResource("planner.target.none", locale: locale))
```

Existing tests:
- `HugoTests/Features/Reports/Domain/ReportComposerTests.swift` uses `private let locale = Locale(identifier: "en_US_POSIX")`. Its two `message` tests compute the expected labels with `String(localized: "…", locale: locale)`. They must assert literal English text instead.
- `HugoTests/Features/Reports/State/SubmitReportFormModelTests.swift:35-41` has the helper:

```swift
    private func makeModel(
        now: Date? = nil,
        userDefaults: UserDefaults? = nil
    ) -> SubmitReportFormModel {
        let defaults = userDefaults ?? UserDefaults(suiteName: "SubmitReportFormModelTests-\(UUID().uuidString)")!
        return SubmitReportFormModel(month: month, calendar: calendar, now: now ?? self.now, userDefaults: defaults)
    }
```

  and the test `composerUsesPreparedTemplateAndCurrentPerLineHours` (around line 362) shows how to prepare a message: it sets a template and a first name in a `UserDefaults(suiteName:)`, loads one entry of 19 200 seconds on 2026-06-05, sets `.down` on the main line, and calls `model.prepareSubmission()`. The model's `month` is June 2026.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `xcrun swift-format lint --strict <changed files>` | exit 0, no output |
| Full gate | `Scripts/verify.sh` | exit 0 (several minutes; run with a 600000 ms timeout or in the background) |

## Scope

**In scope**:
- `Hugo/Features/Reports/Domain/ReportComposer.swift`
- `Hugo/Features/Reports/State/SubmitReportFormModel.swift` (only `greetingTemplate`)
- `HugoTests/Features/Reports/Domain/ReportComposerTests.swift`
- `HugoTests/Features/Reports/State/SubmitReportFormModelTests.swift` (the `makeModel` helper and one new test)

**Out of scope**:
- `Hugo/Resources/Localizable.xcstrings`. No string changes.
- `GreetingTemplateView.swift` and `ReportComposer.render`. They don't look up strings.
- Other files that use `String(localized:locale:)` (`EntryCategory.swift`, `PlannerTarget.swift`). They are a separate clean-up.
- `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` has an uncommitted change by the owner. Never stage, commit, revert or stash it.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- Never stage `plans/`, `.claude/` or `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage files by explicit path.
- One commit: `fix: build the report message in the language it is given`

## Steps

### Step 1: Use `LocalizedStringResource` in the composer

In `ReportComposer.message`, replace the three lookups:

```swift
        let hoursUnit = String(localized: LocalizedStringResource("report.hours.unit", locale: locale))
```

```swift
                    String(localized: LocalizedStringResource("report.compose.field-service", locale: locale))
```

```swift
        let studiesLabel = String(localized: LocalizedStringResource("report.compose.bible-studies", locale: locale))
```

Add a doc comment above `static func message(`:

```swift
    /// Builds the message sent to the group overseer. Every label, the unit
    /// and the month name use `locale`'s language. Look strings up with
    /// `LocalizedStringResource(_:locale:)`: `String(localized:locale:)`
    /// takes its language from the app, not from `locale`.
```

**Verify**: `grep -c 'String(localized: "' Hugo/Features/Reports/Domain/ReportComposer.swift` → `0`. `grep -c "LocalizedStringResource(" Hugo/Features/Reports/Domain/ReportComposer.swift` → `4` (three lookups plus the doc comment).

### Step 2: Use it for the default greeting

In `SubmitReportFormModel.greetingTemplate`, change the last line to:

```swift
            : String(localized: LocalizedStringResource("report.greeting.default", locale: locale))
```

**Verify**: `grep -n "report.greeting.default" Hugo/Features/Reports/State/SubmitReportFormModel.swift` prints one line containing `LocalizedStringResource`.

### Step 3: Make the composer tests assert real text, and add Danish

In `ReportComposerTests.swift`:

1. Change `private let locale = Locale(identifier: "en_US_POSIX")` to `private let locale = Locale(identifier: "en_US")`.
2. In `messageUsesOrderedReportingLineResultsAndBibleStudies`, delete the three `let … = String(localized: …)` lines. The expectation becomes:

```swift
        #expect(
            content.body.components(separatedBy: "\n") == [
                "Hi John!",
                "",
                "Field Service: 6 h",
                "LDC: 0 h",
                "Bible studies: 3",
            ])
```

3. In `messageRendersMonthAndYearTagsInlineInTheGreeting`, delete the two `let … = String(localized: …)` lines and change the last expectation to `#expect(lines[3] == "Field Service: 5 h")`.
4. Add this test at the end of the struct:

```swift
    @Test
    func messageUsesTheGivenLocaleForLabelsUnitAndMonth() {
        let results = [
            result(id: "", type: .main, name: "", seconds: 19_800, rule: .up),
            result(id: "LDC", type: .separate, name: "LDC", seconds: 0, rule: nil),
        ]

        let content = ReportComposer.message(
            month: month,
            results: results,
            bibleStudies: 3,
            template: "Hej {first}! Rapport for {month}.",
            firstName: "Jens",
            lastName: "",
            locale: Locale(identifier: "da_DK"),
            calendar: calendar
        )

        #expect(
            content.body.components(separatedBy: "\n") == [
                "Hej Jens! Rapport for juni.",
                "",
                "Timer: 6 t",
                "LDC: 0 t",
                "Bibelstudier: 3",
            ])
    }
```

**Verify**: `grep -c 'String(localized:' HugoTests/Features/Reports/Domain/ReportComposerTests.swift` → `0`.

### Step 4: Test the default greeting in Danish

In `SubmitReportFormModelTests.swift`:

1. Give `makeModel` a locale parameter, with English as the default so existing tests keep their behavior:

```swift
    private func makeModel(
        now: Date? = nil,
        userDefaults: UserDefaults? = nil,
        locale: Locale = Locale(identifier: "en_US")
    ) -> SubmitReportFormModel {
        let defaults = userDefaults ?? UserDefaults(suiteName: "SubmitReportFormModelTests-\(UUID().uuidString)")!
        return SubmitReportFormModel(
            month: month, calendar: calendar, now: now ?? self.now, locale: locale, userDefaults: defaults)
    }
```

2. Add this test right after `composerUsesPreparedTemplateAndCurrentPerLineHours`:

```swift
    @Test
    func defaultGreetingAndLabelsFollowTheModelsLocale() {
        let defaults = UserDefaults(suiteName: "SubmitReportFormModelTests-\(UUID().uuidString)")!
        defaults.set("Jens", forKey: UserDefaultsKeys.overseerFirstName)

        let model = makeModel(userDefaults: defaults, locale: Locale(identifier: "da_DK"))
        model.load(entries: [entry(2026, 6, 5, seconds: 19_200)], submissions: [])
        model.setRule(.down, for: mainLineID(in: model))

        let lines = model.prepareSubmission()?.body.components(separatedBy: "\n")

        #expect(lines == ["Hej Jens!", "Her er min rapport for juni.", "", "Timer: 5 t", "Bibelstudier: 0"])
    }
```

**Verify**: `grep -c "defaultGreetingAndLabelsFollowTheModelsLocale" HugoTests/Features/Reports/State/SubmitReportFormModelTests.swift` → `1`.

### Step 5: Run the gate and commit

**Verify**:
- `xcrun swift-format lint --strict Hugo/Features/Reports/Domain/ReportComposer.swift Hugo/Features/Reports/State/SubmitReportFormModel.swift HugoTests/Features/Reports/Domain/ReportComposerTests.swift HugoTests/Features/Reports/State/SubmitReportFormModelTests.swift` → exit 0.
- `Scripts/verify.sh` → exit 0. Both new tests pass.

Commit the four files by path.

## Test plan

- New: `ReportComposerTests.messageUsesTheGivenLocaleForLabelsUnitAndMonth` (Danish labels, unit and month) and `SubmitReportFormModelTests.defaultGreetingAndLabelsFollowTheModelsLocale` (Danish default greeting through the model).
- Changed: the two English composer tests assert literal text instead of re-running the lookup under test.

## Done criteria

- [ ] `grep -rn 'String(localized: "' Hugo/Features/Reports/Domain/ReportComposer.swift` prints nothing
- [ ] `grep -n "report.greeting.default" Hugo/Features/Reports/State/SubmitReportFormModel.swift` shows `LocalizedStringResource`
- [ ] `Scripts/verify.sh` exits 0, including the two new tests
- [ ] `git show --stat HEAD` lists exactly the four in-scope files

## STOP conditions

- The drift check shows changes other than plan 116's single removed line, and the excerpts don't match.
- A Danish test fails because a label comes out in English. That would mean `LocalizedStringResource` doesn't pick the catalog language in the test host, which contradicts the advisor's check. Report the actual lines.
- `Scripts/verify.sh` fails twice. Report the failing test names.

## Maintenance notes

- Any new text in the report message must use `LocalizedStringResource(_:locale:)`, never `String(localized:locale:)`. The Danish test catches a slip only for the strings it covers.
- Four other lookups have the same pattern: `EntryCategory.swift:39` and `PlannerTarget.swift:32-37`. They work in the app for the same reason this code did. Clean them up when a caller outside the app's language needs them.
