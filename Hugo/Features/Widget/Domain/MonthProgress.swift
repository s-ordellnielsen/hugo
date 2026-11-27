import Foundation

/// This month's time against the Monthly goal, with the same numbers as the Overview circle.
nonisolated struct MonthProgress: Equatable, Sendable {
    let month: YearMonth
    /// The month's logged time, as `OverviewMetrics.progress * 3600`.
    let loggedSeconds: TimeInterval
    /// `OverviewMetrics.monthlyGoal`.
    let goalHours: Double
    let fill: MonthlyCircleFill
    /// Hours still needed to reach the Monthly goal, never below 0. Nil when the month has no Monthly goal.
    let leftHours: Double?
    /// Logged hours minus an even pace through the month (`OverviewMetrics.expectedProgress`). Positive is
    /// ahead. Nil when the month has no Monthly goal.
    let paceHours: Double?
    /// Days remaining in the month, counting today.
    let daysLeft: Int

    init(
        month: YearMonth, loggedSeconds: TimeInterval, goalHours: Double, fill: MonthlyCircleFill,
        leftHours: Double? = nil, paceHours: Double? = nil, daysLeft: Int = 1
    ) {
        self.month = month
        self.loggedSeconds = loggedSeconds
        self.goalHours = goalHours
        self.fill = fill
        self.leftHours = leftHours
        self.paceHours = paceHours
        self.daysLeft = daysLeft
    }

    var headline: HeadlineDuration {
        HeadlineDuration(seconds: loggedSeconds.rounded())
    }

    /// Calls the Overview's own types with the same inputs, so the numbers match the circle.
    static func make(
        entries: [Entry], plannedSeconds: TimeInterval, settings: WidgetSettings, now: Date, calendar: Calendar
    ) -> MonthProgress {
        let status = PublisherStatus.status(for: settings.publisherStatusID)
        let metrics = OverviewMetrics.make(
            entries: entries, status: status, bufferHours: settings.bufferHours, now: now, calendar: calendar)
        let loggedSeconds = metrics.progress * 3_600
        let fill = MonthlyCircleFill.make(
            monthlyGoalHours: metrics.monthlyGoal, loggedSeconds: loggedSeconds,
            plannedSeconds: plannedSeconds, hasOwnEntries: metrics.hasOwnEntries)
        let hasGoal = metrics.monthlyGoal > 0
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 0
        let day = calendar.component(.day, from: now)
        return MonthProgress(
            month: now.yearMonth(using: calendar),
            loggedSeconds: loggedSeconds,
            goalHours: metrics.monthlyGoal,
            fill: fill,
            leftHours: hasGoal ? max(metrics.monthlyGoal - metrics.progress, 0) : nil,
            paceHours: hasGoal ? metrics.progress - metrics.expectedProgress : nil,
            daysLeft: max(daysInMonth - day + 1, 1))
    }
}
