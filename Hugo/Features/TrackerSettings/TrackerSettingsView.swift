//
//  TrackerSettingsView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 27/11/2025.
//

import SwiftUI
import SwiftData

struct TrackerSettingsView: View {
    @Query private var trackers: [Tracker]
    
    @State private var addTrackerSheetIsPresented: Bool = false
    
    var body: some View {
        List(trackers) { tracker in
            NavigationLink(destination: DetailView(tracker: tracker)) {
                Label {
                    HStack {
                        Text(tracker.name)
                        Spacer()
                        if tracker.isDefault {
                            Image(systemName: "star.fill")
                                .font(.callout)
                                .foregroundStyle(.yellow)
                        }
                    }
                } icon: {
                    Image(systemName: tracker.iconName)
                }
            }
        }
        .navigationTitle("settings.trackers.title")
        .tint(.primary)
        .toolbar {
            ToolbarItem {
                Button {
                    addTrackerSheetIsPresented = true
                } label: {
                    Label("navigation.add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $addTrackerSheetIsPresented) {
            AddTrackerSheet()
        }
    }
}

#Preview {
    NavigationStack {
        TrackerSettingsView()
            .modelContainer(.preview)
            .navigationBarTitleDisplayMode(.inline)
    }
}
