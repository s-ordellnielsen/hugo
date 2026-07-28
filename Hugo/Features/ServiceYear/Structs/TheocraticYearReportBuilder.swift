import Foundation

@MainActor
enum TheocraticYearReportBuilder {
    static func report(
        for year: TheocraticYear,
        entries: [Entry],
        submissions: [SubmittedReport] = [],
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> TheocraticYearReport {
        let yearEntries = entries.filter { year.contains($0.date.yearMonth(using: calendar)) }
        let summaries = MonthlyReportBuilder.summaries(from: yearEntries, calendar: calendar, locale: locale)
        let summariesByMonth = Dictionary(uniqueKeysWithValues: summaries.map { ($0.id, $0) })
        let submissionsByMonth = Dictionary(uniqueKeysWithValues: submissions.map { ($0.yearMonth, $0) })
        let currentMonth = now.yearMonth(using: calendar)
        let months = year.months.map { month in
            let summary = summariesByMonth[month]
            let submission = submissionsByMonth[month]
            return TheocraticYearMonth(
                id: month,
                displayName: summary?.displayName ?? month.monthYearString(locale: locale, calendar: calendar),
                summary: summary,
                isFuture: month > currentMonth,
                submittedReport: submission,
                hasUnreportedEntries: ReportReminderSchedule.hasUnreportedEntries(
                    report: submission,
                    entries: summary?.entries ?? [],
                    month: month,
                    calendar: calendar
                )
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
