import Foundation

nonisolated enum MonthlyReportBuilder {
    static func summaries(
        from entries: [Entry],
        calendar: Calendar = .current,
        locale: Locale = .current,
        trackers: [Tracker] = []
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

            for entry in monthEntries {
                totalSeconds += entry.duration
                bibleStudies += entry.bibleStudies

                let type = entry.resolvedCategory(locale: locale).type
                if type == .main { mainDuration += entry.duration }
                if type == .separate { separateDuration += entry.duration }
            }

            let categorySummaries = CategoryTotals.rows(entries: monthEntries, trackers: trackers, locale: locale).map {
                MonthlyCategorySummary(
                    id: $0.id, name: $0.name, iconName: $0.iconName, type: $0.type, duration: $0.duration)
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
