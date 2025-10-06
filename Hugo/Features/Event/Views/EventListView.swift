//
//  EventListView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 06/10/2025.
//

import SwiftUI
import SwiftData

struct EventListView: View {
    @EnvironmentObject private var viewModel: EventListViewModel
    
    var body: some View {
        List {
            ForEach(viewModel.events) { event in
                NavigationLink {
                    Text("Item at \(event.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: getEventIcon(for: event.type))
                            .foregroundStyle(.accent)
                        VStack(alignment: .leading) {
                            Text(formatDuration(event.duration))
                                .fontWeight(.medium)
                            Text(event.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .none))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .onDelete(perform: deleteItems)
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                viewModel.delete(event: viewModel.allEvents[index])
            }
        }
    }
    
    private func formatDuration(_ duration: Int) -> String {
        let totalMinutes = duration / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        var components = [String]()
        if hours > 0 {
            components.append("\(hours) hour\(hours > 1 ? "s" : "")")
        }
        if minutes > 0 {
            components.append("\(minutes) minute\(minutes > 1 ? "s" : "")")
        }
        
        return components.joined(separator: " ")
    }
}

#Preview {
    EventListView()
        .environmentObject(EventListViewModel(events: [Event(type: .fieldService, timestamp: Date(), duration: 3600)]))
}
