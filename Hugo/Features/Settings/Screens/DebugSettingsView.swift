import SwiftUI

struct DebugSettingsView: View {
    @AppStorage(UserDefaultsKeys.isOnboarding) var isOnboarding: Bool = true

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
