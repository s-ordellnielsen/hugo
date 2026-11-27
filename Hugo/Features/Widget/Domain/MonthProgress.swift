import Foundation

/// This month's time against the Monthly goal, with the same numbers as the Overview circle.
nonisolated struct MonthProgress: Equatable, Sendable {
    let month: YearMonth
    /// The month's logged time, as `OverviewMetrics.progress * 3600`.
    let loggedSeconds: TimeInterval
    /// `OverviewMetrics.monthlyGoal`.
    let goalHours: Double
    let fill: MonthlyCircleFill

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
        return MonthProgress(
            month: now.yearMonth(using: calendar),
            loggedSeconds: loggedSeconds,
            goalHours: metrics.monthlyGoal,
            fill: fill)
    }
}
