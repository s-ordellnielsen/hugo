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
    private static let logger = Logger(subsystem: "Hugo.Persistence", category: "Migration")

    static var schemas: [any VersionedSchema.Type] {
        [
            SchemaV1.self, SchemaV2.self, SchemaV2_1.self, SchemaV3.self,
            SchemaV4.self, SchemaV5.self, SchemaV6.self, SchemaV7.self,
            SchemaV8.self, SchemaV9.self, SchemaV10.self,
        ]
    }

    static var stages: [MigrationStage] {
        [
            migrateV1toV2, migrateV2toV2_1, migrateV2_1toV3, migrateV3toV4,
            migrateV4toV5, migrateV5toV6, migrateV6toV7, migrateV7toV8,
            migrateV8toV9, migrateV9toV10,
        ]
    }

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: { context in
            logger.debug("Migrating from V1 to V2")
            let entries = try context.fetch(
                FetchDescriptor<SchemaV1.Entry>()
            )

            for entry in entries {
                context.insert(
                    SchemaV2.Entry(
                        date: entry.timestamp,
                        duration: entry.duration,
                        tracker: nil
                    )
                )

                context.delete(entry)
            }

            try context.save()
        },
        didMigrate: nil
    )

    static let migrateV2toV2_1 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV2_1.self
    )

    static let migrateV2_1toV3 = MigrationStage.custom(
        fromVersion: SchemaV2_1.self,
        toVersion: SchemaV3.self,
        willMigrate: { context in
            logger.debug("Migrating from V2.1 to V3")

            try context.save()
        },
        didMigrate: nil
    )

    static let migrateV3toV4 = MigrationStage.custom(
        fromVersion: SchemaV3.self,
        toVersion: SchemaV4.self,
        willMigrate: { context in
            logger.debug("Migrating from V3 to V4")

            try context.save()
        },
        didMigrate: nil
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

}
