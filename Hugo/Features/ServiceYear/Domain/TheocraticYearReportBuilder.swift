import Foundation

nonisolated enum TheocraticYearReportBuilder {
    static func report(
        for year: TheocraticYear,
        entries: [Entry],
        submissions: [SubmittedReport] = [],
        trackers: [Tracker] = [],
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> TheocraticYearReport {
        let yearEntries = entries.filter { year.contains($0.date.yearMonth(using: calendar)) }
        let months = year.months.map { month in
            ServiceMonth.make(
                month, entries: yearEntries, submissions: submissions, trackers: trackers, now: now,
                calendar: calendar, locale: locale)
        }
        let contributions = months.map(\.contribution)

        return TheocraticYearReport(
            year: year,
            months: months,
            totalSeconds: contributions.reduce(0) { $0 + $1.total },
            totalBibleStudies: contributions.reduce(0) { $0 + $1.bibleStudies },
            mainDuration: contributions.reduce(0) { $0 + $1.main },
            separateDuration: contributions.reduce(0) { $0 + $1.separate }
        )
    }
}
