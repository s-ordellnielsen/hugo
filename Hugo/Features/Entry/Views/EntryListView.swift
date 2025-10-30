//
//  EventListView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 06/10/2025.
//

import SwiftData
import SwiftUI

struct EntryListView: View {
    @Environment(\.modelContext) var modelContext

    var entries: [Entry]

    @State var selectedEntry: Entry? = nil

    var body: some View {
        ForEach(entries) { entry in
            RowView(entry: entry, selectedEntry: $selectedEntry)
        }
        .sheet(item: $selectedEntry) { entry in
            EntryDetailSheet(entry: entry)
                .presentationDetents([.medium])
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                entries[index].delete(in: modelContext)
            }
        }
    }
}

private struct RowView: View {
    @Environment(\.colorScheme) var colorScheme

    var entry: Entry
    @Binding var selectedEntry: Entry?

    var body: some View {
        Button {
            selectedEntry = entry
        } label: {
            HStack(spacing: 16) {
                Image(
                    systemName: entry.tracker?.iconName ?? "questionmark.circle"
                )
                .font(.title)
                .fontWeight(.medium)
                .frame(width: 32, height: 32)
                .alignmentGuide(
                    .leading,
                    computeValue: { dimension in
                        dimension[.leading]
                    }
                )
                VStack(alignment: .leading) {
                    HStack(spacing: 6) {
                        Text(formatDuration(entry.duration))
                            .fontWeight(.bold)
                        Text(entry.tracker?.name ?? "Unknown")
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                    .font(.system(size: 17))
                    .fontDesign(.rounded)
                    Text(
                        entry.date,
                        format: Date.FormatStyle(
                            date: .abbreviated,
                            time: .none
                        )
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 24)
            .background(
                colorScheme == .dark
                    ? Color(.secondarySystemBackground)
                    : Color(.systemBackground)
            )
            .cornerRadius(32)
            .shadow(color: .primary.opacity(0.05), radius: 16, y: 12)
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

private struct EntryDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme

    @Query private var trackers: [Tracker]

    @State var entry: Entry

    @State private var deleteConfirmationShown: Bool = false
    
    var durationAsDate: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        
        let seconds = entry.duration
        
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        components.hour = hours
        components.minute = minutes
        components.second = secs
        
        return calendar.date(from: components) ?? Date()
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(
                        systemName: entry.tracker?.iconName
                            ?? "questionmark.circle"
                    )
                    .font(.title)
                    Text(entry.tracker?.name ?? "Unknown")
                        .font(.title)
                        .fontDesign(.rounded)
                    Spacer()
                    Menu {
                        Button(role: .destructive) {
                            deleteConfirmationShown = true
                        } label: {
                            Label(
                                "entry.delete.label",
                                systemImage: "trash"
                            )
                        }
                    } label: {
                        Label("Change Tracker", systemImage: "chevron.down")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.extraLarge)
                    .buttonBorderShape(.circle)
                    .confirmationDialog(
                        "entry.delete.confirmation.label",
                        isPresented: $deleteConfirmationShown
                    ) {
                        Button(
                            "entry.delete.confirmation.action",
                            role: .destructive
                        ) {
                            context.delete(entry)
                            dismiss()
                        }
                    } message: {
                        Text("entry.delete.confirmation.message")
                    }
                }
                .padding(.leading, 12)
                .fontWeight(.bold)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(.all, 0)
            
            DurationSelect(duration: $entry.duration, durationAsDate: durationAsDate)
            
            DatePicker(selection: $entry.date) {
                Label("Date", systemImage: "calendar")
            }
        }
    }

    private func formatDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

fileprivate struct DurationSelect: View {
    @Environment(\.modelContext) private var context
    
    @Binding var duration: Int
    
    @State var durationAsDate: Date
    
    var body: some View {
        DatePicker(selection: $durationAsDate, displayedComponents: .hourAndMinute) {
            Label("Duration", systemImage: "clock")
        }
        .onChange(of: durationAsDate, updateDuration)
    }
    
    private func updateDuration() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: durationAsDate)
        
        let hours: Int = (components.hour ?? 0) * 60 * 60
        let minutes: Int = (components.minute ?? 0) * 60
        let seconds: Int = components.second ?? 0
        
        duration = hours + minutes + seconds
    }
}

#Preview {
    EntryListView(entries: [
        Entry(date: Date(), duration: 3600)
    ])
    .modelContainer(.preview)
}

#Preview {
    let tracker = Tracker(name: "Field Service")

    EntryDetailSheet(
        entry: Entry(date: Date(), duration: 3600, tracker: tracker)
    )
    .modelContainer(.preview)
}
