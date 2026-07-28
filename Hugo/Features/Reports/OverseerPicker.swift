import ContactsUI
import MessageUI
import SwiftUI

/// Contact picker constrained to contacts with a phone number. Reports the
/// picked contact's name parts so greeting tags (`{first}`/`{last}`) render
/// correctly; the contact identifier is deliberately not persisted.
struct OverseerContactPicker: UIViewControllerRepresentable {
    let onPick: (_ fullName: String, _ phoneNumber: String, _ firstName: String, _ lastName: String) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        private let onPick: (String, String, String, String) -> Void

        init(onPick: @escaping (String, String, String, String) -> Void) {
            self.onPick = onPick
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            guard let phone = contact.phoneNumbers.first?.value.stringValue, !phone.isEmpty else { return }
            let fullName = CNContactFormatter.string(from: contact, style: .fullName)
                ?? [contact.givenName, contact.familyName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            onPick(fullName, phone, contact.givenName, contact.familyName)
        }
    }
}

/// The one acceptable UIKit bridge in the app: there is no SwiftUI message
/// composer. Reports `didFinish(true)` only when the message was sent (or the
/// body was copied as a fallback), so persistence never happens on cancel.
struct MessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let didFinish: (Bool) -> Void

    static var canSendText: Bool {
        MFMessageComposeViewController.canSendText()
    }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let composer = MFMessageComposeViewController()
        composer.recipients = recipients
        composer.body = body
        composer.messageComposeDelegate = context.coordinator
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(didFinish: didFinish)
    }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        private let didFinish: (Bool) -> Void

        init(didFinish: @escaping (Bool) -> Void) {
            self.didFinish = didFinish
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            didFinish(result == .sent)
        }
    }
}
