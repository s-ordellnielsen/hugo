//
//  MonthlyReportListView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 28/10/2025.
//

import SwiftUI
import SwiftData

struct MonthlyReportListView: View {
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]

    private var monthlySummaries: [MonthlySummary] {
        let groups = Dictionary(grouping: entries) { $0.date.yearMonth() }

        // Map to MonthlySummary and sort descending (most recent first)
        return
            (groups.map { (key, entriesInMonth) in
                let total = entriesInMonth.reduce(0) { $0 + $1.duration }
                let bibleStudies = entriesInMonth.reduce(0) { $0 + $1.bibleStudies }
                
                var totalsByTrackerID: [UUID: TimeInterval] = [:]
                var trackerByID: [UUID: Tracker] = [:]
                
                for entry in entriesInMonth {
                    guard let tracker = entry.tracker else { continue }
                    let trackerID = tracker.id
                    totalsByTrackerID[trackerID, default: 0] += entry.duration
                    trackerByID[trackerID] = tracker
                }
                
                let trackers: [MonthlySummaryTracker] = trackerByID.map { (trackerID, tracker) in
                    MonthlySummaryTracker(tracker: tracker, total: totalsByTrackerID[trackerID]!)
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

    var body: some View {
        VStack(spacing: 24) {
            ForEach(monthlySummaries) { month in
                Row(month: month)
            }
        }
    }
}

#Preview {
    ReportView()
        .modelContainer(.preview)
}
