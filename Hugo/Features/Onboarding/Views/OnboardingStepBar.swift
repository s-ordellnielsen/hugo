import SwiftUI

/// The bottom of every onboarding page: the step counter, the main button
/// and, on optional steps, a skip button.
struct OnboardingStepBar: View {
    let step: OnboardingStep
    let isLast: Bool
    var canContinue = true
    var onSkip: (() -> Void)? = nil
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: HugoLayout.Spacing.compact) {
            Text("onboarding.step.\(step.number).\(OnboardingStep.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(action: onContinue) {
                Label(
                    isLast ? "splash.action.complete" : "onboarding.action.continue",
                    systemImage: "arrow.right"
                )
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.hugoAccent)
                .foregroundStyle(.white)
                .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.compactCard))
            }
            .disabled(!canContinue)

            if let onSkip {
                Button("onboarding.action.skip", action: onSkip)
                    .padding(.vertical, HugoLayout.Spacing.tight)
            }
        }
        .padding()
        .background(.bar)
    }
}

#Preview {
    VStack {
        Spacer()
        OnboardingStepBar(step: .overseer, isLast: false, canContinue: false, onSkip: {}, onContinue: {})
    }
}
