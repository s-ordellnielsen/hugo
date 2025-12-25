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
                    let fieldServiceTracker = Tracker(
                        name: "Field Service",
                        isDefault: true,
                        iconName: "figure.walk",
                    )
                    print("Adding Field Service testing tracker")
                    context.insert(fieldServiceTracker)

                    // Add an entry to the custom tracker
                    let entry1 = Entry(date: Date().addingTimeInterval(-86400), duration: 3600, tracker: fieldServiceTracker)
                    context.insert(entry1)

                    let entry2 = Entry(date: Date(), duration: 9000, tracker: fieldServiceTracker)
                    context.insert(entry2)
                    
                    let phoneServiceTracker = Tracker(
                        name: "Phone Service",
                        isDefault: false,
                        iconName: "phone.fill"
                    )
                    print("Adding Phone Service testing tracker")
                    context.insert(phoneServiceTracker)
                    
                    let entry3 = Entry(date: Date(), duration: 7200, tracker: phoneServiceTracker)
                    context.insert(entry3)
                    
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
