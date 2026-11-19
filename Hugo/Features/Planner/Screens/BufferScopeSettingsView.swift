import SwiftUI

/// Where the Buffer counts besides the Planner, which always counts it.
struct BufferScopeSettingsView: View {
    @AppStorage(UserDefaultsKeys.bufferInOverview) private var includeInOverview = false
    @AppStorage(UserDefaultsKeys.bufferInYear) private var includeInYear = false

    var body: some View {
        List {
            Section {
                LabeledContent {
                    Text("planner.target.countsIn.always")
                } label: {
                    Text("tab.planner")
                }
                Toggle(isOn: $includeInOverview) { Text("tab.overview") }
                    .accessibilityLabel("planner.target.includeBuffer.overview")
                Toggle(isOn: $includeInYear) { Text("tab.year") }
                    .accessibilityLabel("planner.target.includeBuffer.year")
            }
        }
        .navigationTitle("planner.target.countsIn.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Count Buffer in") {
    let defaults = UserDefaults(suiteName: "BufferScopePreview")!
    defaults.set(false, forKey: UserDefaultsKeys.bufferInOverview)
    defaults.set(true, forKey: UserDefaultsKeys.bufferInYear)
    return NavigationStack {
        BufferScopeSettingsView()
    }
    .defaultAppStorage(defaults)
}

#Preview("Count Buffer in, large text") {
    let defaults = UserDefaults(suiteName: "BufferScopeLargeTextPreview")!
    defaults.set(true, forKey: UserDefaultsKeys.bufferInOverview)
    return NavigationStack {
        BufferScopeSettingsView()
    }
    .defaultAppStorage(defaults)
    .dynamicTypeSize(.accessibility5)
}
