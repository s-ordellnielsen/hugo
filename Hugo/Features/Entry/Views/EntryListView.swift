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
            EventDetailSheet(entry: entry)
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
                Image(systemName: getEventIcon(for: entry.type))
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
                            .fontWeight(.semibold)
                        Text("Field Service")
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.primary)
                    .font(.system(size: 17))
                    .fontDesign(.rounded)
                    Text(
                        entry.timestamp,
                        format: Date.FormatStyle(
                            date: .abbreviated,
                            time: .none
                        )
                    )
                    .font(.callout)
                    .foregroundColor(.secondary)
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

private struct EventDetailSheet: View {
    @Environment(\.dismiss) var dismiss

    var entry: Entry

    @State private var deleteConfirmationShown: Bool = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                HStack(spacing: 12) {
                    Image(systemName: getEventIcon(for: entry.type))
                        .font(.title)
                    Text("entry.label")
                        .font(.title)
                        .fontDesign(.rounded)
                    Spacer()
                }
                .fontWeight(.bold)
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem {
                    Menu {
                        Button {

                        } label: {
                            Label("entry.edit.label", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deleteConfirmationShown = true
                        } label: {
                            Label("entry.delete.label", systemImage: "trash")
                        }
                    } label: {
                        Label("navigation.done", systemImage: "ellipsis")
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
}

#Preview(traits: .sampleData) {
    EntryListView(entries: [
        Entry(type: .fieldService, timestamp: Date(), duration: 3600)
    ])
}
