import SwiftData
import SwiftUI

struct EntryDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(UserDefaultsKeys.durationMinuteInterval) private var durationMinuteInterval = 1
    var entry: Entry
    @State var selectTrackerIsPresented: Bool = false

    @State private var deleteConfirmationShown: Bool = false
    @State private var deletionError: String?

    private var category: EntryCategory { entry.resolvedCategory() }

    var body: some View {
        @Bindable var entry = entry
        NavigationStack {
            Form {
                Section("entry.duration.label") {
                    DurationWheelPicker(
                        duration: $entry.duration,
                        minuteInterval: durationMinuteInterval,
                        maxDuration: max(24 * 60 * 60, entry.duration)
                    )
                }

                Section {
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
                        Image(systemName: category.iconName)
                        Text(category.name).font(.headline)
                    }
                }
                ToolbarItem {
                    Menu {
                        Button("entry.action.tracker.change", systemImage: "checklist") {
                            selectTrackerIsPresented = true
                        }
                        Button("entry.delete.label", systemImage: "trash", role: .destructive) {
                            deleteConfirmationShown = true
                        }
                    } label: {
                        Label("common.more", systemImage: "ellipsis")
                    }
                    .confirmationDialog(
                        "entry.delete.confirmation.label",
                        isPresented: $deleteConfirmationShown
                    ) {
                        Button(
                            "entry.delete.confirmation.action",
                            role: .destructive
                        ) {
                            do {
                                context.delete(entry)
                                try context.save()
                                dismiss()
                            } catch {
                                context.rollback()
                                deletionError = error.localizedDescription
                            }
                        }
                    } message: {
                        Text("entry.delete.confirmation.message")
                    }
                }
            }
            .sheet(isPresented: $selectTrackerIsPresented) {
                CategoryPicker(
                    selection: Binding(
                        get: { entry.tracker },
                        set: { newValue in
                            entry.tracker = newValue
                            entry.refreshStoredTracker()
                        }
                    ),
                    dismissOnSelection: true
                )
                .presentationDetents([.medium, .large])
            }
            .errorAlert(message: $deletionError)
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

#Preview {
    let entry = Entry(date: Date(), duration: 3600, tracker: nil)

    EntryDetailView(entry: entry)
}
