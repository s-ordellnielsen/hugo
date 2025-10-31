//
//  EntryListDetailSheet.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 31/10/2025.
//

import SwiftUI
import SwiftData

extension EntryList {
    struct DetailSheet: View {
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
                
                EntryList.DurationPicker(duration: $entry.duration, durationAsDate: durationAsDate)
                
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
}
