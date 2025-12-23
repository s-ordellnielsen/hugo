//
//  TrackerSummary.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 12/11/2025.
//

import Foundation

struct MonthlySummaryTracker: Identifiable {
    let tracker: Tracker
    let total: TimeInterval

    var id: UUID { self.tracker.id }
}
