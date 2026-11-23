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
        Form {
            Section {
                DurationWheelPicker(
                    duration: $entry.duration,
                    minuteInterval: durationMinuteInterval,
                    maxDuration: max(24 * 60 * 60, entry.duration)
                )
            } header: {
                titleHeader
            }

            Section {
                DatePicker(selection: $entry.date) {
                    Label("entry.date.label", systemImage: "calendar")
                }
            }

            if BibleStudiesRule.showsControl(
                categoryAllows: category.allowsBibleStudies, count: entry.bibleStudies)
            {
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
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .confirmationDialog(
            "entry.delete.confirmation.label",
            isPresented: $deleteConfirmationShown
        ) {
            Button(
                "entry.delete.confirmation.action",
                role: .destructive
            ) {
                do {
                    try context.performIsolatedChange { context.delete(entry) }
                    dismiss()
                } catch {
                    deletionError = error.localizedDescription
                }
            }
        } message: {
            Text("entry.delete.confirmation.message")
        }
        .sheet(isPresented: $selectTrackerIsPresented) {
            CategoryPicker(
                selection: Binding(
                    get: { entry.tracker },
                    set: { newValue in
                        entry.tracker = newValue
                        entry.refreshStoredTracker()
                    }
                )
            )
            .presentationDetents([.medium, .large])
        }
        .errorAlert(message: $deletionError)
    }

    private var titleHeader: some View {
        HStack(alignment: .top, spacing: HugoLayout.Spacing.regular) {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                Label {
                    Text(category.name)
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: category.iconName)
                        .font(.system(.title2, weight: .semibold))
                }
                .labelStyle(.titleAndIcon)
                .foregroundStyle(Color.primary)
                .accessibilityAddTraits(.isHeader)
                Text("entry.duration.label")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
            .layoutPriority(1)
            Spacer(minLength: HugoLayout.Spacing.regular)
            headerControls
        }
        .textCase(nil)
        .padding(.bottom, HugoLayout.Spacing.compact)
    }

    private var headerControls: some View {
        HStack(spacing: HugoLayout.Spacing.compact) {
            Menu {
                Button("entry.action.tracker.change", systemImage: "checklist") {
                    selectTrackerIsPresented = true
                }
                Button("entry.delete.label", systemImage: "trash", role: .destructive) {
                    deleteConfirmationShown = true
                }
            } label: {
                Label("common.more", systemImage: "ellipsis").labelStyle(.iconOnly)
            }
            Button(role: .close) {
                dismiss()
            }
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.regular)
        .fixedSize()
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
