import SwiftData
import SwiftUI

struct CategoryDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var tracker: Tracker

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = HugoLayout.Size.categoryIcon
    @ScaledMetric(relativeTo: .largeTitle) private var tileSize: CGFloat = HugoLayout.Size.categoryIconTile

    @State private var showDeleteConfirmation = false
    @State private var iconPickerIsPresented: Bool = false
    @State private var errorMessage: String?
    @State private var originalName: String?
    @State private var colorIsCustom = false

    var body: some View {
        @Bindable var tracker = tracker
        Form {
            Section {
                VStack(alignment: .center, spacing: HugoLayout.Spacing.compact) {
                    Button {
                        iconPickerIsPresented = true
                    } label: {
                        VStack {
                            Image(systemName: tracker.iconName)
                                .font(.system(size: iconSize))
                                .foregroundStyle(CategoryColorStyle(tracker.categoryColor))
                        }
                        .frame(width: tileSize, height: tileSize)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
                    }
                    .frame(width: tileSize, height: tileSize)
                    Text("symbol.picker.select.label")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .listRowBackground(Color.clear)

            Section("tracker.settings.name.label") {
                TextField("tracker.settings.name.placeholder", text: $tracker.name)
                    .onSubmit { commitName() }
            }

            Section {
                CategoryColorPicker(
                    selection: Binding(
                        get: { tracker.categoryColor },
                        set: { tracker.setCategoryColor($0) }),
                    onCustomChange: { colorIsCustom = $0 })
            } header: {
                Text("tracker.color.label")
            } footer: {
                Text(
                    colorIsCustom
                        ? LocalizedStringKey("tracker.color.custom.footer") : LocalizedStringKey("tracker.color.footer")
                )
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
        .onAppear {
            if originalName == nil { originalName = tracker.name }
        }
        .onDisappear { commitName() }
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
                        do {
                            try context.performIsolatedChange {
                                try CategoryDeletionService(context: context).delete(tracker)
                            }
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
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
        .errorAlert(message: $errorMessage)
    }

    private func commitName() {
        tracker.name = CategoryName.committed(edited: tracker.name, original: originalName ?? tracker.name)
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(tracker: Tracker(name: "Field Service"))
    }
}
