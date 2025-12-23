//
//  SavedReportListItemView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 13/11/2025.
//

import Charts
import SwiftUI

extension SubmittedReportsListView {
    struct ListItem: View {
        let report: Report

        var formattedMonth: String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM, yyyy"

            var dateComponents = DateComponents()
            dateComponents.year = report.year
            dateComponents.month = report.month

            if let date = Calendar.current.date(from: dateComponents) {
                return dateFormatter.string(from: date)
            }

            return dateFormatter.string(from: Date())
        }

        var body: some View {
            NavigationLink(destination: SubmittedReportDetailView(report: report)) {
                VStack(alignment: .leading) {
                    HStack {
                        Text(formattedMonth)
                            .font(.caption)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                        Spacer()
                        Image(systemName: "chevron.right") 
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    HStack {
                        HStack(alignment: .firstTextBaseline) {
                            Text(formatDuration(report.fieldService))
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.top, 4)
                            Text("reportList.row.hours.label")
                                .foregroundStyle(.secondary)
                                .fontWeight(.medium)
                        }
                        .fontDesign(.rounded)
                    }
                    Divider()
                    VStack {
                        HStack {
                            Label("report.bible-studies", systemImage: "book")
                            Spacer()
                            Text(String("\(report.bibleStudies)"))
                                .fontDesign(.monospaced)
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                    .padding(.vertical, 8)
                    if !report.dailyPoints.isEmpty {
                        Divider()
                        ReportChart.CumulativeLine(report: report)
                            .padding(.top, 8)
                            .frame(height: 64)
                    }
                }
                .labelReservedIconWidth(24)
                .padding(24)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(32)
            }
        }
    }
}

#Preview {
    let reports = sampleReports()

    NavigationStack {
        ScrollView {
            SubmittedReportsListView(reports: reports)
                .navigationTitle("Reports")
                .navigationBarTitleDisplayMode(.inline)
                .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}
