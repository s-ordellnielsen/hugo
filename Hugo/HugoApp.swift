//
//  HugoApp.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 05/10/2025.
//

import SwiftUI
import SwiftData
import os.log

@main
struct HugoApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let logger = Logger(subsystem: "com.ordellnielsen.Hugo", category: "CloudKit")
        
        logger.info("Initializing ModelContainer...")
        
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" || ProcessInfo.processInfo.environment["XCODE_SERVICE_ACCOUNT_STATUS"] != nil {
            print("Initializing ModelContainer with in-memory storage for previews...")
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            
            do {
                return try ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: [config])
            } catch {
                fatalError("Still could not create ModelContainer: \(error)")
            }
        }
        #endif
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: [modelConfiguration])
        } catch {
            logger.error("SwiftData init failed: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("tab.overview", systemImage: "house") {
                    ContentView()
                }
//                Tab("tab.planner", systemImage: "calendar") {
//                    PlannerView()
//                }
                Tab("tab.report", systemImage: "tray.full.fill") {
                    ReportView()
                }
            }
            .task {
                await AppInitializer.initialize(modelContext: sharedModelContainer.mainContext)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

