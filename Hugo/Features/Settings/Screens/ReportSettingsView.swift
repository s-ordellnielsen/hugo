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
	
	private var currentRoundingRule: RoundingRule {
		RoundingRule(rawValue: defaultRoundingRule) ?? .up
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
				Picker(selection: $defaultRoundingRule) {
					ForEach(RoundingRule.allCases) { rule in
						Text(rule.localizedName).tag(rule.rawValue)
					}
				} label: {
					Label {
						Text("settings.screen.report.section.calculation.rounding.label")
						Text(currentRoundingRule.localizedName)
					} icon: {
						Image(systemName: "arrow.up.arrow.down")
					}
				}
				.pickerStyle(.navigationLink)
			} header: {
				Text("settings.screen.report.section.calculation.label")
			}
		}
		.navigationTitle("settings.group.settings.report")
    }
}

#Preview {
    ReportSettingsView()
}
