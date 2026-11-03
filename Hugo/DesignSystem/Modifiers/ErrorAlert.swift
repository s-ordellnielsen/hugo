import SwiftUI

/// Presents a localized error alert driven by an optional message.
/// Binding-to-Bool plumbing lives here once instead of in every caller.
extension View {
    func errorAlert(
        message: Binding<String?>,
        retry: (() -> Void)? = nil
    ) -> some View {
        let isPresented = Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )
        return alert("common.error", isPresented: isPresented) {
            if let retry {
                Button("common.retry") { retry() }
            }
            Button("common.dismiss", role: .cancel) { message.wrappedValue = nil }
        } message: {
            if let text = message.wrappedValue {
                Text(verbatim: text)
            } else {
                Text("common.error")
            }
        }
    }
}
