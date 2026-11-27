import Foundation

nonisolated struct OverviewMetrics: Sendable {
    let totalHours: Double
    let monthlyGoal: Double
    let expectedProgress: Double
    /// True when the month has logged time other than carried-in entries.
    let hasOwnEntries: Bool

    var progress: Double { max(totalHours, 0) }

    /// `bufferHours` is the Buffer to add to the goal, or 0. Without a status goal it is the whole goal.
    static func make(
        entries: [Entry], status: PublisherStatus?, bufferHours: Int = 0, now: Date, calendar: Calendar
    ) -> OverviewMetrics {
        let totalHours = entries.reduce(0) { $0 + max($1.duration, 0) } / 3600
        let goal = Double((status?.monthlyGoal ?? 0) + max(0, bufferHours))
        let days = Double(calendar.range(of: .day, in: .month, for: now)?.count ?? 0)
        let day = Double(calendar.component(.day, from: now))
        let expected = days > 0 ? day / days * goal : 0
        let hasOwnEntries = entries.contains { !$0.isCarriedIn && $0.duration > 0 }
        return OverviewMetrics(
            totalHours: totalHours, monthlyGoal: goal, expectedProgress: expected, hasOwnEntries: hasOwnEntries)
    }
}
