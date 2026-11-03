import Foundation
import Testing

@testable import Hugo

@MainActor
struct YearMonthTests {
    @Test
    func ordersMonthsAcrossYears() {
        #expect(YearMonth(year: 2025, month: 12) < YearMonth(year: 2026, month: 1))
        #expect(YearMonth(year: 2026, month: 1) > YearMonth(year: 2025, month: 12))
    }

    @Test
    func ordersMonthsWithinTheSameYear() {
        #expect(YearMonth(year: 2025, month: 2) < YearMonth(year: 2025, month: 9))
        #expect(YearMonth(year: 2025, month: 9) > YearMonth(year: 2025, month: 2))
        #expect(YearMonth(year: 2025, month: 9) == YearMonth(year: 2025, month: 9))
    }

    @Test
    func formatsSeptemberWithRequestedLocale() {
        let month = YearMonth(year: 2025, month: 9)
        #expect(month.monthYearString(locale: Locale(identifier: "en_US_POSIX")) == "September 2025")
    }

    @Test
    func monthNameFormatsTheMonthOnly() {
        let calendar = gregorianGMT()
        let month = YearMonth(year: 2026, month: 6)

        #expect(
            month.monthName(locale: Locale(identifier: "en_US_POSIX"), calendar: calendar) == "June"
        )
        #expect(
            month.monthName(locale: Locale(identifier: "da_DK"), calendar: calendar) == "juni"
        )
    }
}

extension YearMonthTests {
    private func gregorianGMT() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test
    func middayOnFirstStaysInMonthAcrossTimeZones() {
        var copenhagen = Calendar(identifier: .gregorian)
        copenhagen.timeZone = TimeZone(identifier: "Europe/Copenhagen")!
        let midday = YearMonth(year: 2026, month: 7).middayOnFirst(calendar: copenhagen)

        var west = Calendar(identifier: .gregorian)
        west.timeZone = TimeZone(secondsFromGMT: -10 * 3600)!

        #expect(midday.yearMonth(using: gregorianGMT()) == YearMonth(year: 2026, month: 7))
        #expect(midday.yearMonth(using: west) == YearMonth(year: 2026, month: 7))
    }

    @Test
    func nextMonthCrossesTheYearBoundary() {
        let calendar = gregorianGMT()

        #expect(
            YearMonth(year: 2025, month: 12).nextMonth(calendar: calendar)
                == YearMonth(year: 2026, month: 1)
        )
        #expect(
            YearMonth(year: 2025, month: 11).nextMonth(calendar: calendar)
                == YearMonth(year: 2025, month: 12)
        )
    }

    @Test
    func previousCrossesTheYearBoundary() {
        let calendar = gregorianGMT()

        #expect(
            YearMonth.previous(before: YearMonth(year: 2026, month: 1), calendar: calendar)
                == YearMonth(year: 2025, month: 12)
        )
        #expect(
            YearMonth.previous(before: YearMonth(year: 2026, month: 3), calendar: calendar)
                == YearMonth(year: 2026, month: 2)
        )
    }

    @Test
    func lastDayHandlesLeapFebruary() {
        let calendar = gregorianGMT()

        #expect(YearMonth(year: 2024, month: 2).lastDay(calendar: calendar) == 29)
        #expect(YearMonth(year: 2026, month: 2).lastDay(calendar: calendar) == 28)
        #expect(YearMonth(year: 2026, month: 7).lastDay(calendar: calendar) == 31)
        #expect(YearMonth(year: 2026, month: 6).lastDay(calendar: calendar) == 30)
    }

    @Test
    func dateRangeCoversTheWholeMonthHalfOpen() {
        let calendar = gregorianGMT()
        let range = YearMonth(year: 2026, month: 12).dateRange(calendar: calendar)
        let start = calendar.date(from: DateComponents(year: 2026, month: 12, day: 1))!
        let end = calendar.date(from: DateComponents(year: 2027, month: 1, day: 1))!
        let lastSecond = calendar.date(
            from: DateComponents(year: 2026, month: 12, day: 31, hour: 23, minute: 59, second: 59))!

        #expect(range.lowerBound == start)
        #expect(range.upperBound == end)
        #expect(range.contains(lastSecond))
        #expect(!range.contains(range.upperBound))
    }
}
