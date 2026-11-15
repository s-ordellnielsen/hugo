import Foundation

/// The group overseer's name and phone number while the user types them in
/// `OverseerManualEntryView`, for users who would rather not choose the
/// overseer from Contacts. Hugo needs a first name for the greeting and a
/// phone number to send the report to. The last name is optional.
nonisolated struct OverseerDetails: Equatable, Sendable {
    var firstName: String
    var lastName: String
    var phoneNumber: String

    init(firstName: String = "", lastName: String = "", phoneNumber: String = "") {
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumber = phoneNumber
    }

    /// The saved overseer, ready to edit. An overseer saved before Hugo
    /// stored name parts has only a full name, so that becomes the first name.
    init(savedFullName: String, firstName: String, lastName: String, phoneNumber: String) {
        let hasNameParts = !firstName.isEmpty || !lastName.isEmpty
        self.init(
            firstName: hasNameParts ? firstName : savedFullName,
            lastName: lastName,
            phoneNumber: phoneNumber
        )
    }

    /// The same details without spaces or line breaks at either end.
    var trimmed: OverseerDetails {
        OverseerDetails(
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// Whether the details have the first name and phone number Hugo needs.
    var canSave: Bool {
        let details = trimmed
        return !details.firstName.isEmpty && !details.phoneNumber.isEmpty
    }

    /// The full name in the order the locale writes names, such as
    /// "Anna Berg".
    func fullName(locale: Locale = .current) -> String {
        let details = trimmed
        var components = PersonNameComponents()
        components.givenName = details.firstName.isEmpty ? nil : details.firstName
        components.familyName = details.lastName.isEmpty ? nil : details.lastName
        return components.formatted(PersonNameComponents.FormatStyle(style: .medium, locale: locale))
    }
}
