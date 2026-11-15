import SwiftUI

/// The buttons at the bottom of every onboarding page: the main button and,
/// on optional steps, a skip button. `OnboardingView` puts it in a
/// `safeAreaBar`, so the page scrolls under it.
struct OnboardingStepBar: View {
    let isLast: Bool
    var canContinue = true
    var onSkip: (() -> Void)? = nil
    let onContinue: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var continueTitle: LocalizedStringKey {
        isLast ? "splash.action.complete" : "onboarding.action.continue"
    }

    /// The same side margins as `OnboardingPageLayout`, so the buttons line up
    /// with the text above them.
    private var sideMargin: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? HugoLayout.Spacing.spacious : HugoLayout.Spacing.section
    }

    var body: some View {
        VStack(spacing: HugoLayout.Spacing.compact) {
            Button(action: onContinue) {
                Text(continueTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(.hugoAccent)
            .controlSize(.large)
            .disabled(!canContinue)

            if let onSkip {
                Button("onboarding.action.skip", action: onSkip)
                    .frame(minHeight: HugoLayout.Size.minimumHitTarget)
            }
        }
        .padding(.horizontal, sideMargin)
        .padding(.vertical, HugoLayout.Spacing.compact)
    }
}

#Preview {
    VStack {
        Spacer()
        OnboardingStepBar(isLast: false, canContinue: false, onSkip: {}, onContinue: {})
    }
}
