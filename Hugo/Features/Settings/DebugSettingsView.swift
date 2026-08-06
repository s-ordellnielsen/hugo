import SwiftUI

struct DebugSettingsView: View {
    @AppStorage("isOnboarding") var isOnboarding: Bool = false

    var body: some View {
        List {
            Button("debug.action.reset-onboarding", systemImage: "arrow.counterclockwise") {
                isOnboarding = true
            }
        }
        .navigationTitle("debug.title")
    }
}

#Preview {
    DebugSettingsView()
}
