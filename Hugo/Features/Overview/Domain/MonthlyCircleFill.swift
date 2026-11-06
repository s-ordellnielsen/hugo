import Foundation

/// How full the Overview circle is, and what it is measured against.
nonisolated struct MonthlyCircleFill: Equatable, Sendable {
    nonisolated enum Basis: Equatable, Sendable {
        /// Logged time against the publisher status's monthly goal.
        case monthlyGoal(hours: Double)
        /// No monthly goal: logged time against all time planned this month.
        case plan(plannedSeconds: TimeInterval)
        /// No monthly goal and no plans: full once the month has an entry of its own.
        case presence
    }

    let basis: Basis
    /// Share of the circle's area to fill, from 0 to 1.
    let fraction: Double

    /// A monthly goal wins over plans. Without a goal, the month's plans set
    /// the scale. Without either, the circle is empty or full depending on
    /// `hasOwnEntries` (carried-in entries alone do not fill it).
    static func make(
        monthlyGoalHours: Double, loggedSeconds: TimeInterval, plannedSeconds: TimeInterval, hasOwnEntries: Bool
    ) -> MonthlyCircleFill {
        let logged = max(loggedSeconds, 0)
        if monthlyGoalHours > 0 {
            return MonthlyCircleFill(
                basis: .monthlyGoal(hours: monthlyGoalHours),
                fraction: min(logged / (monthlyGoalHours * 3_600), 1))
        }
        if plannedSeconds > 0 {
            return MonthlyCircleFill(
                basis: .plan(plannedSeconds: plannedSeconds), fraction: min(logged / plannedSeconds, 1))
        }
        return MonthlyCircleFill(basis: .presence, fraction: hasOwnEntries ? 1 : 0)
    }
}
