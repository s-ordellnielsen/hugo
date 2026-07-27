//
//  CategoryPicker.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 21/11/2025.
//

import SwiftData
import SwiftUI

struct CategoryPicker: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selection: Tracker?
    var dismissOnSelection: Bool = false

    @Query private var trackers: [Tracker] = []
    
    @State private var showAddCategoryView: Bool = false

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
            .navigationTitle("trackerPicker.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem {
                    Button {
                        showAddCategoryView = true
                    } label: {
                        Label("addTrackerSheet.title", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddCategoryView) {
                AddCategoryView()
            }
        }
    }
}

#Preview {
    @Previewable @State var selection: Tracker? = nil

    CategoryPicker(selection: $selection)
        .modelContainer(.preview)
}
