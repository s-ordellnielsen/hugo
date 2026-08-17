import Foundation

nonisolated enum MonthlyReportBuilder {
    static func summaries(
        from entries: [Entry],
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [MonthlyReportSummary] {
        var grouped: [YearMonth: [Entry]] = [:]
        for entry in entries {
            grouped[entry.date.yearMonth(using: calendar), default: []].append(entry)
        }

        return grouped.map { month, monthEntries in
            var totalSeconds: TimeInterval = 0
            var bibleStudies = 0
            var mainDuration: TimeInterval = 0
            var separateDuration: TimeInterval = 0
            var categories: [String: (name: String, iconName: String, type: TrackerType?, duration: TimeInterval)] = [:]

            for entry in monthEntries {
                totalSeconds += entry.duration
                bibleStudies += entry.bibleStudies

                let metadata: (key: String, name: String, iconName: String, type: TrackerType?)
                if let tracker = entry.tracker {
                    metadata = (tracker.id.uuidString, tracker.name, tracker.iconName, tracker.type)
                } else if let snapshot = entry.storedTracker {
                    let key = "stored:\(snapshot.name)|\(snapshot.icon)|\(snapshot.type.rawValue)"
                    metadata = (key, snapshot.name, snapshot.icon, snapshot.type)
                } else {
                    metadata = (
                        "untracked", String(localized: "entry.untracked", locale: locale), "questionmark.circle", nil
                    )
                }

                if metadata.type == .main { mainDuration += entry.duration }
                if metadata.type == .separate { separateDuration += entry.duration }
                categories[metadata.key, default: (metadata.name, metadata.iconName, metadata.type, 0)].duration +=
                    entry.duration
            }

            let categorySummaries = categories.map { key, value in
                MonthlyCategorySummary(
                    id: key, name: value.name, iconName: value.iconName, type: value.type, duration: value.duration)
            }.sorted {
                if $0.duration != $1.duration { return $0.duration > $1.duration }
                if $0.name != $1.name { return $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                return $0.id < $1.id
            }

            return MonthlyReportSummary(
                id: month,
                displayName: month.monthYearString(locale: locale, calendar: calendar),
                totalSeconds: totalSeconds,
                totalBibleStudies: bibleStudies,
                mainDuration: mainDuration,
                separateDuration: separateDuration,
                categories: categorySummaries,
                entries: monthEntries
            )
        }.sorted { $0.id > $1.id }
    }
}
