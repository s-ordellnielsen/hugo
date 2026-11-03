import Foundation
import Testing

@testable import Hugo

@MainActor
struct ReportReminderScheduleTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 12,
        minute: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year, month: month, day: day, hour: hour, minute: minute
            )
        )!
    }

    @Test
    func previousMonthStaysDueThroughoutTheGraceWindow() {
        // With a 7-day grace window the previous month stays due for the
        // entire following month, and the current month takes over on its own
        // last day — so from the first due date onward the reminder is
        // effectively always active for exactly one month at a time.
        #expect(
            ReportReminderSchedule.dueMonth(now: date(2026, 6, 5), calendar: calendar)
                == YearMonth(year: 2026, month: 5)
        )
        #expect(
            ReportReminderSchedule.dueMonth(now: date(2026, 7, 7), calendar: calendar)
                == YearMonth(year: 2026, month: 6)
        )
        #expect(
            ReportReminderSchedule.dueMonth(now: date(2026, 7, 31), calendar: calendar)
                == YearMonth(year: 2026, month: 7)
        )
    }

    @Test
    func dueOnTheLastDayOfTheCurrentMonth() {
        #expect(
            ReportReminderSchedule.dueMonth(now: date(2026, 7, 31), calendar: calendar)
                == YearMonth(year: 2026, month: 7)
        )
    }

    @Test
    func previousMonthStaysDueDuringTheGraceWindow() {
        // The grace window is 30 days (see `previousMonthGraceDays`), so the
        // previous month stays reachable for essentially the whole following
        // month — only superseded once the current month itself becomes due.
        #expect(
            ReportReminderSchedule.dueMonth(now: date(2026, 8, 1), calendar: calendar)
                == YearMonth(year: 2026, month: 7)
        )
        #expect(
            ReportReminderSchedule.dueMonth(now: date(2026, 8, 4), calendar: calendar)
                == YearMonth(year: 2026, month: 7)
        )
        #expect(
            ReportReminderSchedule.dueMonth(now: date(2026, 8, 7), calendar: calendar)
                == YearMonth(year: 2026, month: 7)
        )
    }

    @Test
    func currentMonthSupersedesThePreviousOnItsLastDay() {
        #expect(
            ReportReminderSchedule.dueMonth(now: date(2026, 8, 31), calendar: calendar)
                == YearMonth(year: 2026, month: 8)
        )
    }

    @Test
    func dueMonthHandlesYearBoundaries() {
        #expect(
            ReportReminderSchedule.dueMonth(now: date(2026, 1, 31), calendar: calendar)
                == YearMonth(year: 2026, month: 1)
        )
        #expect(
            ReportReminderSchedule.dueMonth(now: date(2026, 2, 5), calendar: calendar)
                == YearMonth(year: 2026, month: 1)
        )
        #expect(
            ReportReminderSchedule.dueMonth(now: date(2026, 3, 1), calendar: calendar)
                == YearMonth(year: 2026, month: 2)
        )
    }
}
