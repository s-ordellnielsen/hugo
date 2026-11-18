import Foundation

nonisolated struct YearlyGoalProgress: Equatable, Sendable {
    let creditedSeconds: TimeInterval
    /// The year total: reported hours of submitted months plus logged time of the rest.
    let yearTotalSeconds: TimeInterval
    /// Seconds the user should have by now: the monthly goal for each month that is over, plus the current month's goal spread by day. Nil when the year has not started.
    let expectedSeconds: TimeInterval?
    let yearlyGoalSeconds: TimeInterval
    let monthlyGoalSeconds: TimeInterval
    let months: [Month]
    /// The end of the goal bar: the monthly goal times the months of the
    /// theocratic year up to and including the current month. The whole
    /// yearly goal once the year is over. Nil before the year starts.
    let scaleEndSeconds: TimeInterval?
    /// The last month the scale covers: the current month, or August once
    /// the year is over. Nil before the year starts.
    let scaleEndMonth: YearMonth?
    /// True once the year's last month is over.
    let isYearOver: Bool

    /// One month on the year detail screen.
    struct Month: Identifiable, Equatable, Sendable {
        let id: YearMonth
        let displayName: String
        let isFuture: Bool
        let creditedSeconds: TimeInterval
        /// What the month adds to the year total.
        let totalSeconds: TimeInterval

        var showsTotal: Bool { abs(totalSeconds - creditedSeconds) >= YearlyGoalProgress.differenceThreshold }
    }

    /// Differences smaller than a minute are shown as equal.
    static let differenceThreshold: TimeInterval = 60

    var showsYearTotal: Bool { abs(yearTotalSeconds - creditedSeconds) >= Self.differenceThreshold }

    /// Credited minus expected. Nil when there is no expectation.
    var differenceSeconds: TimeInterval? { expectedSeconds.map { creditedSeconds - $0 } }

    /// Counted time as a share of the scale, from 0 to 1. Time above the
    /// scale fills the bar. Nil before the year starts.
    var fillFraction: Double? {
        guard let scaleEndSeconds, scaleEndSeconds > 0 else { return nil }
        return min(max(creditedSeconds / scaleEndSeconds, 0), 1)
    }

    /// Where "Target today" sits on the scale, from 0 to 1. Nil before the
    /// year starts and once it is over, because a finished year has no today.
    var markerFraction: Double? {
        guard !isYearOver, let expectedSeconds, let scaleEndSeconds, scaleEndSeconds > 0 else { return nil }
        return min(max(expectedSeconds / scaleEndSeconds, 0), 1)
    }

    var isOnTrack: Bool { abs(differenceSeconds ?? 0) < Self.differenceThreshold }

    /// Nil when the status has no yearly goal.
    static func make(
        report: TheocraticYearReport,
        status: PublisherStatus,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> YearlyGoalProgress? {
        guard let rule = status.yearlyGoalRule else { return nil }
        let months = report.months.map { month in
            let contribution = month.contribution
            return Month(
                id: month.id,
                displayName: month.displayName,
                isFuture: month.isFuture,
                creditedSeconds: rule.creditedSeconds(for: contribution),
                totalSeconds: contribution.total)
        }

        let current = now.yearMonth(using: calendar)
        let expectedSeconds: TimeInterval?
        if let first = report.months.first, first.id > current {
            expectedSeconds = nil
        } else {
            expectedSeconds = report.months.reduce(0) { total, month in
                if month.id < current {
                    return total + rule.monthlyGoalSeconds
                }
                guard month.id == current else { return total }
                return total + rule.monthlyGoalSeconds * currentMonthFraction(now: now, calendar: calendar)
            }
        }

        let monthsSoFar = report.months.filter { $0.id <= current }
        let scaleEndMonth = monthsSoFar.last?.id
        let scaleEndSeconds = scaleEndMonth.map { _ in rule.monthlyGoalSeconds * Double(monthsSoFar.count) }
        let isYearOver = report.months.last.map { $0.id < current } ?? false

        return YearlyGoalProgress(
            creditedSeconds: months.reduce(0) { $0 + $1.creditedSeconds },
            yearTotalSeconds: report.totalSeconds,
            expectedSeconds: expectedSeconds,
            yearlyGoalSeconds: TimeInterval(status.yearlyGoal) * 3_600,
            monthlyGoalSeconds: rule.monthlyGoalSeconds,
            months: months,
            scaleEndSeconds: scaleEndSeconds,
            scaleEndMonth: scaleEndMonth,
            isYearOver: isYearOver)
    }

    /// How much of the current month's goal is expected by `now`: today's day
    /// number divided by the number of days in the month. Today counts as a
    /// whole day, so November 1 gives 1/30 and November 15 gives 15/30.
    static func currentMonthFraction(now: Date, calendar: Calendar) -> Double {
        let day = calendar.component(.day, from: now)
        return Double(day) / Double(now.yearMonth(using: calendar).lastDay(calendar: calendar))
    }
}

extension YearlyGoalProgress {
    /// "On pace", "1 hour, 30 minutes ahead" or "3 hours behind". Nil when there is no expectation.
    var paceSentence: String? {
        guard let differenceSeconds else { return nil }
        if isOnTrack {
            return String(
                localized: "year.header.onTrack", defaultValue: "On pace",
                comment: "Shown when the counted time matches the time expected so far.")
        }
        let amount = ServiceDurationFormatter.hoursString(from: abs(differenceSeconds))
        if differenceSeconds > 0 {
            return String(
                localized: "year.header.ahead", defaultValue: "\(amount) ahead",
                comment: "Counted time is ahead of the expected time. The argument is a duration such as 3 hours.")
        }
        return String(
            localized: "year.header.behind", defaultValue: "\(amount) behind",
            comment: "Counted time is behind the expected time. The argument is a duration such as 3 hours.")
    }
}
