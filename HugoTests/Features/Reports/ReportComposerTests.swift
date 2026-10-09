import Foundation
import Testing

@testable import Hugo

struct ReportComposerTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let locale = Locale(identifier: "en_US_POSIX")
    private let month = YearMonth(year: 2026, month: 6)

    private func result(
        id: String,
        type: TrackerType,
        name: String,
        seconds: TimeInterval,
        rule: RoundingRule?
    ) -> ReportingLineResult {
        let line = ReportingLine(
            id: id,
            type: type,
            name: name,
            iconName: "tag.fill",
            actualSeconds: seconds,
            carriedInSeconds: 0,
            carriedInFrom: []
        )
        return ReportingLineCalculator.compute(line, rule: rule)
    }

    @Test
    func renderSubstitutesFirstAndLastNameTags() {
        #expect(
            ReportComposer.render(
                template: "Hi {first} {last}!", firstName: "John", lastName: "Smith", month: "June", year: "2026")
                == "Hi John Smith!"
        )
    }

    @Test
    func renderLeavesUnknownTagsUntouched() {
        #expect(
            ReportComposer.render(
                template: "Hi {first}, {foo}!", firstName: "John", lastName: "Smith", month: "June", year: "2026")
                == "Hi John, {foo}!"
        )
    }

    @Test
    func renderCollapsesWhitespaceLeftByEmptyNames() {
        #expect(
            ReportComposer.render(
                template: "Hi {first} {last}!", firstName: "John", lastName: "", month: "June", year: "2026")
                == "Hi John !"
        )
        #expect(
            ReportComposer.render(
                template: "{first}{last} Hi", firstName: "John", lastName: "", month: "June", year: "2026")
                == "John Hi"
        )
    }

    @Test
    func renderSubstitutesMonthAndYearTags() {
        #expect(
            ReportComposer.render(
                template: "Report for {month} {year}.",
                firstName: "",
                lastName: "",
                month: "June",
                year: "2026"
            ) == "Report for June 2026."
        )
    }

    @Test
    func renderPreservesLineBreaksAndDropsEmptyLines() {
        #expect(
            ReportComposer.render(
                template: "A\n\nB {month}",
                firstName: "",
                lastName: "",
                month: "June",
                year: "2026"
            ) == "A\nB June"
        )
    }

    @Test
    func messageUsesOrderedReportingLineResultsAndBibleStudies() {
        let results = [
            result(id: "", type: .main, name: "", seconds: 19_800, rule: .up),
            result(id: "LDC", type: .separate, name: "LDC", seconds: 0, rule: nil),
        ]

        let content = ReportComposer.message(
            month: month,
            results: results,
            bibleStudies: 3,
            template: "Hi {first}!",
            firstName: "John",
            lastName: "Smith",
            locale: locale,
            calendar: calendar
        )

        let hoursUnit = String(localized: "report.hours.unit", locale: locale)
        let fieldServiceLabel = String(localized: "report.compose.field-service", locale: locale)
        let studiesLabel = String(localized: "report.compose.bible-studies", locale: locale)

        #expect(
            content.body.components(separatedBy: "\n") == [
                "Hi John!",
                "",
                "\(fieldServiceLabel): 6 \(hoursUnit)",
                "LDC: 0 \(hoursUnit)",
                "\(studiesLabel): 3",
            ])
    }

    @Test
    func messageRendersMonthAndYearTagsInlineInTheGreeting() {
        let content = ReportComposer.message(
            month: month,
            results: [result(id: "", type: .main, name: "", seconds: 19_200, rule: .down)],
            bibleStudies: 2,
            template: "Hi {first}!\nReport for {month} {year}.",
            firstName: "Jens",
            lastName: "",
            locale: locale,
            calendar: calendar
        )

        let lines = content.body.components(separatedBy: "\n")
        let hoursUnit = String(localized: "report.hours.unit", locale: locale)
        let fieldServiceLabel = String(localized: "report.compose.field-service", locale: locale)

        #expect(lines[0] == "Hi Jens!")
        #expect(lines[1] == "Report for June 2026.")
        #expect(lines[2] == "")
        #expect(lines[3] == "\(fieldServiceLabel): 5 \(hoursUnit)")
    }
}
