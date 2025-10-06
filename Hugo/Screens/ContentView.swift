//
//  ContentView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 05/10/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Event]
    
    @State private var showAddItemSheet: Bool = false
    
    @State private var date: Date = Date()

    var body: some View {
        NavigationSplitView {
            EventListView(items: items)
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button {
                        showAddItemSheet.toggle()
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
        .sheet(isPresented: $showAddItemSheet) {
            AddEventSheet(submitAction: addItem)
                .presentationDetents([.medium])
        }
    }

    private func addItem(date: Date, duration: Int) {
        withAnimation {
            let newItem = Event(type: EventType.fieldService, timestamp: date, duration: duration)
            modelContext.insert(newItem)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Event.self, inMemory: true)
}

