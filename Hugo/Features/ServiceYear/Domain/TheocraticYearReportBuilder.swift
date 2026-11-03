import Foundation

nonisolated enum TheocraticYearReportBuilder {
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
        let submissionsByMonth = SubmittedReportSelection.canonicalByMonth(submissions)
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

        let contributions = months.map(contribution(for:))

        return TheocraticYearReport(
            year: year,
            months: months,
            totalSeconds: contributions.reduce(0) { $0 + $1.total },
            totalBibleStudies: contributions.reduce(0) { $0 + $1.bibleStudies },
            mainDuration: contributions.reduce(0) { $0 + $1.main },
            separateDuration: contributions.reduce(0) { $0 + $1.separate }
        )
    }

    static func contribution(
        for month: TheocraticYearMonth
    ) -> (total: TimeInterval, main: TimeInterval, separate: TimeInterval, bibleStudies: Int) {
        if let submission = month.submittedReport, SubmittedReportSelection.isReal(submission) {
            let studies = submission.totalBibleStudies ?? 0

            guard !submission.reportingLines.isEmpty else {
                let main = TimeInterval(submission.submittedHours ?? 0) * 3_600
                return (main, main, 0, studies)
            }

            let main = submission.reportingLines
                .filter { $0.type == .main }
                .reduce(0) { $0 + TimeInterval($1.submittedHours) * 3_600 }
            let separate = submission.reportingLines
                .filter { $0.type == .separate }
                .reduce(0) { $0 + TimeInterval($1.submittedHours) * 3_600 }
            return (main + separate, main, separate, studies)
        }

        guard let summary = month.summary else {
            return (0, 0, 0, 0)
        }

        return (summary.totalSeconds, summary.mainDuration, summary.separateDuration, summary.totalBibleStudies)
    }
}
