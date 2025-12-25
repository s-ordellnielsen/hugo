//
//  EntryV2_1.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//

import Foundation
import SwiftData

extension SchemaV8 {
    @Model
    final class Entry {
        var date: Date = Date()
        var duration: TimeInterval = 0
        var bibleStudies: Int = 0

        var createdAt: Date = Date()

        @Relationship var tracker: Tracker?
        var storedTracker: EntryTracker? = nil

        init(
            date: Date,
            duration: TimeInterval,
            tracker: Tracker?,
            bibleStudies: Int? = nil
        ) {
            self.date = date
            self.duration = duration
            self.tracker = tracker
            self.bibleStudies = bibleStudies ?? 0

            if tracker != nil {
                let storedTracker = EntryTracker(name: tracker!.name, icon: tracker!.iconName, type: tracker!.type)
                self.storedTracker = storedTracker
            }
        }
        
        struct EntryTracker: Codable, Hashable, Identifiable {
            var name: String = ""
            var icon: String = "questionmark.circle"
            var type: TrackerType = .main

            init(name: String? = nil, icon: String? = nil, type: TrackerType? = nil) {
                if let name = name { self.name = name }
                if let icon = icon { self.icon = icon }
                if let type = type { self.type = type }
            }

            var id: String {
                return name
            }
        }
    }
}
