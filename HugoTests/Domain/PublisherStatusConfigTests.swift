import Foundation
import Testing
@testable import Hugo

struct PublisherStatusConfigTests {
    @Test
    func convertsYearlyGoalToMonthlyGoal() {
        let config = PublisherStatusConfig(id: "yearly", nameKey: "", shortName: "", goalType: .yearly, goal: 600)
        #expect(config.monthlyGoal() == 50)
    }

    @Test
    func convertsMonthlyGoalToYearlyGoal() {
        let config = PublisherStatusConfig(id: "monthly", nameKey: "", shortName: "", goalType: .monthly, goal: 30)
        #expect(config.yearlyGoal() == 360)
    }

    @Test
    func resolvesKnownStatus() {
        #expect(PublisherStatusConfig.current("regular-pioneer")?.id == "regular-pioneer")
    }

    @Test(arguments: ["", "unknown"])
    func returnsNilForUnknownStatus(identifier: String) {
        #expect(PublisherStatusConfig.current(identifier) == nil)
    }
}
