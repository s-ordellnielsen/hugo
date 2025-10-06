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
    @Query private var events: [Event]

    @State private var showAddItemSheet: Bool = false
    
    @State private var selectedEventType: EventType?
    
    init(showAddItemSheet: Bool, selectedEventType: EventType? = nil) {
        self.showAddItemSheet = showAddItemSheet
        self.selectedEventType = selectedEventType
        
        debugPrint(selectedEventType as Any)
    }

    var body: some View {
        NavigationSplitView {
            EventListView()
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem {
                    Menu {
                        Picker("Filter Type", selection: $selectedEventType) {
                            Label("Show All", systemImage: "list.bullet")
                                .tag(nil as EventType?)
                            ForEach(EventType.allCases) { type in
                                Label(String(describing: type.label), systemImage: getEventIcon(for: type))
                                    .tag(type)
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease")
                    }
                }
                ToolbarSpacer(.fixed)
                ToolbarItem {
                    Button {
                        print("Clicked")
                        showAddItemSheet.toggle()
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .environmentObject(EventListViewModel(events: events))
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
    ContentView(showAddItemSheet: false)
        .modelContainer(for: Event.self, inMemory: true)
}

