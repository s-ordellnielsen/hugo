//
//  MonthlyReportDetailView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 13/11/2025.
//

import SwiftData
import SwiftUI

struct MonthlyReportDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let summary: MonthlySummary

    var body: some View {
        ScrollView {
            VStack {
                LazyVStack {
                    LargeTotal(summary: summary)
                }
            }
            .padding()
        }
        .navigationTitle(summary.displayName)
        .navigationSubtitle("report.title")
        .navigationBarTitleDisplayMode(.automatic)
        .background(Color(.systemGroupedBackground))
        .toolbar {
            Button("report.submit.action.message", systemImage: "arrow.up.message") {
                
            }
            Menu {
                Button("report.submit.action.message", systemImage: "arrow.up.message") {
                    
                }
                Button("report.submit.action.email", systemImage: "envelope") {
                    
                }
                Button("report.submit.action.copy", systemImage: "square.on.square") {
                    
                }
                Button("report.submit.action.lock", systemImage: "lock") {
                    _ = makeReport()
                    dismiss()
                }
            } label: {
                Label("common.more", systemImage: "ellipsis")
            }
        }
    }
    
    private func makeReport() -> Result<Report, ReportError> {
        let report = Report.make(from: summary.entries, in: context)
        
        if report == nil {
            // TODO: Handle error case correctly
            
            print("Unable to generate report")
            
            return .failure(.unableToGenerateReport)
        }
        
        for entry in summary.entries {
            context.delete(entry)
        }
        
        return .success(report!)
    }
    
    enum ReportError: Error {
        case unableToGenerateReport
    }
}

#Preview {
    let tracker1: Tracker = .init(
        name: "Field Service",
        type: .main,
        isDefault: true,
        iconName: "figure.walk"
    )
    let tracker2: Tracker = .init(
        name: "Bethel",
        type: .separate,
        isDefault: false,
        iconName: "building"
    )

    let entries: [Entry] = [
        Entry(date: Date(), duration: 3600, tracker: tracker1, bibleStudies: 1),
        Entry(date: Date(), duration: 7200, tracker: tracker2),
    ]

    var monthlySummaries: [MonthlySummary] {
        let groups = Dictionary(grouping: entries) { $0.date.yearMonth() }

        // Map to MonthlySummary and sort descending (most recent first)
        return
            (groups.map { (key, entriesInMonth) in
                let total = entriesInMonth.reduce(0) { $0 + $1.duration }
                let bibleStudies = entriesInMonth.reduce(0) {
                    $0 + $1.bibleStudies
                }

                var totalsByTrackerID: [UUID: TimeInterval] = [:]
                var trackerByID: [UUID: Tracker] = [:]

                for entry in entriesInMonth {
                    guard let tracker = entry.tracker else { continue }
                    let trackerID = tracker.id
                    totalsByTrackerID[trackerID, default: 0] += entry.duration
                    trackerByID[trackerID] = tracker
                }

                let trackers: [MonthlySummaryTracker] = trackerByID.map {
                    (trackerID, tracker) in
                    MonthlySummaryTracker(
                        tracker: tracker,
                        total: totalsByTrackerID[trackerID]!
                    )
                }

                return MonthlySummary(
                    id: key,
                    displayName: key.monthYearString(
                        locale: Locale(identifier: "en_US")
                    ),
                    year: key.year,
                    month: key.month,
                    totalSeconds: total,
                    totalBibleStudies: bibleStudies,
                    trackers: trackers,
                    entries: entriesInMonth
                )
            }).sorted { $0.id > $1.id }  // descending
    }

    NavigationStack {
        MonthlyReportDetailView(summary: monthlySummaries[0])
    }
}
