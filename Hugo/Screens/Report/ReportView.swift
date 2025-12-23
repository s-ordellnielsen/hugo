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
    @Query(sort: [
        SortDescriptor(\Report.year, order: .reverse),
        SortDescriptor(\Report.month, order: .reverse),
        SortDescriptor(\Report.createdAt, order: .reverse)
    ]) private var reports: [Report]
    
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

                VStack(alignment: .leading) {
                    Text("report.submitted.title")
                        .padding(.horizontal)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)

                    if reports.isEmpty {
                        ContentUnavailableView(
                            "reports.submitted.empty.title",
                            systemImage: "receipt.fill",
                            description: Text(
                                "reports.submitted.empty.description"
                            )
                        )
                        .padding(.top, 48)
                    } else {
                        SubmittedReportsListView(reports: reports)
                    }

                    NavigationLink(destination: Text("reports.all")) {
                        Label {
                            HStack {
                                Text("reports.all")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .fontWeight(.semibold)
                            }
                        } icon: {
                            Image(systemName: "list.bullet")
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(24)
                    .labelReservedIconWidth(24)
                    .tint(.primary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("reports.title")
            .navigationBarTitleDisplayMode(.automatic)
            .toolbar {
                ToolbarItem {
                    Menu {
                        Button("report.add.report", systemImage: "plus") {
                            addReportSheetIsPresented =  true
                        }
                    } label: {
                        Label("report.add.more", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $addReportSheetIsPresented) {
                AddReportSheet()
            }
        }
    }
}

#Preview {
    ReportView()
        .modelContainer(.preview)
}
