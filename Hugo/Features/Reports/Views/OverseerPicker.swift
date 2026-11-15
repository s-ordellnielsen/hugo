import ContactsUI
import MessageUI
import SwiftUI

/// Contact picker constrained to contacts with a phone number. Reports the
/// picked contact's name parts so greeting tags (`{first}`/`{last}`) render
/// correctly; the contact identifier is deliberately not persisted.
///
/// Attach it with `.background` and show it with `isPresented`, not inside a
/// `.sheet`. The picker closes itself after a choice. Inside a SwiftUI sheet,
/// SwiftUI then closes the sheet a second time, which closes the screen that
/// presented it, such as Settings or onboarding. Here an invisible view
/// controller presents the picker, so only the picker closes.
struct OverseerContactPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: (_ fullName: String, _ phoneNumber: String, _ firstName: String, _ lastName: String) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented, host.presentedViewController == nil else { return }
        let picker = CNContactPickerViewController()
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        picker.delegate = context.coordinator
        host.present(picker, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: OverseerContactPicker

        init(parent: OverseerContactPicker) {
            self.parent = parent
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.isPresented = false
            guard let phone = contact.phoneNumbers.first?.value.stringValue, !phone.isEmpty else { return }
            let fullName =
                CNContactFormatter.string(from: contact, style: .fullName)
                ?? [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            parent.onPick(fullName, phone, contact.givenName, contact.familyName)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.isPresented = false
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
