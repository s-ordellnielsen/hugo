//
//  MonthlyReportDetailLargeTotalView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 13/11/2025.
//

import SwiftUI

extension MonthlyReportDetailView {
    struct LargeTotal: View {
        let summary: MonthlySummary
        
        var primaryTotal: TimeInterval {
            summary.entries.reduce(0, { curr, acc in
                if acc.tracker?.type == .main {
                    return curr + acc.duration
                }
                
                return curr
            })
        }
        
        var secondaryTotal: TimeInterval {
            summary.entries.reduce(0, { curr, acc in
                if acc.tracker?.type == .separate {
                    return curr + acc.duration
                }
                
                return curr
            })
        }
        
        var body: some View {
            VStack {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDuration(primaryTotal))
                            .font(.callout)
                            .fontDesign(.monospaced)
                            .fontWeight(.medium)
                        Text("monthlyReport.detail.largeTotal.main.label")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack {
                            Text(formatDuration(summary.totalSeconds))
                                .font(.title)
                                .fontDesign(.monospaced)
                                .fontWeight(.bold)
                        Text("monthlyReport.detail.largeTotal.total.label")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatDuration(secondaryTotal))
                            .font(.callout)
                            .fontDesign(.monospaced)
                            .fontWeight(.medium)
                        Text("monthlyReport.detail.largeTotal.separate.label")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(8)
        }
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
