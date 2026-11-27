import Foundation
import SwiftData
import Testing

@testable import Hugo

@MainActor
struct MonthProgressTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private var now: Date { date(2026, 11, 15) }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func settings(status: String, bufferHours: Int = 0) -> WidgetSettings {
        WidgetSettings(publisherStatusID: status, bufferHours: bufferHours, storeSchemaVersion: "test")
    }

    private func monthEntries() -> [Entry] {
        let own = Entry(date: date(2026, 11, 3), duration: 3_600 * 10, tracker: nil)
        let credit = Entry(date: date(2026, 11, 10), duration: 3_600 * 5, tracker: nil)
        let carriedIn = Entry(date: date(2026, 11, 1), duration: 3_600 * 2, tracker: nil)
        carriedIn.sourceReportYear = 2026
        carriedIn.sourceReportMonth = 10
        return [own, credit, carriedIn]
    }

    @Test
    func matchesOverviewNumbersForEachGoal() throws {
        let entries = monthEntries()
        for status in ["regular-pioneer", "auxiliary-pioneer", "publisher"] {
            let progress = MonthProgress.make(
                entries: entries, plannedSeconds: 0, settings: settings(status: status), now: now,
                calendar: calendar)
            let metrics = OverviewMetrics.make(
                entries: entries, status: PublisherStatus.status(for: status), bufferHours: 0, now: now,
                calendar: calendar)
            let fill = MonthlyCircleFill.make(
                monthlyGoalHours: metrics.monthlyGoal, loggedSeconds: metrics.progress * 3_600,
                plannedSeconds: 0, hasOwnEntries: metrics.hasOwnEntries)

            #expect(progress.loggedSeconds == metrics.progress * 3_600)
            #expect(progress.goalHours == metrics.monthlyGoal)
            #expect(progress.fill == fill)
        }
    }

    @Test
    func bufferAddsToTheGoal() throws {
        let withBuffer = MonthProgress.make(
            entries: monthEntries(), plannedSeconds: 0, settings: settings(status: "regular-pioneer", bufferHours: 5),
            now: now, calendar: calendar)
        let withoutBuffer = MonthProgress.make(
            entries: monthEntries(), plannedSeconds: 0, settings: settings(status: "regular-pioneer"), now: now,
            calendar: calendar)

        #expect(withBuffer.goalHours == 55)
        #expect(withoutBuffer.goalHours == 50)
    }

    @Test
    func noGoalWithPlansUsesThePlanBasis() throws {
        let progress = MonthProgress.make(
            entries: monthEntries(), plannedSeconds: 3_600 * 20, settings: settings(status: "publisher"), now: now,
            calendar: calendar)

        #expect(progress.fill.basis == .plan(plannedSeconds: 3_600 * 20))
        // Logged 17 hours (own 10, credit 5, carried-in 2) over 20 planned hours.
        #expect(abs(progress.fill.fraction - 0.85) < 0.0001)
    }

    @Test
    func noGoalNoPlanUsesPresence() throws {
        let ownOnly = MonthProgress.make(
            entries: monthEntries(), plannedSeconds: 0, settings: settings(status: "publisher"), now: now,
            calendar: calendar)
        let carriedOnly = MonthProgress.make(
            entries: [monthEntries()[2]], plannedSeconds: 0, settings: settings(status: "publisher"), now: now,
            calendar: calendar)

        #expect(ownOnly.fill == MonthlyCircleFill(basis: .presence, fraction: 1))
        #expect(carriedOnly.fill == MonthlyCircleFill(basis: .presence, fraction: 0))
    }

    @Test
    func headlineShowsMinutesUnderAnHourAndHoursAbove() throws {
        func headline(seconds: TimeInterval) -> HeadlineDuration {
            MonthProgress(
                month: YearMonth(year: 2026, month: 11), loggedSeconds: seconds, goalHours: 0,
                fill: MonthlyCircleFill(basis: .presence, fraction: 0)
            ).headline
        }

        #expect(headline(seconds: 45 * 60) == .minutes(45))
        #expect(headline(seconds: 59 * 60) == .minutes(59))
        #expect(headline(seconds: 60 * 60) == .hours(1))
        #expect(headline(seconds: 12 * 3_600) == .hours(12))
    }
}
