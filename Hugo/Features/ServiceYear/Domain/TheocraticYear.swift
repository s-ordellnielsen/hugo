import Foundation

nonisolated struct TheocraticYear: Hashable, Comparable, Identifiable, Sendable {
    let startYear: Int

    var id: Int { startYear }

    var displayName: String { "\(startYear)/\(startYear + 1)" }

    /// The year as VoiceOver says it, for example "2026 to 2027".
    var spokenName: String {
        String(
            localized: "year.picker.a11y.value",
            defaultValue: "\(String(startYear)) to \(String(startYear + 1))",
            comment:
                "Spoken name of a theocratic year. The arguments are its two calendar years, such as 2026 and 2027."
        )
    }

    var months: [YearMonth] {
        (9...12).map { YearMonth(year: startYear, month: $0) }
            + (1...8).map { YearMonth(year: startYear + 1, month: $0) }
    }

    func contains(_ month: YearMonth) -> Bool {
        (month.year == startYear && month.month >= 9 && month.month <= 12)
            || (month.year == startYear + 1 && month.month >= 1 && month.month <= 8)
    }

    /// The half-open range from September 1 of `startYear` to September 1 of
    /// the following year.
    func dateRange(calendar: Calendar = .current) -> Range<Date> {
        let start = YearMonth(year: startYear, month: 9).date(calendar: calendar)
        let end = YearMonth(year: startYear + 1, month: 9).date(calendar: calendar)
        return start..<end
    }

    static func containing(_ date: Date, calendar: Calendar = .current) -> TheocraticYear {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        return TheocraticYear(startYear: month >= 9 ? year : year - 1)
    }

    static func < (lhs: TheocraticYear, rhs: TheocraticYear) -> Bool {
        lhs.startYear < rhs.startYear
    }

    static func availableYears(
        entryDates: [Date],
        now: Date,
        calendar: Calendar = .current
    ) -> [TheocraticYear] {
        let currentYear = containing(now, calendar: calendar)
        guard let earliest = entryDates.min(), let latest = entryDates.max() else {
            return [currentYear]
        }

        let firstYear = min(containing(earliest, calendar: calendar), currentYear)
        let lastYear = max(containing(latest, calendar: calendar), currentYear)

        return (firstYear.startYear...lastYear.startYear).map(TheocraticYear.init(startYear:))
    }
}

extension Date {
    nonisolated func theocraticYear(using calendar: Calendar = .current) -> TheocraticYear {
        TheocraticYear.containing(self, calendar: calendar)
    }
}
