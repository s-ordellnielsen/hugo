//
//  Schema.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//

import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Entry.self]
    }
}

enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self]
    }
}

enum SchemaV2_1: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 1, 0)

    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self]
    }
}

enum SchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self]
    }
}

enum SchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self]
    }
}

enum SchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 1, 0)
    
    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self]
    }
}

enum SchemaV6: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 1, 1)
    
    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self]
    }
}

enum SchemaV7: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 2, 0)
    
    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self]
    }
}

enum SchemaV8: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self]
    }
}

enum SchemaV9: VersionedSchema {
    static let versionIdentifier = Schema.Version(6, 0, 0)

    typealias Entry = SchemaV8.Entry
    typealias Tracker = SchemaV8.Tracker
    typealias Report = SchemaV8.Report

    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self, SubmittedReport.self]
    }
}

typealias CurrentSchema = SchemaV9

// SchemaV8/V9.Report remains as migration compatibility ballast until a tested
// future schema version can remove it safely.
typealias Entry = CurrentSchema.Entry
typealias Tracker = CurrentSchema.Tracker
typealias SubmittedReport = CurrentSchema.SubmittedReport
