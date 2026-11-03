import Foundation

/// How much of one month's time counts toward a yearly goal.
nonisolated struct YearlyGoalRule: Equatable, Sendable {
    let monthlyGoalSeconds: TimeInterval
    /// Separate-category time that may count on top of the monthly goal.
    let separateAllowanceSeconds: TimeInterval

    /// All main time counts. Separate time counts only up to
    /// `monthlyGoalSeconds + separateAllowanceSeconds` in total.
    func creditedSeconds(main: TimeInterval, separate: TimeInterval) -> TimeInterval {
        let room = max(0, monthlyGoalSeconds + separateAllowanceSeconds - main)
        return main + min(separate, room)
    }
}
