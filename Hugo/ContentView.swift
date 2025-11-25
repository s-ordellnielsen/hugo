//
//  ContentView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 05/10/2025.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) var context
    
    @AppStorage("isOnboarding") private var isOnboarding: Bool = true
    
    var body: some View {
        TabView {
            Tab("tab.overview", systemImage: "house") {
                OverviewView()
            }
            //                Tab("tab.planner", systemImage: "calendar") {
            //                    PlannerView()
            //                }
            Tab("tab.report", systemImage: "tray.full.fill") {
                ReportView()
            }
        }
//        .tint(.primary)
//        .task {
//            await AppInitializer.initialize(
//                modelContext: context
//            )
//        }
        .sheet(isPresented: $isOnboarding) {
            Task {
                await AppInitializer.initialize(
                    modelContext: context
                )
            }
        } content: {
            OnboardingView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(.preview)
}
