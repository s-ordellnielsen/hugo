//
//  TrackerPicker.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 21/11/2025.
//

import SwiftData
import SwiftUI

struct TrackerPicker: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selection: Tracker?
    var dismissOnSelection: Bool = false

    @Query private var trackers: [Tracker] = []
    
    @State private var showAddTrackerSheet: Bool = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(TrackerType.allCases, id: \.self) { type in
                    let filtered = trackers.filter { $0.type == type }
                    
                    if !filtered.isEmpty {
                        Section(type.label) {
                            ForEach(filtered, id: \.id) { tracker in
                                Button {
                                    selection = tracker
                                    
                                    if dismissOnSelection {
                                        dismiss()
                                    }
                                } label: {
                                    HStack {
                                        Label {
                                            Text(tracker.name)
                                        } icon: {
                                            Image(systemName: tracker.iconName)
                                        }
                                        Spacer()
                                        if selection?.id == tracker.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem {
                    Button {
                        showAddTrackerSheet = true
                    } label: {
                        Label("Add Tracker", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddTrackerSheet) {
                AddTrackerSheet()
            }
        }
    }
}

#Preview {
    @Previewable @State var selection: Tracker? = nil

    TrackerPicker(selection: $selection)
        .modelContainer(.preview)
}
