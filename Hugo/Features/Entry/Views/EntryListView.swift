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

    var entry: Entry

    @State private var deleteConfirmationShown: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
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
                        ForEach(trackers) { tracker in
                            Button {

                            } label: {
                                Label(
                                    tracker.name,
                                    systemImage: tracker.iconName
                                )
                            }
                        }
                    } label: {
                        Label("Change Tracker", systemImage: "chevron.down")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.extraLarge)
                    .buttonBorderShape(.circle)
                }
                .padding(.leading, 12)
                .fontWeight(.bold)

                HStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Duration")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Text(formatDuration(entry.duration))
                                .fontDesign(.monospaced)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(colorScheme == .dark ? Color(.systemGroupedBackground).opacity(0.5) : .white.opacity(0.5))
                    .cornerRadius(24)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Date")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .fontDesign(.monospaced)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(colorScheme == .dark ? Color(.systemGroupedBackground).opacity(0.5) : .white.opacity(0.5))
                    .cornerRadius(24)
                }
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem {
                    Button {

                    } label: {
                        Label("entry.edit.label", systemImage: "pencil")
                    }
                }
                ToolbarSpacer()
                ToolbarItem {
                    Button(role: .destructive) {
                        deleteConfirmationShown = true
                    } label: {
                        Label("entry.delete.label", systemImage: "trash")
                    }
                    .confirmationDialog(
                        "Delete Entry?",
                        isPresented: $deleteConfirmationShown
                    ) {
                        Button("Delete", role: .destructive) {
                            context.delete(entry)
                            dismiss()
                        }
                    } message: {
                        Text("Are you sure you want to delete this entry?")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("navigation.done", systemImage: "xmark")
                    }
                }

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

//#Preview {
//    EntryListView(entries: [
//        Entry(date: Date(), duration: 3600)
//    ])
//    .modelContainer(.preview)
//}

#Preview {
    let tracker = Tracker(name: "Field Service")

    EntryDetailSheet(
        entry: Entry(date: Date(), duration: 3600, tracker: tracker)
    )
    .modelContainer(.preview)
}
