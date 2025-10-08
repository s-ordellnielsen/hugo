//
//  ContentView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 05/10/2025.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Query private var events: [Event]

    @State private var showAddItemSheet: Bool = false

    let goal: Double = 50.0
    var current: Double {
        let totalSeconds = events.reduce(0) { $0 + Double($1.duration) }

        let totalHours = totalSeconds / 3600.0

        return totalHours
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    MonthlyProgressView(value: current)
                        .padding(.horizontal, 48)
                        .padding(.bottom, 32)
                        .padding(.top, 16)
                    EventListView()
                        .padding(.bottom, 20)
                        .padding(.top, 24)
                }
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem {
                    Button {
                        
                    } label: {
                        Label("Open Account", systemImage: "person.fill")
                    }
                    .tint(.secondary)
                }
            }
        }
    }
}

#Preview(traits: .sampleData) {
    ContentView()
}
