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
                        Text("symbol.picker.select.label")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowBackground(Color.clear)

                Section {
                    TextField("addTracker.field.name.placeholder", text: $tracker.name)
                }
                
                Section {
                    Picker("tracker.type.label.long", selection: $tracker.type) {
                        ForEach(TrackerType.allCases) { trackerType in
                            Text(trackerType.label).tag(trackerType)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("tracker.type.label.long")
                } footer: {
                    Text(tracker.type.description)
                }
                
                Section {
                    Toggle("tracker.options.allow-bible-studies", isOn: $tracker.allowBibleStudies)
                    Toggle("tracker.options.use-as-default", isOn: $tracker.isDefault)
                } header: {
                    Text("tracker.options.label")
                } footer: {
                    if trackers.first(where: { $0.isDefault == true }) != nil {
                        Text("addTracker.option.useAsDefault.warning.\(trackers.first(where: { $0.isDefault == true })!.name)")
                    }
                }
                .tint(.green)
            }
            .navigationTitle("addTrackerSheet.title")
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
