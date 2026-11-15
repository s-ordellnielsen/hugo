import SwiftUI

/// Settings → Report → Group Overseer. Choosing the overseer from Contacts is
/// the main action. Typing the name and number is the alternative for users
/// who would rather not use Contacts.
struct OverseerSettingsView: View {
    @AppStorage(UserDefaultsKeys.overseerFullName) private var fullName = ""
    @AppStorage(UserDefaultsKeys.overseerPhoneNumber) private var phoneNumber = ""
    @AppStorage(UserDefaultsKeys.overseerFirstName) private var firstName = ""
    @AppStorage(UserDefaultsKeys.overseerLastName) private var lastName = ""

    @State private var isPickingContact = false
    @State private var isEnteringManually = false

    private var hasOverseer: Bool { !fullName.isEmpty }

    var body: some View {
        List {
            Section {
                VStack(spacing: HugoLayout.Spacing.section) {
                    CurrentOverseerView(fullName: fullName, phoneNumber: phoneNumber)

                    VStack(spacing: HugoLayout.Spacing.regular) {
                        Button {
                            isPickingContact = true
                        } label: {
                            // A button inside a list row takes the tint as its text
                            // color, which matches the prominent background.
                            Label("overseer.contacts.choose", systemImage: "person.crop.circle.badge.plus")
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.hugoAccent)
                        .controlSize(.large)

                        Text("overseer.contacts.privacy")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .listRowBackground(Color.clear)
            }

            Section {
                Button {
                    isEnteringManually = true
                } label: {
                    Label(hasOverseer ? "overseer.manual.edit" : "overseer.manual.add", systemImage: "keyboard")
                }
            } footer: {
                if !hasOverseer {
                    Text("overseer.manual.footer")
                }
            }

            if hasOverseer {
                Section {
                    Button(role: .destructive) {
                        fullName = ""
                        phoneNumber = ""
                        firstName = ""
                        lastName = ""
                    } label: {
                        // The list draws the symbol in the primary color unless
                        // it is set, so the symbol and text are red together.
                        Label("report.overseer.clear", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("settings.report.overseer")
        .navigationBarTitleDisplayMode(.inline)
        .motion(Motion.presence, value: hasOverseer)
        .background {
            OverseerContactPicker(isPresented: $isPickingContact) {
                pickedFullName, pickedPhone, pickedFirst, pickedLast in
                fullName = pickedFullName
                phoneNumber = pickedPhone
                firstName = pickedFirst
                lastName = pickedLast
            }
        }
        .sheet(isPresented: $isEnteringManually) {
            OverseerManualEntryView()
        }
    }
}

#Preview {
    NavigationStack {
        OverseerSettingsView()
    }
}
