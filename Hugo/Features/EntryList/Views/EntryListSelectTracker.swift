//
//  EntryListSelectTracker.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 20/11/2025.
//

import SwiftUI
import SwiftData

extension EntryList {
    struct SelectTracker: View {
        @Environment(\.dismiss) private var dismiss
        
        @Query private var trackers: [Tracker]
        
        @State var entry: Entry
        
        var body: some View {
            NavigationStack {
                List {
                    ForEach(trackers) { tracker in
                        Button {
                            entry.tracker = tracker
                            
                            dismiss()
                        } label: {
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
                            }
                        }
                    }
                }
                .navigationTitle("Select Tracker")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem {
                        Button(role: .confirm) {
                            dismiss()
                        }
                        .disabled(entry.tracker == nil)
                    }
                }
            }
        }
    }
}

#Preview {
    let entry = Entry(date: Date(), duration: 3600)
    
    EntryList.DetailSheet(entry: entry)
        .modelContainer(.preview)
}
