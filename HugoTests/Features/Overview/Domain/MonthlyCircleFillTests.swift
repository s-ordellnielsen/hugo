import Testing

@testable import Hugo

struct MonthlyCircleFillTests {
    @Test
    func goalSetsTheScale() {
        let fill = MonthlyCircleFill.make(
            monthlyGoalHours: 30, loggedSeconds: 15 * 3_600, plannedSeconds: 0, hasOwnEntries: true)
        #expect(fill.fraction == 0.5)
        #expect(fill.basis == .monthlyGoal(hours: 30))
    }

    @Test
    func goalWinsOverPlans() {
        let fill = MonthlyCircleFill.make(
            monthlyGoalHours: 30, loggedSeconds: 15 * 3_600, plannedSeconds: 20 * 3_600, hasOwnEntries: true)
        #expect(fill.fraction == 0.5)
        #expect(fill.basis == .monthlyGoal(hours: 30))
    }

    @Test
    func goalCapsAtFull() {
        let fill = MonthlyCircleFill.make(
            monthlyGoalHours: 30, loggedSeconds: 40 * 3_600, plannedSeconds: 0, hasOwnEntries: true)
        #expect(fill.fraction == 1)
    }

    @Test
    func withoutGoalPlansSetTheScale() {
        let fill = MonthlyCircleFill.make(
            monthlyGoalHours: 0, loggedSeconds: 5 * 3_600, plannedSeconds: 20 * 3_600, hasOwnEntries: true)
        #expect(fill.fraction == 0.25)
        #expect(fill.basis == .plan(plannedSeconds: 20 * 3_600))
    }

    @Test
    func withoutGoalPlansCapAtFull() {
        let fill = MonthlyCircleFill.make(
            monthlyGoalHours: 0, loggedSeconds: 25 * 3_600, plannedSeconds: 20 * 3_600, hasOwnEntries: true)
        #expect(fill.fraction == 1)
    }

    @Test
    func withoutGoalOrPlansAnOwnEntryFillsTheCircle() {
        let fill = MonthlyCircleFill.make(
            monthlyGoalHours: 0, loggedSeconds: 0.5 * 3_600, plannedSeconds: 0, hasOwnEntries: true)
        #expect(fill.fraction == 1)
        #expect(fill.basis == .presence)
    }

    @Test
    func withoutGoalOrPlansNoEntryLeavesItEmpty() {
        let fill = MonthlyCircleFill.make(
            monthlyGoalHours: 0, loggedSeconds: 0, plannedSeconds: 0, hasOwnEntries: false)
        #expect(fill.fraction == 0)
        #expect(fill.basis == .presence)
    }

    @Test
    func negativeLoggedTimeCountsAsZero() {
        let fill = MonthlyCircleFill.make(
            monthlyGoalHours: 30, loggedSeconds: -100, plannedSeconds: 0, hasOwnEntries: false)
        #expect(fill.fraction == 0)
    }
}
