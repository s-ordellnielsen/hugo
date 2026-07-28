import SwiftUI

struct OverseerSettingsView: View {
    @AppStorage(UserDefaultsKeys.overseerFullName) private var fullName = ""
    @AppStorage(UserDefaultsKeys.overseerPhoneNumber) private var phoneNumber = ""
    @AppStorage(UserDefaultsKeys.overseerFirstName) private var firstName = ""
    @AppStorage(UserDefaultsKeys.overseerLastName) private var lastName = ""

    @State private var isPickingContact = false

    var body: some View {
        List {
            if !fullName.isEmpty {
                Section {
                    Label(fullName, systemImage: "person.crop.circle")
                    Label(phoneNumber, systemImage: "phone")
                }
            }

            Section {
                Button("report.overseer.pick") {
                    isPickingContact = true
                }

                if !fullName.isEmpty {
                    Button("report.overseer.clear", role: .destructive) {
                        fullName = ""
                        phoneNumber = ""
                        firstName = ""
                        lastName = ""
                    }
                }
            }
        }
        .navigationTitle("settings.report.overseer")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPickingContact) {
            OverseerContactPicker { pickedFullName, pickedPhone, pickedFirst, pickedLast in
                fullName = pickedFullName
                phoneNumber = pickedPhone
                firstName = pickedFirst
                lastName = pickedLast
                isPickingContact = false
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    NavigationStack {
        OverseerSettingsView()
    }
}
