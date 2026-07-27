import Foundation
import Testing
@testable import Hugo

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

    @Test(arguments: ["", "unknown"])
    func returnsNilForUnknownStatus(identifier: String) {
        #expect(PublisherStatus.status(for: identifier) == nil)
    }
}
