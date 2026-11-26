import SwiftUI

/// A sheet where the user types the group overseer's name and phone number,
/// for users who would rather not choose the overseer from Contacts. It
/// starts with the saved overseer, so it also edits an overseer chosen from
/// Contacts. It saves the same settings as the contact picker.
struct OverseerManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @AppStorage(UserDefaultsKeys.overseerFullName) private var fullName = ""
    @AppStorage(UserDefaultsKeys.overseerPhoneNumber) private var phoneNumber = ""
    @AppStorage(UserDefaultsKeys.overseerFirstName) private var firstName = ""
    @AppStorage(UserDefaultsKeys.overseerLastName) private var lastName = ""

    @State private var details = OverseerDetails()

    private enum Field: Hashable {
        case firstName, lastName, phoneNumber
    }

    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("overseer.field.firstName", text: $details.firstName)
                        .textContentType(.givenName)
                        .focused($focusedField, equals: .firstName)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .lastName }
                    TextField("overseer.field.lastName", text: $details.lastName)
                        .textContentType(.familyName)
                        .focused($focusedField, equals: .lastName)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .phoneNumber }
                } header: {
                    Text("overseer.section.name")
                }

                Section {
                    TextField("overseer.field.phoneNumber", text: $details.phoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .focused($focusedField, equals: .phoneNumber)
                } header: {
                    Text("overseer.section.phoneNumber")
                }
            }
            .editorialNavigationTitle("settings.report.overseer")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                ToolbarItem {
                    Button(role: .confirm, action: save) {
                        Label("common.done", systemImage: "checkmark")
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!details.canSave)
                }
            }
        }
        .onAppear {
            details = OverseerDetails(
                savedFullName: fullName, firstName: firstName, lastName: lastName, phoneNumber: phoneNumber)
            if details.firstName.isEmpty {
                focusedField = .firstName
            }
        }
    }

    private func save() {
        let saved = details.trimmed
        fullName = saved.fullName(locale: locale)
        firstName = saved.firstName
        lastName = saved.lastName
        phoneNumber = saved.phoneNumber
        dismiss()
    }
}

#Preview {
    OverseerManualEntryView()
}
