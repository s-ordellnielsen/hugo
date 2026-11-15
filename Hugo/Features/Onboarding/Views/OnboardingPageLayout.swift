import SwiftUI

/// The layout every onboarding page shares: the step counter (setup pages
/// only), a serif title, a short explanation, a note when the setting came
/// from iCloud, then the page's own content. It scrolls, so the pages work at
/// the largest text sizes. `OnboardingView` puts the buttons in a bar below it.
struct OnboardingPageLayout<Content: View>: View {
    private let step: OnboardingStep
    private let title: LocalizedStringKey
    private let explanation: LocalizedStringKey
    private let showsCloudNote: Bool
    private let content: Content

    init(
        step: OnboardingStep,
        title: LocalizedStringKey,
        explanation: LocalizedStringKey,
        showsCloudNote: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.step = step
        self.title = title
        self.explanation = explanation
        self.showsCloudNote = showsCloudNote
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.card) {
                VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                    if let number = step.setupNumber {
                        Text("onboarding.step.\(number).\(OnboardingStep.setupCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .textCase(.uppercase)
                            .tracking(HugoLayout.Typography.eyebrowTracking)
                            .foregroundStyle(.secondary)
                    }
                    Text(title)
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                    Text(explanation)
                }

                if showsCloudNote {
                    Label("onboarding.cloudNote", systemImage: "icloud")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }

                content
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .motion(Motion.presence, value: showsCloudNote)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        OnboardingPageLayout(
            step: .publisherStatus,
            title: "onboarding.publisherStatus.title",
            explanation: "onboarding.publisherStatus.explanation",
            showsCloudNote: true
        ) {
            Text(verbatim: "Content")
        }
    }
}
