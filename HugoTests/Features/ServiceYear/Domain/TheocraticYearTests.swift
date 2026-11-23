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
    func spellsOutBothCalendarYearsForVoiceOver() {
        let spoken = TheocraticYear(startYear: 2026).spokenName
        #expect(spoken.contains("2026"))
        #expect(spoken.contains("2027"))
        #expect(!spoken.contains("/"))
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

    @Test
    func rangeRunsFromSeptemberFirstToNextSeptemberFirst() {
        let range = TheocraticYear(startYear: 2026).dateRange(calendar: calendar)

        #expect(range.lowerBound == date(2026, 9, 1))
        #expect(range.upperBound == date(2027, 9, 1))
        #expect(range.contains(date(2027, 8, 31)))
        #expect(!range.contains(date(2027, 9, 1)))
    }

    @Test
    func identifiesYearsAtTheEndOfTheYear() {
        #expect(TheocraticYear.containing(date(2027, 8, 31), calendar: calendar).startYear == 2026)
        #expect(TheocraticYear.containing(date(2027, 9, 1), calendar: calendar).startYear == 2027)
    }

    @Test
    func theLastSecondOfAugustBelongsToTheOldYear() {
        let lastSecond = calendar.date(
            from: DateComponents(year: 2027, month: 8, day: 31, hour: 23, minute: 59, second: 59))!
        let firstSecond = calendar.date(
            from: DateComponents(year: 2027, month: 9, day: 1, hour: 0, minute: 0, second: 0))!

        #expect(TheocraticYear.containing(lastSecond, calendar: calendar).startYear == 2026)
        #expect(TheocraticYear.containing(firstSecond, calendar: calendar).startYear == 2027)
        #expect(!TheocraticYear(startYear: 2026).dateRange(calendar: calendar).contains(firstSecond))
        #expect(TheocraticYear(startYear: 2026).dateRange(calendar: calendar).contains(lastSecond))
    }

    @Test
    func theBoundaryFollowsTheCalendarTimeZone() {
        var copenhagen = Calendar(identifier: .gregorian)
        copenhagen.timeZone = TimeZone(identifier: "Europe/Copenhagen")!
        // 22:30 UTC on August 31 is 00:30 on September 1 in Copenhagen (UTC+2).
        let instant = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 31, hour: 22, minute: 30))!

        #expect(TheocraticYear.containing(instant, calendar: calendar).startYear == 2025)
        #expect(TheocraticYear.containing(instant, calendar: copenhagen).startYear == 2026)
        #expect(instant.theocraticYear(using: copenhagen) == TheocraticYear(startYear: 2026))
    }

    @Test
    func availableYearsStaysOnOneYearWhenEntriesAreInTheCurrentYear() {
        let years = TheocraticYear.availableYears(
            entryDates: [date(2025, 9, 1), date(2026, 8, 31)],
            now: date(2026, 8, 31),
            calendar: calendar
        )
        #expect(years.map(\.startYear) == [2025])
    }

    @Test
    func availableYearsAddsTheNewYearOnSeptemberFirst() {
        let years = TheocraticYear.availableYears(
            entryDates: [date(2026, 8, 31)],
            now: date(2026, 9, 1),
            calendar: calendar
        )
        #expect(years.map(\.startYear) == [2025, 2026])
    }

    @Test
    func availableYearsIncludesAnEntryOnSeptemberFirstBeforeItIsCurrent() {
        let years = TheocraticYear.availableYears(
            entryDates: [date(2026, 9, 1)],
            now: date(2026, 8, 31),
            calendar: calendar
        )
        #expect(years.map(\.startYear) == [2025, 2026])
    }

    @Test
    func availableYearsFillsTheGapBetweenEntriesWhateverTheirOrder() {
        let years = TheocraticYear.availableYears(
            entryDates: [date(2025, 1, 15), date(2022, 10, 1)],
            now: date(2026, 7, 1),
            calendar: calendar
        )
        #expect(years.map(\.startYear) == [2022, 2023, 2024, 2025])
    }

    @Test
    func availableYearsKeepsAnEntryYearThatIsAlreadyPast() {
        let years = TheocraticYear.availableYears(
            entryDates: [date(2026, 11, 10)],
            now: date(2027, 3, 1),
            calendar: calendar
        )
        #expect(years.map(\.startYear) == [2026])
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
