import SwiftUI

/// Onboarding step 2 of 2: the group overseer, chosen from Contacts. It saves
/// the same settings as Settings → Report → Group Overseer
/// (`OverseerSettingsView`). `OnboardingView` offers Skip for Now while no
/// overseer is chosen.
struct OnboardingOverseerPage: View {
    /// Whether to say that the overseer came from the user's other devices.
    let showsCloudNote: Bool
    /// Called when the user picks an overseer on this page.
    let onChange: () -> Void

    @AppStorage(UserDefaultsKeys.overseerFullName) private var fullName = ""
    @AppStorage(UserDefaultsKeys.overseerPhoneNumber) private var phoneNumber = ""
    @AppStorage(UserDefaultsKeys.overseerFirstName) private var firstName = ""
    @AppStorage(UserDefaultsKeys.overseerLastName) private var lastName = ""

    @State private var isPickingContact = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var pickTitle: LocalizedStringKey {
        fullName.isEmpty ? "report.overseer.pick" : "onboarding.overseer.change"
    }

    /// The symbol beside the name normally, and above it at accessibility
    /// text sizes, so the name keeps the card's full width.
    private var nameLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: HugoLayout.Spacing.compact))
            : AnyLayout(HStackLayout(alignment: .center, spacing: HugoLayout.Spacing.regular))
    }

    var body: some View {
        OnboardingPageLayout(
            step: .overseer,
            title: "onboarding.overseer.title",
            explanation: "onboarding.overseer.introduction",
            showsCloudNote: showsCloudNote
        ) {
            card
        }
        .sheet(isPresented: $isPickingContact) {
            OverseerContactPicker { pickedFullName, pickedPhone, pickedFirst, pickedLast in
                fullName = pickedFullName
                phoneNumber = pickedPhone
                firstName = pickedFirst
                lastName = pickedLast
                isPickingContact = false
                onChange()
            }
            .ignoresSafeArea()
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.spacious) {
            nameLayout {
                Image(systemName: fullName.isEmpty ? "person.crop.circle" : "person.crop.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(fullName.isEmpty ? Color.secondary : Color.hugoAccent)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                    Text(fullName.isEmpty ? String(localized: "report.overseer.empty") : fullName)
                        .font(.headline)
                    if !fullName.isEmpty, !phoneNumber.isEmpty {
                        Text(phoneNumber)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)

            Button {
                isPickingContact = true
            } label: {
                Text(pickTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
        }
        .padding(HugoLayout.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
        .motion(Motion.presence, value: fullName)
    }
}

#Preview {
    NavigationStack {
        OnboardingOverseerPage(showsCloudNote: false, onChange: {})
    }
}
