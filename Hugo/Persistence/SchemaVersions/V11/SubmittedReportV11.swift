//
//  SubmittedReportV11.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 28/07/2026.
//

import Foundation
import SwiftData

extension SchemaV11 {
    @Model
    final class SubmittedReport {
        /// Gregorian calendar month identity (matches `YearMonth`).
        var year: Int?
        var month: Int?

        /// First submission of this month.
        var firstSubmittedAt: Date?
        /// Latest submission (== `firstSubmittedAt` unless re-submitted).
        var submittedAt: Date?
        /// `max(Entry.createdAt)` included in this submission; entries with
        /// `createdAt > entriesClosedAt` are "unreported".
        var entriesClosedAt: Date?

        /// Legacy report-level rounding fields retained for lightweight
        /// migration and for the current submission workflow. V11 reporting
        /// lines contain the new per-line representation as well.
        var roundingRuleRaw: String?

        /// Actual (unrounded) total of `.main` categories — "Field Service".
        var fieldServiceSeconds: TimeInterval?
        /// Actual grand total incl. carry-in, before rounding.
        var actualTotalSeconds: TimeInterval?
        /// The whole-hour total sent to the overseer.
        var submittedHours: Int?

        /// Legacy carry and rounding amounts retained unchanged from V10.
        var carriedInSeconds: TimeInterval?
        var carriedOutSeconds: TimeInterval?
        var roundedUpSeconds: TimeInterval?
        var roundedDownSeconds: TimeInterval?

        var totalBibleStudies: Int?

        /// Value-type snapshot list; a `Tracker` may be renamed or deleted
        /// later, so categories must be self-contained (same reasoning as
        /// `Entry.EntryTracker`).
        var categories: [SubmittedCategory]?

        var reportingLines: [SubmittedReportingLine] = []
        @Relationship(deleteRule: .nullify, inverse: \Entry.sourceSubmission) var generatedEntries: [Entry]? = []

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
            categories: [SubmittedCategory] = [],
            reportingLines: [SubmittedReportingLine] = []
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
            self.reportingLines = reportingLines
        }

        var yearMonth: YearMonth {
            YearMonth(year: year ?? 0, month: month ?? 0)
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

        struct SubmittedReportingLine: Codable, Hashable, Identifiable {
            var typeRaw: String = ""

            /// Unused for aggregate `.main` line; always "" there.
            var typeName: String = ""
            var durationInSeconds: TimeInterval = 0
            var submittedHours: Int = 0
            var roundingRaw: String = RoundingRule.defaultValue.rawValue

            init(
                typeRaw: String? = nil,
                typeName: String? = nil,
                durationInSeconds: TimeInterval? = nil,
                submittedHours: Int? = nil,
                roundingRaw: String? = nil
            ) {
                if let typeRaw { self.typeRaw = typeRaw }
                if let typeName { self.typeName = typeName }
                if let durationInSeconds { self.durationInSeconds = durationInSeconds }
                if let submittedHours { self.submittedHours = submittedHours }
                if let roundingRaw { self.roundingRaw = roundingRaw }
            }

            var type: TrackerType {
                TrackerType(rawValue: typeRaw) ?? .main
            }

            var id: String {
                if type == .main { return "" }

                return typeName
            }

            var rounding: RoundingRule? {
                RoundingRule(rawValue: roundingRaw)
            }

            var duration: Duration {
                get { .seconds(durationInSeconds) }
                set {
                    let components = newValue.components
                    durationInSeconds = Double(components.seconds) + (Double(components.attoseconds) * 1e-18)
                }
            }

            var remainder: Duration {
                let remainder = duration - .seconds(submittedHours * 3600)

                return remainder < .zero ? remainder * -1 : remainder
            }
        }
    }
}
