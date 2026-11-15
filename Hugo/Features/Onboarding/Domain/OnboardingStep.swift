/// One page of the first-run setup, in order.
nonisolated enum OnboardingStep: Int, CaseIterable, Hashable {
    case welcome
    case publisherStatus
    case overseer

    /// The page's number in "Step 1 of 2". The welcome page has none.
    var setupNumber: Int? {
        self == .welcome ? nil : rawValue
    }

    /// How many pages show "Step N of …": every page except the welcome page.
    static var setupCount: Int {
        allCases.filter { $0.setupNumber != nil }.count
    }

    /// The page after this one, or nil after the last page.
    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    /// Whether this page says that its setting came from the user's other
    /// devices through iCloud: the setting is filled in, and the user hasn't
    /// changed it during this onboarding. On a new install, a setting the user
    /// didn't enter can only have come from iCloud.
    func showsCloudNote(hasValue: Bool, changedSteps: Set<OnboardingStep>) -> Bool {
        hasValue && !changedSteps.contains(self)
    }
}
