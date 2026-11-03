import Foundation

/// Decides which stored report counts for a month. Sync duplicates and upgrade
/// placeholders can leave several rows for one month, and every device and
/// every screen must pick the same one.
nonisolated enum SubmittedReportSelection {
    /// False for a placeholder report (`submittedAt == .distantPast`), which
    /// the V8 to V9 upgrade created for months that were never sent.
    static func isReal(_ submission: SubmittedReport) -> Bool {
        (submission.submittedAt ?? .distantPast) != .distantPast
    }

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
        let candidateIsReal = isReal(candidate)
        let existingIsReal = isReal(existing)

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
}
