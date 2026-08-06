import SwiftData
import SwiftUI

struct EntryDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    var entry: Entry
    @State var selectTrackerIsPresented: Bool = false

    @State private var deleteConfirmationShown: Bool = false

    @AppStorage(UserDefaultsKeys.durationMinuteInterval) private var durationMinuteInterval = 1

    var body: some View {
        @Bindable var entry = entry
        NavigationStack {
            Form {
                Section {
                    EntryDurationPicker(
                        duration: $entry.duration,
                        minuteInterval: durationMinuteInterval,
                        maxDuration: 24 * 60 * 60
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
                        Text(
                            entry.tracker != nil
                                ? String(entry.tracker?.name ?? "") : String(localized: "entry.untracked")
                        ).font(.headline)
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
                        .tint(.red)
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
                            context.delete(entry)
                            dismiss()
                        }
                    } message: {
                        Text("entry.delete.confirmation.message")
                    }
                }
            }
            .sheet(isPresented: $selectTrackerIsPresented) {
                CategoryPicker(selection: $entry.tracker, dismissOnSelection: true)
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

#Preview {
    let entry = Entry(date: Date(), duration: 3600, tracker: nil)

    EntryDetailView(entry: entry)
}
