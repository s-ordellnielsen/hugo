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

    private func category(
        _ id: String,
        name: String,
        type: TrackerType? = .main,
        seconds: TimeInterval
    ) -> MonthlyCategorySummary {
        MonthlyCategorySummary(
            id: id,
            name: name,
            iconName: "tag.fill",
            type: type,
            duration: seconds
        )
    }

    private func summary(
        categories: [MonthlyCategorySummary],
        bibleStudies: Int = 0,
        month: YearMonth = YearMonth(year: 2026, month: 6)
    ) -> MonthlyReportSummary {
        MonthlyReportSummary(
            id: month,
            displayName: month.monthYearString(locale: locale, calendar: calendar),
            totalSeconds: categories.reduce(0) { $0 + $1.duration },
            totalBibleStudies: bibleStudies,
            mainDuration: categories.filter { $0.type == .main }.reduce(0) { $0 + $1.duration },
            separateDuration: categories.filter { $0.type == .separate }.reduce(0) { $0 + $1.duration },
            categories: categories,
            entries: []
        )
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
        #expect(
            ReportComposer.render(
                template: "Hi {first} {last}!", firstName: "", lastName: "", month: "June", year: "2026")
                == "Hi !"
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
    func messageContainsGreetingMonthHoursAndBibleStudies() {
        let categories = [
            category("field", name: "Field Service", type: .main, seconds: 19_200),
            category("ldc", name: "LDC", type: .separate, seconds: 1_800),
        ]
        let summary = summary(categories: categories, bibleStudies: 3)
        let computation = ReportRoundingCalculator.compute(
            summary: summary,
            carriedIn: 0,
            rule: .up
        )

        let content = ReportComposer.message(
            summary: summary,
            computation: computation,
            template: "Hi {first}!",
            firstName: "John",
            lastName: "Smith",
            locale: locale,
            calendar: calendar
        )

        let lines = content.body.components(separatedBy: "\n")

        let hoursUnit = String(localized: "report.hours.unit", locale: locale)
        let fieldServiceLabel = String(localized: "report.compose.field-service", locale: locale)
        let studiesLabel = String(localized: "report.compose.bible-studies", locale: locale)

        // Field Service 5h20m + LDC 0h30m = 5h50m → ceil 6h; the extra hour
        // lands on LDC (largest remainder, 30m), Field Service keeps 5h.
        #expect(
            lines == [
                "Hi John!",
                "",
                "\(fieldServiceLabel): 5 \(hoursUnit)",
                "LDC: 1 \(hoursUnit)",
                "\(studiesLabel): 3",
            ])
        #expect(computation.submittedHours == 6)
    }

    @Test
    func messageRendersMonthAndYearTagsInlineInTheGreeting() {
        let categories = [
            category("field", name: "Field Service", type: .main, seconds: 19_200),
            category("ldc", name: "LDC", type: .separate, seconds: 1_800),
        ]
        let summary = summary(categories: categories, bibleStudies: 3)
        let computation = ReportRoundingCalculator.compute(
            summary: summary,
            carriedIn: 0,
            rule: .up
        )

        let content = ReportComposer.message(
            summary: summary,
            computation: computation,
            template: "Hi {first}!\nReport for {month} {year}.",
            firstName: "John",
            lastName: "Smith",
            locale: locale,
            calendar: calendar
        )

        let lines = content.body.components(separatedBy: "\n")

        let hoursUnit = String(localized: "report.hours.unit", locale: locale)
        let fieldServiceLabel = String(localized: "report.compose.field-service", locale: locale)

        #expect(lines[0] == "Hi John!")
        #expect(lines[1] == "Report for June 2026.")
        #expect(lines[2] == "")
        #expect(lines[3] == "\(fieldServiceLabel): 5 \(hoursUnit)")
    }

    @Test
    func messageSumsAllMainCategoriesIntoTheFieldServiceLine() {
        let categories = [
            category("field", name: "Field Service", type: .main, seconds: 7_200),
            category("rural", name: "Rural", type: .main, seconds: 3_600),
            category("ldc", name: "LDC", type: .separate, seconds: 1_800),
        ]
        let summary = summary(categories: categories)
        let computation = ReportRoundingCalculator.compute(
            summary: summary,
            carriedIn: 0,
            rule: .down
        )

        let content = ReportComposer.message(
            summary: summary,
            computation: computation,
            template: "Hi {first}!",
            firstName: "John",
            lastName: "",
            locale: locale,
            calendar: calendar
        )

        let lines = content.body.components(separatedBy: "\n")

        let hoursUnit = String(localized: "report.hours.unit", locale: locale)
        let fieldServiceLabel = String(localized: "report.compose.field-service", locale: locale)
        let studiesLabel = String(localized: "report.compose.bible-studies", locale: locale)

        #expect(lines.contains("\(fieldServiceLabel): 3 \(hoursUnit)"))
        #expect(lines.contains("LDC: 0 \(hoursUnit)"))
        #expect(lines.contains("\(studiesLabel): 0"))
        #expect(!lines.contains("Rural: 1 h"))
    }

    @Test
    func localeDrivesTheMonthNameWhileLabelsFollowTheDevelopmentLanguage() {
        // FLAGGED for Task 6: the month name honors the supplied locale, but
        // the labels currently resolve to the development language (en) even
        // for a Danish locale. The greeting always carries the language.
        let danish = Locale(identifier: "da_DK")
        let summary = summary(
            categories: [category("field", name: "Field Service", type: .main, seconds: 19_200)],
            bibleStudies: 2
        )
        let computation = ReportRoundingCalculator.compute(
            summary: summary,
            carriedIn: 0,
            rule: .down
        )

        let content = ReportComposer.message(
            summary: summary,
            computation: computation,
            template: "Hej {first}! {month}",
            firstName: "Jens",
            lastName: "",
            locale: danish,
            calendar: calendar
        )

        let lines = content.body.components(separatedBy: "\n")

        let hoursUnit = String(localized: "report.hours.unit", locale: locale)
        let fieldServiceLabel = String(localized: "report.compose.field-service", locale: locale)
        let studiesLabel = String(localized: "report.compose.bible-studies", locale: locale)

        #expect(lines[0] == "Hej Jens! juni")
        #expect(lines[2] == "\(fieldServiceLabel): 5 \(hoursUnit)")
        #expect(lines[3] == "\(studiesLabel): 2")
    }
}
