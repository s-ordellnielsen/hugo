import Foundation

struct CurrentMonthInterval: Equatable {
    let start: Date
    let end: Date

    static func current(now: Date, calendar: Calendar) -> CurrentMonthInterval {
        let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return CurrentMonthInterval(start: start, end: end)
    }
}

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

nonisolated struct CategoryProgressColor: Equatable, Sendable {
    let hue: Double
    let saturation: Double
    let brightness: Double

    init?(hue: Double, saturation: Double, brightness: Double) {
        guard (0...1).contains(hue), (0...1).contains(saturation), (0...1).contains(brightness),
            brightness > 0
        else { return nil }
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
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
        var totals: [UUID: TimeInterval] = [:]
        var untrackedDuration: TimeInterval = 0
        for entry in entries {
            if let tracker = entry.tracker {
                totals[tracker.id, default: 0] += entry.duration
            } else {
                untrackedDuration += entry.duration
            }
        }

        var rows = trackers.compactMap { tracker -> CategoryProgressRow? in
            let duration = totals[tracker.id, default: 0]
            guard duration > 0 else { return nil }
            return CategoryProgressRow(
                id: tracker.id.uuidString,
                name: tracker.name,
                iconName: tracker.iconName,
                duration: duration,
                color: CategoryProgressColor(hue: tracker.hue, saturation: tracker.sat, brightness: tracker.bri)
            )
        }

        if untrackedDuration > 0 {
            rows.append(
                CategoryProgressRow(
                    id: "untracked",
                    name: String(localized: "entry.untracked", locale: locale),
                    iconName: "questionmark.circle",
                    duration: untrackedDuration,
                    color: nil
                )
            )
        }
        return rows
    }
}
