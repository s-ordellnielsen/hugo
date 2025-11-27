//
//  SavedReportListView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 13/11/2025.
//

import SwiftUI

struct SavedReportListView: View {
    
    let reports: [Report]
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(reports) { report in
                ListItem(report: report)
            }
        }
        .tint(.primary)
    }
}

#Preview {
    @Previewable @Environment(\.modelContext) var context
    
    let reports = sampleReports()
    
    NavigationStack {
        ScrollView {
            SavedReportListView(reports: reports)
                .navigationTitle("Reports")
                .navigationBarTitleDisplayMode(.inline)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
