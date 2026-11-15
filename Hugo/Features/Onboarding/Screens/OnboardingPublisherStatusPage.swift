import SwiftUI

/// Onboarding step 1 of 2: the publisher status, which sets the user's goal.
/// `OnboardingView` keeps Continue off until a status is chosen.
struct OnboardingPublisherStatusPage: View {
    /// Whether to say that the status came from the user's other devices.
    let showsCloudNote: Bool
    /// Called when the user picks a status on this page.
    let onChange: () -> Void

    @AppStorage(UserDefaultsKeys.publisherStatus) private var currentStatus = ""

    /// The stored status. Setting it also calls `onChange`.
    private var selection: Binding<String> {
        Binding(
            get: { currentStatus },
            set: { newValue in
                currentStatus = newValue
                onChange()
            }
        )
    }

    var body: some View {
        OnboardingPageLayout(
            step: .publisherStatus,
            title: "onboarding.publisherStatus.title",
            explanation: "onboarding.publisherStatus.explanation",
            showsCloudNote: showsCloudNote
        ) {
            VStack(spacing: HugoLayout.Spacing.compact) {
                PublisherStatusOptionsView(selection: selection, rowStyle: .card)
            }
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingPublisherStatusPage(showsCloudNote: true, onChange: {})
    }
}
