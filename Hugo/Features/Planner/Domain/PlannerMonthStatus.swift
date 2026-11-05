import Foundation

/// The numbers in the Planner header for one month.
nonisolated struct PlannerMonthStatus: Equatable, Sendable {
    let targetSeconds: TimeInterval?
    /// Logged time; credited time when the status has a yearly goal.
    let loggedSeconds: TimeInterval
    /// Projected minus logged time, on the same basis as `loggedSeconds`.
    let stillPlannedSeconds: TimeInterval
    /// Projected time that does not count toward the yearly goal (separate
    /// time beyond the allowance). Always 0 without a yearly goal.
    let uncountedSeconds: TimeInterval
    /// Days from today (or the month's first day, for a future month) to the
    /// month's last day, including both. 0 for a past month.
    let daysLeft: Int

    /// Differences smaller than a minute are shown as equal.
    static let differenceThreshold: TimeInterval = 60

    var projectedSeconds: TimeInterval { loggedSeconds + stillPlannedSeconds }

    /// Target minus projected time. Positive when the plan falls short. Nil without a target.
    var shortfallSeconds: TimeInterval? { targetSeconds.map { $0 - projectedSeconds } }

    /// Target minus logged time, never below zero. Nil without a target.
    var leftSeconds: TimeInterval? { targetSeconds.map { max(0, $0 - loggedSeconds) } }

    /// `leftSeconds` spread evenly over `daysLeft`. Nil without a target, when
    /// nothing is left, or when no days are left.
    var perDaySeconds: TimeInterval? {
        guard let leftSeconds, leftSeconds >= Self.differenceThreshold, daysLeft > 0 else { return nil }
        return leftSeconds / TimeInterval(daysLeft)
    }

    /// With a yearly goal `rule`, logged and projected time count only their credited part.
    static func make(month: PlannerMonth, targetSeconds: TimeInterval?, rule: YearlyGoalRule?) -> PlannerMonthStatus {
        let logged: TimeInterval
        let projected: TimeInterval
        if let rule {
            logged = rule.creditedSeconds(main: month.logged.main, separate: month.logged.separate)
            projected = rule.creditedSeconds(main: month.projected.main, separate: month.projected.separate)
        } else {
            logged = month.logged.total
            projected = month.projected.total
        }
        return PlannerMonthStatus(
            targetSeconds: targetSeconds,
            loggedSeconds: logged,
            stillPlannedSeconds: max(0, projected - logged),
            uncountedSeconds: max(0, month.projected.total - projected),
            daysLeft: month.days.filter { $0.id >= month.today }.count)
    }
}

extension PlannerMonthStatus {
    nonisolated var summarySentence: String {
        guard let shortfall = shortfallSeconds else {
            return String(
                localized: "planner.header.noTarget", defaultValue: "Set a target to compare your plan with",
                comment: "Planner header when there is no monthly target.")
        }
        let amount = ServiceDurationFormatter.hoursString(from: abs(shortfall))
        if shortfall >= Self.differenceThreshold {
            return String(
                localized: "planner.header.short", defaultValue: "Plan \(amount) more to reach your target",
                comment: "The plan falls short of the monthly target. The argument is a duration such as 4 hours.")
        }
        if shortfall <= -Self.differenceThreshold {
            return String(
                localized: "planner.header.over", defaultValue: "Your plan is \(amount) over your target",
                comment: "The plan goes past the monthly target. The argument is a duration such as 3 hours.")
        }
        return String(
            localized: "planner.header.reached", defaultValue: "Your plan reaches your target",
            comment: "The plan meets the monthly target.")
    }

    /// "16 hours left · about 1 hour, 10 minutes a day", or nil.
    nonisolated var perDaySentence: String? {
        guard let leftSeconds, let perDaySeconds else { return nil }
        let left = ServiceDurationFormatter.hoursString(from: leftSeconds)
        let perDay = ServiceDurationFormatter.hoursString(from: perDaySeconds)
        return String(
            localized: "planner.header.perDay", defaultValue: "\(left) left · about \(perDay) a day",
            comment:
                "Time still needed this month and that time spread over the days left. Both arguments are durations.")
    }

    /// Nil unless some planned or logged time will not count toward the yearly goal.
    nonisolated var uncountedSentence: String? {
        guard uncountedSeconds >= Self.differenceThreshold else { return nil }
        let amount = ServiceDurationFormatter.hoursString(from: uncountedSeconds)
        return String(
            localized: "planner.header.uncounted",
            defaultValue: "\(amount) in other categories won't count toward your goal",
            comment: "Separate-category time beyond the allowance. The argument is a duration.")
    }
}
