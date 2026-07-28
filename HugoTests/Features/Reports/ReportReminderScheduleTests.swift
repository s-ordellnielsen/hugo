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
    func notDueBeforeTheLastDayOfTheMonth() {
        #expect(ReportReminderSchedule.dueMonth(now: date(2026, 7, 15), calendar: calendar) == nil)
        #expect(ReportReminderSchedule.dueMonth(now: date(2026, 7, 30), calendar: calendar) == nil)
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
        #expect(
            ReportReminderSchedule.dueMonth(now: date(2026, 8, 1), calendar: calendar)
                == YearMonth(year: 2026, month: 7)
        )
        #expect(
            ReportReminderSchedule.dueMonth(now: date(2026, 8, 7), calendar: calendar)
                == YearMonth(year: 2026, month: 7)
        )
    }

    @Test
    func reminderGoesQuietAfterTheGraceWindow() {
        // FLAGGED: plan 012 keeps the previous month due until submitted; the
        // cutoff below is an implementation decision (see dueMonth's doc
        // comment) so the card stops nagging about a stale month.
        #expect(ReportReminderSchedule.dueMonth(now: date(2026, 8, 8), calendar: calendar) == nil)
        #expect(ReportReminderSchedule.dueMonth(now: date(2026, 8, 15), calendar: calendar) == nil)
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
