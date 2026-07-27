import Foundation

@MainActor
enum TheocraticYearReportBuilder {
    static func report(
        for year: TheocraticYear,
        entries: [Entry],
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> TheocraticYearReport {
        let yearEntries = entries.filter { year.contains($0.date.yearMonth(using: calendar)) }
        let summaries = MonthlyReportBuilder.summaries(from: yearEntries, calendar: calendar, locale: locale)
        let summariesByMonth = Dictionary(uniqueKeysWithValues: summaries.map { ($0.id, $0) })
        let currentMonth = now.yearMonth(using: calendar)
        let months = year.months.map { month in
            let summary = summariesByMonth[month]
            return TheocraticYearMonth(
                id: month,
                displayName: summary?.displayName ?? month.monthYearString(locale: locale, calendar: calendar),
                summary: summary,
                isFuture: month > currentMonth
            )
        }

        return TheocraticYearReport(
            year: year,
            months: months,
            totalSeconds: summaries.reduce(0) { $0 + $1.totalSeconds },
            totalBibleStudies: summaries.reduce(0) { $0 + $1.totalBibleStudies },
            mainDuration: summaries.reduce(0) { $0 + $1.mainDuration },
            separateDuration: summaries.reduce(0) { $0 + $1.separateDuration }
        )
    }
}
