import Foundation
import Testing

@testable import Hugo

struct PlanLogSeedTests {
    private let fieldServiceID = UUID()

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test
    func unloggedPlanSeedsTheWholePlan() throws {
        let item = plan("p", fieldServiceID, type: .main, hours: 2, startMinute: 600)
        let bar = PlanMatcher.bars(plans: [item], logged: []).first

        let seed = PlanLogSeed(item: item, bar: bar, calendar: calendar)

        #expect(seed.id == "p")
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
        let bar = PlanMatcher.bars(plans: [item], logged: logged).first

        let seed = PlanLogSeed(item: item, bar: bar, calendar: calendar)

        #expect(seed.duration == 3_600)
    }

    @Test
    func remainingTimeIsRoundedDownToWholeMinutes() throws {
        let item = plan("p", fieldServiceID, type: .main, hours: 1)
        let logged = [time(fieldServiceID, name: "Field Service", type: .main, seconds: 1_830)]
        let bar = PlanMatcher.bars(plans: [item], logged: logged).first

        let seed = PlanLogSeed(item: item, bar: bar, calendar: calendar)

        #expect(seed.duration == 1_740)
    }

    @Test
    func missingBarSeedsTheWholePlan() {
        let item = plan("p", fieldServiceID, type: .main, hours: 1.5)

        let seed = PlanLogSeed(item: item, bar: nil, calendar: calendar)

        #expect(seed.duration == 5_400)
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
