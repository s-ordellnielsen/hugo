//
//  EntryListDetailSheet.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 31/10/2025.
//

import SwiftData
import SwiftUI

extension EntryList {
    struct DetailSheet: View {
        @Environment(\.dismiss) var dismiss
        @Environment(\.modelContext) private var context
        @Environment(\.colorScheme) private var colorScheme

        @Query private var trackers: [Tracker]

        @State var entry: Entry
        @State var selectTrackerIsPresented: Bool = false

        @State private var deleteConfirmationShown: Bool = false

        var durationAsDate: Date {
            let calendar = Calendar.current
            var components = calendar.dateComponents(
                [.year, .month, .day],
                from: Date()
            )

            let seconds = entry.duration

            let hours = Int(seconds / 3600)
            let minutes = Int(
                seconds.truncatingRemainder(dividingBy: 3600) / 60
            )
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))

            components.hour = hours
            components.minute = minutes
            components.second = secs

            return calendar.date(from: components) ?? Date()
        }

        var body: some View {
            NavigationStack {
                Form {
                    Section {
                        EntryList.DurationPicker(
                            duration: $entry.duration,
                            durationAsDate: durationAsDate
                        )
                        DatePicker(selection: $entry.date) {
                            Label("entry.date.label", systemImage: "calendar")
                        }
                    }

                    Section {
                        Stepper(
                            onIncrement: incrementBibleStudies,
                            onDecrement: decrementBibleStudies
                        ) {
                            Label(
                                "entry.biblestudies.count.label.\(entry.bibleStudies)",
                                systemImage: "book"
                            )
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack {
                            Image(systemName: entry.tracker?.iconName ?? "questionmark.circle.fill")
                            Text(entry.tracker != nil ? String(entry.tracker?.name ?? "") : String(localized: "entry.untracked")).font(.headline)
                        }
                    }
                    ToolbarItem {
                        Menu {
                            Button("Change Tracker...", systemImage: "checklist") {
                                selectTrackerIsPresented = true
                            }
                            Button("entry.delete.label", systemImage: "trash", role: .destructive) {
                                deleteConfirmationShown = true
                            }
                            .tint(.red)
                        } label: {
                            Label("More options", systemImage: "ellipsis")
                        }
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
                }
                .sheet(isPresented: $selectTrackerIsPresented) {
                    TrackerPicker(selection: $entry.tracker, dismissOnSelection: true)
                        .presentationDetents([.medium, .large])
                }
                .tint(.primary)
            }
        }

        private func incrementBibleStudies() {
            entry.bibleStudies += 1
        }

        private func decrementBibleStudies() {
            if entry.bibleStudies == 0 {
                return
            }

            entry.bibleStudies -= 1
        }
    }
}

#Preview {
    let entry = Entry(date: Date(), duration: 3600)
    
    EntryList.DetailSheet(entry: entry)
}
