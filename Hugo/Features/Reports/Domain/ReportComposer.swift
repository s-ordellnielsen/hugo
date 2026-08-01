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
        let rendered = template
            .replacingOccurrences(of: "{first}", with: firstName)
            .replacingOccurrences(of: "{last}", with: lastName)
            .replacingOccurrences(of: "{month}", with: month)
            .replacingOccurrences(of: "{year}", with: year)

        return rendered
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
        summary: MonthlyReportSummary,
        computation: RoundingComputation,
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
            month: summary.id.monthName(locale: locale, calendar: calendar),
            year: String(summary.id.year)
        )

        var lines: [String] = [greeting, ""]

        let mainCategories = summary.categories.filter { $0.type == .main }
        let otherCategories = summary.categories.filter { $0.type != .main }

        let fieldServiceHours = mainCategories.reduce(0) {
            $0 + (computation.categoryHours[$1.id] ?? 0)
        }
        // NOTE: labels always resolve against the development locale (en) for
        // now — see the Task 2 note in the PR. Task 6 decides the real
        // language strategy for the message body.
        let fieldServiceLabel = String(localized: "report.compose.field-service", locale: locale)
        lines.append("\(fieldServiceLabel): \(fieldServiceHours) \(hoursUnit)")

        for category in otherCategories {
            lines.append("\(category.name): \(computation.categoryHours[category.id] ?? 0) \(hoursUnit)")
        }

        let studiesLabel = String(localized: "report.compose.bible-studies", locale: locale)
        lines.append("\(studiesLabel): \(summary.totalBibleStudies)")

        return ReportMessageContent(recipient: nil, body: lines.joined(separator: "\n"))
    }
}
