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

    @Test
    func unreportedWhenNoReportExists() {
        #expect(
            ReportReminderSchedule.hasUnreportedEntries(
                report: nil,
                entries: [],
                month: YearMonth(year: 2026, month: 6),
                calendar: calendar
            )
        )
    }

    @Test
    func unreportedForSentinelReports() {
        let sentinel = SubmittedReport(
            year: 2026,
            month: 6,
            entriesClosedAt: date(2026, 6, 30)
        )

        #expect(
            ReportReminderSchedule.hasUnreportedEntries(
                report: sentinel,
                entries: [],
                month: YearMonth(year: 2026, month: 6),
                calendar: calendar
            )
        )
    }

    @Test
    func entriesCreatedAfterTheCutoffAreUnreported() {
        let report = SubmittedReport(
            year: 2026,
            month: 6,
            firstSubmittedAt: date(2026, 7, 1),
            submittedAt: date(2026, 7, 1),
            entriesClosedAt: date(2026, 6, 20, hour: 10)
        )

        let older = Entry(date: date(2026, 6, 10), duration: 3_600, tracker: nil)
        older.createdAt = date(2026, 6, 10, hour: 9)
        let newer = Entry(date: date(2026, 6, 25), duration: 3_600, tracker: nil)
        newer.createdAt = date(2026, 7, 2, hour: 9)

        #expect(
            ReportReminderSchedule.hasUnreportedEntries(
                report: report,
                entries: [older],
                month: YearMonth(year: 2026, month: 6),
                calendar: calendar
            ) == false
        )
        #expect(
            ReportReminderSchedule.hasUnreportedEntries(
                report: report,
                entries: [older, newer],
                month: YearMonth(year: 2026, month: 6),
                calendar: calendar
            ) == true
        )
    }

    @Test
    func entriesFromOtherMonthsDoNotTriggerTheWarning() {
        let report = SubmittedReport(
            year: 2026,
            month: 6,
            firstSubmittedAt: date(2026, 7, 1),
            submittedAt: date(2026, 7, 1),
            entriesClosedAt: date(2026, 6, 20, hour: 10)
        )

        let julyEntry = Entry(date: date(2026, 7, 5), duration: 3_600, tracker: nil)
        julyEntry.createdAt = date(2026, 7, 5, hour: 9)

        #expect(
            ReportReminderSchedule.hasUnreportedEntries(
                report: report,
                entries: [julyEntry],
                month: YearMonth(year: 2026, month: 6),
                calendar: calendar
            ) == false
        )
    }
}
