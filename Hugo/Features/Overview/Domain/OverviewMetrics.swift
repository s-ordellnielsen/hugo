import Foundation

struct OverviewMetrics {
    let totalHours: Double
    let monthlyGoal: Double
    let expectedProgress: Double
    /// True when the month has logged time other than carried-in entries.
    let hasOwnEntries: Bool

    var progress: Double { max(totalHours, 0) }

    static func make(entries: [Entry], status: PublisherStatus?, now: Date, calendar: Calendar) -> OverviewMetrics {
        let totalHours = entries.reduce(0) { $0 + max($1.duration, 0) } / 3600
        let goal = Double(status?.monthlyGoal ?? 0)
        let days = Double(calendar.range(of: .day, in: .month, for: now)?.count ?? 0)
        let day = Double(calendar.component(.day, from: now))
        let expected = days > 0 ? day / days * goal : 0
        let hasOwnEntries = entries.contains { !$0.isCarriedIn && $0.duration > 0 }
        return OverviewMetrics(
            totalHours: totalHours, monthlyGoal: goal, expectedProgress: expected, hasOwnEntries: hasOwnEntries)
    }
}
