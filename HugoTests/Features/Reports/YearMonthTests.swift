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
    func endDateIsTheLastInstantOfTheMonth() {
        let calendar = gregorianGMT()
        let end = YearMonth(year: 2026, month: 6).endDate(calendar: calendar)
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: end
        )

        #expect(components.year == 2026)
        #expect(components.month == 6)
        #expect(components.day == 30)
        #expect(components.hour == 23)
        #expect(components.minute == 59)
        #expect(components.second == 59)
    }
}
