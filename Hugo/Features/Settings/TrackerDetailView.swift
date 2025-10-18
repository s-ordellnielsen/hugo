//
//  TrackerDetailView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 17/10/2025.
//

import SwiftUI
import SwiftData

struct TrackerDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var tracker: Tracker
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        List {
            
        }
        .navigationTitle(tracker.name)
        .toolbar {
            ToolbarItem {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Tracker", systemImage: "trash")
                }
                .confirmationDialog("Delete \(tracker.name)?", isPresented: $showDeleteConfirmation) {
                    Button("Delete") {
                        context.delete(tracker)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    VStack {
                        Text("Delete \(tracker.name)?")
                        Text("All entries connected to this tracker will be deleted as well")
                    }
                }
            }
        }
    }
}

#Preview {
    TrackerDetailView(tracker: Tracker(name: "Field Service"))
}
