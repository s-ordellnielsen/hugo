import SwiftUI

struct SettingsButton: View {
    @State private var showAccount: Bool = false

    var body: some View {
        Button {
            showAccount = true
        } label: {
            Image(systemName: "person.fill")
        }
        .sheet(isPresented: $showAccount) {
            SettingsView()
                .presentationDetents([.large])
        }
    }
}
