//
//  EntryListRow.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 31/10/2025.
//

import SwiftUI

extension EntryList {
    struct Row: View {
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
                    if entry.bibleStudies != 0 {
                        VStack(spacing: 4) {
                            Image(systemName: "book")
                            Text("\(entry.bibleStudies)")
                                .fontDesign(.rounded)
                        }
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        
                    }
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
}

#Preview {
    @Previewable @State var selectedEntry: Entry? = nil
    let tracker = Tracker()
    
    EntryList.Row(entry: Entry(date: Date(), duration: 3600, tracker: tracker, bibleStudies: 2), selectedEntry: $selectedEntry)
}
