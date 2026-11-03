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

    /// The month whose report reminder should show: the due month, unless it
    /// already has a real submission. A placeholder report counts as not sent.
    static func reminderMonth(
        now: Date, submissions: [SubmittedReport], calendar: Calendar = .current
    ) -> YearMonth? {
        guard let due = dueMonth(now: now, calendar: calendar) else { return nil }
        guard let submission = SubmittedReportSelection.canonical(for: due, in: submissions) else { return due }
        return SubmittedReportSelection.isReal(submission) ? nil : due
    }

    /// 7 days into the following month during which the previous month's
    /// report is still prompted; after that the reminder goes quiet until the
    /// current month itself becomes due.
    private static let previousMonthGraceDays = 7
}
