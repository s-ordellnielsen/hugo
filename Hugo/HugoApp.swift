//
//  HugoApp.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 05/10/2025.
//

import SwiftUI
import SwiftData

@main
struct HugoApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Event.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView(showAddItemSheet: false)
                    .tabItem {
                        Label("Overview", systemImage: "house")
                    }
                PlannerView()
                    .tabItem {
                        Label("Planner", systemImage: "calendar")
                    }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
