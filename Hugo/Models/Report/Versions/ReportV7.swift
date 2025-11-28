//
//  ReportV1.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//

import Foundation
import SwiftData

extension SchemaV7 {
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
        
        var fieldServiceHours: TimeInterval {
            get { fieldService / 3600 }
            set {
                fieldService = newValue
            }
        }
        
        static func make(
            from entries: [Entry],
            in context: ModelContext,
            rounding: RoundingPolicy = .roundDown
        ) -> Report? {
            var goalID: String? = nil
            var goalMonthlyHours: Int = 0
            
            let goalKey = UserDefaults.publisherStatusKey
            if let id = UserDefaults.standard.string(forKey: goalKey) {
                goalID = id
                let goal = PublisherStatusConfig.current(id)
                if let hours = goal?.monthlyGoal() {
                    goalMonthlyHours = hours
                }
            }
            
            let report = makePure(from: entries, goalID: goalID, goal: goalMonthlyHours, withRounding: rounding)
            
            if report == nil {
                return nil
            }
            
            context.insert(report!)
            
            return report
        }
        
        static func makePure(
            from entries: [Entry],
            goalID: String? = nil,
            goal: Int? = nil,
            withRounding rounding: RoundingPolicy = .roundDown
        ) -> Report? {
            let calendar = Calendar.current
            let refDate = entries.first?.date ?? Date()
            let components = calendar.dateComponents(
                [.year, .month],
                from: refDate
            )
            let year = components.year ?? 0
            let month = components.month ?? 0
            
            func dayStart(_ date: Date) -> Date {
                return calendar.startOfDay(for: date)
            }
            
            var trackerMap: [String: TrackerSummary] = [:]
            var dailyMap: [Date: TimeInterval] = [:]
            var fieldServiceTotal: TimeInterval = 0
            var bibleStudyTotal: Int = 0
            var extraTime: TimeInterval = 0
            
            for e in entries {
                let duration = e.duration
                
                if e.tracker?.type == .main {
                    fieldServiceTotal += duration
                }
                
                bibleStudyTotal += e.bibleStudies
                
                let trackerKey = e.tracker?.id.uuidString ?? "unknown"
                
                if var existing = trackerMap[trackerKey] {
                    existing.duration += duration
                    trackerMap[trackerKey] = existing
                } else {
                    let summary = TrackerSummary(
                        name: e.tracker?.name ?? "Unknown",
                        duration: duration,
                        type: e.tracker?.type ?? .separate,
                        hue: e.tracker?.hue ?? 0,
                        sat: 0.8,
                        bri: 0.9,
                        icon: e.tracker?.iconName ?? nil
                    )
                    trackerMap[trackerKey] = summary
                }
                
                let day = dayStart(e.date)
                dailyMap[day, default: 0] += duration
            }
            
            let combinedSeconds: Double = trackerMap.values.reduce(
                0,
                { x, y in
                    x + Double(y.duration)
                }
            )
            let combinedHoursFloor = floor(combinedSeconds / 3600.0)
            let combinedHoursCeil = ceil(combinedSeconds / 3600.0)
            
            switch rounding {
            case .roundUp:
                let targetSeconds = combinedHoursCeil * 3600.0
                fieldServiceTotal = TimeInterval(targetSeconds)
                
            case .roundDownAndTransfer:
                let targetSeconds = combinedHoursFloor * 3600.0
                fieldServiceTotal = TimeInterval(targetSeconds)
                extraTime = TimeInterval(
                    combinedSeconds.truncatingRemainder(dividingBy: 3600.0)
                )
            case .roundDown:
                let targetSeconds = combinedHoursFloor * 3600.0
                fieldServiceTotal = TimeInterval(targetSeconds)
            }
            
            let trackers = Array(trackerMap.values)
            let dailyPoints: [DailyPoint] = dailyMap.map {
                DailyPoint(date: $0.key, total: $0.value)
            }
                .sorted { $0.date < $1.date }
            
            let report = Report(
                year: year,
                month: month,
                fieldService: fieldServiceTotal,
                bibleStudies: bibleStudyTotal,
                goalID: goalID,
                goalMonthlyHours: goal ?? 0,
                extraTime: extraTime,
                trackers: trackers,
                dailyPoints: dailyPoints
            )
            
            return report
        }
    }
}
