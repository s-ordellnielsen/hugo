//
//  ReportV8.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//
//  An empty model with no attributes. It is in the `models` of every schema
//  version up to the current one, so removing it changes the stored schema.
//  It stays until a new, tested schema version drops it (see the note in
//  `AppSchema.swift`).
//

import Foundation
import SwiftData

extension SchemaV8 {
    @Model
    final class Report {
        init() {}
    }
}
