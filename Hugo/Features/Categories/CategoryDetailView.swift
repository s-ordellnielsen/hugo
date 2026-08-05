//
//  TrackerDetailView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 17/10/2025.
//

import SwiftData
import SwiftUI

struct CategoryDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var tracker: Tracker

    @State private var showDeleteConfirmation = false
    @State private var iconPickerIsPresented: Bool = false

    var body: some View {
        @Bindable var tracker = tracker
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
                    Text("symbol.picker.select.label")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .listRowBackground(Color.clear)

            Section("tracker.settings.name.label") {
                TextField("tracker.settings.name.placeholder", text: $tracker.name)
            }

            Section {
                Picker("tracker.type.label.long", selection: $tracker.type) {
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
                NavigationLink(destination: CategoryAdvancedOptionsView(tracker: tracker)) {
                    Text("tracker.settings.advancedOptions.label")
                }
            }
        }
        .sheet(
            isPresented: $iconPickerIsPresented,
            content: {
                SymbolPicker(set: .tracker, selectedSymbol: $tracker.iconName)
            }
        )
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    Image(systemName: tracker.iconName)
                    Text(tracker.name).font(.headline)
                }
            }
            ToolbarItem {
                DefaultCategoryButton(tracker: tracker)
            }
            ToolbarSpacer()
            ToolbarItem {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("tracker.action.delete", systemImage: "trash")
                }
                .confirmationDialog("tracker.action.delete.\(tracker.name)?", isPresented: $showDeleteConfirmation) {
                    Button("common.delete", role: .destructive) {
                        context.delete(tracker)
                        try? context.save()
                        dismiss()
                    }
                    Button(role: .cancel) {}
                } message: {
                    VStack {
                        Text("tracker.action.delete.confirmation.\(tracker.name)")
                        Text("tracker.action.delete.confirmation.warning")
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(tracker: Tracker(name: "Field Service"))
    }
}
