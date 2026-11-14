/// One page of the first-run setup, in order.
nonisolated enum OnboardingStep: Int, CaseIterable, Hashable {
    case welcome
    case publisherStatus
    case overseer
    case greeting

    /// The step's position for "Step 2 of 4", starting at 1.
    var number: Int { rawValue + 1 }

    static var count: Int { allCases.count }

    /// The page after this one. Pages for settings that already exist, for
    /// example synced from the user's other devices, are skipped. Nil means
    /// the setup is finished.
    func next(hasOverseer: Bool, hasGreeting: Bool) -> OnboardingStep? {
        var candidate = OnboardingStep(rawValue: rawValue + 1)
        while let step = candidate {
            switch step {
            case .overseer where hasOverseer, .greeting where hasGreeting:
                candidate = OnboardingStep(rawValue: step.rawValue + 1)
            default:
                return step
            }
        }
        return nil
    }
}
