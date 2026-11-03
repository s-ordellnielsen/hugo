import SwiftUI

struct SettingsButton: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var showAccount: Bool = false

    var sizeClass: UserInterfaceSizeClass? = nil

    var body: some View {
        if sizeClass == nil || sizeClass == horizontalSizeClass {
            Button {
                showAccount = true
            } label: {
                Label("settings.title", systemImage: "person.fill")
                    .labelStyle(.iconOnly)
            }
            .sheet(isPresented: $showAccount) {
                SettingsView(showDismiss: true)
                    .presentationDetents([.large])
            }
        }
    }
}
