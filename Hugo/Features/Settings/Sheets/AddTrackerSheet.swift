//
//  AddTrackerSheet.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 16/10/2025.
//

import SwiftUI
import SwiftData

struct AddTrackerSheet: View {
    @Query var trackers: [Tracker] = []
    
    @State private var tracker: Tracker = Tracker()
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $tracker.name)
                }
                Section {
                    Toggle("Use as Default", isOn: $tracker.isDefault)
                } footer: {
                    if trackers.first(where: { $0.isDefault == true }) != nil {
                        Text("Turning this on will override the current default tracker: \(trackers.first(where: { $0.isDefault == true })!.name).")
                    }
                }
            }
            .navigationTitle("Add Tracker")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    AddTrackerSheet()
}
