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
}
