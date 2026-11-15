import SwiftUI

/// A short note on an onboarding page, such as the privacy promise on the
/// welcome page or the line saying a setting came from iCloud: a symbol in
/// the accent color beside the text, on a soft rounded background that sets
/// it apart from the choices on the page. With its padding, the text starts
/// where the text of an `OnboardingFeatureRow` starts. VoiceOver reads it as
/// one item.
struct OnboardingNote: View {
    let symbol: String
    let text: LocalizedStringKey

    @ScaledMetric(relativeTo: .title2) private var symbolWidth: CGFloat = HugoLayout.Size.labelReservedIconWidth

    var body: some View {
        HStack(alignment: .center, spacing: HugoLayout.Spacing.spacious) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.hugoAccent)
                .frame(width: symbolWidth)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(HugoLayout.Spacing.spacious)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: HugoLayout.CornerRadius.compactCard))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: HugoLayout.Spacing.spacious) {
        OnboardingNote(symbol: "lock.shield.fill", text: "onboarding.welcome.privacy")
        OnboardingNote(symbol: "checkmark.icloud.fill", text: "onboarding.cloudNote")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
