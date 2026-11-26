import Foundation
import Testing

@testable import Hugo

struct PlanMoveRuleTests {
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
    func cannotDropOnPastDay() {
        let target = day(1)
        let source = CalendarDay(year: 2026, month: 11, day: 10)
        #expect(!PlanMoveRule.canDrop(from: source, on: target))
        #expect(!PlanMoveRule.acceptsDrops(target))
    }

    @Test
    func cannotDropOnSourceDay() {
        let target = day(10)
        #expect(!PlanMoveRule.canDrop(from: target.id, on: target))
    }

    @Test
    func canDropOnTodayAndLater() {
        let source = CalendarDay(year: 2026, month: 11, day: 1)
        #expect(PlanMoveRule.canDrop(from: source, on: day(3)))
        #expect(PlanMoveRule.canDrop(from: source, on: day(20)))
    }

    private func day(_ number: Int) -> PlannerDay {
        PlannerMonth.make(month: november, items: [], entries: [], now: now, calendar: calendar)
            .days[number - 1]
    }
}
