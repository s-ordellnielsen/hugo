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
        let submissionsByMonth = canonicalSubmissionsByMonth(submissions)
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

    private static func contribution(
        for month: TheocraticYearMonth
    ) -> (total: TimeInterval, main: TimeInterval, separate: TimeInterval, bibleStudies: Int) {
        if let submission = month.submittedReport, isRealSubmission(submission) {
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

    static func canonicalSubmission(
        for month: YearMonth,
        in submissions: [SubmittedReport]
    ) -> SubmittedReport? {
        canonicalSubmissionsByMonth(submissions)[month]
    }

    static func canonicalSubmissionsByMonth(
        _ submissions: [SubmittedReport]
    ) -> [YearMonth: SubmittedReport] {
        submissions.reduce(into: [YearMonth: SubmittedReport]()) { result, candidate in
            guard let month = validYearMonth(for: candidate) else {
                // Ignore incomplete or invalid V10 records rather than indexing
                // them under YearMonth(year: 0, month: 0).
                return
            }

            guard let existing = result[month] else {
                result[month] = candidate
                return
            }

            if shouldPrefer(candidate, over: existing) {
                result[month] = candidate
            }
        }
    }

    private static func validYearMonth(
        for submission: SubmittedReport
    ) -> YearMonth? {
        guard
            let year = submission.year,
            let month = submission.month,
            year > 0,
            (1...12).contains(month)
        else {
            return nil
        }

        return YearMonth(year: year, month: month)
    }

    private static func shouldPrefer(
        _ candidate: SubmittedReport,
        over existing: SubmittedReport
    ) -> Bool {
        let candidateIsReal = isRealSubmission(candidate)
        let existingIsReal = isRealSubmission(existing)

        // A real submission always wins over a migration sentinel.
        if candidateIsReal != existingIsReal {
            return candidateIsReal
        }

        if candidateIsReal {
            // Among real submissions, retain the most recent submission.
            let candidateDate = candidate.submittedAt ?? .distantPast
            let existingDate = existing.submittedAt ?? .distantPast

            if candidateDate != existingDate {
                return candidateDate > existingDate
            }
        }

        // Among sentinels, retain the one that covers the most recently created
        // pre-existing entry.
        let candidateClosedAt = candidate.entriesClosedAt ?? .distantPast
        let existingClosedAt = existing.entriesClosedAt ?? .distantPast

        if candidateClosedAt != existingClosedAt {
            return candidateClosedAt > existingClosedAt
        }

        // Equal records are semantically equivalent for this purpose.
        return false
    }

    private static func isRealSubmission(
        _ submission: SubmittedReport
    ) -> Bool {
        (submission.submittedAt ?? .distantPast) != .distantPast
    }
}
