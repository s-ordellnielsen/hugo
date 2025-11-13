//
//  SampleData.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/10/2025.
//

import Foundation
import SwiftData
import SwiftUI

extension ModelContainer {
    static var preview: ModelContainer {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true) // Key: In-memory store
            let schema = Schema(versionedSchema: CurrentSchema.self)
            let container = try ModelContainer(for: schema, configurations: [config])

            // Optionally, add some sample data for your previews
            Task { @MainActor in
                let context = container.mainContext

                // Check if data already exists to avoid duplicates when preview refreshes
                let descriptor = FetchDescriptor<Tracker>()
                let count = try context.fetch(descriptor).count

                if count == 0 {
                    print("Adding sample data for preview...")
                    // Add sample default trackers
                    await AppInitializer.initialize(modelContext: context)

                    // Add a custom tracker
                    let customTracker = Tracker(
                        name: "Field Service",
                        isDefault: true,
                        iconName: "figure.walk",
                        hue: 0.1,
                    )
                    print("Adding testing tracker")
                    context.insert(customTracker)

                    // Add an entry to the custom tracker
                    let entry1 = Entry(date: Date().addingTimeInterval(-86400), duration: 3600)
                    entry1.tracker = customTracker
                    context.insert(entry1)

                    let entry2 = Entry(date: Date(), duration: 9000)
                    entry2.tracker = customTracker
                    context.insert(entry2)
                    
                    try context.save()
                    print("Sample data added for preview.")
                } else {
                    print("Preview already has data, skipping sample data addition.")
                }
            }
            return container

        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }
}

func sampleReports() -> [Report] {
    let tracker1: Tracker = .init(
        name: "Field Service",
        type: .main,
        isDefault: true,
        iconName: "figure.walk"
    )
    let tracker2: Tracker = .init(
        name: "Bethel",
        type: .separate,
        isDefault: false,
        iconName: "building"
    )

    let entries: [Entry] = [
        Entry(date: Date(), duration: 3600, tracker: tracker1, bibleStudies: 1),
        Entry(date: Date(), duration: 7200, tracker: tracker2),
        .init(date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(), duration: 3600, tracker: tracker1)
    ]

    let report = Report.makePure(from: entries, goal: 30)
    
    if report == nil {
        return []
    }
    
    return [report!]
}
