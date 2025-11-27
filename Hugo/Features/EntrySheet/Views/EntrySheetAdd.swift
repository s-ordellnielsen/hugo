//
//  Add.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 31/10/2025.
//

import SwiftData
import SwiftUI

extension EntrySheet {
    struct Add: View {
        @Environment(\.dismiss) var dismiss
        @Environment(\.modelContext) var context

        @Query private var trackers: [Tracker]

        @State var date: Date =
            (Calendar.current.date(
                bySettingHour: 0,
                minute: 0,
                second: 0,
                of: Date()
            ) ?? Date())
        @State var time: Date? = nil
        @State var duration: Date =
            (Calendar.current.date(
                bySettingHour: 0,
                minute: 0,
                second: 0,
                of: Date()
            ) ?? Date())
        @State var bibleStudies: Int = 0

        @State private var selectedTracker: Tracker? = nil

        @State var showTimeSheet: Bool = false
        @State var showTrackerSheet: Bool = false

        @State var includeTime: Bool = false

        var body: some View {
            NavigationStack {
                Form {
                    Section("entry.duration.label") {
                        VStack(alignment: .center) {
                            DatePicker(
                                "entry.duration.label",
                                selection: $duration,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Section {
                        HStack {
                            Text("entry.add.tracker.label")
                            Spacer()
                            Button {
                                showTrackerSheet = true
                            } label: {
                                HStack {
                                    Image(
                                        systemName: selectedTracker?.iconName
                                            ?? "circle"
                                    )
                                    Text(
                                        selectedTracker?.name
                                            ?? "entry.add.tracker.none"
                                    )
                                }
                                .foregroundStyle(.accent)
                            }
                        }.sheet(isPresented: $showTrackerSheet) {
                            TrackerPicker(selection: $selectedTracker)
                                .presentationDetents([.medium])
                        }
                    }
                    .onChange(of: trackers) { old, new in
                        selectedTracker = new.first
                    }

                    Section {
                        DatePicker(
                            "entry.date.label",
                            selection: $date,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        Button {
                            showTimeSheet = true
                        } label: {
                            HStack {
                                Text("entry.time.label")
                                Spacer()
                                if time == nil {
                                    Text("entry.add.time.none")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(
                                        (time != nil)
                                            ? formatTime(time ?? Date())
                                            : "Error"
                                    )
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                        .sheet(isPresented: $showTimeSheet) {
                            SelectTimeSheet(
                                date: $time,
                                showTimeSheet: $showTimeSheet
                            )
                            .presentationDetents([.height(300)])
                        }
                    }

                    Section {
                        Stepper(
                            onIncrement: incrementBibleStudies,
                            onDecrement: decrementBibleStudies,
                        ) {
                            Text(
                                "entry.biblestudies.count.label.\(bibleStudies)"
                            )
                        }
                    }
                }
                .navigationTitle("entry.add.label")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Label("navigation.dismiss", systemImage: "xmark")
                        }
                    }
                    ToolbarItem {
                        Button(action: submitForm) {
                            Label("entry.add.label", systemImage: "plus")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(isDurationZero())
                    }
                }
            }
            .onAppear {
                if selectedTracker == nil {
                    if let defaultTracker = trackers.first(where: \.isDefault) {
                        selectedTracker = defaultTracker
                    } else {
                        selectedTracker = trackers.first
                    }
                }
            }

        }

        private func submitForm() {
            let calendar = Calendar.current
            var components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: date
            )

            if time != nil {
                components.hour = calendar.component(.hour, from: time!)
                components.minute = calendar.component(.minute, from: time!)
            }

            let newDate = calendar.date(from: components)!

            if trackers.first != nil {
                let entry = Entry(
                    date: newDate,
                    duration: durationInSeconds(),
                    tracker: selectedTracker ?? trackers.first!,
                    bibleStudies: bibleStudies
                )
                context.insert(entry)
            }
            dismiss()
        }

        private func isDurationZero() -> Bool {
            withAnimation {
                let calendar = Calendar.current
                let durationComponents = calendar.dateComponents(
                    [.hour, .minute],
                    from: duration
                )
                return
                    (durationComponents.hour == 0
                    && durationComponents.minute == 0)
            }
        }

        private func durationInSeconds() -> TimeInterval {
            let calendar = Calendar.current
            let components = calendar.dateComponents(
                [.hour, .minute],
                from: duration
            )

            let hours = components.hour ?? 0
            let minutes = components.minute ?? 0

            return TimeInterval(hours * 3600 + minutes * 60)
        }

        private func formatTime(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }

        private func isDateAtMidnight() -> Bool {
            let calendar = Calendar.current
            let components = calendar.dateComponents(
                [.hour, .minute],
                from: date
            )
            return components.hour == 0 && components.minute == 0
        }

        private func incrementBibleStudies() {
            bibleStudies += 1
        }

        private func decrementBibleStudies() {
            bibleStudies -= 1

            if bibleStudies < 0 {
                bibleStudies = 0
            }
        }

        private func setBibleStudies(_ value: Int) {
            if value < 0 {
                return
            }

            bibleStudies = value
        }

        struct SelectTimeSheet: View {
            @Binding var date: Date?
            @Binding var showTimeSheet: Bool

            @State private var selectedDate: Date = Date()

            var body: some View {
                NavigationStack {
                    DatePicker(
                        "entry.add.time.select.label",
                        selection: $selectedDate,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .navigationBarTitle("entry.add.time.select.label")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem {
                            Button {
                                date = selectedDate
                                showTimeSheet = false
                            } label: {
                                Label(
                                    "navigation.done",
                                    systemImage: "checkmark"
                                )
                            }
                        }
                        if date != nil {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    date = nil
                                    showTimeSheet = false
                                } label: {
                                    Label(
                                        "navigation.clear",
                                        systemImage: "trash"
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    EntrySheet.Add()
        .modelContainer(.preview)
}
