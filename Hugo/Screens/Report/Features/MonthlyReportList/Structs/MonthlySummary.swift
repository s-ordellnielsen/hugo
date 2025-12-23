//
//  MonthlySummary.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 28/10/2025.
//

import Foundation

struct MonthlySummary: Identifiable {
    let id: YearMonth
    let displayName: String
    let year: Int
    let month: Int
    let totalSeconds: TimeInterval
    let totalBibleStudies: Int
    let trackers: [MonthlySummaryTracker]
    let entries: [Entry]
}
