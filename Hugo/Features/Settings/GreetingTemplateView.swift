import SwiftUI

struct GreetingTemplateView: View {
    @AppStorage(UserDefaultsKeys.overseerGreetingTemplate) private var template = ""
    @AppStorage(UserDefaultsKeys.overseerFullName) private var overseerFullName = ""
    @AppStorage(UserDefaultsKeys.overseerFirstName) private var overseerFirstName = ""
    @AppStorage(UserDefaultsKeys.overseerLastName) private var overseerLastName = ""

    /// The effective template: the stored one, or a locale-aware default when
    /// the user hasn't customized it yet.
    private var effectiveTemplate: String {
        if !template.isEmpty { return template }
        return String(localized: "report.greeting.default")
    }

    private var previewFirstName: String {
        if !overseerFirstName.isEmpty { return overseerFirstName }
        if !overseerFullName.isEmpty { return overseerFullName }
        return String(localized: "report.greeting.placeholder-first")
    }

    private var previewLastName: String {
        overseerLastName
    }

    var body: some View {
        List {
            Section {
                TextField("report.greeting.default", text: $template, axis: .vertical)
            } header: {
                Text("settings.report.greeting")
            } footer: {
                Text("report.greeting.footer")
            }

            Section {
                Text(preview)
                    .foregroundStyle(.secondary)
            } header: {
                Text("report.greeting.preview")
            }
        }
        .navigationTitle("settings.report.greeting")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var preview: String {
        ReportComposer.render(
            template: effectiveTemplate,
            firstName: previewFirstName,
            lastName: previewLastName
        )
    }
}

#Preview {
    NavigationStack {
        GreetingTemplateView()
    }
}
