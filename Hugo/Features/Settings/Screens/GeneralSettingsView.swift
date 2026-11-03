//
//  GeneralSettingsView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 06/08/2026.
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(UserDefaultsKeys.durationMinuteInterval) private var durationMinuteInterval = 1
    @AppStorage(UserDefaultsKeys.yearlyGoalPacing) private var pacing: YearlyGoalPacing = .proRated
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""

    var body: some View {
        List {
            Section {
                Picker(selection: $durationMinuteInterval) {
                    Text("settings.duration.minute-interval.1").tag(1)
                    Text("settings.duration.minute-interval.5").tag(5)
                    Text("settings.duration.minute-interval.15").tag(15)
                } label: {
                    Label("settings.duration.minute-interval", systemImage: "clock")
                }
                .pickerStyle(.navigationLink)
            }

            if PublisherStatus.status(for: statusID)?.yearlyGoalRule != nil {
                Section {
                    Picker(selection: $pacing) {
                        ForEach(YearlyGoalPacing.allCases, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    } label: {
                        Label("settings.yearlyGoal.pacing", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .pickerStyle(.navigationLink)
                } footer: {
                    Text("settings.yearlyGoal.pacing.footer")
                }
            }
        }
        .navigationTitle("settings.group.settings.general")
    }
}

#Preview {
    GeneralSettingsView()
}
