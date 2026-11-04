import Foundation

nonisolated struct YearlyGoalProgress: Equatable, Sendable {
    let creditedSeconds: TimeInterval
    /// The year total: reported hours of submitted months plus logged time of the rest.
    let yearTotalSeconds: TimeInterval
    /// Seconds the user should have by now. Nil when the year has not started.
    let expectedSeconds: TimeInterval?
    let yearlyGoalSeconds: TimeInterval
    let monthlyGoalSeconds: TimeInterval
    let months: [Month]

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

    /// The knob position from -1 (a monthly goal behind) to 1 (a monthly goal ahead).
    var barFraction: Double? {
        guard let differenceSeconds, monthlyGoalSeconds > 0 else { return nil }
        return min(1, max(-1, differenceSeconds / monthlyGoalSeconds))
    }

    var isOnTrack: Bool { abs(differenceSeconds ?? 0) < Self.differenceThreshold }

    /// Nil when the status has no yearly goal.
    static func make(
        report: TheocraticYearReport,
        status: PublisherStatus,
        pacing: YearlyGoalPacing,
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
                creditedSeconds: rule.creditedSeconds(main: contribution.main, separate: contribution.separate),
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
                switch pacing {
                case .proRated:
                    let day = calendar.component(.day, from: now)
                    let lastDay = current.lastDay(calendar: calendar)
                    return total + rule.monthlyGoalSeconds * TimeInterval(day) / TimeInterval(lastDay)
                case .completedMonths:
                    return total
                case .includeCurrentMonth:
                    return total + rule.monthlyGoalSeconds
                }
            }
        }

        return YearlyGoalProgress(
            creditedSeconds: months.reduce(0) { $0 + $1.creditedSeconds },
            yearTotalSeconds: report.totalSeconds,
            expectedSeconds: expectedSeconds,
            yearlyGoalSeconds: TimeInterval(status.yearlyGoal) * 3_600,
            monthlyGoalSeconds: rule.monthlyGoalSeconds,
            months: months)
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
