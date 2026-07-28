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

    /// Days into month M+1 during which month M's report is still prompted.
    /// At 30 days the previous month stays reachable for essentially the whole
    /// following month — it is only superseded once the current month itself
    /// becomes due on its own last day.
    private static let previousMonthGraceDays = 30

    /// True when the month has never been submitted (no report, or a sentinel
    /// report left by the V8→V9 backfill), or when entries exist that were
    /// created after the submission's `entriesClosedAt` cutoff.
    static func hasUnreportedEntries(
        report: SubmittedReport?,
        entries: [Entry],
        month: YearMonth,
        calendar: Calendar = .current
    ) -> Bool {
        guard let report, report.submittedAt != .distantPast else { return true }

        return entries.contains {
            $0.date.yearMonth(using: calendar) == month && $0.createdAt > report.entriesClosedAt
        }
    }
}
