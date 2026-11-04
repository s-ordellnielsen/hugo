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
