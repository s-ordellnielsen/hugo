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
                    MonthlyReportListView()
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
                        ContentUnavailableView(
                            "No Reports",
                            systemImage: "receipt.fill",
                            description: Text(
                                "Reports submitted from this Service Year, will be shown here. To see previous reports, go to **All Reports**."
                            )
                        )
                        .padding(.top, 48)
                    } else {
                        SavedReportListView(reports: reports)
                    }

                    NavigationLink(destination: Text("All Reports")) {
                        Label {
                            HStack {
                                Text("All Reports")
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
