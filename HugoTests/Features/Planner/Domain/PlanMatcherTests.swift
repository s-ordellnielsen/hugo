import Foundation
import Testing

@testable import Hugo

struct PlanMatcherTests {
    private let fieldServiceID = UUID()
    private let ldcID = UUID()
    private let phoneID = UUID()

    @Test
    func ownersExampleFillsEachPlanFromItsOwnCategory() throws {
        let plans = [
            plan("fs", fieldServiceID, type: .main, hours: 2),
            plan("ldc", ldcID, type: .separate, hours: 1),
        ]
        let logged = [
            time(fieldServiceID, name: "Field Service", type: .main, hours: 1),
            time(ldcID, name: "LDC", type: .separate, hours: 1),
        ]

        let bars = PlanMatcher.bars(plans: plans, logged: logged)

        #expect(bars.count == 2)
        let fieldService = try #require(bars.first { $0.id == barID(fieldServiceID) })
        #expect(fieldService.fraction == 0.5)
        #expect(fieldService.remainingSeconds == 3_600)
        let ldc = try #require(bars.first { $0.id == barID(ldcID) })
        #expect(ldc.fraction == 1)
        #expect(ldc.isFull)
        #expect(bars.allSatisfy { $0.kind == .plan })
    }

    @Test
    func secondPassLetsAnotherMainCategoryFillThePlan() {
        let plans = [plan("fs", fieldServiceID, type: .main, hours: 2)]
        let logged = [time(phoneID, name: "Phone", type: .main, hours: 2)]

        let bars = PlanMatcher.bars(plans: plans, logged: logged)

        #expect(bars.count == 1)
        #expect(bars.first?.isFull == true)
        #expect(bars.allSatisfy { $0.kind == .plan })
    }

    @Test
    func secondPassRespectsTheKindOfTime() throws {
        let plans = [plan("fs", fieldServiceID, type: .main, hours: 2)]
        let logged = [time(ldcID, name: "LDC", type: .separate, hours: 2)]

        let bars = PlanMatcher.bars(plans: plans, logged: logged)

        let planBar = try #require(bars.first { $0.id == barID(fieldServiceID) })
        #expect(planBar.fraction == 0)
        let unplanned = try #require(bars.first { $0.kind == .unplanned })
        #expect(unplanned.id == "unplanned:\(ldcID.uuidString)")
        #expect(unplanned.seconds == 7_200)
        #expect(unplanned.fraction == 1)
    }

    @Test
    func timeBeyondAPlanStaysOnThePlanBar() throws {
        let plans = [plan("fs", fieldServiceID, type: .main, hours: 1)]
        let logged = [time(fieldServiceID, name: "Field Service", type: .main, hours: 3)]

        let bars = PlanMatcher.bars(plans: plans, logged: logged)

        #expect(bars.count == 1)
        let planBar = try #require(bars.first)
        #expect(planBar.kind == .plan)
        #expect(planBar.filledSeconds == 10_800)
        #expect(planBar.fraction == 1)
        #expect(planBar.isFull == true)
    }

    @Test
    func plansOfOneCategoryShareOneBarInStartTimeOrder() {
        let plans = [
            plan("none", fieldServiceID, type: .main, hours: 1, startMinute: nil),
            plan("late", fieldServiceID, type: .main, hours: 1, startMinute: 840),
            plan("early", fieldServiceID, type: .main, hours: 1, startMinute: 600),
        ]
        let logged = [time(fieldServiceID, name: "Field Service", type: .main, hours: 1.5)]

        let bars = PlanMatcher.bars(plans: plans, logged: logged)

        #expect(bars.count == 1)
        #expect(bars.first?.id == barID(fieldServiceID))
        #expect(bars.first?.items.map(\.id) == ["early", "late", "none"])
        #expect(bars.first?.seconds == 10_800)
        #expect(bars.first?.filledSeconds == 5_400)
        #expect(bars.first?.fraction == 0.5)
    }

    @Test
    func leftoverUnderAMinuteMakesNoUnplannedBar() {
        let plans = [plan("fs", fieldServiceID, type: .main, hours: 1)]
        let logged = [time(fieldServiceID, name: "Field Service", type: .main, seconds: 3_630)]

        let bars = PlanMatcher.bars(plans: plans, logged: logged)

        #expect(bars.count == 1)
        #expect(bars.first?.isFull == true)
        #expect(bars.first?.filledSeconds == 3_630)
    }

    @Test
    func untrackedLoggedTimeFillsAMainPlan() {
        let plans = [plan("fs", fieldServiceID, type: .main, hours: 1)]
        let logged = [
            LoggedCategoryTime(
                key: "untracked", name: "Untracked", iconName: "questionmark.circle", type: nil,
                color: nil, seconds: 3_600)
        ]

        let bars = PlanMatcher.bars(plans: plans, logged: logged)

        #expect(bars.count == 1)
        #expect(bars.first?.isFull == true)
    }

    @Test
    func startTimesDoNotAffectMatching() {
        let plans = [
            plan("morning", fieldServiceID, type: .main, hours: 2, startMinute: 600),
            plan("afternoon", fieldServiceID, type: .main, hours: 3, startMinute: 840),
        ]
        let logged = [time(fieldServiceID, name: "Field Service", type: .main, hours: 2.5)]

        let bars = PlanMatcher.bars(plans: plans, logged: logged)

        #expect(bars.count == 1)
        #expect(bars.first?.seconds == 18_000)
        #expect(bars.first?.filledSeconds == 9_000)
        #expect(bars.first?.remainingSeconds == 9_000)
    }

    @Test
    func barsFollowEachCategorysFirstStartTime() {
        let plans = [
            plan("phone", phoneID, type: .main, hours: 1),
            plan("fs", fieldServiceID, type: .main, hours: 1, startMinute: 600),
            plan("ldc", ldcID, type: .separate, hours: 1, startMinute: 540),
        ]

        let bars = PlanMatcher.bars(plans: plans, logged: [])

        #expect(bars.map(\.id) == [barID(ldcID), barID(fieldServiceID), barID(phoneID)])
    }

    @Test
    func extraTimeFillsAnotherPlanOfTheSameKindFirst() {
        let plans = [
            plan("fs", fieldServiceID, type: .main, hours: 1),
            plan("phone", phoneID, type: .main, hours: 1),
        ]
        let logged = [time(fieldServiceID, name: "Field Service", type: .main, hours: 2)]

        let bars = PlanMatcher.bars(plans: plans, logged: logged)

        #expect(bars.count == 2)
        #expect(bars.allSatisfy { $0.isFull })
        #expect(!bars.contains { $0.kind == .unplanned })
    }

    @Test
    func categoryWithoutAPlanStillGetsItsOwnBar() throws {
        let plans = [plan("fs", fieldServiceID, type: .main, hours: 1)]
        let logged = [
            time(fieldServiceID, name: "Field Service", type: .main, hours: 2),
            time(ldcID, name: "LDC", type: .separate, hours: 1),
        ]

        let bars = PlanMatcher.bars(plans: plans, logged: logged)

        #expect(bars.count == 2)
        let planBar = try #require(bars.first { $0.id == barID(fieldServiceID) })
        #expect(planBar.filledSeconds == 7_200)
        let unplanned = try #require(bars.first { $0.kind == .unplanned })
        #expect(unplanned.id == "unplanned:\(ldcID.uuidString)")
        #expect(unplanned.seconds == 3_600)
    }

    private func barID(_ id: UUID) -> String { "plan:\(id.uuidString)" }

    private func plan(
        _ id: String, _ trackerID: UUID, type: TrackerType, hours: Double, startMinute: Int? = nil
    ) -> PlannedItem {
        PlannedItem(
            id: id, day: CalendarDay(year: 2026, month: 11, day: 5), duration: hours * 3_600,
            startMinute: startMinute, categoryName: "Category", categoryIconName: "figure.walk",
            categoryType: type, trackerID: trackerID, color: nil)
    }

    private func time(
        _ id: UUID, name: String, type: TrackerType, hours: Double
    ) -> LoggedCategoryTime {
        time(id, name: name, type: type, seconds: hours * 3_600)
    }

    private func time(
        _ id: UUID, name: String, type: TrackerType, seconds: TimeInterval
    ) -> LoggedCategoryTime {
        LoggedCategoryTime(
            key: id.uuidString, name: name, iconName: "figure.walk", type: type, color: nil,
            seconds: seconds)
    }
}
