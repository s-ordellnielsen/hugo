//
//  SettingsView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 08/10/2025.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
//            Section {
//                NavigationLink(destination: TrackerSelectionView()) {
//                    Label("settings.link.trackers", systemImage: "chart.line.text.clipboard.fill")
//                }
//            } footer: {
//                Text("settings.group.trackers.description")
//            }
        }
        .navigationTitle("settings.title")
    }
}

#Preview {
    SettingsView()
}
