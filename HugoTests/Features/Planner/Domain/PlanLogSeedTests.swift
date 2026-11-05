import Foundation
import Testing

@testable import Hugo

struct PlanLogSeedTests {
    private let fieldServiceID = UUID()
    private let day = CalendarDay(year: 2026, month: 11, day: 5)

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test
    func unloggedPlanSeedsTheWholePlan() throws {
        let item = plan("p", fieldServiceID, type: .main, hours: 2, startMinute: 600)
        let bar = try planBar([item])

        let seed = PlanLogSeed(bar: bar, day: day, calendar: calendar)

        #expect(seed.id == "plan:\(fieldServiceID.uuidString)")
        #expect(seed.duration == 7_200)
        #expect(seed.trackerID == fieldServiceID)
        #expect(seed.startMinute == 600)
        #expect(
            seed.date == calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 12)))
    }

    @Test
    func partlyLoggedPlanSeedsOnlyTheRemainingTime() throws {
        let item = plan("p", fieldServiceID, type: .main, hours: 2)
        let logged = [time(fieldServiceID, name: "Field Service", type: .main, seconds: 3_600)]
        let bar = try planBar([item], logged: logged)

        let seed = PlanLogSeed(bar: bar, day: day, calendar: calendar)

        #expect(seed.duration == 3_600)
    }

    @Test
    func remainingTimeIsRoundedDownToWholeMinutes() throws {
        let item = plan("p", fieldServiceID, type: .main, hours: 1)
        let logged = [time(fieldServiceID, name: "Field Service", type: .main, seconds: 1_830)]
        let bar = try planBar([item], logged: logged)

        let seed = PlanLogSeed(bar: bar, day: day, calendar: calendar)

        #expect(seed.duration == 1_740)
    }

    @Test
    func startTimeComesFromTheFirstPlanNotCoveredYet() throws {
        let plans = [
            plan("morning", fieldServiceID, type: .main, hours: 2, startMinute: 600),
            plan("afternoon", fieldServiceID, type: .main, hours: 3, startMinute: 840),
        ]
        let logged = [time(fieldServiceID, name: "Field Service", type: .main, seconds: 9_000)]
        let bar = try planBar(plans, logged: logged)

        let seed = PlanLogSeed(bar: bar, day: day, calendar: calendar)

        #expect(seed.duration == 9_000)
        #expect(seed.startMinute == 840)
    }

    @Test
    func startTimeIsNilWhenThatPlanHasNone() throws {
        let plans = [
            plan("a", fieldServiceID, type: .main, hours: 1, startMinute: 600),
            plan("b", fieldServiceID, type: .main, hours: 1, startMinute: nil),
        ]
        let logged = [time(fieldServiceID, name: "Field Service", type: .main, seconds: 3_600)]
        let bar = try planBar(plans, logged: logged)

        let seed = PlanLogSeed(bar: bar, day: day, calendar: calendar)

        #expect(seed.duration == 3_600)
        #expect(seed.startMinute == nil)
    }

    private func planBar(_ plans: [PlannedItem], logged: [LoggedCategoryTime] = []) throws -> PlannerBar {
        try #require(PlanMatcher.bars(plans: plans, logged: logged).first { $0.kind == .plan })
    }

    private func plan(
        _ id: String, _ trackerID: UUID, type: TrackerType, hours: Double, startMinute: Int? = nil
    ) -> PlannedItem {
        PlannedItem(
            id: id, day: CalendarDay(year: 2026, month: 11, day: 5), duration: hours * 3_600,
            startMinute: startMinute, categoryName: "Category", categoryIconName: "figure.walk",
            categoryType: type, trackerID: trackerID, color: nil)
    }

    private func time(
        _ id: UUID, name: String, type: TrackerType, seconds: TimeInterval
    ) -> LoggedCategoryTime {
        LoggedCategoryTime(
            key: id.uuidString, name: name, iconName: "figure.walk", type: type, color: nil,
            seconds: seconds)
    }
}
