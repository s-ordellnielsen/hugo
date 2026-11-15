import SwiftUI

/// The first onboarding page: what Hugo does, in four rows, and that Hugo
/// collects nothing. The rows fade in one after another when the page opens.
/// With Reduce Motion on, they fade in together without moving.
struct OnboardingWelcomePage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingRows = false

    var body: some View {
        OnboardingPageLayout(step: .welcome, title: "splash.title", explanation: "splash.subtitle") {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.roomy) {
                appearing(0) {
                    OnboardingFeatureRow(
                        symbol: "clock",
                        title: "onboarding.welcome.log.title",
                        detail: "onboarding.welcome.log.detail"
                    )
                }
                appearing(1) {
                    OnboardingFeatureRow(
                        symbol: "calendar",
                        title: "onboarding.welcome.plan.title",
                        detail: "onboarding.welcome.plan.detail"
                    )
                }
                appearing(2) {
                    OnboardingFeatureRow(
                        symbol: "arrow.up.message",
                        title: "onboarding.welcome.report.title",
                        detail: "onboarding.welcome.report.detail"
                    )
                }
                appearing(3) {
                    OnboardingFeatureRow(
                        symbol: "target",
                        title: "onboarding.welcome.goal.title",
                        detail: "onboarding.welcome.goal.detail"
                    )
                }
                appearing(4) {
                    Label("onboarding.welcome.privacy", systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        // The setup pages start below their back button. This page has none,
        // so it gets the same space above its title.
        .contentMargins(.top, HugoLayout.Spacing.section, for: .scrollContent)
        .onAppear { isShowingRows = true }
    }

    /// Fades a row in after the rows above it, and slides it up a little
    /// unless Reduce Motion is on.
    private func appearing<Row: View>(_ index: Int, @ViewBuilder row: () -> Row) -> some View {
        row()
            .opacity(isShowingRows ? 1 : 0)
            .offset(y: isShowingRows || reduceMotion ? 0 : HugoLayout.Spacing.regular)
            .motion(Motion.presence.delay(Double(index) * 0.06), value: isShowingRows)
    }
}

#Preview {
    NavigationStack {
        OnboardingWelcomePage()
    }
}
