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
        var snapshotRows: [String: (name: String, iconName: String, duration: TimeInterval)] = [:]
        var untrackedDuration: TimeInterval = 0
        for entry in entries {
            let category = entry.resolvedCategory(locale: locale)
            if let trackerID = category.trackerID {
                totals[trackerID, default: 0] += entry.duration
            } else if let type = category.type {
                if let match = trackers.first(where: { $0.name == category.name && $0.type == type }) {
                    totals[match.id, default: 0] += entry.duration
                } else {
                    snapshotRows[category.key, default: (category.name, category.iconName, 0)].duration +=
                        entry.duration
                }
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

        let sortedSnapshots = snapshotRows.sorted {
            $0.value.name.localizedStandardCompare($1.value.name) == .orderedAscending
        }
        for (key, value) in sortedSnapshots where value.duration > 0 {
            rows.append(
                CategoryProgressRow(
                    id: key, name: value.name, iconName: value.iconName, duration: value.duration, color: nil))
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
