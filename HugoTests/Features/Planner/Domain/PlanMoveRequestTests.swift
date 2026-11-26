import Foundation
import Testing

@testable import Hugo

struct PlanMoveRequestTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let november = YearMonth(year: 2026, month: 11)
    private let main = Tracker(name: "Field Service", type: .main, iconName: "figure.walk")
    private let separate = Tracker(name: "LDC", type: .separate, iconName: "hammer")

    private var now: Date { date(2026, 11, 3, hour: 12) }

    @Test
    func dayWithPlansCarriesTheirIDs() throws {
        let day = CalendarDay(year: 2026, month: 11, day: 10)
        let first = item(day, hours: 2, tracker: main)
        let second = item(day, hours: 1, tracker: separate)
        let month = makeMonth(items: [first, second], entries: [])

        let request = try #require(PlanMoveRequest(day: month.days[9]))

        #expect(Set(request.planIDs) == Set([first, second].compactMap { UUID(uuidString: $0.id) }))
        #expect(request.sourceDay == day)
    }

    @Test
    func dayWithOnlyLoggedTimeCarriesNothing() {
        let entries = [Entry(date: date(2026, 11, 3, hour: 10), duration: 3_600, tracker: main)]
        let month = makeMonth(items: [], entries: entries)
        #expect(PlanMoveRequest(day: month.days[2]) == nil)
    }

    @Test
    func emptyDayCarriesNothing() {
        let month = makeMonth(items: [], entries: [])
        #expect(PlanMoveRequest(day: month.days[9]) == nil)
    }

    @Test
    func itemWithNonUUIDIDIsSkipped() throws {
        let day = CalendarDay(year: 2026, month: 11, day: 10)
        let normal = item(day, hours: 2, tracker: main)
        let repeating = item(day, hours: 1, tracker: separate, id: "repeat:1")
        let month = makeMonth(items: [normal, repeating], entries: [])

        let request = try #require(PlanMoveRequest(day: month.days[9]))

        #expect(request.planIDs == [UUID(uuidString: normal.id)!])
    }

    @Test
    func requestRoundTripsThroughJSON() throws {
        let request = PlanMoveRequest(
            planIDs: [UUID(), UUID()], sourceDay: CalendarDay(year: 2026, month: 11, day: 10))

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(PlanMoveRequest.self, from: data)

        #expect(decoded == request)
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
