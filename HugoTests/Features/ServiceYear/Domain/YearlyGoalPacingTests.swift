import Foundation
import Testing

@testable import Hugo

struct YearlyGoalPacingTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    @Test(arguments: [
        (YearlyGoalPacing.completedMonths, 0.0),
        (YearlyGoalPacing.includeCurrentMonth, 1.0),
    ])
    func fixedPacingFractions(argument: (YearlyGoalPacing, Double)) {
        #expect(argument.0.currentMonthFraction(now: date(2026, 11, 3), calendar: calendar) == argument.1)
    }

    @Test(arguments: [
        (2026, 11, 3, 30, 0.1),
        (2026, 11, 1, 30, 1.0 / 30.0),
        (2026, 11, 30, 30, 1.0),
        (2028, 2, 29, 29, 1.0),
        (2027, 2, 1, 28, 1.0 / 28.0),
    ])
    func proratedFractionUsesInclusiveCalendarDay(argument: (Int, Int, Int, Int, Double)) {
        let actual = YearlyGoalPacing.proRated.currentMonthFraction(
            now: date(argument.0, argument.1, argument.2), calendar: calendar)
        #expect(abs(actual - argument.4) < 1e-9)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
