import Foundation

nonisolated struct ReportMessageContent {
    let recipient: String?
    let body: String
}

nonisolated enum ReportComposer {
    /// Renders the greeting template. Supported tags: `{first}`, `{last}`.
    /// Unknown tags are left untouched; empty names never leave double
    /// whitespace behind.
    static func render(template: String, firstName: String, lastName: String) -> String {
        let rendered = template
            .replacingOccurrences(of: "{first}", with: firstName)
            .replacingOccurrences(of: "{last}", with: lastName)

        return rendered
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
        let hoursUnit = String(localized: "report.hours.unit")
        let greeting = render(template: template, firstName: firstName, lastName: lastName)
        let month = summary.id.monthYearString(locale: locale, calendar: calendar)

        var lines: [String] = [greeting, "", month]

        let mainCategories = summary.categories.filter { $0.type == .main }
        let otherCategories = summary.categories.filter { $0.type != .main }

        let fieldServiceHours = mainCategories.reduce(0) {
            $0 + (computation.categoryHours[$1.id] ?? 0)
        }
        // NOTE: labels always resolve against the development locale (en) for
        // now — see the Task 2 note in the PR. Task 6 decides the real
        // language strategy for the message body.
        let fieldServiceLabel = String(localized: "report.compose.field-service")
        lines.append("\(fieldServiceLabel): \(fieldServiceHours) \(hoursUnit)")

        for category in otherCategories {
            lines.append("\(category.name): \(computation.categoryHours[category.id] ?? 0) \(hoursUnit)")
        }

        let studiesLabel = String(localized: "report.compose.bible-studies")
        lines.append("\(studiesLabel): \(summary.totalBibleStudies)")

        return ReportMessageContent(recipient: nil, body: lines.joined(separator: "\n"))
    }
}
