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
            let container = try ModelContainer(for: Schema([
                Tracker.self,
                Entry.self,
            ]), configurations: [config])

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
