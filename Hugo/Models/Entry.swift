//
//  Item.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 05/10/2025.
//

import Foundation
import SwiftData

enum EntrySchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Entry.self]
    }

    @Model
    final class Entry {
        var type: EventType = EventType.fieldService
        var timestamp: Date = Date()
        var duration: Int = 0

        init(type: EventType, timestamp: Date, duration: Int) {
            self.type = type
            self.timestamp = timestamp
            self.duration = duration
        }

        public func delete(in context: ModelContext) {
            context.delete(self)
        }

        static func makeSampleData(in container: ModelContainer) {
            let context = ModelContext(container)
            let data = [
                Entry(type: .fieldService, timestamp: Date(), duration: 3600),
                Entry(
                    type: .bethel,
                    timestamp: Date().addingTimeInterval(-86_400),
                    duration: 3600
                ),
                Entry(
                    type: .custom,
                    timestamp: Date().addingTimeInterval(-1_728_000),
                    duration: 3600
                ),
            ]
            for event in data {
                context.insert(event)
            }
        }
    }

    enum EventType: String, Codable, CaseIterable, Identifiable {
        case fieldService
        case bethel
        case custom

        var id: String { rawValue }

        var label: String {
            switch self {
            case .fieldService: return "Field Service"
            case .bethel: return "Bethel"
            case .custom: return "Custom"
            }
        }
    }
}

enum EntrySchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Entry.self]
    }

    @Model
    final class Entry {
        var date: Date = Date()
        var duration: Int = 0

        var createdAt: Date = Date()

        @Relationship var tracker: Tracker?

        init(date: Date, duration: Int, tracker: Tracker? = nil) {
            self.date = date
            self.duration = duration
            self.tracker = tracker
        }

        public func delete(in context: ModelContext) {
            context.delete(self)
        }

        static func makeSampleData(in container: ModelContainer) {
            let context = ModelContext(container)
            let data = [
                Entry(date: Date(), duration: 3600),
                Entry(date: Date().addingTimeInterval(-86_400), duration: 3600),
                Entry(
                    date: Date().addingTimeInterval(-1_728_000),
                    duration: 3600
                ),
            ]
            for event in data {
                context.insert(event)
            }
        }
    }
}

enum EntrySchemaV2_1: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 1, 0)

    static var models: [any PersistentModel.Type] {
        [Entry.self]
    }

    @Model
    final class Entry {
        var date: Date = Date()
        var duration: Int = 0
        var bibleStudies: Int = 0

        var createdAt: Date = Date()

        @Relationship var tracker: Tracker?

        init(
            date: Date,
            duration: Int,
            tracker: Tracker? = nil,
            bibleStudies: Int? = nil
        ) {
            self.date = date
            self.duration = duration
            self.tracker = tracker
            self.bibleStudies = bibleStudies ?? 0
        }

        public func delete(in context: ModelContext) {
            context.delete(self)
        }

        static func makeSampleData(in container: ModelContainer) {
            let context = ModelContext(container)
            let data = [
                Entry(date: Date(), duration: 3600),
                Entry(date: Date().addingTimeInterval(-86_400), duration: 3600),
                Entry(
                    date: Date().addingTimeInterval(-1_728_000),
                    duration: 3600
                ),
            ]
            for event in data {
                context.insert(event)
            }
        }
    }
}

typealias Entry = EntrySchemaV2_1.Entry

enum EntryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [EntrySchemaV1.self, EntrySchemaV2.self, EntrySchemaV2_1.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV2_1]
    }

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: EntrySchemaV1.self,
        toVersion: EntrySchemaV2.self,
        willMigrate: { context in
            print("Migrating from V1 to V2...")
            let entries = try context.fetch(
                FetchDescriptor<EntrySchemaV1.Entry>()
            )

            for entry in entries {
                context.insert(
                    EntrySchemaV2.Entry(
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
    
    static let migrateV2toV2_1 = MigrationStage.lightweight(fromVersion: EntrySchemaV2.self, toVersion: EntrySchemaV2_1.self)
}
