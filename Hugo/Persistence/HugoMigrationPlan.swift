//
//  Migration.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//

import Foundation
import OSLog
import SwiftData

enum MigrationPlan: SchemaMigrationPlan {
    private static let logger = Logger(subsystem: "com.ordellnielsen.Hugo", category: "Migration")

    static var schemas: [any VersionedSchema.Type] {
        [
            SchemaV1.self, SchemaV2.self, SchemaV2_1.self, SchemaV3.self,
            SchemaV4.self, SchemaV5.self, SchemaV6.self, SchemaV7.self,
            SchemaV8.self, SchemaV9.self, SchemaV10.self, SchemaV11.self,
        ]
    }

    static var stages: [MigrationStage] {
        [
            migrateV1toV2, migrateV2ToV21, migrateV21ToV3, migrateV3toV4,
            migrateV4toV5, migrateV5toV6, migrateV6toV7, migrateV7toV8,
            migrateV8toV9, migrateV9toV10, migrateV10toV11,
        ]
    }

    private struct LegacyV1Entry: Sendable {
        let timestamp: Date
        let duration: Int
    }

    nonisolated(unsafe) private static var legacyV1Entries: [LegacyV1Entry] = []

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: { context in
            logger.debug("Migrating from V1 to V2")
            let entries = try context.fetch(
                FetchDescriptor<SchemaV1.Entry>()
            )
            legacyV1Entries = entries.map { LegacyV1Entry(timestamp: $0.timestamp, duration: $0.duration) }

            entries.forEach(context.delete)
            try context.save()
        },
        didMigrate: { context in
            for legacy in legacyV1Entries {
                context.insert(SchemaV2.Entry(date: legacy.timestamp, duration: legacy.duration, tracker: nil))
            }

            legacyV1Entries = []

            try context.save()
        }
    )

    static let migrateV2ToV21 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV2_1.self
    )

    static let migrateV21ToV3: MigrationStage = .lightweight(
        fromVersion: SchemaV2_1.self,
        toVersion: SchemaV3.self
    )

    static let migrateV3toV4: MigrationStage = .lightweight(
        fromVersion: SchemaV3.self,
        toVersion: SchemaV4.self
    )

    static let migrateV4toV5: MigrationStage = .lightweight(
        fromVersion: SchemaV4.self,
        toVersion: SchemaV5.self
    )

    static let migrateV5toV6: MigrationStage = .lightweight(
        fromVersion: SchemaV5.self,
        toVersion: SchemaV6.self
    )

    static let migrateV6toV7: MigrationStage = .custom(
        fromVersion: SchemaV6.self,
        toVersion: SchemaV7.self,
        willMigrate: { context in
            logger.debug("Migrating from V6 to V7")

            let trackers = try context.fetch(
                FetchDescriptor<SchemaV6.Tracker>()
            )

            for tracker in trackers {
                if tracker.type.rawValue == "none" {
                    tracker.type = .separate
                }

                tracker.hue = 0.0
            }

            try context.save()
        },
        didMigrate: nil
    )

    static let migrateV7toV8: MigrationStage = .custom(
        fromVersion: SchemaV7.self,
        toVersion: SchemaV8.self,
        willMigrate: { context in
            logger.debug("Migrating from V7 to V8")

            let reports = try context.fetch(
                FetchDescriptor<SchemaV7.Report>()
            )

            var calendar = Calendar.current

            for report in reports {
                var components = DateComponents()
                components.year = report.year
                components.month = report.month
                components.day = 1
                components.hour = 0
                components.minute = 0
                components.second = 0

                let date = calendar.date(from: components) ?? Date()
                let trackers = try context.fetch(
                    FetchDescriptor<SchemaV7.Tracker>()
                )

                for trackerSummary in report.trackers {
                    let tracker = trackers.first {
                        $0.name == trackerSummary.name
                    }

                    let entry = SchemaV7.Entry(
                        date: date,
                        duration: trackerSummary.duration,
                        tracker: tracker
                    )
                    context.insert(entry)
                }

                context.delete(report)
            }

            try context.save()
        },
        didMigrate: { context in
            let entries = try context.fetch(FetchDescriptor<SchemaV8.Entry>())

            for entry in entries {
                if let tracker = entry.tracker, entry.storedTracker == nil {
                    let storedTracker = SchemaV8.Entry.EntryTracker(
                        name: tracker.name, icon: tracker.iconName, type: tracker.type
                    )
                    entry.storedTracker = storedTracker
                }
            }

            try context.save()
        }
    )

    static let migrateV8toV9: MigrationStage = .custom(
        fromVersion: SchemaV8.self,
        toVersion: SchemaV9.self,
        willMigrate: { context in
            logger.debug("Migrating from V8 to V9")
            try context.save()
        },
        didMigrate: { context in
            logger.debug("Backfilling V8 to V9 SubmittedReport sentinels")

            let entries = try context.fetch(
                FetchDescriptor<SchemaV9.Entry>()
            )

            // Backfill one sentinel SubmittedReport per month that has
            // entries: `submittedAt == .distantPast` marks the month as
            // "never submitted", while `entriesClosedAt` (the newest
            // `Entry.createdAt` of the month) keeps pre-existing entries
            // from being falsely flagged as "added after submission".
            var newestCreatedAtByMonth: [YearMonth: Date] = [:]

            for entry in entries {
                let yearMonth = entry.date.yearMonth()
                let createdAt = entry.createdAt
                if let current = newestCreatedAtByMonth[yearMonth] {
                    newestCreatedAtByMonth[yearMonth] = max(current, createdAt)
                } else {
                    newestCreatedAtByMonth[yearMonth] = createdAt
                }
            }

            for (yearMonth, entriesClosedAt) in newestCreatedAtByMonth {
                context.insert(
                    SchemaV9.SubmittedReport(
                        year: yearMonth.year,
                        month: yearMonth.month,
                        entriesClosedAt: entriesClosedAt
                    )
                )
            }

            try context.save()
        }
    )

    /// Optionality-only CloudKit-eligibility repair for `SubmittedReport`.
    /// No data transform: the on-disk columns are identical, so this is a
    /// lightweight inferred-mapping migration that re-stamps the store hash.
    static let migrateV9toV10: MigrationStage = .lightweight(
        fromVersion: SchemaV9.self,
        toVersion: SchemaV10.self
    )

    private struct LegacyReportSnapshot: Sendable {
        let year: Int
        let month: Int
        let categories: [LegacyCategorySnapshot]
        let roundingRuleRaw: String
        let carriedInSeconds: TimeInterval
        let carriedOutSeconds: TimeInterval
        let roundedUpSeconds: TimeInterval
        let roundedDownSeconds: TimeInterval
        let submittedAt: Date
    }

    private struct LegacyCategorySnapshot: Sendable {
        let name: String
        let iconName: String
        let typeRaw: String
        let actualSeconds: TimeInterval
        let submittedHours: Int

        var type: TrackerType {
            TrackerType(rawValue: typeRaw) ?? .main
        }
    }

    nonisolated(unsafe) private static var legacyReports: [LegacyReportSnapshot] = []

    static let migrateV10toV11: MigrationStage = .custom(
        fromVersion: SchemaV10.self,
        toVersion: SchemaV11.self,
        willMigrate: { context in
            let reports = try context.fetch(FetchDescriptor<SchemaV10.SubmittedReport>())
            legacyReports = reports.compactMap { report in
                guard let year = report.year, let month = report.month else { return nil }

                return LegacyReportSnapshot(
                    year: year,
                    month: month,
                    categories: (report.categories ?? []).map {
                        LegacyCategorySnapshot(
                            name: $0.name,
                            iconName: $0.iconName,
                            typeRaw: $0.typeRaw,
                            actualSeconds: $0.actualSeconds,
                            submittedHours: $0.submittedHours
                        )
                    },
                    roundingRuleRaw: report.roundingRuleRaw ?? "",
                    carriedInSeconds: report.carriedInSeconds ?? 0,
                    carriedOutSeconds: report.carriedOutSeconds ?? 0,
                    roundedUpSeconds: report.roundedUpSeconds ?? 0,
                    roundedDownSeconds: report.roundedDownSeconds ?? 0,
                    submittedAt: report.submittedAt ?? .distantPast
                )
            }

            try context.save()
        },
        didMigrate: { context in
            let reports = try context.fetch(FetchDescriptor<SchemaV11.SubmittedReport>())

            for legacyReport in legacyReports {
                guard legacyReport.submittedAt != .distantPast else { continue }

                guard
                    let report = reports.first(where: {
                        $0.year == legacyReport.year && $0.month == legacyReport.month
                    })
                else { continue }

                let mainCategories = legacyReport.categories.filter { $0.type == .main }
                let separateCategories = legacyReport.categories.filter { $0.type == .separate }

                var submittedReportingLines = separateCategories.map { category in
                    SubmittedReportingLine(
                        typeRaw: category.typeRaw,
                        typeName: category.name,
                        durationInSeconds: category.actualSeconds,
                        submittedHours: category.submittedHours,
                        roundingRaw: inferredRoundingRaw(
                            actualSeconds: category.actualSeconds,
                            submittedHours: category.submittedHours
                        )
                    )
                }

                let mainActualSeconds = mainCategories.reduce(0) {
                    $0 + $1.actualSeconds
                }
                let mainSubmittedHours = mainCategories.reduce(0) {
                    $0 + $1.submittedHours
                }
                let mainSubmittedSeconds = TimeInterval(mainSubmittedHours) * 3_600
                let hasCarryOut = legacyReport.carriedOutSeconds > 0
                let mainDuration =
                    hasCarryOut
                    ? mainSubmittedSeconds + legacyReport.carriedOutSeconds
                    : mainActualSeconds
                let mainRoundingRaw =
                    hasCarryOut
                    ? RoundingRule.transfer.rawValue
                    : inferredRoundingRaw(
                        actualSeconds: mainActualSeconds,
                        submittedHours: mainSubmittedHours
                    )

                if hasCarryOut {
                    let nextMonth = YearMonth(
                        year: legacyReport.year,
                        month: legacyReport.month
                    ).nextMonth()
                    let nextMonthStart = nextMonth.date()
                    let entry = SchemaV11.Entry(
                        date: nextMonthStart,
                        duration: legacyReport.carriedOutSeconds,
                        tracker: nil,
                        source: (submission: report, lineID: "")
                    )
                    entry.storedTracker = .init(
                        name: String(localized: "category.default.label"),
                        icon: "figure.walk",
                        type: .main
                    )
                    entry.createdAt = nextMonthStart
                    context.insert(entry)
                }

                submittedReportingLines.append(
                    SubmittedReportingLine(
                        typeRaw: TrackerType.main.rawValue,
                        typeName: "",
                        durationInSeconds: mainDuration,
                        submittedHours: mainSubmittedHours,
                        roundingRaw: mainRoundingRaw
                    )
                )
                report.reportingLines = submittedReportingLines

                // Preserve the V10 report-level values while adding the V11
                // reporting-line and carry-entry projections.
                //report.roundingRuleRaw = legacyReport.roundingRuleRaw
                //report.carriedInSeconds = legacyReport.carriedInSeconds
                //report.carriedOutSeconds = legacyReport.carriedOutSeconds
                //report.roundedUpSeconds = legacyReport.roundedUpSeconds
                //report.roundedDownSeconds = legacyReport.roundedDownSeconds
            }

            legacyReports = []
            try context.save()
        }
    )

    private static func inferredRoundingRaw(
        actualSeconds: TimeInterval,
        submittedHours: Int
    ) -> String {
        let submittedSeconds = TimeInterval(submittedHours) * 3_600

        if submittedSeconds > actualSeconds { return RoundingRule.up.rawValue }
        if submittedSeconds < actualSeconds { return RoundingRule.down.rawValue }
        return ""
    }

    private typealias SubmittedReportingLine = SchemaV11.SubmittedReport.SubmittedReportingLine
}
