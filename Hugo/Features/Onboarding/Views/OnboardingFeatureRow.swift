import SwiftUI

/// One row of the onboarding welcome page: a symbol, a short title and one
/// sentence. VoiceOver reads the row as one item. At accessibility text sizes
/// the symbol moves above the text, so the text keeps the full width.
struct OnboardingFeatureRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title) private var symbolWidth: CGFloat = HugoLayout.Size.rowSymbolWidth

    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: HugoLayout.Spacing.compact))
            : AnyLayout(HStackLayout(alignment: .center, spacing: HugoLayout.Spacing.spacious))
    }

    var body: some View {
        layout {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(.hugoAccent)
                .frame(width: symbolWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingFeatureRow(
        symbol: "calendar",
        title: "onboarding.welcome.plan.title",
        detail: "onboarding.welcome.plan.detail"
    )
    .padding()
}
