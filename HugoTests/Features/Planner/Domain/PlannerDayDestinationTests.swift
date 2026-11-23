import Foundation
import Testing

@testable import Hugo

struct PlannerDayDestinationTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let november = YearMonth(year: 2026, month: 11)
    private let main = Tracker(name: "Field Service", type: .main, iconName: "figure.walk")

    private var now: Date { date(2026, 11, 3, hour: 12) }

    @Test
    func emptyFutureDayOpensAddPlan() {
        let month = makeMonth(items: [], entries: [])
        #expect(PlannerDayDestination(day: month.days[9]) == .addPlan)
    }

    @Test
    func emptyTodayOpensAddPlan() {
        let month = makeMonth(items: [], entries: [])
        #expect(PlannerDayDestination(day: month.days[2]) == .addPlan)
    }

    @Test
    func emptyPastDayOpensDaySheet() {
        let month = makeMonth(items: [], entries: [])
        #expect(PlannerDayDestination(day: month.days[0]) == .daySheet)
    }

    @Test
    func dayWithPlanOpensDaySheet() {
        let items = [item(CalendarDay(year: 2026, month: 11, day: 10), hours: 2, tracker: main)]
        let month = makeMonth(items: items, entries: [])
        #expect(PlannerDayDestination(day: month.days[9]) == .daySheet)
    }

    @Test
    func dayWithOnlyLoggedEntryOpensDaySheet() {
        let entries = [Entry(date: date(2026, 11, 3, hour: 10), duration: 3_600, tracker: main)]
        let month = makeMonth(items: [], entries: entries)
        #expect(PlannerDayDestination(day: month.days[2]) == .daySheet)
    }

    private func makeMonth(items: [PlannedItem], entries: [Entry]) -> PlannerMonth {
        PlannerMonth.make(month: november, items: items, entries: entries, now: now, calendar: calendar)
    }

    private func item(
        _ day: CalendarDay, hours: Double, tracker: Tracker, id: String = UUID().uuidString
    ) -> PlannedItem {
        PlannedItem(
            id: id, day: day, duration: hours * 3_600, startMinute: nil,
            categoryName: tracker.name, categoryIconName: tracker.iconName, categoryType: tracker.type,
            trackerID: tracker.id, color: nil)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
