# Plan 171: Drag a month's report out of Service Year

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat <BASELINE>..HEAD -- Hugo/Features/Reports/Domain/ReportComposer.swift HugoTests/Features/Reports/Domain/ReportComposerTests.swift Hugo/Features/ServiceYear/Views`
> The reviewer sets <BASELINE> at dispatch to the commit after the previous plan in the batch (166–173). Expected: no output. STOP on any output.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). This plan adds no strings. Never stage that file.

## Status

- **Priority**: P2
- **Effort**: S + owner
- **Risk**: LOW. A drag source on a card that already taps, scrolls and has a context menu. The main risk is that the three gestures interfere; the owner check covers it.
- **Depends on**: 167 (same card; run after it). Plan 169 runs before this plan and puts the same cards in a grid without changing them.
- **Category**: ux
- **Planned at**: commit `16b697c`, 2026-11-26
- **Issue**: [SLN-349](https://linear.app/sebastianln/issue/SLN-349)

## Why this matters

Publishers sometimes keep their own record of reports in Notes, or forward a
month's numbers by Mail. Today the report text is only available inside Submit
Report (Copy or Messages), and only while sending. On iPad, the natural way to
move a month's numbers into another app is to drag the month.

After this plan, a submitted month's card on the Service Year tab can be dragged
into Notes, Mail, Messages or any app that accepts text. It drops the numbers
that were sent:

```
November 2026
Field Service: 52 h
LDC: 5 h
School credit: 30 h
Bible studies: 4
```

(labels and unit in the app's language; Danish uses "Timer", "t", "Skole" and
"Bibelstudier", the same words as the report message.)

## Decisions (owner can override)

1. **Only submitted months can be dragged.** An unsubmitted month has no final
   numbers yet: rounding and transfer are chosen in Submit Report, so a draft
   could differ from what is sent later. Placeholder reports count as not
   submitted (`ServiceMonth.isSubmitted`).
2. **The text is rebuilt from the submitted report, never from today's
   entries.** Entries can change after sending (an unreported change); the drag
   must show what the overseer received. The sent message itself is not stored,
   so the text is rebuilt from the stored report lines.
3. **No greeting, and school credit as one line.** The greeting depends on the
   current template and overseer, which may have changed since. The stored
   report keeps only the total school credit hours (`schoolCreditHours`), not
   each school, so school credit becomes one "School credit" line. That line
   uses the `school.unknown.name` string ("School credit" / "Skole"), not a
   school's own name as the sent message does. Everything else matches the sent
   message's lines and order.
4. **The drag preview is a small label** (the month's name with a document
   symbol in a capsule), not the whole card, so the drop target stays visible.

## Current state

`Hugo/Features/Reports/Domain/ReportComposer.swift` builds the report message:

```swift
nonisolated enum ReportComposer {
    static func render(template: String, firstName: String, lastName: String, month: String, year: String) -> String { ... }

    /// Builds the message sent to the group overseer. Every label, the unit
    /// and the month name use `locale`'s language. Look strings up with
    /// `LocalizedStringResource(_:locale:)`: `String(localized:locale:)`
    /// takes its language from the app, not from `locale`.
    static func message(
        month: YearMonth,
        results: [ReportingLineResult],
        schoolCredits: [SchoolCreditLine] = [],
        bibleStudies: Int,
        template: String,
        firstName: String,
        lastName: String,
        locale: Locale = .current,
        calendar: Calendar = .current
    ) -> ReportMessageContent {
        let hoursUnit = String(localized: LocalizedStringResource("report.hours.unit", locale: locale))
        ...
        for result in results {
            let label =
                if result.line.type == .main {
                    String(localized: LocalizedStringResource("report.compose.field-service", locale: locale))
                } else {
                    result.line.name
                }
            lines.append("\(label): \(result.submittedHours) \(hoursUnit)")
        }
        for credit in schoolCredits {
            lines.append("\(School.name(forID: credit.schoolID, locale: locale)): \(credit.hours) \(hoursUnit)")
        }
        let studiesLabel = String(localized: LocalizedStringResource("report.compose.bible-studies", locale: locale))
        lines.append("\(studiesLabel): \(bibleStudies)")
        return ReportMessageContent(recipient: nil, body: lines.joined(separator: "\n"))
    }
}
```

String values: `report.hours.unit` "h" / "t"; `report.compose.field-service`
"Field Service" / "Timer"; `report.compose.bible-studies` "Bible studies" /
"Bibelstudier"; `school.unknown.name` "School credit" / "Skole".

`SubmittedReport` (`Hugo/Persistence/SchemaVersions/V14/SubmittedReportV14.swift`,
the current schema) stores, among others:

- `submittedHours: Int?` (whole-hour total; the only figure on reports from before reporting lines),
- `totalBibleStudies: Int?`,
- `schoolCreditHours: Int?` (nil on old reports; read nil as 0),
- `reportingLines: [SubmittedReportingLine]`, each with `type: TrackerType` (`.main` or `.separate`), `typeName: String` (the Credit category's name; "" for `.main`) and `submittedHours: Int`.

`Hugo/Persistence/SubmittedReport+Submission.swift` defines
`var isSubmitted: Bool` (false for a placeholder report).

`Hugo/Features/Reports/Domain/ServiceMonth.swift` is a `nonisolated struct` with
`let id: YearMonth`, `let displayName: String`, `let isFuture: Bool`,
`let submittedReport: SubmittedReport?` and `var isSubmitted: Bool`. Its
`contribution` already reads `submission.reportingLines`, `.totalBibleStudies`
and `.schoolCreditHours` from a `nonisolated` context, so a `nonisolated`
function can read them too.

`YearMonth.monthYearString(locale:calendar:)` returns "November 2026"
(format "LLLL yyyy"; Danish gives "november 2026").

`Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift`, `body` (after plan
167, which added the two hover lines; plan 169 puts the row in a `LazyVGrid` but
does not change it):

```swift
var body: some View {
    Group {
        if month.isFuture {
            card
        } else {
            NavigationLink {
                MonthDetailView(month: month, schoolCredits: schoolCredits)
                    .navigationTransition(.zoom(sourceID: month.id, in: transition))
            } label: {
                card
                    .matchedTransitionSource(id: month.id, in: transition) { source in
                        source.clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
                    }
            }
            .buttonStyle(.card)
            .contentShape(.contextMenuPreview, .rect(cornerRadius: HugoLayout.CornerRadius.card))
            .contextMenu {
                quickActions
            }
            .contentShape(.hoverEffect, .rect(cornerRadius: HugoLayout.CornerRadius.card))
            .hoverEffect(.highlight)
        }
    }
    .sheet(isPresented: $isPresentingAddEntry) { ... }
    .sheet(isPresented: $isPresentingSubmitSheet) { ... }
}
```

`card` is a private computed property: a `VStack` with the card's padding,
background and clip. Future months show `card` alone and stay that way.

`MonthDetailView` (the page the link pushes) presents `SubmitReportView` itself.
When the user submits from there, the month becomes submitted and this row
re-renders while the detail page is still on screen. If the drag modifier
changed the identity of the `NavigationLink` (for example a branch around the
link), that page could pop. The drag source therefore goes on `card`, inside the
link's label, so a conditional only changes the label's subtree.

Test pattern: `HugoTests/Features/Reports/Domain/ReportComposerTests.swift`
(`struct`, fixed UTC Gregorian calendar, `Locale(identifier: "en_US")`), and
`ServiceMonthTests` builds `SubmittedReport(year:month:firstSubmittedAt:submittedAt:...reportingLines:)`
directly and is `@MainActor`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` (run as `sh -c 'Scripts/verify.sh; echo "VERIFY_EXIT=$?"'`) | `VERIFY_EXIT=0` |
| Format check | `xcrun swift-format lint --strict <files>` | exit 0 |
| Format fix | `xcrun swift-format format -i <files>` | then re-run lint; use when `lint --strict` fails on formatting only |

## Scope

**In scope**:

- `Hugo/Features/Reports/Domain/ReportComposer.swift` (one new function)
- `HugoTests/Features/Reports/Domain/ReportedTextTests.swift` (create)
- `Hugo/Features/ServiceYear/Views/MonthReportDragSource.swift` (create)
- `Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift` (one modifier)

**Out of scope**: `SubmittedReport` and every schema file (no new stored data), `SubmitReportView`, the message the app sends, the year totals card, `MonthDetailView`.

## Git workflow

- Work on `main`. Commit per step with the messages given. Do not push.

## Steps

### Step 1: The reported text, with tests

In `ReportComposer.swift`, inside `enum ReportComposer`, after `message(...)`, add:

```swift
    /// The numbers of a submitted report as plain text, for dragging a month
    /// into another app: the month, one line per reporting line (Field Service
    /// first), school credit as one line when there is any, and Bible studies.
    /// Rebuilt from what was sent, never from the month's entries. Nil for a
    /// placeholder report. Labels and unit use `locale`'s language, as in
    /// `message(...)`.
    static func reportedText(
        for report: SubmittedReport, month: YearMonth, locale: Locale = .current, calendar: Calendar = .current
    ) -> String? {
        guard report.isSubmitted else { return nil }
        let hoursUnit = String(localized: LocalizedStringResource("report.hours.unit", locale: locale))
        let fieldService = String(localized: LocalizedStringResource("report.compose.field-service", locale: locale))
        var lines = [month.monthYearString(locale: locale, calendar: calendar).capitalized(with: locale)]

        if report.reportingLines.isEmpty {
            lines.append("\(fieldService): \(report.submittedHours ?? 0) \(hoursUnit)")
        } else {
            let ordered =
                report.reportingLines.filter { $0.type == .main }
                + report.reportingLines.filter { $0.type != .main }
            for line in ordered {
                let label = line.type == .main ? fieldService : line.typeName
                lines.append("\(label): \(line.submittedHours) \(hoursUnit)")
            }
        }

        let schoolCredit = report.schoolCreditHours ?? 0
        if schoolCredit > 0 {
            let label = String(localized: LocalizedStringResource("school.unknown.name", locale: locale))
            lines.append("\(label): \(schoolCredit) \(hoursUnit)")
        }

        let studies = String(localized: LocalizedStringResource("report.compose.bible-studies", locale: locale))
        lines.append("\(studies): \(report.totalBibleStudies ?? 0)")
        return lines.joined(separator: "\n")
    }
```

If this does not compile because `SubmittedReport` is main-actor isolated in a
`nonisolated` enum, mark only this function `@MainActor` and note it.

Create `HugoTests/Features/Reports/Domain/ReportedTextTests.swift` (`@MainActor
struct ReportedTextTests`, `import Foundation`, `import Testing`,
`@testable import Hugo`), with a fixed UTC Gregorian calendar,
`Locale(identifier: "en_US")`, `month = YearMonth(year: 2026, month: 11)` and a
sent date `Date(timeIntervalSince1970: 1_796_000_000)`:

Build each reporting line as
`SubmittedReport.SubmittedReportingLine(typeRaw: TrackerType.main.rawValue, typeName: "", durationInSeconds: 0, submittedHours: 52)`
(all parameters are optional; `typeRaw` is `TrackerType.main.rawValue` or
`TrackerType.separate.rawValue`, `typeName` is the Credit category's name, `""`
for main). Pass the lines to `SubmittedReport(year: 2026, month: 11, firstSubmittedAt: sent, submittedAt: sent, totalBibleStudies: 4, reportingLines: lines)`.

1. `listsSentLinesWithFieldServiceFirst`: reporting lines `[separate "LDC" 5 h, main 52 h]`, `totalBibleStudies: 4`, `submittedAt` and `firstSubmittedAt` set → exactly `"November 2026\nField Service: 52 h\nLDC: 5 h\nBible studies: 4"`.
2. `addsSchoolCreditAsOneLine`: main 40 h, `schoolCreditHours = 30`, studies 0 → `"November 2026\nField Service: 40 h\nSchool credit: 30 h\nBible studies: 0"`.
3. `olderReportWithoutLinesUsesTheTotal`: no reporting lines, `submittedHours: 38`, studies 2 → `"November 2026\nField Service: 38 h\nBible studies: 2"`.
4. `placeholderReportHasNoText`: `SubmittedReport(year: 2026, month: 11)` (dates default to `.distantPast`) → `nil`.

Set `schoolCreditHours` after init (`report.schoolCreditHours = 30`), since the
initializer has no parameter for it.

**Verify**: lint both files; `Scripts/verify.sh` → `VERIFY_EXIT=0`, 4 more tests
than before. Commit `feat(reports): build a submitted report's numbers as text`.

### Step 2: The drag source

Create `Hugo/Features/ServiceYear/Views/MonthReportDragSource.swift`:

```swift
import SwiftUI

extension View {
    /// Lets a submitted month be dragged into another app, which receives the
    /// numbers that were sent (see `ReportComposer.reportedText`). Does nothing
    /// for a month that is not submitted. Put it on the card inside a
    /// `NavigationLink`'s label, never around the link, so a month becoming
    /// submitted does not change the link's identity.
    func monthReportDragSource(_ month: ServiceMonth) -> some View {
        modifier(MonthReportDragSource(month: month))
    }
}

private struct MonthReportDragSource: ViewModifier {
    let month: ServiceMonth

    private var text: String? {
        guard month.isSubmitted, let report = month.submittedReport else { return nil }
        return ReportComposer.reportedText(for: report, month: month.id)
    }

    func body(content: Content) -> some View {
        if let text {
            content.draggable(text) {
                Label(month.displayName, systemImage: "doc.text")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, HugoLayout.Spacing.regular)
                    .padding(.vertical, HugoLayout.Spacing.compact)
                    .background(.regularMaterial, in: .capsule)
            }
        } else {
            content
        }
    }
}
```

In `ServiceYearMonthRow.swift`, add `.monthReportDragSource(month)` on `card`
inside the `NavigationLink`'s `label:` closure, directly after `card` and before
`.matchedTransitionSource(...)`. Do not put it on the `NavigationLink` itself,
and do not add it to the future-month branch. The label becomes:

```swift
} label: {
    card
        .monthReportDragSource(month)
        .matchedTransitionSource(id: month.id, in: transition) { source in
            source.clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
        }
}
```

The `NavigationLink`, its modifiers (`.buttonStyle(.card)`, the context menu and
the hover lines) and the `Group` stay exactly as they are.

**Verify**: lint both files; `Scripts/verify.sh` → `VERIFY_EXIT=0`, same count as
after Step 1. Commit `feat(service-year): drag a submitted month's report into other apps`.

## Test plan

- `ReportedTextTests` (4). The drag itself is checked by the owner.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, 4 more tests than before this plan
- [ ] Only the four in-scope files changed
- [ ] `plans/README.md` row updated

Owner check on the iPad (Sean), English and Danish:

1. Open Notes next to Hugo (split or Slide Over). On the Service Year tab, press and drag a submitted month's card into a note: the text above appears, with the numbers that were sent.
2. Do the same with a month that has an unreported change: the dropped numbers are the sent ones, not the current entries.
3. A month that is not submitted (or the current month) cannot be dragged; long press still shows Add Entry and Submit.
4. Tapping a card still opens the month with the zoom; scrolling the page by dragging over cards still scrolls; long press still shows the context menu.
5. Drag into Mail and Messages as well.
6. Open a month that is not submitted, then submit it from the detail page (Submit Report, as far as the sheet lets you finish). When the sheet closes, the month's detail page is still open and has not popped back to the list.

Owner check on the iPhone (Mona): tapping, scrolling and long press on month cards work as before.

## STOP conditions

Stop and report if:

- The drift check shows unexpected changes.
- Adding `.draggable` stops the card's tap, scroll or context menu from working in a way visible in the build (for example the `NavigationLink` no longer navigates in a preview), or the build reports an ambiguity between `.contextMenu` and `.draggable`.
- `SubmittedReport` has gained or lost any of the fields listed in Current state.
- Submitting from an open month's detail page (owner check 6) pops the detail page. Report it; do not move the drag source around the `NavigationLink`.

## Maintenance notes

- Plan 169 (grid on wide screens) reuses `ServiceYearMonthRow` for every month, so the drag source added here works in the grid unchanged. A new view that shows a month and links to it should put `.monthReportDragSource(month)` on its card inside the link's label.
- If `SubmittedReport` later stores each school's credit, `reportedText` should list schools like `message(...)` does.
- If the sent message is ever stored (for example for a report history), drag that stored text instead of rebuilding it.
