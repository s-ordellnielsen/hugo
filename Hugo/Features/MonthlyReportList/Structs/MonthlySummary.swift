//
//  MonthlySummary.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 28/10/2025.
//


extension MonthlyReportListView {
    struct MonthlySummary: Identifiable {
        let id: YearMonth
        let displayName: String
        let totalSeconds: Int
        let totalBibleStudies: Int
        let trackers: [MonthlySummaryTracker]
    }
}
