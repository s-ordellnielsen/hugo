//
//  SubmittedReportDetailView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 23/12/2025.
//

import SwiftData
import SwiftUI

struct SubmittedReportDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let report: Report

    var body: some View {
        List {
            Section {
                ForEach(report.dailyPoints) { point in
                    HStack {
                        Text(
                            point.date,
                            format: Date.FormatStyle(
                                date: .abbreviated,
                                time: .none
                            )
                        )
                        Spacer()
                        Text(formatDuration(point.total))
                            .fontDesign(.monospaced)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.automatic)
    }
}

#Preview {
    let reports = sampleReports()

    NavigationStack {
        SubmittedReportDetailView(report: reports.first!)
    }
}
