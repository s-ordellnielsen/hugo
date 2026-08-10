//
//  SwiftUIView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 06/08/2026.
//

import SwiftUI

struct ReportSettingsView: View {
    @AppStorage(UserDefaultsKeys.overseerFullName) private var overseerFullName = ""
    @AppStorage(UserDefaultsKeys.overseerGreetingTemplate) private var greetingTemplate = ""
    @AppStorage(UserDefaultsKeys.defaultRoundingRule) private var defaultRoundingRule = ""

    @State private var showingHelp = false

    private var currentRoundingRule: RoundingRule {
        RoundingRule(rawValue: defaultRoundingRule) ?? RoundingRule.defaultValue
    }

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

            Section {
                NavigationLink(destination: RoundingRuleSelectionView()) {
                    Label {
                        HStack {
                            Text("settings.screen.report.section.calculation.rounding.label")
                            Spacer()
                            Text(currentRoundingRule.localizedName)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            } header: {
                Text("settings.screen.report.section.calculation.label")
            }
        }
        .navigationTitle("settings.group.settings.report")
    }

}

#Preview {
    NavigationStack {
        ReportSettingsView()
            .navigationBarTitleDisplayMode(.inline)
    }
}
