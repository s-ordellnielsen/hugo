//
//  AppSchema.swift
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

enum SchemaV10: VersionedSchema {
    static let versionIdentifier = Schema.Version(7, 0, 0)

    typealias Entry = SchemaV9.Entry
    typealias Tracker = SchemaV9.Tracker
    typealias Report = SchemaV9.Report

    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self, SubmittedReport.self]
    }
}

enum SchemaV11: VersionedSchema {
    static let versionIdentifier = Schema.Version(8, 0, 0)

    typealias Report = SchemaV10.Report

    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self, SubmittedReport.self]
    }
}

enum SchemaV12: VersionedSchema {
    static let versionIdentifier = Schema.Version(9, 0, 0)

    typealias Entry = SchemaV11.Entry
    typealias Tracker = SchemaV11.Tracker
    typealias Report = SchemaV11.Report
    typealias SubmittedReport = SchemaV11.SubmittedReport

    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self, SubmittedReport.self, Plan.self]
    }
}

typealias CurrentSchema = SchemaV12

// SchemaV8/V9.Report remains as migration compatibility ballast until a tested
// future schema version can remove it safely.
typealias Entry = CurrentSchema.Entry
typealias Tracker = CurrentSchema.Tracker
typealias SubmittedReport = CurrentSchema.SubmittedReport
typealias Plan = CurrentSchema.Plan
