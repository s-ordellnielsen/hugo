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
    
    @State private var addReportSheetIsPresented: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if entries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.green)

                        Text("report.pending.empty")
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
                    MonthlyReportListView()
                        .padding()
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("reports.title")
            .navigationBarTitleDisplayMode(.automatic)
//            .toolbar {
//                ToolbarItem {
//                    Menu {
//                        Button("report.add.report", systemImage: "plus") {
//                            addReportSheetIsPresented =  true
//                        }
//                    } label: {
//                        Label("report.add.more", systemImage: "plus")
//                    }
//                }
//            }
//            .sheet(isPresented: $addReportSheetIsPresented) {
//                AddReportSheet()
//            }
        }
    }
}

#Preview {
    ReportView()
        .modelContainer(.preview)
}
