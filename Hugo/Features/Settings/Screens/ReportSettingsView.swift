//
//  ReportSettingsView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 06/08/2026.
//

import SwiftUI

struct ReportSettingsView: View {
    @AppStorage(UserDefaultsKeys.overseerFullName) private var overseerFullName = ""
    @AppStorage(UserDefaultsKeys.overseerGreetingTemplate) private var greetingTemplate = ""

    var body: some View {
        List {
            Section {
                NavigationLink(destination: OverseerSettingsView()) {
                    Label {
                        Text("settings.report.overseer")
                        Text(
                            overseerFullName.isEmpty
                                ? String(localized: "report.overseer.empty")
                                : overseerFullName)
                    } icon: {
                        Image(systemName: "person.crop.circle")
                    }
                }

                NavigationLink(destination: GreetingTemplateView()) {
                    Label {
                        Text("settings.report.greeting")
                        Text(
                            greetingTemplate.isEmpty
                                ? String(localized: "report.greeting.default")
                                : greetingTemplate
                        )
                        .lineLimit(1)
                    } icon: {
                        Image(systemName: "text.quote")
                    }
                }
            } header: {
                Text("settings.screen.report.section.content.label")
            }
        }
        .readableListWidth()
        .editorialNavigationTitle("settings.group.settings.report")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HelpMenu(articles: HelpArticle.reportSettings)
            }
        }
    }

}

#Preview {
    NavigationStack {
        ReportSettingsView()
            .navigationBarTitleDisplayMode(.inline)
    }
}
