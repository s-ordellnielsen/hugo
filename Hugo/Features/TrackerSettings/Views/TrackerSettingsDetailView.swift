//
//  TrackerDetailView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 17/10/2025.
//

import SwiftUI
import SwiftData

extension TrackerSettingsView {
    struct DetailView: View {
        @Environment(\.modelContext) private var context
        @Environment(\.dismiss) private var dismiss
        
        @Query private var trackers: [Tracker]
        
        @State var tracker: Tracker
        
        @State private var showDeleteConfirmation = false
        @State private var iconPickerIsPresented: Bool = false
        
        var body: some View {
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
                        .frame(width: 128, height: 128)
                        Text("Select Icon")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowBackground(Color.clear)

                Section("Name") {
                    TextField("Tracker Name", text: $tracker.name)
                }
                
                Section {
                    Picker("Tracker Type", selection: $tracker.type) {
                            ForEach(TrackerType.allCases) { trackerType in
                                Text(trackerType.label).tag(trackerType)
                            }
                    }
                    .pickerStyle(.navigationLink)
                    .labelsHidden()
                } footer: {
                    Text(tracker.type.description)
                }
                
                Section {
                    NavigationLink(destination: OptionView(tracker: tracker)) {
                        Text("Advanced Options")
                    }
                }
            }
            .sheet(isPresented: $iconPickerIsPresented, content: {
                SymbolPicker(set: .tracker, selectedSymbol: $tracker.iconName)
            })
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Image(systemName: tracker.iconName)
                        Text(tracker.name).font(.headline)
                    }
                }
                ToolbarItem {
                    FavoriteSwitch(tracker: tracker)
                }
                ToolbarSpacer()
                ToolbarItem {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Tracker", systemImage: "trash")
                    }
                    .confirmationDialog("Delete \(tracker.name)?", isPresented: $showDeleteConfirmation) {
                        Button("common.delete", role: .destructive) {
                            context.delete(tracker)
                            dismiss()
                        }
                        Button(role: .cancel) {}
                    } message: {
                        VStack {
                            Text("Delete \(tracker.name)?")
                            Text("All entries connected to this tracker will be deleted as well")
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TrackerSettingsView.DetailView(tracker: Tracker(name: "Field Service"))
    }
}
