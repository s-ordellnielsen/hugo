//
//  MonthlyReportDetailDailyListView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 23/12/2025.
//

import SwiftUI

extension MonthlyReportDetailView {
    struct DailyList: View {
        let summary: MonthlySummary
        
        var body: some View {
            Section {
                ForEach(summary.entries) { entry in
                    NavigationLink(destination: EntryList.DetailSheet(entry: entry)) {
                        Label {
                            HStack {
                                Text(
                                    entry.date,
                                    format: Date.FormatStyle(
                                        date: .abbreviated,
                                        time: .none
                                    )
                                )
                                Spacer()
                                Text(formatDuration(entry.duration))
                                    .fontDesign(.monospaced)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: entry.tracker?.iconName ?? "questionmark")
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
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

