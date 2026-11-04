import Foundation
import Testing

@testable import Hugo

struct PlanPaceTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let main = Tracker(name: "Field Service", type: .main, iconName: "figure.walk")

    @Test
    func noPlansMeansNoPace() {
        let month = makeNovember(items: [], entries: [entry(date(2026, 11, 2, hour: 10), hours: 1)])
        #expect(PlanPace.make(month: month) == nil)
    }

    @Test
    func plansOnlyAfterTodayExpectNothingYet() throws {
        let month = makeNovember(
            items: [item(CalendarDay(year: 2026, month: 11, day: 10), hours: 5)],
            entries: [entry(date(2026, 11, 5, hour: 10), hours: 4)])

        let pace = try #require(PlanPace.make(month: month))

        #expect(pace.expectedSeconds == 0)
        #expect(pace.differenceSeconds == 4 * 3_600)
    }

    @Test
    func missedPlanOnAPastDayShowsBehind() throws {
        let month = makeNovember(
            items: [item(CalendarDay(year: 2026, month: 11, day: 2), hours: 3)],
            entries: [entry(date(2026, 11, 2, hour: 10), hours: 1)])

        let pace = try #require(PlanPace.make(month: month))

        #expect(pace.expectedSeconds == 3 * 3_600)
        #expect(pace.differenceSeconds == -2 * 3_600)
    }

    @Test
    func todaysPlanCountsAgainstNoOneUntilLogged() throws {
        let month = makeNovember(
            items: [item(CalendarDay(year: 2026, month: 11, day: 3), hours: 2)],
            entries: [])

        let pace = try #require(PlanPace.make(month: month))

        #expect(pace.expectedSeconds == 0)
        #expect(pace.differenceSeconds == 0)
    }

    @Test
    func loggingMoreThanTodaysPlanShowsAhead() throws {
        let month = makeNovember(
            items: [item(CalendarDay(year: 2026, month: 11, day: 3), hours: 2)],
            entries: [entry(date(2026, 11, 3, hour: 10), hours: 3)])

        let pace = try #require(PlanPace.make(month: month))

        #expect(pace.expectedSeconds == 2 * 3_600)
        #expect(pace.differenceSeconds == 1 * 3_600)
    }

    @Test
    func todaysPlanExpectsOnlyWhatIsLoggedSoFar() throws {
        let month = makeNovember(
            items: [item(CalendarDay(year: 2026, month: 11, day: 3), hours: 2)],
            entries: [entry(date(2026, 11, 3, hour: 10), hours: 1)])

        let pace = try #require(PlanPace.make(month: month))

        #expect(pace.expectedSeconds == 1 * 3_600)
        #expect(pace.differenceSeconds == 0)
    }

    private func makeNovember(items: [PlannedItem], entries: [Entry]) -> PlannerMonth {
        PlannerMonth.make(
            month: YearMonth(year: 2026, month: 11), items: items, entries: entries,
            now: date(2026, 11, 3, hour: 12), calendar: calendar)
    }

    private func item(_ day: CalendarDay, hours: Double) -> PlannedItem {
        PlannedItem(
            id: UUID().uuidString, day: day, duration: hours * 3_600, startMinute: nil,
            categoryName: main.name, categoryIconName: main.iconName, categoryType: main.type,
            trackerID: main.id, color: nil)
    }

    private func entry(_ date: Date, hours: Double) -> Entry {
        Entry(date: date, duration: hours * 3_600, tracker: main)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
