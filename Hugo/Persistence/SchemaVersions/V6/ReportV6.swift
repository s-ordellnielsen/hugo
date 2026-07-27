//
//  ReportV1.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//

import Foundation
import SwiftData

extension SchemaV6 {
    @Model
    final class Report {
        var id: UUID = UUID()
        
        var year: Int = 0
        var month: Int = 0
        
        var fieldService: TimeInterval = 0
        var bibleStudies: Int = 0
        
        var goalID: String? = nil
        var goal: Int = 0
        
        var extraTime: TimeInterval = 0
        
        var trackers: [TrackerSummary] = []
        var dailyPoints: [DailyPoint] = []
        
        var createdAt: Date = Date()
        
        init(
            year: Int,
            month: Int,
            fieldService: TimeInterval,
            bibleStudies: Int,
            goalID: String?,
            goalMonthlyHours: Int,
            extraTime: TimeInterval,
            trackers: [TrackerSummary] = [],
            dailyPoints: [DailyPoint] = []
        ) {
            self.year = year
            self.month = month
            self.fieldService = fieldService
            self.bibleStudies = bibleStudies
            
            self.goalID = goalID
            self.goal = goalMonthlyHours
            
            self.extraTime = extraTime
            
            if !trackers.isEmpty {
                self.trackers = trackers
            }
            
            if !dailyPoints.isEmpty {
                self.dailyPoints = dailyPoints
            }
        }
        
    }
}
