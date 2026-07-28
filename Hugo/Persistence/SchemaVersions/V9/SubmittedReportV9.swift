//
//  SubmittedReportV9.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 28/07/2026.
//

import Foundation
import SwiftData

extension SchemaV9 {
    @Model
    final class SubmittedReport {
        /// Gregorian calendar month identity (matches `YearMonth`).
        var year: Int = 0
        var month: Int = 0

        /// First submission of this month.
        var firstSubmittedAt: Date = Date.distantPast
        /// Latest submission (== `firstSubmittedAt` unless re-submitted).
        var submittedAt: Date = Date.distantPast
        /// `max(Entry.createdAt)` included in this submission; entries with
        /// `createdAt > entriesClosedAt` are "unreported".
        var entriesClosedAt: Date = Date.distantPast

        /// `RoundingRule` raw value used for this submission (empty until a
        /// real submission happens; Task 2 introduces the enum).
        var roundingRuleRaw: String = ""

        /// Actual (unrounded) total of `.main` categories — "Field Service".
        var fieldServiceSeconds: TimeInterval = 0
        /// Actual grand total incl. carry-in, before rounding.
        var actualTotalSeconds: TimeInterval = 0
        /// The whole-hour total sent to the overseer.
        var submittedHours: Int = 0

        /// Minutes carried in from the previous month's submission.
        var carriedInSeconds: TimeInterval = 0
        /// Minutes carried out to next month (transfer rule only).
        var carriedOutSeconds: TimeInterval = 0
        /// Minutes added by rounding up (0 otherwise).
        var roundedUpSeconds: TimeInterval = 0
        /// Minutes dropped by rounding down (0 otherwise).
        var roundedDownSeconds: TimeInterval = 0

        var totalBibleStudies: Int = 0

        /// Value-type snapshot list; a `Tracker` may be renamed or deleted
        /// later, so categories must be self-contained (same reasoning as
        /// `Entry.EntryTracker`).
        var categories: [SubmittedCategory] = []

        init(
            year: Int = 0,
            month: Int = 0,
            firstSubmittedAt: Date = .distantPast,
            submittedAt: Date = .distantPast,
            entriesClosedAt: Date = .distantPast,
            roundingRuleRaw: String = "",
            fieldServiceSeconds: TimeInterval = 0,
            actualTotalSeconds: TimeInterval = 0,
            submittedHours: Int = 0,
            carriedInSeconds: TimeInterval = 0,
            carriedOutSeconds: TimeInterval = 0,
            roundedUpSeconds: TimeInterval = 0,
            roundedDownSeconds: TimeInterval = 0,
            totalBibleStudies: Int = 0,
            categories: [SubmittedCategory] = []
        ) {
            self.year = year
            self.month = month
            self.firstSubmittedAt = firstSubmittedAt
            self.submittedAt = submittedAt
            self.entriesClosedAt = entriesClosedAt
            self.roundingRuleRaw = roundingRuleRaw
            self.fieldServiceSeconds = fieldServiceSeconds
            self.actualTotalSeconds = actualTotalSeconds
            self.submittedHours = submittedHours
            self.carriedInSeconds = carriedInSeconds
            self.carriedOutSeconds = carriedOutSeconds
            self.roundedUpSeconds = roundedUpSeconds
            self.roundedDownSeconds = roundedDownSeconds
            self.totalBibleStudies = totalBibleStudies
            self.categories = categories
        }

        var yearMonth: YearMonth {
            YearMonth(year: year, month: month)
        }

        struct SubmittedCategory: Codable, Hashable, Identifiable {
            var name: String = ""
            var iconName: String = "tag.fill"
            var typeRaw: String = TrackerType.main.rawValue
            var actualSeconds: TimeInterval = 0
            var submittedHours: Int = 0

            init(
                name: String? = nil,
                iconName: String? = nil,
                typeRaw: String? = nil,
                actualSeconds: TimeInterval? = nil,
                submittedHours: Int? = nil
            ) {
                if let name { self.name = name }
                if let iconName { self.iconName = iconName }
                if let typeRaw { self.typeRaw = typeRaw }
                if let actualSeconds { self.actualSeconds = actualSeconds }
                if let submittedHours { self.submittedHours = submittedHours }
            }

            var type: TrackerType {
                TrackerType(rawValue: typeRaw) ?? .main
            }

            var id: String {
                name
            }
        }
    }
}
