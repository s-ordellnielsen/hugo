//
//  AddReportSheet.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 13/11/2025.
//

import SwiftData
import SwiftUI

struct AddReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @Query private var trackers: [Tracker]

    @State private var year: Int = Calendar.current.component(
        .year,
        from: Date()
    )

    var lastFiveYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return (currentYear - 4...currentYear).reversed()
    }

    @State private var month = Calendar.current.component(.month, from: Date())

    var monthNames: [Int: String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"

        var months: [Int: String] = [:]
        for month in 1...12 {
            let date = Calendar.current.date(
                from: DateComponents(month: month)
            )!
            months[month] = formatter.string(from: date)
        }
        return months
    }

    @State private var trackerValues: [UUID: String] = [:]
    @FocusState private var focusedTracker: UUID?

    @State private var goal: String = ""
    let goalInputID = UUID()

    var body: some View {
        NavigationStack {
            Form(content: {
                Section {
                    Picker("Year", selection: $year) {
                        ForEach(lastFiveYears, id: \.self) { year in
                            Text(String(year))
                        }
                    }
                    Picker("Month", selection: $month) {
                        ForEach(1...12, id: \.self) { month in
                            Text(Calendar.current.monthSymbols[month - 1]).tag(
                                month
                            )
                        }
                    }
                }

                Section("Trackers") {
                    ForEach(trackers) { tracker in
                        HStack {
                            Label(tracker.name, systemImage: tracker.iconName)
                            Spacer()
                            TextField("0", text: binding(for: tracker.id))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedTracker, equals: tracker.id)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedTracker = tracker.id
                        }
                    }
                }

                Section {
                    HStack {
                        Text("goal.label")
                        Spacer()
                        TextField("0", text: $goal)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedTracker, equals: goalInputID)
                    }
                    .onTapGesture {
                        focusedTracker = goalInputID
                    }
                }
            })
            .navigationTitle("Add Report")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                syncInitialValues()
            }
            .onChange(of: trackers) {
                syncInitialValues()
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        // TODO: Handle adding report manually
                        
                        dismiss()
                    } label: {
                        Label("Submit", systemImage: "plus")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.blue)
                }
            }
        }
    }

    private func binding(for id: UUID) -> Binding<String> {
        return Binding<String>(
            get: { trackerValues[id] ?? "" },
            set: { newValue in trackerValues[id] = newValue }
        )
    }

    private func syncInitialValues() {
        let ids = Set(trackers.map { $0.id })
        // ensure every tracker has a value
        for id in ids {
            trackerValues[id] = trackerValues[id] ?? ""
        }
        // remove values for trackers that no longer exist
        trackerValues.keys.forEach { key in
            if !ids.contains(key) {
                trackerValues.removeValue(forKey: key)
            }
        }
    }
}

#Preview {
    AddReportSheet()
        .modelContainer(.preview)
}
