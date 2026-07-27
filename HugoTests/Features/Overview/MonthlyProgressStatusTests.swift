import Testing
@testable import Hugo

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
}
