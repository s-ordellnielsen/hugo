import Foundation

nonisolated struct ReportMessageContent {
    let recipient: String?
    let body: String
}

nonisolated enum ReportComposer {
    /// Renders the greeting template. Supported tags: `{first}`, `{last}`,
    /// `{month}`, `{year}`. Unknown tags are left untouched; empty names
    /// never leave double whitespace behind. Intentional line breaks are
    /// preserved; empty lines are dropped.
    static func render(template: String, firstName: String, lastName: String, month: String, year: String) -> String {
        let rendered =
            template
            .replacingOccurrences(of: "{first}", with: firstName)
            .replacingOccurrences(of: "{last}", with: lastName)
            .replacingOccurrences(of: "{month}", with: month)
            .replacingOccurrences(of: "{year}", with: year)

        return
            rendered
            .components(separatedBy: .newlines)
            .map { line in
                line.components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

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
}
