import Foundation
import Testing

@testable import Hugo

@MainActor
struct PublisherStatusTests {
    @Test
    func convertsYearlyGoalToMonthlyGoal() {
        let config = PublisherStatus(id: "yearly", nameKey: "", shortName: "", goalPeriod: .yearly, goal: 600)
        #expect(config.monthlyGoal == 50)
    }

    @Test
    func convertsMonthlyGoalToYearlyGoal() {
        let config = PublisherStatus(id: "monthly", nameKey: "", shortName: "", goalPeriod: .monthly, goal: 30)
        #expect(config.yearlyGoal == 360)
    }

    @Test
    func resolvesKnownStatus() {
        #expect(PublisherStatus.status(for: "regular-pioneer")?.id == "regular-pioneer")
    }

    @Test
    func aPublisherWithoutAGoalHasNoMonthlyOrYearlyGoal() throws {
        let publisher = try #require(PublisherStatus.status(for: "publisher"))
        #expect(publisher.goal == 0)
        #expect(publisher.monthlyGoal == 0)
        #expect(publisher.yearlyGoal == 0)
        #expect(publisher.yearlyGoalRule == nil)
    }

    @Test
    func aYearlyStatusWithAGoalOfZeroHasNoRule() {
        let config = PublisherStatus(id: "yearly-zero", nameKey: "", shortName: "", goalPeriod: .yearly, goal: 0)
        #expect(config.monthlyGoal == 0)
        #expect(config.yearlyGoal == 0)
        #expect(config.yearlyGoalRule == nil)
    }

    @Test(arguments: ["", "unknown"])
    func returnsNilForUnknownStatus(identifier: String) {
        #expect(PublisherStatus.status(for: identifier) == nil)
    }
}
