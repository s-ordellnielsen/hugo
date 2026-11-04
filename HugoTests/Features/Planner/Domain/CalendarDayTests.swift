import Foundation
import Testing

@testable import Hugo

struct CalendarDayTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test
    func dateTakesTheCalendarDayIgnoringTheTime() {
        let day = CalendarDay(date(2026, 11, 4, hour: 23), calendar: calendar)
        #expect(day == CalendarDay(year: 2026, month: 11, day: 4))
    }

    @Test
    func middayIsTwelveOClockOnTheDay() {
        let day = CalendarDay(year: 2026, month: 11, day: 4)
        #expect(day.midday(calendar: calendar) == date(2026, 11, 4, hour: 12))
    }

    @Test
    func dateRangeEndsAtTheStartOfTheNextDay() {
        let day = CalendarDay(year: 2026, month: 11, day: 30)
        #expect(day.dateRange(calendar: calendar) == date(2026, 11, 30)..<date(2026, 12, 1))
    }

    @Test
    func daysOrderAcrossMonthAndYearBoundaries() {
        #expect(CalendarDay(year: 2026, month: 10, day: 31) < CalendarDay(year: 2026, month: 11, day: 1))
        #expect(CalendarDay(year: 2026, month: 11, day: 1) < CalendarDay(year: 2026, month: 11, day: 2))
        #expect(CalendarDay(year: 2026, month: 12, day: 31) < CalendarDay(year: 2027, month: 1, day: 1))
    }

    @Test
    func monthListsEveryDay() {
        let november = YearMonth(year: 2026, month: 11).days(calendar: calendar)
        #expect(november.count == 30)
        #expect(november.first?.day == 1)
        #expect(november.last?.day == 30)
    }

    @Test
    func februaryLeapYearHasTwentyNineDays() {
        let february = YearMonth(year: 2028, month: 2).days(calendar: calendar)
        #expect(february.count == 29)
        #expect(february.last?.day == 29)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
