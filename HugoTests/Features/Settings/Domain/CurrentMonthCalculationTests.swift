import Foundation
import Testing

@testable import Hugo

struct CurrentMonthCalculationTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    @Test
    func novemberCalculationSeparatesMonthContributionFromYearExpectation() throws {
        let calculation = try #require(
            CurrentMonthCalculation.make(
                status: PublisherStatus.status(for: "regular-pioneer"),
                now: date(2026, 11, 3), calendar: calendar, locale: Locale(identifier: "en_US")))

        #expect(calculation.todayFraction == 0.1)
        #expect(calculation.monthlyGoalSeconds == TimeInterval(50 * 3_600))
        #expect(calculation.options.map(\.fraction) == [0.1, 0, 1])
        #expect(calculation.options.map(\.contributionSeconds) == [5, 0, 50].map { TimeInterval($0 * 3_600) })
    }

    @Test(arguments: ["publisher", "auxiliary-pioneer"])
    func statusesWithoutYearlyGoalsReturnNil(statusID: String) {
        #expect(
            CurrentMonthCalculation.make(
                status: PublisherStatus.status(for: statusID), now: date(2026, 11, 3), calendar: calendar) == nil)
    }

    @Test
    func missingStatusReturnsNil() {
        #expect(CurrentMonthCalculation.make(status: nil, now: date(2026, 11, 3), calendar: calendar) == nil)
    }

    @Test(arguments: [Locale(identifier: "en_US"), Locale(identifier: "da_DK")])
    func datesUseSuppliedLocale(locale: Locale) throws {
        let calculation = try #require(
            CurrentMonthCalculation.make(
                status: PublisherStatus.status(for: "regular-pioneer"),
                now: date(2026, 11, 3), calendar: calendar, locale: locale))
        var style = Date.FormatStyle().month(.wide).day()
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        style.locale = locale
        var todayStyle = Date.FormatStyle().month(.wide).day().weekday(.wide)
        todayStyle.calendar = calendar
        todayStyle.timeZone = calendar.timeZone
        todayStyle.locale = locale
        #expect(calculation.todayLabel == date(2026, 11, 3).formatted(todayStyle))
        #expect(calculation.firstDayLabel == date(2026, 11, 1).formatted(style))
        #expect(calculation.lastDayLabel == date(2026, 11, 30).formatted(style))
    }

    @Test
    func februaryLeapDayAndMonthEndAreInclusive() throws {
        let leap = try #require(
            CurrentMonthCalculation.make(
                status: PublisherStatus.status(for: "regular-pioneer"), now: date(2028, 2, 29), calendar: calendar))
        #expect(leap.todayFraction == 1)
        #expect(leap.lastDayLabel == date(2028, 2, 29).formatted(dateStyle))
    }

    private var dateStyle: Date.FormatStyle {
        var style = Date.FormatStyle().month(.wide).day()
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        style.locale = .current
        return style
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
