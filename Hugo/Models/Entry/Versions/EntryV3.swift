//
//  EntryV2_1.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//

import Foundation
import SwiftData

extension SchemaV3 {
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
    }
}
