//
//  TrackerSettingsView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 27/11/2025.
//

import SwiftData
import SwiftUI

struct TrackerSettingsView: View {
    @Query private var trackers: [Tracker]

    @State private var addTrackerSheetIsPresented: Bool = false

    var body: some View {
        List {
            ForEach(TrackerType.allCases, id: \.self) { type in
                let filtered = trackers.filter { $0.type == type }

                if !filtered.isEmpty {
                    Section(type.label) {
                        ForEach(filtered, id: \.id) { tracker in
                            NavigationLink(
                                destination: DetailView(tracker: tracker)
                            ) {
                                HStack {
                                    Label {
                                        Text(tracker.name)
                                    } icon: {
                                        Image(systemName: tracker.iconName)
                                    }
                                    Spacer()
                                    if tracker.isDefault {
                                        Image(systemName: "star.fill")
                                            .font(.callout)
                                            .foregroundStyle(.yellow)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
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
