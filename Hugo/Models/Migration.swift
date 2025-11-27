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
            SchemaV4.self, SchemaV5.self, SchemaV6.self
        ]
    }

    static var stages: [MigrationStage] {
        [
            migrateV1toV2, migrateV2toV2_1, migrateV2_1toV3, migrateV3toV4, migrateV4toV5, migrateV5toV6
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
}
