//
//  EventListView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 06/10/2025.
//

import SwiftData
import SwiftUI

struct EventListView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Event.timestamp, order: .reverse) var events: [Event]
    
    @State var selectedEvent: Event? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("This Month")
                        .font(.headline)
                        .fontDesign(.rounded)
                    Text("October, 2025")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding()
            ForEach(events) { event in
                RowView(event: event, selectedEvent: $selectedEvent)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .frame(maxWidth: .infinity)
        .sheet(item: $selectedEvent) { event in
            EventDetailSheet(event: event)
                .presentationDetents([.medium])
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                events[index].delete(in: modelContext)
            }
        }
    }
}

fileprivate struct RowView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var event: Event
    @Binding var selectedEvent: Event?
    
    var body: some View {
        Button {
            selectedEvent = event
        } label: {
            HStack(spacing: 16) {
                Image(systemName: getEventIcon(for: event.type))
                    .font(.title)
                    .fontWeight(.medium)
                    .frame(width: 32, height: 32)
                    .alignmentGuide(.leading, computeValue: {dimension in
                        dimension[.leading]
                    })
                VStack(alignment: .leading) {
                    Text(formatDuration(event.duration))
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .font(.system(size: 16))
                    Text(
                        event.timestamp,
                        format: Date.FormatStyle(
                            date: .abbreviated,
                            time: .none
                        )
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 24)
            .background(colorScheme == .dark
                        ? Color(.secondarySystemBackground)
                        : Color(.systemBackground))
            .cornerRadius(32)
        }
        .buttonStyle(.plain)
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

fileprivate struct EventDetailSheet: View {
    var event: Event
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Image(systemName: getEventIcon(for: event.type))
                    Text("Event")
                }
            }
        }
    }
}

#Preview(traits: .sampleData) {
    EventListView()
}
