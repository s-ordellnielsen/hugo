import Foundation
import Testing

@testable import Hugo

struct CalendarGridLayoutTests {
    private func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    @Test
    func sundayFirstStartsWithS() {
        let symbols = CalendarGridLayout.weekdaySymbols(calendar: calendar(firstWeekday: 1))
        #expect(symbols.count == 7)
        #expect(symbols.first == "S")
    }

    @Test
    func mondayFirstStartsWithMAndEndsWithS() {
        let symbols = CalendarGridLayout.weekdaySymbols(calendar: calendar(firstWeekday: 2))
        #expect(symbols.count == 7)
        #expect(symbols.first == "M")
        #expect(symbols.last == "S")
    }

    @Test
    func novemberStartsOnASundayAfterSixBlanksWhenMondayFirst() {
        let november = YearMonth(year: 2026, month: 11)
        #expect(CalendarGridLayout.leadingBlankDays(in: november, calendar: calendar(firstWeekday: 2)) == 6)
    }

    @Test
    func novemberHasNoBlanksWhenSundayFirst() {
        let november = YearMonth(year: 2026, month: 11)
        #expect(CalendarGridLayout.leadingBlankDays(in: november, calendar: calendar(firstWeekday: 1)) == 0)
    }

    @Test
    func decemberHasOneBlankWhenMondayFirst() {
        let december = YearMonth(year: 2026, month: 12)
        #expect(CalendarGridLayout.leadingBlankDays(in: december, calendar: calendar(firstWeekday: 2)) == 1)
    }
}
