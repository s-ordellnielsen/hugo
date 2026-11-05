import Foundation
import SwiftData
import Testing

@testable import Hugo

@MainActor
struct PlanServiceTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test
    func addStoresMiddayOnThePlannedDay() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let tracker = Tracker(name: "Field Service", type: .main)
        context.insert(tracker)
        let service = PlanService(context: context, calendar: calendar)

        let plan = try service.add(
            PlanDraft(
                day: CalendarDay(year: 2026, month: 11, day: 4), duration: 7_200, startMinute: 600, tracker: tracker))

        let fetched = try #require(try context.fetch(FetchDescriptor<Plan>()).first)
        #expect(fetched.id == plan.id)
        #expect(fetched.date == date(2026, 11, 4, hour: 12))
        #expect(fetched.duration == 7_200)
        #expect(fetched.startMinute == 600)
        #expect(fetched.categoryID == tracker.id)
        #expect(fetched.categoryName == "Field Service")
    }

    @Test
    func updateChangesDurationCategoryAndStartTime() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let fieldService = Tracker(name: "Field Service", type: .main)
        let ldc = Tracker(name: "LDC", type: .separate)
        context.insert(fieldService)
        context.insert(ldc)
        let day = CalendarDay(year: 2026, month: 11, day: 4)
        let service = PlanService(context: context, calendar: calendar)
        let plan = try service.add(PlanDraft(day: day, duration: 7_200, startMinute: 600, tracker: fieldService))

        try service.update(plan, with: PlanDraft(day: day, duration: 3_600, startMinute: nil, tracker: ldc))

        let fetched = try #require(try context.fetch(FetchDescriptor<Plan>()).first)
        #expect(fetched.duration == 3_600)
        #expect(fetched.startMinute == nil)
        #expect(fetched.categoryID == ldc.id)
        #expect(fetched.categoryName == "LDC")
        #expect(fetched.categoryType == .separate)
    }

    @Test
    func deleteRemovesThePlan() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let tracker = Tracker(name: "Field Service", type: .main)
        context.insert(tracker)
        let service = PlanService(context: context, calendar: calendar)
        let day = CalendarDay(year: 2026, month: 11, day: 4)
        let plan = try service.add(PlanDraft(day: day, duration: 3_600, startMinute: nil, tracker: tracker))

        try service.delete(plan)

        let remaining = try context.fetch(FetchDescriptor<Plan>())
        #expect(remaining.isEmpty)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
