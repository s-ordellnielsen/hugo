//
//  Schema.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//

import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Entry.self]
    }
}

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self]
    }
}

enum SchemaV2_1: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 1, 0)

    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self]
    }
}

enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self]
    }
}

enum SchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self]
    }
}

enum SchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 1, 0)
    
    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self]
    }
}

enum SchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 1, 1)
    
    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self]
    }
}

enum SchemaV7: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 2, 0)
    
    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self]
    }
}

typealias CurrentSchema = SchemaV7

typealias Entry = CurrentSchema.Entry
typealias Tracker = CurrentSchema.Tracker
typealias Report = CurrentSchema.Report
