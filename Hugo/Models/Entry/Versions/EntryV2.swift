//
//  EntryV2.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//

import Foundation
import SwiftData

extension SchemaV2 {
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
