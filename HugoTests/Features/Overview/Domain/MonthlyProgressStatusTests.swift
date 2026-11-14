import Testing

@testable import Hugo

@MainActor
struct MonthlyProgressStatusTests {
    @Test(arguments: [
        (6.0, MonthlyProgressStatus.wayAboveTarget),
        (3.0, MonthlyProgressStatus.aboveTarget),
        (2.0, MonthlyProgressStatus.onTarget),
        (-2.0, MonthlyProgressStatus.onTarget),
        (-3.0, MonthlyProgressStatus.belowTarget),
        (-6.0, MonthlyProgressStatus.wayBelowTarget),
    ])
    func thresholds(input: (Double, MonthlyProgressStatus)) {
        #expect(MonthlyProgressStatus.make(expected: 10, current: 10 + input.0) == input.1)
    }

    @Test
    func zeroExpectedProgressIsOnTarget() {
        #expect(MonthlyProgressStatus.make(expected: 0, current: 100) == .onTarget)
    }

    @Test
    func planPaceAboveTarget() {
        let pace = PlanPace(expectedSeconds: 10 * 3_600, loggedSeconds: 13 * 3_600)
        #expect(MonthlyProgressStatus.make(pace: pace) == .aboveTarget)
    }

    @Test
    func planPaceWayBelowTarget() {
        let pace = PlanPace(expectedSeconds: 10 * 3_600, loggedSeconds: 4 * 3_600)
        #expect(MonthlyProgressStatus.make(pace: pace) == .wayBelowTarget)
    }

    @Test
    func planPaceWithoutExpectedTimeIsOnTarget() {
        let pace = PlanPace(expectedSeconds: 0, loggedSeconds: 4 * 3_600)
        #expect(MonthlyProgressStatus.make(pace: pace) == .onTarget)
    }

    @Test(arguments: [
        (MonthlyProgressStatus.wayAboveTarget, true),
        (MonthlyProgressStatus.aboveTarget, false),
        (MonthlyProgressStatus.onTarget, false),
        (MonthlyProgressStatus.belowTarget, false),
        (MonthlyProgressStatus.wayBelowTarget, true),
    ])
    func onlyWayAheadOrWayBehindIsEmphasized(input: (MonthlyProgressStatus, Bool)) {
        #expect(input.0.isEmphasized == input.1)
    }
}
