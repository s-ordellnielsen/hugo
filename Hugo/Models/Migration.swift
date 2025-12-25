//
//  Migration.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//

import Foundation
import SwiftData

enum MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            SchemaV1.self, SchemaV2.self, SchemaV2_1.self, SchemaV3.self,
            SchemaV4.self, SchemaV5.self, SchemaV6.self, SchemaV7.self,
            SchemaV8.self,
        ]
    }

    static var stages: [MigrationStage] {
        [
            migrateV1toV2, migrateV2toV2_1, migrateV2_1toV3, migrateV3toV4,
            migrateV4toV5, migrateV5toV6, migrateV6toV7, migrateV7toV8,
        ]
    }

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: { context in
            print("Migrating from V1 to V2...")
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
            print("Migrating from v2.1 to v3 (adding Report model)")

            try context.save()
        },
        didMigrate: nil
    )

    static let migrateV3toV4 = MigrationStage.custom(
        fromVersion: SchemaV3.self,
        toVersion: SchemaV4.self,
        willMigrate: { context in
            print("Migrating from v3 to v4")

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
            print("Migrating from v6 to v7 ...")

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
            print("Migrating from v7 to v8 ...")

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
                }
                
                context.delete(report)
            }

            try context.save()
        },
        didMigrate: { context in
            let entries = try context.fetch(FetchDescriptor<SchemaV8.Entry>())

            for entry in entries {
                if entry.tracker !== nil && entry.storedTracker == nil {
                    let storedTracker = SchemaV8.Entry.EntryTracker(
                        name: entry.tracker!.name, icon: entry.tracker!.iconName, type: entry.tracker!.type
                    )
                    entry.storedTracker = storedTracker
                }
            }
            
            try context.save()
        }
    )

}
