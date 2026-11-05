import Foundation

/// What the monthly target starts from before extra hours are added.
nonisolated enum PlannerTargetBase: String, CaseIterable, Sendable {
    /// The publisher status's monthly goal.
    case monthlyGoal
    /// What is left of the yearly goal, shared evenly over the months left in
    /// the theocratic year. Only statuses with a yearly goal offer it.
    case yearlyGoalShare
}

extension PlannerTargetBase {
    var label: LocalizedStringResource {
        switch self {
        case .monthlyGoal: "planner.target.base.monthlyGoal"
        case .yearlyGoalShare: "planner.target.base.yearlyGoalShare"
        }
    }
}

nonisolated enum PlannerTarget {
    /// The monthly target for `month` in seconds, or nil when it would be zero.
    /// `creditedBeforeCurrentMonth` is the credited time of the current
    /// theocratic year's months before the current month; it is read only for
    /// `.yearlyGoalShare`.
    static func seconds(
        for month: YearMonth,
        base: PlannerTargetBase,
        extraHours: Int,
        status: PublisherStatus?,
        creditedBeforeCurrentMonth: TimeInterval,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TimeInterval? {
        var baseSeconds = TimeInterval(status?.monthlyGoal ?? 0) * 3_600

        if base == .yearlyGoalShare, let status, status.yearlyGoalRule != nil {
            let currentYear = TheocraticYear.containing(now, calendar: calendar)
            if currentYear.contains(month) {
                let current = now.yearMonth(using: calendar)
                let monthsLeft = currentYear.months.filter { $0 >= current }.count
                let left = max(0, TimeInterval(status.yearlyGoal) * 3_600 - creditedBeforeCurrentMonth)
                let hours = monthsLeft > 0 ? left / TimeInterval(monthsLeft) / 3_600 : 0
                // The epsilon keeps an exact 50.0 from rounding up to 51.
                baseSeconds = max(0, (hours - 1e-9).rounded(.up)) * 3_600
            }
        }

        let total = baseSeconds + TimeInterval(max(0, extraHours)) * 3_600
        return total > 0 ? total : nil
    }

    /// Credited time of the months in `report` before `month`, with the same
    /// formula as `YearlyGoalProgress`.
    static func creditedSeconds(
        before month: YearMonth, in report: TheocraticYearReport, rule: YearlyGoalRule
    ) -> TimeInterval {
        report.months.filter { $0.id < month }.reduce(0) { total, serviceMonth in
            let contribution = serviceMonth.contribution
            return total + rule.creditedSeconds(main: contribution.main, separate: contribution.separate)
        }
    }
}
