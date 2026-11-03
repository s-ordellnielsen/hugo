import Foundation

nonisolated struct YearlyGoalProgress: Equatable, Sendable {
    let creditedSeconds: TimeInterval
    let actualSeconds: TimeInterval
    /// Seconds the user should have by now. Nil when the year has not started.
    let expectedSeconds: TimeInterval?
    let yearlyGoalSeconds: TimeInterval
    let monthlyGoalSeconds: TimeInterval
    let creditedByMonth: [YearMonth: TimeInterval]

    var showsActualTotal: Bool { abs(actualSeconds - creditedSeconds) >= 60 }

    /// Credited minus expected. Nil when there is no expectation.
    var differenceSeconds: TimeInterval? { expectedSeconds.map { creditedSeconds - $0 } }

    /// The knob position from -1 (a monthly goal behind) to 1 (a monthly goal ahead).
    var barFraction: Double? {
        guard let differenceSeconds, monthlyGoalSeconds > 0 else { return nil }
        return min(1, max(-1, differenceSeconds / monthlyGoalSeconds))
    }

    var isOnTrack: Bool { abs(differenceSeconds ?? 0) < 60 }

    static func make(
        report: TheocraticYearReport,
        rule: YearlyGoalRule,
        yearlyGoalSeconds: TimeInterval,
        pacing: YearlyGoalPacing,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> YearlyGoalProgress {
        var creditedByMonth: [YearMonth: TimeInterval] = [:]
        for month in report.months {
            let contribution = month.contribution
            creditedByMonth[month.id] = rule.creditedSeconds(
                main: contribution.main, separate: contribution.separate)
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
            creditedSeconds: creditedByMonth.values.reduce(0, +),
            actualSeconds: report.totalSeconds,
            expectedSeconds: expectedSeconds,
            yearlyGoalSeconds: yearlyGoalSeconds,
            monthlyGoalSeconds: rule.monthlyGoalSeconds,
            creditedByMonth: creditedByMonth)
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
