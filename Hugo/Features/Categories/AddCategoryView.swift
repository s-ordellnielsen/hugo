import SwiftData
import SwiftUI

struct AddCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var trackers: [Tracker]

    @State private var name = ""
    @State private var type: TrackerType = .main
    @State private var allowBibleStudies = true
    @State private var isDefault = false
    @State private var iconName = "tag.fill"
    @State private var iconPickerIsPresented = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        iconPickerIsPresented = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: iconName)
                                .font(.system(size: 48))
                                .tint(.primary)
                                .frame(width: 128, height: 128)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(32)
                            Text("symbol.picker.select.label")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .listRowBackground(Color.clear)

                Section {
                    TextField("addTracker.field.name.placeholder", text: $name)
                }

                Section {
                    Picker("tracker.type.label.long", selection: $type) {
                        ForEach(TrackerType.allCases) { trackerType in
                            Text(trackerType.label).tag(trackerType)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("tracker.type.label.long")
                } footer: {
                    Text(type.description)
                }

                Section("tracker.options.label") {
                    Toggle("tracker.options.allow-bible-studies", isOn: $allowBibleStudies)
                    Toggle("tracker.options.use-as-default", isOn: $isDefault)
                }
            }
            .navigationTitle("addTrackerSheet.title")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $iconPickerIsPresented) {
                SymbolPicker(set: .tracker, selectedSymbol: $iconName)
            }
            .toolbar {
                ToolbarItem {
                    Button(role: .confirm, action: submit) {
                        Label("common.done", systemImage: "checkmark")
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .errorAlert(message: $errorMessage)
        }
    }

    private func submit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let tracker = Tracker(
            name: trimmedName,
            type: type,
            allowBibleStudies: allowBibleStudies,
            isDefault: false,
            iconName: iconName
        )
        context.insert(tracker)

        do {
            if isDefault {
                try DefaultCategoryService(context: context).setDefault(tracker)
            } else {
                try context.save()
            }
            dismiss()
        } catch {
            context.delete(tracker)
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AddCategoryView()
        .modelContainer(.preview)
}
