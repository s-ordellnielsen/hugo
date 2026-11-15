import SwiftUI

/// The first-run setup: one page per step, pushed in a navigation stack so
/// the user can go back.
struct OnboardingView: View {
    let onComplete: () -> Void

    @AppStorage(UserDefaultsKeys.publisherStatus) private var currentStatus = ""
    @AppStorage(UserDefaultsKeys.overseerFullName) private var overseerFullName = ""

    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            page(for: .welcome)
                .navigationDestination(for: OnboardingStep.self) { step in
                    page(for: step)
                }
        }
        .interactiveDismissDisabled(true)
    }

    private func nextStep(after step: OnboardingStep) -> OnboardingStep? {
        step.next
    }

    private func advance(from step: OnboardingStep) {
        if let next = nextStep(after: step) {
            path.append(next)
        } else {
            onComplete()
        }
    }

    @ViewBuilder
    private func page(for step: OnboardingStep) -> some View {
        let isLast = nextStep(after: step) == nil
        switch step {
        case .welcome:
            welcomePage
                .safeAreaInset(edge: .bottom) {
                    OnboardingStepBar(step: step, isLast: isLast) { advance(from: step) }
                }
        case .publisherStatus:
            publisherStatusPage
                .safeAreaInset(edge: .bottom) {
                    OnboardingStepBar(step: step, isLast: isLast, canContinue: !currentStatus.isEmpty) {
                        advance(from: step)
                    }
                }
        case .overseer:
            OverseerSettingsView(introduction: "onboarding.overseer.introduction")
                .safeAreaInset(edge: .bottom) {
                    OnboardingStepBar(
                        step: step,
                        isLast: isLast,
                        canContinue: !overseerFullName.isEmpty,
                        onSkip: overseerFullName.isEmpty ? { advance(from: step) } : nil
                    ) {
                        advance(from: step)
                    }
                }
        case .greeting:
            GreetingTemplateView(introduction: "onboarding.greeting.introduction")
                .safeAreaInset(edge: .bottom) {
                    OnboardingStepBar(step: step, isLast: isLast) { advance(from: step) }
                }
        }
    }

    private var welcomePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.spacious) {
                Text("splash.subtitle")
                    .font(.title3)
                Text("splash.description.1")
                Text("splash.description.2")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("splash.title")
    }

    private var publisherStatusPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                Text("splash.section.publisherStatus.description")
                    .padding(.horizontal, HugoLayout.Spacing.tight)

                VStack(spacing: HugoLayout.Spacing.compact) {
                    PublisherStatusOptionsView(selection: $currentStatus, rowStyle: .card)
                }
                .padding(.top, HugoLayout.Spacing.spacious)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("splash.section.publisherStatus.title")
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
