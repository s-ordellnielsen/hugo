/// One page of the first-run setup, in order.
nonisolated enum OnboardingStep: Int, CaseIterable, Hashable {
    case welcome
    case publisherStatus
    case overseer
    case greeting

    /// The step's position for "Step 2 of 4", starting at 1.
    var number: Int { rawValue + 1 }

    static var count: Int { allCases.count }

    /// The page after this one, or nil after the last page.
    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
}
