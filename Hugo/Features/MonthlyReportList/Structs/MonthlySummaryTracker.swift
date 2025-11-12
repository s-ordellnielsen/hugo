//
//  TrackerSummary.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 12/11/2025.
//

import Foundation

extension MonthlyReportListView {
    struct MonthlySummaryTracker : Identifiable{
        let tracker: Tracker
        let total: Int
        
        var id: UUID { self.tracker.id }
    }
}
