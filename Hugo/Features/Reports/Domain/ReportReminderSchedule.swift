import Foundation

nonisolated enum ReportReminderSchedule {
    /// The month whose report is currently due.
    ///
    /// A report for month M becomes due on the last day of M. From then on the
    /// *current* month is always the one being prompted for (at most one
    /// reminder card ever exists). The previous month stays reachable for a
    /// short grace window at the start of the following month, so a report
    /// that became due yesterday is still one tap away; after the grace window
    /// the reminder goes quiet rather than nagging about a stale month for
    /// weeks.
    ///
    /// NOTE: plan 012 defines only the start of the due window ("last day of
    /// M… until a SubmittedReport exists"); the grace-window cutoff is an
    /// implementation decision flagged for review.
    static func dueMonth(now: Date, calendar: Calendar = .current) -> YearMonth? {
        let current = now.yearMonth(using: calendar)
        let today = calendar.startOfDay(for: now)
        let currentLastDay = calendar.startOfDay(
            for: current.date(day: current.lastDay(calendar: calendar), calendar: calendar)
        )

        if today >= currentLastDay { return current }

        let previous = YearMonth.previous(before: current, calendar: calendar)
        let previousLastDay = calendar.startOfDay(
            for: previous.date(day: previous.lastDay(calendar: calendar), calendar: calendar)
        )
        guard today > previousLastDay else { return nil }

        let day = calendar.component(.day, from: now)
        return day <= previousMonthGraceDays ? previous : nil
    }

    /// 7 days into the following month during which the previous month's
    /// report is still prompted; after that the reminder goes quiet until the
    /// current month itself becomes due.
    private static let previousMonthGraceDays = 7

    /// True when the month needs a (new) report: it was never submitted (no
    /// report, or a V8→V9 placeholder), an entry was created after the
    /// submission's `entriesClosedAt` cutoff, or the month's current per-line
    /// totals or Bible studies differ from what was submitted. The comparison
    /// applies only to reports whose stored lines add up to their
    /// `actualTotalSeconds`; reports migrated from V10 may not, and keep the
    /// creation-time rule alone.
    static func hasUnreportedEntries(
        report: SubmittedReport?,
        entries: [Entry],
        month: YearMonth,
        calendar: Calendar = .current
    ) -> Bool {
        guard let report, (report.submittedAt ?? .distantPast) != .distantPast else { return true }

        let monthEntries = entries.filter { $0.date.yearMonth(using: calendar) == month }
        let cutoff = report.entriesClosedAt ?? .distantPast
        if monthEntries.contains(where: { $0.createdAt > cutoff }) { return true }

        guard isComparable(report) else { return false }
        return hasChangedTotals(report: report, monthEntries: monthEntries, calendar: calendar)
    }

    private static let toleranceSeconds: TimeInterval = 1

    static func isComparable(_ report: SubmittedReport) -> Bool {
        guard !report.reportingLines.isEmpty, let actual = report.actualTotalSeconds else { return false }
        let storedTotal = report.reportingLines.reduce(0) { $0 + $1.durationInSeconds }
        return abs(storedTotal - actual) < toleranceSeconds
    }

    private static func hasChangedTotals(report: SubmittedReport, monthEntries: [Entry], calendar: Calendar) -> Bool {
        let bibleStudies = monthEntries.reduce(0) { $0 + $1.bibleStudies }
        if bibleStudies != (report.totalBibleStudies ?? 0) { return true }

        let stored = Dictionary(report.reportingLines.map { ($0.id, $0.durationInSeconds) }, uniquingKeysWith: +)
        let current = Dictionary(
            ReportingLineCalculator.lines(from: monthEntries, calendar: calendar).map { ($0.id, $0.actualSeconds) },
            uniquingKeysWith: +)
        let ids = Set(stored.keys).union(current.keys)
        return ids.contains { abs((stored[$0] ?? 0) - (current[$0] ?? 0)) >= toleranceSeconds }
    }
}
