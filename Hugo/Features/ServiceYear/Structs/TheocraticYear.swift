import Foundation

nonisolated struct TheocraticYear: Hashable, Comparable, Identifiable, Sendable {
    let startYear: Int

    var id: Int { startYear }

    var displayName: String { "\(startYear)/\(startYear + 1)" }

    var months: [YearMonth] {
        (9...12).map { YearMonth(year: startYear, month: $0) }
            + (1...8).map { YearMonth(year: startYear + 1, month: $0) }
    }

    func contains(_ month: YearMonth) -> Bool {
        months.contains(month)
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
        let entryYears = entryDates.map { containing($0, calendar: calendar) }
        let firstYear = min(entryYears.min() ?? currentYear, currentYear)
        let lastYear = max(entryYears.max() ?? currentYear, currentYear)

        return (firstYear.startYear...lastYear.startYear).map(TheocraticYear.init(startYear:))
    }
}

extension Date {
    func theocraticYear(using calendar: Calendar = .current) -> TheocraticYear {
        TheocraticYear.containing(self, calendar: calendar)
    }
}
