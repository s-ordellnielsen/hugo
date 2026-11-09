//
//  PlanV13.swift
//  Hugo
//

import Foundation
import SwiftData

extension SchemaV13 {
    /// Time the user intends to spend in service on one day. A plan never
    /// counts as logged time; the Planner compares the two.
    @Model
    final class Plan {
        var id: UUID = UUID()
        /// 12:00 on the planned day, so a time-zone change cannot move the
        /// plan to another day. The start time, if any, is `startMinute`.
        var date: Date = Date()
        var duration: TimeInterval = 0
        /// Minutes after midnight, or nil when the plan has no start time.
        var startMinute: Int?

        /// `Tracker.id` of the plan's category. Plans keep the id and a
        /// snapshot instead of a relationship, so V12 needed no new `Tracker`,
        /// `Entry` or `SubmittedReport` classes.
        var categoryID: UUID?
        var categoryName: String = ""
        var categoryIconName: String = "questionmark.circle"
        var categoryType: TrackerType = TrackerType.main

        var createdAt: Date = Date()

        init(date: Date, duration: TimeInterval, startMinute: Int? = nil, tracker: Tracker?) {
            self.date = date
            self.duration = duration
            self.startMinute = startMinute
            self.categoryID = tracker?.id
            self.categoryName = tracker?.name ?? ""
            self.categoryIconName = tracker?.iconName ?? "questionmark.circle"
            self.categoryType = tracker?.type ?? .main
        }

        /// Points the plan at `tracker` and copies its name, icon and type, so
        /// the plan keeps its category if the category is deleted later.
        func setCategory(_ tracker: Tracker?) {
            categoryID = tracker?.id
            categoryName = tracker?.name ?? ""
            categoryIconName = tracker?.iconName ?? "questionmark.circle"
            categoryType = tracker?.type ?? .main
        }
    }
}
