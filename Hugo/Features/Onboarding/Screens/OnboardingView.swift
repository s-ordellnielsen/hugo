import SwiftUI

/// The first-run setup: a welcome page, then one page per setting, pushed in
/// a navigation stack so the user can go back.
struct OnboardingView: View {
    let onComplete: () -> Void

    @AppStorage(UserDefaultsKeys.publisherStatus) private var currentStatus = ""
    @AppStorage(UserDefaultsKeys.overseerFullName) private var overseerFullName = ""

    @State private var path: [OnboardingStep] = []
    /// The steps whose setting the user changed during this onboarding. It
    /// lives here, not in the pages, because going back and forward again
    /// creates a page anew.
    @State private var changedSteps: Set<OnboardingStep> = []

    var body: some View {
        NavigationStack(path: $path) {
            page(for: .welcome)
                .navigationDestination(for: OnboardingStep.self) { step in
                    page(for: step)
                }
        }
        .interactiveDismissDisabled(true)
    }

    private func advance(from step: OnboardingStep) {
        if let next = step.next {
            path.append(next)
        } else {
            onComplete()
        }
    }

    private func markChanged(_ step: OnboardingStep) {
        changedSteps.insert(step)
    }

    @ViewBuilder
    private func page(for step: OnboardingStep) -> some View {
        let isLast = step.next == nil
        switch step {
        case .welcome:
            OnboardingWelcomePage()
                .safeAreaBar(edge: .bottom) {
                    OnboardingStepBar(isLast: isLast) { advance(from: step) }
                }
        case .publisherStatus:
            OnboardingPublisherStatusPage(
                showsCloudNote: step.showsCloudNote(hasValue: !currentStatus.isEmpty, changedSteps: changedSteps),
                onChange: { markChanged(step) }
            )
            .safeAreaBar(edge: .bottom) {
                OnboardingStepBar(isLast: isLast, canContinue: !currentStatus.isEmpty) {
                    advance(from: step)
                }
            }
        case .overseer:
            OnboardingOverseerPage(
                showsCloudNote: step.showsCloudNote(hasValue: !overseerFullName.isEmpty, changedSteps: changedSteps),
                onChange: { markChanged(step) }
            )
            .safeAreaBar(edge: .bottom) {
                OnboardingStepBar(
                    isLast: isLast,
                    canContinue: !overseerFullName.isEmpty,
                    onSkip: overseerFullName.isEmpty ? { advance(from: step) } : nil
                ) {
                    advance(from: step)
                }
            }
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
