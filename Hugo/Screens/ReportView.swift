//
//  ReportView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 08/10/2025.
//

import SwiftData
import SwiftUI

struct ReportView: View {
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @Query(sort: \Report.year, order: .reverse) private var reports: [Report]

    var body: some View {
        NavigationStack {
            ScrollView {
                if entries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.green)
                            
                            Text("You have reported all entries.")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .fontDesign(.rounded)
                                .padding(.leading, 8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(24)
                    .padding()
                } else {
                    VStack(alignment: .leading) {
//                        Text("Unreported Reports")
//                            .padding(.horizontal)
//                            .font(.callout)
//                            .fontWeight(.semibold)
//                            .fontDesign(.rounded)
//                            .foregroundStyle(.secondary)
                        MonthlyReportListView()
                    }
                    .padding()
                }
                
                VStack(alignment: .leading) {
                    Text("Submitted Reports")
                        .padding(.horizontal)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                    
                    if reports.isEmpty {
                        ContentUnavailableView("No Reports", systemImage: "receipt.fill", description: Text("Once you have marked a report as submitted, it will appear here"))
                            .padding(.top, 48)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("report.title")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ReportView()
        .modelContainer(.preview)
}

