import Foundation
import Testing

@testable import Hugo

struct PlannerMonthTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let november = YearMonth(year: 2026, month: 11)
    private let december = YearMonth(year: 2026, month: 12)
    private let main = Tracker(name: "Field Service", type: .main, iconName: "figure.walk")
    private let separate = Tracker(name: "LDC", type: .separate, iconName: "hammer")
    private let phone = Tracker(name: "Phone Witnessing", type: .main, iconName: "phone")

    private var now: Date { date(2026, 11, 3, hour: 12) }

    @Test
    func novemberHasThirtyDaysWithTodayAndPastFlagsSet() {
        let month = makeMonth(items: [], entries: [])
        #expect(month.days.count == 30)
        #expect(month.days[2].isToday)
        #expect(month.days[1].isPast)
        #expect(month.days[3].isPast == false)
    }

    @Test
    func loggedTimeSplitsByKindAndIgnoresOtherMonths() {
        let entries = [
            Entry(date: date(2026, 11, 1, hour: 10), duration: 3_600, tracker: main),
            Entry(date: date(2026, 11, 2, hour: 10), duration: 1_800, tracker: separate),
            Entry(date: date(2026, 12, 1, hour: 10), duration: 7_200, tracker: main),
        ]
        let month = makeMonth(items: [], entries: entries)
        #expect(month.logged == TimeSplit(main: 3_600, separate: 1_800))
    }

    @Test
    func untrackedEntryCountsAsMain() {
        let entries = [Entry(date: date(2026, 11, 1, hour: 10), duration: 3_600, tracker: nil)]
        let month = makeMonth(items: [], entries: entries)
        #expect(month.logged == TimeSplit(main: 3_600, separate: 0))
    }

    @Test
    func stillPlannedCountsOnlyTodayAndLaterDays() {
        let items = [
            item(CalendarDay(year: 2026, month: 11, day: 1), hours: 2, tracker: main),
            item(CalendarDay(year: 2026, month: 11, day: 3), hours: 3, tracker: main),
            item(CalendarDay(year: 2026, month: 11, day: 10), hours: 2, tracker: main),
        ]
        let entries = [Entry(date: date(2026, 11, 3, hour: 10), duration: 3_600, tracker: main)]
        let month = makeMonth(items: items, entries: entries)

        #expect(month.stillPlanned.total == 4 * 3_600)
        #expect(month.projected.total == month.logged.total + 4 * 3_600)
    }

    @Test
    func loggedAbovePlanTodayAddsNothingAndNeverGoesNegative() {
        let items = [item(CalendarDay(year: 2026, month: 11, day: 3), hours: 1, tracker: main)]
        let entries = [Entry(date: date(2026, 11, 3, hour: 10), duration: 3 * 3_600, tracker: main)]
        let month = makeMonth(items: items, entries: entries)
        #expect(month.stillPlanned == TimeSplit(main: 0, separate: 0))
    }

    @Test
    func separateAndMainAreKeptApartWhenStillPlanned() {
        let items = [item(CalendarDay(year: 2026, month: 11, day: 3), hours: 2, tracker: separate)]
        let entries = [Entry(date: date(2026, 11, 3, hour: 10), duration: 2 * 3_600, tracker: main)]
        let month = makeMonth(items: items, entries: entries)
        #expect(month.stillPlanned == TimeSplit(main: 0, separate: 7_200))
    }

    @Test
    func futureMonthLeavesEveryPlannedSecondStillPlanned() {
        let items = [
            item(CalendarDay(year: 2026, month: 12, day: 5), hours: 2, tracker: main),
            item(CalendarDay(year: 2026, month: 12, day: 6), hours: 1, tracker: separate),
        ]
        let month = PlannerMonth.make(
            month: december, items: items, entries: [], now: now, calendar: calendar)
        #expect(month.stillPlanned == month.planned)
        #expect(month.stillPlanned.total == 3 * 3_600)
    }

    @Test
    func hasPlansIsFalseWithoutItemsAndTrueWithOne() {
        #expect(makeMonth(items: [], entries: []).hasPlans == false)
        let items = [item(CalendarDay(year: 2026, month: 11, day: 10), hours: 1, tracker: main)]
        #expect(makeMonth(items: items, entries: []).hasPlans)
    }

    @Test
    func reachableMonthsCoverTheNextTwelveMonths() {
        let months = PlannerMonth.reachableMonths(from: date(2026, 11, 3), calendar: calendar)
        #expect(months.count == 12)
        #expect(months.first == YearMonth(year: 2026, month: 11))
        #expect(months.last == YearMonth(year: 2027, month: 10))
    }

    @Test
    func plannedItemUsesTheLiveCategoryNameWhenItExists() {
        let tracker = Tracker(name: "Field Service", type: .main, iconName: "figure.walk")
        let plan = Plan(date: date(2026, 11, 10), duration: 3_600, tracker: tracker)
        tracker.name = "Renamed Service"

        let live = PlannedItem(plan, trackers: [tracker], calendar: calendar)
        #expect(live.categoryName == "Renamed Service")

        let snapshot = PlannedItem(plan, trackers: [], calendar: calendar)
        #expect(snapshot.categoryName == "Field Service")
    }

    @Test
    func plannedItemCategoryKeyMatchesTheEntryCategoryKey() {
        let plan = Plan(date: date(2026, 11, 10), duration: 3_600, tracker: main)
        let item = PlannedItem(plan, trackers: [main], calendar: calendar)
        let entry = Entry(date: date(2026, 11, 10, hour: 10), duration: 3_600, tracker: main)
        #expect(item.categoryKey == entry.resolvedCategory().key)
    }

    @Test
    func loggedTimeWithoutAPlanIsOneFullUnplannedBar() {
        let entries = [Entry(date: date(2026, 11, 1, hour: 10), duration: 3_600, tracker: main)]
        let month = makeMonth(items: [], entries: entries)

        let bars = month.days[0].bars
        #expect(bars.count == 1)
        #expect(bars.first?.kind == .unplanned)
        #expect(bars.first?.seconds == 3_600)
        #expect(bars.first?.fraction == 1)
        #expect(month.days[4].bars.isEmpty)
    }

    @Test
    func planBarsAgreeWithStillPlannedTimePerKind() {
        let day = CalendarDay(year: 2026, month: 11, day: 5)
        let fieldService = item(day, hours: 2, tracker: main, id: "fs")
        let phoneItem = item(day, hours: 1, tracker: phone, id: "phone")
        let ldc = item(day, hours: 1, tracker: separate, id: "ldc")
        let entries = [
            Entry(date: date(2026, 11, 5, hour: 9), duration: 2.5 * 3_600, tracker: main),
            Entry(date: date(2026, 11, 5, hour: 13), duration: 2 * 3_600, tracker: separate),
        ]

        let planned = PlannerDay.make(
            day: day, items: [fieldService, phoneItem, ldc], entries: entries,
            trackers: [main, phone, separate], today: CalendarDay(year: 2026, month: 11, day: 3))

        let mainRemaining = planned.bars.filter { $0.items.first?.categoryType == .main }
            .reduce(0) { $0 + $1.remainingSeconds }
        let separateRemaining = planned.bars.filter { $0.items.first?.categoryType == .separate }
            .reduce(0) { $0 + $1.remainingSeconds }
        let expected = planned.planned.remaining(after: planned.logged)

        #expect(expected.main == 1_800)
        #expect(mainRemaining == expected.main)
        #expect(separateRemaining == expected.separate)
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
