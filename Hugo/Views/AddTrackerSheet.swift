//
//  AddTrackerSheet.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 16/10/2025.
//

import SwiftUI
import SwiftData

struct AddTrackerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Query var trackers: [Tracker] = []
    
    @State private var tracker: Tracker = Tracker()
    
    @State private var iconPickerIsPresented: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .center, spacing: 8) {
                        Button {
                            iconPickerIsPresented = true
                        } label: {
                            VStack {
                                Image(systemName: tracker.iconName)
                                    .font(.system(size: 48))
                                    .tint(.primary)
                            }
                            .frame(width: 128, height: 128)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(32)
                        }
                        Text("Select Icon")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowBackground(Color.clear)

                Section {
                    TextField("Name", text: $tracker.name)
                }
                
                Section {
                    Picker("Type", selection: $tracker.type) {
                        ForEach(TrackerType.allCases) { trackerType in
                            Text(trackerType.label).tag(trackerType)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Tracker Type")
                } footer: {
                    Text(tracker.type.description)
                }
                
                Section {
                    Toggle("Can add Bible Studies", isOn: $tracker.allowBibleStudies)
                    Toggle("Use as Default", isOn: $tracker.isDefault)
                } header: {
                    Text("Options")
                } footer: {
                    if trackers.first(where: { $0.isDefault == true }) != nil {
                        Text("Turning this on will override the current default tracker: \(trackers.first(where: { $0.isDefault == true })!.name).")
                    }
                }
                .tint(.green)
            }
            .navigationTitle("Add Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $iconPickerIsPresented, content: {
                SymbolPicker(set: .tracker, selectedSymbol: $tracker.iconName)
            })
            .toolbar {
                ToolbarItem {
                    Button(role: .confirm) {
                        context.insert(tracker)
                        dismiss()
                    }
                    .disabled(tracker.name == "")
                }
            }
        }
    }
}

#Preview {
    AddTrackerSheet()
}
