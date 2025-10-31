//
//  List.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 28/10/2025.
//

import SwiftData
import SwiftUI

extension MonthlyReportList {
    struct Content: View {
        @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]

        private var monthlySummaries: [MonthlySummary] {
            let groups = Dictionary(grouping: entries) { $0.date.yearMonth() }

            // Map to MonthlySummary and sort descending (most recent first)
            return
                (groups.map { (key, entriesInMonth) in
                    let total = entriesInMonth.reduce(0) { $0 + $1.duration }
                    return MonthlySummary(
                        id: key,
                        displayName: key.monthYearString(
                            locale: Locale(identifier: "en_US")
                        ),
                        totalSeconds: total
                    )
                }).sorted { $0.id > $1.id }  // descending
        }

        var body: some View {
            List {
                ForEach(monthlySummaries) { month in
                    MonthlyReportList.Row(month: month)
                }
            }
        }
    }
}

#Preview {
    MonthlyReportList.Content()
        .modelContainer(.preview)
}
