import Testing

@testable import Hugo

struct OnboardingStepTests {
    @Test
    func aNewUserSeesEveryStepInOrder() {
        #expect(OnboardingStep.welcome.next(hasOverseer: false, hasGreeting: false) == .publisherStatus)
        #expect(OnboardingStep.publisherStatus.next(hasOverseer: false, hasGreeting: false) == .overseer)
        #expect(OnboardingStep.overseer.next(hasOverseer: false, hasGreeting: false) == .greeting)
        #expect(OnboardingStep.greeting.next(hasOverseer: false, hasGreeting: false) == nil)
    }

    @Test
    func stepsThatAreAlreadySetUpAreSkipped() {
        #expect(OnboardingStep.publisherStatus.next(hasOverseer: true, hasGreeting: false) == .greeting)
        #expect(OnboardingStep.publisherStatus.next(hasOverseer: false, hasGreeting: true) == .overseer)
        #expect(OnboardingStep.publisherStatus.next(hasOverseer: true, hasGreeting: true) == nil)
        #expect(OnboardingStep.overseer.next(hasOverseer: true, hasGreeting: true) == nil)
    }

    @Test
    func theWelcomeAndPublisherStatusAreNeverSkipped() {
        #expect(OnboardingStep.welcome.next(hasOverseer: true, hasGreeting: true) == .publisherStatus)
    }

    @Test
    func numbersCountFromOne() {
        #expect(OnboardingStep.allCases.map(\.number) == [1, 2, 3, 4])
        #expect(OnboardingStep.count == 4)
    }
}
