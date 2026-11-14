import Foundation

/// How the current month's logged time compares with the time planned up to now.
nonisolated struct PlanPace: Equatable, Sendable {
    /// Planned time on days before today, plus today's planned time as far as
    /// it has been logged. A planned day never counts against the user until it is over.
    let expectedSeconds: TimeInterval
    let loggedSeconds: TimeInterval
    /// All time planned in the month, past and future days. Zero when unknown.
    var plannedSeconds: TimeInterval = 0

    /// Positive when ahead of the plan.
    var differenceSeconds: TimeInterval { loggedSeconds - expectedSeconds }

    /// The bar's full length: the month's plan, or the time expected so far
    /// if that is larger (which only happens when `plannedSeconds` is unknown).
    private var barScale: TimeInterval { max(plannedSeconds, expectedSeconds, 1) }

    /// Logged time as a fraction of the month's plan, capped at 1.
    var loggedFraction: Double { min(loggedSeconds / barScale, 1) }

    /// Time planned until today as a fraction of the month's plan.
    var expectedFraction: Double { min(expectedSeconds / barScale, 1) }

    /// Nil when the month has no plans.
    static func make(month: PlannerMonth) -> PlanPace? {
        guard month.hasPlans else { return nil }
        let expected = month.days.reduce(0) { total, day in
            if day.id < month.today { return total + day.planned.total }
            if day.id == month.today { return total + min(day.planned.total, day.logged.total) }
            return total
        }
        return PlanPace(
            expectedSeconds: expected, loggedSeconds: month.logged.total, plannedSeconds: month.planned.total)
    }
}
