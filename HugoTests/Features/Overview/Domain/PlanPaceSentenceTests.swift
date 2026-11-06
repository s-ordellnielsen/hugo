import Testing

@testable import Hugo

struct PlanPaceSentenceTests {
    private let onPlan = PlanPace(expectedSeconds: 10 * 3_600, loggedSeconds: 10 * 3_600)
    private let nearlyOnPlan = PlanPace(expectedSeconds: 10 * 3_600, loggedSeconds: 10 * 3_600 - 59)
    private let ahead = PlanPace(expectedSeconds: 10 * 3_600, loggedSeconds: 13 * 3_600)
    private let behind = PlanPace(expectedSeconds: 10 * 3_600, loggedSeconds: 6 * 3_600)

    @Test
    func smallDifferencesReadAsOnPlan() {
        #expect(nearlyOnPlan.differenceSentence == onPlan.differenceSentence)
    }

    @Test
    func aheadAndBehindNameTheDifference() {
        #expect(ahead.differenceSentence.contains("3"))
        #expect(behind.differenceSentence.contains("4"))
        #expect(ahead.differenceSentence != behind.differenceSentence)
        #expect(ahead.differenceSentence != onPlan.differenceSentence)
        #expect(behind.differenceSentence != onPlan.differenceSentence)
    }
}
