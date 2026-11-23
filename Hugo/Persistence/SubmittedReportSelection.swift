import Foundation

/// Decides which stored report counts for a month. Sync duplicates and upgrade
/// placeholders can leave several rows for one month, and every device and
/// every screen must pick the same one.
nonisolated enum SubmittedReportSelection {
    static func canonical(for month: YearMonth, in submissions: [SubmittedReport]) -> SubmittedReport? {
        canonicalByMonth(submissions)[month]
    }

    static func canonicalByMonth(
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
        let candidateIsSubmitted = candidate.isSubmitted
        let existingIsSubmitted = existing.isSubmitted

        // A submitted report always wins over a placeholder report.
        if candidateIsSubmitted != existingIsSubmitted {
            return candidateIsSubmitted
        }

        if let candidateDate = candidate.submittedDate,
            let existingDate = existing.submittedDate,
            candidateDate != existingDate
        {
            // Among submitted reports, retain the most recent submission.
            return candidateDate > existingDate
        }

        // Among placeholders, retain the one that covers the most recently
        // created pre-existing entry.
        if candidate.entriesCutoff != existing.entriesCutoff {
            return candidate.entriesCutoff > existing.entriesCutoff
        }

        // Equal records are semantically equivalent for this purpose.
        return false
    }
}
