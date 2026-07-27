import Foundation
import Testing

@testable import Hugo

@MainActor
struct TheocraticYearTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test
    func identifiesYearsAtTheAugustSeptemberBoundary() {
        #expect(TheocraticYear.containing(date(2026, 8, 31), calendar: calendar).startYear == 2025)
        #expect(TheocraticYear.containing(date(2026, 9, 1), calendar: calendar).startYear == 2026)
    }

    @Test
    func displaysTheocraticYearDesignation() {
        #expect(TheocraticYear(startYear: 2026).displayName == "2026/2027")
    }

    @Test
    func providesTwelveChronologicalMonths() {
        let months = TheocraticYear(startYear: 2026).months
        #expect(months.count == 12)
        #expect(months.first == YearMonth(year: 2026, month: 9))
        #expect(months.last == YearMonth(year: 2027, month: 8))
        #expect(months == months.sorted())
    }

    @Test
    func identifiesMonthsInsideTheYear() {
        let year = TheocraticYear(startYear: 2026)
        #expect(year.contains(YearMonth(year: 2026, month: 9)))
        #expect(year.contains(YearMonth(year: 2027, month: 8)))
        #expect(!year.contains(YearMonth(year: 2026, month: 8)))
        #expect(!year.contains(YearMonth(year: 2027, month: 9)))
    }

    @Test
    func availableYearsContainsOnlyCurrentYearWithoutEntries() {
        let years = TheocraticYear.availableYears(entryDates: [], now: date(2026, 7, 1), calendar: calendar)
        #expect(years == [TheocraticYear(startYear: 2025)])
    }

    @Test
    func availableYearsIsContiguousFromOldestEntryToCurrentYear() {
        let years = TheocraticYear.availableYears(
            entryDates: [date(2022, 10, 1)],
            now: date(2026, 7, 1),
            calendar: calendar
        )
        #expect(years.map(\.startYear) == [2022, 2023, 2024, 2025])
    }

    @Test
    func availableYearsExtendsToFutureEntries() {
        let years = TheocraticYear.availableYears(
            entryDates: [date(2027, 9, 1)],
            now: date(2026, 7, 1),
            calendar: calendar
        )
        #expect(years.map(\.startYear) == [2025, 2026, 2027])
    }

    @Test
    func ordersByStartYear() {
        #expect(TheocraticYear(startYear: 2024) < TheocraticYear(startYear: 2025))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
