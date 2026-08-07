//
//  RoundingRuleSelectionView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/08/2026.
//

import SwiftUI

struct RoundingRuleSelectionView: View {
    @AppStorage(UserDefaultsKeys.defaultRoundingRule) private var defaultRoundingRule = ""
	
	@State private var showHelp = false

    private var currentRoundingRule: RoundingRule {
        RoundingRule(rawValue: defaultRoundingRule) ?? RoundingRule.defaultValue
    }

    var body: some View {
        List {
            ForEach(RoundingRule.allCases) { rule in
                Button {
                    defaultRoundingRule = rule.rawValue
                } label: {
                    HStack {
                        Text(rule.localizedName)

                        Spacer()

                        Checkmark(checked: currentRoundingRule == rule)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button("common.help", systemImage: "questionmark") {
					showHelp.toggle()
				}
			}
		}
		.sheet(isPresented: $showHelp) {
			HelpView(for: "RoundingRule")
		}
    }
}

#Preview {
    RoundingRuleSelectionView()
}
