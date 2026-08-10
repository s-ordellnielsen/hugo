//
//  AppSettingsView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 06/08/2026.
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(UserDefaultsKeys.durationMinuteInterval) private var durationMinuteInterval = 1

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
        }
        .navigationTitle("settings.group.settings.general")
    }
}

#Preview {
    GeneralSettingsView()
}
