import Foundation

/// How the current month's logged time compares with the time planned up to now.
nonisolated struct PlanPace: Equatable, Sendable {
    /// Planned time on days before today, plus today's planned time as far as
    /// it has been logged. A planned day never counts against the user until it is over.
    let expectedSeconds: TimeInterval
    let loggedSeconds: TimeInterval

    /// Positive when ahead of the plan.
    var differenceSeconds: TimeInterval { loggedSeconds - expectedSeconds }

    /// Nil when the month has no plans.
    static func make(month: PlannerMonth) -> PlanPace? {
        guard month.hasPlans else { return nil }
        let expected = month.days.reduce(0) { total, day in
            if day.id < month.today { return total + day.planned.total }
            if day.id == month.today { return total + min(day.planned.total, day.logged.total) }
            return total
        }
        return PlanPace(expectedSeconds: expected, loggedSeconds: month.logged.total)
    }
}
