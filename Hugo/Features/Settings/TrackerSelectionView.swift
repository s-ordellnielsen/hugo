//
//  TrackerSelectionView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 14/10/2025.
//

import SwiftUI
import SwiftData

struct TrackerSelectionView: View {
    @Query private var trackers: [Tracker]
    
    @State private var addTrackerSheetIsPresented: Bool = false
    
    var body: some View {
        List(trackers) { tracker in
            NavigationLink(destination: TrackerDetailView(tracker: tracker)) {
                Label {
                    HStack {
                        Text(tracker.name)
                        Spacer()
                        if tracker.isDefault {
                            Image(systemName: "star.fill")
                        }
                    }
                } icon: {
                    Image(systemName: tracker.iconName)
                        .tint(Color(
                            hue: tracker.hue, saturation: 0.8, brightness: 0.9
                        ))
                }
            }
        }
        .navigationTitle("settings.trackers.title")
        .toolbar {
            ToolbarItem {
                Button {
                    addTrackerSheetIsPresented = true
                } label: {
                    Label("navigation.add", systemImage: "plus")
                }
            }
            ToolbarSpacer()
            ToolbarItem {
                Menu {
                    Button {
                        
                    } label: {
                        Label("Help", systemImage: "questionmark")
                    }
                    EditButton()
                } label: {
                    Label("navigation.more", systemImage: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $addTrackerSheetIsPresented) {
            AddTrackerSheet()
                .presentationDetents([.medium])
        }
    }
}

#Preview {
    TrackerSelectionView()
        .modelContainer(.preview)
}
