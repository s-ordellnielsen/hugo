import Foundation
import Testing

@testable import Hugo

struct PlannerMonthStatusTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let regular = PublisherStatus.status(for: "regular-pioneer")!
    private let main = Tracker(name: "Field Service", type: .main, iconName: "figure.walk")
    private let separate = Tracker(name: "LDC", type: .separate, iconName: "hammer")

    @Test
    func projectedTimeAddsStillPlannedTimeToLoggedTime() {
        // 10 h logged on 10 Nov, 40 h planned that day: 30 h still planned.
        let month = makeNovember(
            items: [item(CalendarDay(year: 2026, month: 11, day: 10), hours: 40, tracker: main)],
            entries: [entry(date(2026, 11, 10, hour: 10), hours: 10, tracker: main)])

        let status = PlannerMonthStatus.make(month: month, targetSeconds: 50 * 3_600, rule: nil)

        #expect(status.loggedSeconds == TimeInterval(10 * 3_600))
        #expect(status.stillPlannedSeconds == TimeInterval(30 * 3_600))
        #expect(status.projectedSeconds == TimeInterval(40 * 3_600))
        #expect(status.shortfallSeconds == TimeInterval(10 * 3_600))
        #expect(status.leftSeconds == TimeInterval(40 * 3_600))
    }

    @Test
    func daysLeftCountsFromTodayOrFromTheFirstOfAFutureMonth() {
        let now = date(2026, 11, 3, hour: 12)
        let november = PlannerMonth.make(
            month: YearMonth(year: 2026, month: 11), items: [],
            entries: [entry(date(2026, 11, 2, hour: 10), hours: 10, tracker: main)], now: now, calendar: calendar)
        let december = PlannerMonth.make(
            month: YearMonth(year: 2026, month: 12), items: [], entries: [], now: now, calendar: calendar)

        let novemberStatus = PlannerMonthStatus.make(
            month: november, targetSeconds: 50 * 3_600, rule: nil)
        let decemberStatus = PlannerMonthStatus.make(
            month: december, targetSeconds: 50 * 3_600, rule: nil)

        #expect(novemberStatus.daysLeft == 28)
        #expect(decemberStatus.daysLeft == 31)
        #expect(novemberStatus.perDaySeconds == TimeInterval(40 * 3_600) / 28)
    }

    @Test
    func noTargetMeansNoShortfallLeftOrPerDay() {
        let month = makeNovember(
            items: [item(CalendarDay(year: 2026, month: 11, day: 10), hours: 4, tracker: main)],
            entries: [])

        let status = PlannerMonthStatus.make(month: month, targetSeconds: nil, rule: nil)

        #expect(status.shortfallSeconds == nil)
        #expect(status.leftSeconds == nil)
        #expect(status.perDaySeconds == nil)
    }

    @Test
    func yearlyGoalCountsOnlyCreditedTimeAndReportsTheRest() {
        let month = makeNovember(
            items: [
                item(CalendarDay(year: 2026, month: 11, day: 10), hours: 30, tracker: main),
                item(CalendarDay(year: 2026, month: 11, day: 11), hours: 40, tracker: separate),
            ],
            entries: [])

        let status = PlannerMonthStatus.make(
            month: month, targetSeconds: nil, rule: regular.yearlyGoalRule)

        #expect(status.projectedSeconds == TimeInterval(55 * 3_600))
        #expect(status.uncountedSeconds == TimeInterval(15 * 3_600))
    }

    @Test
    func loggedTimeAboveTheTargetLeavesNothingToPlan() {
        let month = makeNovember(
            items: [],
            entries: [entry(date(2026, 11, 10, hour: 10), hours: 52, tracker: main)])

        let status = PlannerMonthStatus.make(month: month, targetSeconds: 50 * 3_600, rule: nil)

        #expect(status.leftSeconds == 0)
        #expect(status.perDaySeconds == nil)
        #expect(status.shortfallSeconds == TimeInterval(-2 * 3_600))
    }

    @Test
    func summarySentenceNamesTheShortfallAndTreatsSmallDifferencesAsEqual() {
        let short = PlannerMonthStatus(
            targetSeconds: 50 * 3_600, loggedSeconds: 0, stillPlannedSeconds: 46 * 3_600,
            uncountedSeconds: 0, daysLeft: 10)
        let reached = PlannerMonthStatus(
            targetSeconds: 50 * 3_600, loggedSeconds: 0, stillPlannedSeconds: 50 * 3_600,
            uncountedSeconds: 0, daysLeft: 10)
        let nearlyReached = PlannerMonthStatus(
            targetSeconds: 50 * 3_600, loggedSeconds: 0, stillPlannedSeconds: 50 * 3_600 - 30,
            uncountedSeconds: 0, daysLeft: 10)
        let over = PlannerMonthStatus(
            targetSeconds: 50 * 3_600, loggedSeconds: 0, stillPlannedSeconds: 53 * 3_600,
            uncountedSeconds: 0, daysLeft: 10)
        let noTarget = PlannerMonthStatus(
            targetSeconds: nil, loggedSeconds: 0, stillPlannedSeconds: 46 * 3_600,
            uncountedSeconds: 0, daysLeft: 10)

        #expect(short.summarySentence.contains("4"))
        #expect(short.summarySentence != reached.summarySentence)
        #expect(nearlyReached.summarySentence == reached.summarySentence)
        #expect(over.summarySentence != reached.summarySentence)
        #expect(over.summarySentence != short.summarySentence)
        #expect(noTarget.summarySentence != short.summarySentence)
        #expect(noTarget.summarySentence != reached.summarySentence)
        #expect(noTarget.summarySentence != over.summarySentence)
    }

    @Test
    func perDaySentenceNeedsATarget() {
        let withoutTarget = PlannerMonthStatus(
            targetSeconds: nil, loggedSeconds: 0, stillPlannedSeconds: 0,
            uncountedSeconds: 0, daysLeft: 10)

        #expect(withoutTarget.perDaySentence == nil)
    }

    @Test
    func uncountedSentenceAppearsOnlyForAMinuteOrMore() {
        let belowThreshold = PlannerMonthStatus(
            targetSeconds: nil, loggedSeconds: 0, stillPlannedSeconds: 0,
            uncountedSeconds: 59, daysLeft: 10)
        let aboveThreshold = PlannerMonthStatus(
            targetSeconds: nil, loggedSeconds: 0, stillPlannedSeconds: 0,
            uncountedSeconds: 15 * 3_600, daysLeft: 10)

        #expect(belowThreshold.uncountedSentence == nil)
        #expect(aboveThreshold.uncountedSentence != nil)
    }

    private func makeNovember(items: [PlannedItem], entries: [Entry]) -> PlannerMonth {
        PlannerMonth.make(
            month: YearMonth(year: 2026, month: 11), items: items, entries: entries,
            now: date(2026, 11, 3, hour: 12), calendar: calendar)
    }

    private func item(_ day: CalendarDay, hours: Double, tracker: Tracker) -> PlannedItem {
        PlannedItem(
            id: UUID().uuidString, day: day, duration: hours * 3_600, startMinute: nil,
            categoryName: tracker.name, categoryIconName: tracker.iconName, categoryType: tracker.type,
            trackerID: tracker.id, color: nil)
    }

    private func entry(_ date: Date, hours: Double, tracker: Tracker) -> Entry {
        Entry(date: date, duration: hours * 3_600, tracker: tracker)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
