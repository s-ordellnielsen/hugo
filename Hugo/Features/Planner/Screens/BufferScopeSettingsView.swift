import SwiftUI

/// Where the Buffer counts besides the Planner, which always counts it.
struct BufferScopeSettingsView: View {
    // The parent owns these two settings. Do not declare @AppStorage for them
    // here: when this page did, opening it froze the app (plan 132, revision 3).
    @Binding var includeInOverview: Bool
    @Binding var includeInYear: Bool

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
    @Previewable @State var overview = false
    @Previewable @State var year = true
    NavigationStack {
        BufferScopeSettingsView(includeInOverview: $overview, includeInYear: $year)
    }
}

#Preview("Count Buffer in, large text") {
    @Previewable @State var overview = true
    @Previewable @State var year = false
    NavigationStack {
        BufferScopeSettingsView(includeInOverview: $overview, includeInYear: $year)
    }
    .dynamicTypeSize(.accessibility5)
}
