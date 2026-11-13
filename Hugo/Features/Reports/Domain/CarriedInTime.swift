import Foundation

/// The time a month holds in carried-in entries: minutes transferred from
/// earlier months' reports. Nil when the month has none.
nonisolated struct CarriedInTime: Equatable, Sendable {
    let seconds: TimeInterval
    /// The months whose reports transferred the time, oldest first.
    let sourceMonths: [YearMonth]

    init?(entries: [Entry]) {
        var seconds: TimeInterval = 0
        var months: Set<YearMonth> = []
        for entry in entries where entry.isCarriedIn && entry.duration > 0 {
            seconds += entry.duration
            if let year = entry.sourceReportYear, let month = entry.sourceReportMonth {
                months.insert(YearMonth(year: year, month: month))
            }
        }
        guard seconds > 0 else { return nil }
        self.seconds = seconds
        self.sourceMonths = months.sorted()
    }

    /// "30 minutes transferred from October" (Danish "30 minutter overført
    /// fra oktober"), the same words the Submit Report screen uses.
    func label(locale: Locale = .current, calendar: Calendar = .current) -> LocalizedStringResource {
        let duration = ServiceDurationFormatter.accessibilityString(from: seconds, locale: locale)
        let months = sourceMonths.map { $0.monthName(locale: locale, calendar: calendar) }
            .joined(separator: ", ")
        return LocalizedStringResource("report.line.carried-in.\(duration).\(months)")
    }
}
