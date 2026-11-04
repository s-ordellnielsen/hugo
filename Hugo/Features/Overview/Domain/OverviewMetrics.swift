import Foundation

struct OverviewMetrics {
    let totalHours: Double
    let monthlyGoal: Double
    let expectedProgress: Double

    var progress: Double { max(totalHours, 0) }

    static func make(entries: [Entry], status: PublisherStatus?, now: Date, calendar: Calendar) -> OverviewMetrics {
        let totalHours = entries.reduce(0) { $0 + max($1.duration, 0) } / 3600
        let goal = Double(status?.monthlyGoal ?? 0)
        let days = Double(calendar.range(of: .day, in: .month, for: now)?.count ?? 0)
        let day = Double(calendar.component(.day, from: now))
        let expected = days > 0 ? day / days * goal : 0
        return OverviewMetrics(totalHours: totalHours, monthlyGoal: goal, expectedProgress: expected)
    }
}

struct CategoryProgressRow: Identifiable {
    let id: String
    let name: String
    let iconName: String
    let duration: TimeInterval
    let color: CategoryProgressColor?
}

enum CategoryProgressAggregator {
    static func rows(
        entries: [Entry], trackers: [Tracker], locale: Locale = .current
    ) -> [CategoryProgressRow] {
        let totals = CategoryTotals.rows(entries: entries, trackers: trackers, locale: locale)
            .filter { $0.duration > 0 }
        let trackersByID = Dictionary(trackers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        func row(_ total: CategoryTotal) -> CategoryProgressRow {
            let tracker = total.trackerID.flatMap { trackersByID[$0] }
            return CategoryProgressRow(
                id: total.id, name: total.name, iconName: total.iconName, duration: total.duration,
                color: tracker.flatMap { CategoryProgressColor(hue: $0.hue, saturation: $0.sat, brightness: $0.bri) }
            )
        }

        let live = trackers.compactMap { tracker in totals.first { $0.trackerID == tracker.id } }
        let liveIDs = Set(live.map(\.id))
        let others =
            totals
            .filter { $0.id != "untracked" && !liveIDs.contains($0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let untracked = totals.filter { $0.id == "untracked" }
        return (live + others + untracked).map(row)
    }
}
