import Foundation
import Testing

@testable import Hugo

struct PlannerDayActionsTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let november = YearMonth(year: 2026, month: 11)

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 12))!
    }

    @Test
    func pastDayOffersLogTimeOnly() {
        let actions = PlannerDayActions(day: makeMonth().days[0])
        #expect(actions.canAddPlan == false)
        #expect(actions.canLogTime == true)
    }

    @Test
    func todayOffersBoth() {
        let actions = PlannerDayActions(day: makeMonth().days[2])
        #expect(actions.canAddPlan == true)
        #expect(actions.canLogTime == true)
    }

    @Test
    func futureDayOffersAddPlanOnly() {
        let actions = PlannerDayActions(day: makeMonth().days[9])
        #expect(actions.canAddPlan == true)
        #expect(actions.canLogTime == false)
    }

    private func makeMonth() -> PlannerMonth {
        PlannerMonth.make(month: november, items: [], entries: [], now: now, calendar: calendar)
    }
}
