import Foundation
import Testing

@testable import Hugo

struct YearlyGoalRuleTests {
    private let rule = YearlyGoalRule(monthlyGoalSeconds: 50 * 3_600, separateAllowanceSeconds: 5 * 3_600)

    private func credited(main: Double, separate: Double) -> Double {
        rule.creditedSeconds(main: main * 3_600, separate: separate * 3_600) / 3_600
    }

    @Test
    func mainAboveTheGoalCountsInFull() {
        #expect(credited(main: 65, separate: 0) == 65)
    }

    @Test
    func separateFillsTheGapUpToTheAllowance() {
        #expect(credited(main: 40, separate: 20) == 55)
    }

    @Test
    func separateIsIgnoredWhenMainAlreadyExceedsTheGoalPlusAllowance() {
        #expect(credited(main: 65, separate: 10) == 65)
    }

    @Test
    func separateCountsOnlyTheAllowanceWhenMainMeetsTheGoal() {
        #expect(credited(main: 50, separate: 10) == 55)
    }

    @Test
    func separateAloneIsCappedAtTheGoalPlusAllowance() {
        #expect(credited(main: 0, separate: 100) == 55)
    }

    @Test
    func nothingCreditsNothing() {
        #expect(credited(main: 0, separate: 0) == 0)
    }

    @Test
    func fractionalMinutesSurvive() {
        let seconds = rule.creditedSeconds(main: 49 * 3_600 + 30 * 60, separate: 10 * 3_600)
        #expect(seconds == 55 * 3_600)
        let partial = rule.creditedSeconds(main: 49 * 3_600 + 30 * 60, separate: 60)
        #expect(partial == 49 * 3_600 + 31 * 60)
    }

    @Test
    func regularPioneerHasTheFiftyAndFiveHourRule() {
        let rule = PublisherStatus.status(for: "regular-pioneer")?.yearlyGoalRule
        #expect(rule == YearlyGoalRule(monthlyGoalSeconds: 50 * 3_600, separateAllowanceSeconds: 5 * 3_600))
    }

    @Test
    func statusesWithoutAYearlyGoalHaveNoRule() {
        #expect(PublisherStatus.status(for: "auxiliary-pioneer")?.yearlyGoalRule == nil)
        #expect(PublisherStatus.status(for: "publisher")?.yearlyGoalRule == nil)
    }
}
