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
    func onlyTheSetupPagesAreNumbered() {
        #expect(OnboardingStep.allCases.map(\.setupNumber) == [nil, 1, 2])
        #expect(OnboardingStep.setupCount == 2)
    }

    @Test
    func aFilledInSettingTheUserHasNotChangedShowsTheCloudNote() {
        #expect(OnboardingStep.publisherStatus.showsCloudNote(hasValue: true, changedSteps: []))
        #expect(OnboardingStep.overseer.showsCloudNote(hasValue: true, changedSteps: [.publisherStatus]))
    }

    @Test
    func anEmptyOrChangedSettingShowsNoCloudNote() {
        #expect(!OnboardingStep.publisherStatus.showsCloudNote(hasValue: false, changedSteps: []))
        #expect(!OnboardingStep.overseer.showsCloudNote(hasValue: true, changedSteps: [.overseer]))
    }
}
