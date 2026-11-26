import Foundation
import Testing

@testable import Hugo

struct PlannerKeyboardNavigationTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let november = YearMonth(year: 2026, month: 11)
    private let today = CalendarDay(year: 2026, month: 11, day: 26)

    @Test
    func startsOnTodayInTheCurrentMonth() {
        #expect(PlannerKeyboardNavigation.startDay(in: november, today: today) == today)
    }

    @Test
    func startsOnTheFirstInOtherMonths() {
        let december = YearMonth(year: 2026, month: 12)
        #expect(
            PlannerKeyboardNavigation.startDay(in: december, today: today)
                == CalendarDay(year: 2026, month: 12, day: 1))
    }

    @Test
    func firstPressShowsTheStartDay() {
        #expect(step(.nextDay, from: nil) == today)
    }

    @Test
    func dayFromAnotherMonthRestarts() {
        #expect(step(.nextDay, from: CalendarDay(year: 2026, month: 10, day: 31)) == today)
    }

    @Test
    func arrowsMoveOneDayOrOneWeek() {
        let start = nov(10)
        #expect(step(.nextDay, from: start) == nov(11))
        #expect(step(.previousDay, from: start) == nov(9))
        #expect(step(.nextWeek, from: start) == nov(17))
        #expect(step(.previousWeek, from: start) == nov(3))
    }

    @Test
    func staysAtTheStartOfTheMonth() {
        #expect(step(.previousDay, from: nov(1)) == nov(1))
        #expect(step(.previousWeek, from: nov(3)) == nov(3))
    }

    @Test
    func staysAtTheEndOfTheMonth() {
        #expect(step(.nextDay, from: nov(30)) == nov(30))
        #expect(step(.nextWeek, from: nov(26)) == nov(26))
    }

    @Test
    func leapFebruaryHas29Days() {
        let february = YearMonth(year: 2028, month: 2)
        let result = PlannerKeyboardNavigation.day(
            after: .nextDay, from: CalendarDay(year: 2028, month: 2, day: 28), in: february, today: today,
            calendar: calendar)
        #expect(result == CalendarDay(year: 2028, month: 2, day: 29))
    }

    private func step(_ move: PlannerKeyboardMove, from day: CalendarDay?) -> CalendarDay {
        PlannerKeyboardNavigation.day(after: move, from: day, in: november, today: today, calendar: calendar)
    }

    private func nov(_ day: Int) -> CalendarDay {
        CalendarDay(year: 2026, month: 11, day: day)
    }
}
