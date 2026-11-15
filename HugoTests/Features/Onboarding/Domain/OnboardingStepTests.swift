import Testing

@testable import Hugo

struct OnboardingStepTests {
    @Test
    func everyStepFollowsTheOneBefore() {
        #expect(OnboardingStep.welcome.next == .publisherStatus)
        #expect(OnboardingStep.publisherStatus.next == .overseer)
        #expect(OnboardingStep.overseer.next == nil)
    }

    @Test
    func numbersCountFromOne() {
        #expect(OnboardingStep.allCases.map(\.number) == [1, 2, 3])
        #expect(OnboardingStep.count == 3)
    }
}
