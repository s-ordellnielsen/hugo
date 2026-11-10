import SwiftData
import SwiftUI

struct AddEntryView: View {
    @AppStorage(UserDefaultsKeys.durationMinuteInterval) private var durationMinuteInterval = 1
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @Query private var trackers: [Tracker]

    @State private var form: AddEntryFormModel

    init(
        seededDate: Date? = nil,
        seededDuration: TimeInterval? = nil,
        preferredTrackerID: UUID? = nil,
        seededStartMinute: Int? = nil
    ) {
        _form = State(
            initialValue: AddEntryFormModel(
                seededDate: seededDate, seededDuration: seededDuration,
                preferredTrackerID: preferredTrackerID, seededStartMinute: seededStartMinute))
    }

    var body: some View {
        @Bindable var form = form
        NavigationStack {
            Form {
                Section("entry.duration.label") {
                    DurationWheelPicker(
                        duration: $form.durationInSeconds,
                        minuteInterval: durationMinuteInterval,
                        maxDuration: 24 * 60 * 60
                    )
                }
                Section {
                    Button {
                        form.isCategoryPickerPresented = true
                    } label: {
                        categoryLabel
                    }
                }
                Section {
                    DatePicker("entry.date.label", selection: $form.date, in: ...Date.now, displayedComponents: .date)
                    Button {
                        form.isTimePickerPresented = true
                    } label: {
                        HStack {
                            Text("entry.time.label")
                            Spacer()
                            timeLabel
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if form.showsBibleStudies {
                    Section {
                        Stepper(onIncrement: form.incrementBibleStudies, onDecrement: form.decrementBibleStudies) {
                            bibleStudiesLabel
                        }
                    }
                }
            }
            .navigationTitle("entry.add.label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("navigation.dismiss", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem {
                    Button("entry.add.label", systemImage: "plus", action: submit)
                        .buttonStyle(.glassProminent)
                        .tint(.hugoAccent)
                        .disabled(form.isSubmitDisabled)
                }
            }
            .sheet(isPresented: $form.isCategoryPickerPresented) {
                CategoryPicker(selection: $form.selectedTracker)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $form.isTimePickerPresented) {
                EntryTimePickerView(date: $form.time)
                    .presentationDetents([.height(HugoLayout.Size.addEntryCompactSheetHeight)])
            }
            .errorAlert(message: $form.validationMessage)
        }
        .task { form.reconcileSelection(with: trackers) }
        .onChange(of: trackers) { _, newTrackers in
            form.reconcileSelection(with: newTrackers)
        }
    }

    private func submit() {
        guard let draft = form.draft() else { return }
        let entry = Entry(
            date: draft.date, duration: draft.duration, tracker: draft.tracker, bibleStudies: draft.bibleStudies)
        context.insert(entry)
        do {
            try context.save()
            dismiss()
        } catch {
            context.delete(entry)
            form.validationMessage = error.localizedDescription
        }
    }

    /// The selected category in its color, or "no category" in the accent
    /// color, so the row reads as a button. With Increase Contrast on, the
    /// name stays in the normal text color and only the icon is tinted.
    @ViewBuilder
    private var categoryLabel: some View {
        let style = CategoryColorStyle(form.selectedTracker?.categoryColor)
        let nameStyle =
            colorSchemeContrast == .increased ? AnyShapeStyle(.primary) : AnyShapeStyle(style)
        if let tracker = form.selectedTracker {
            Label {
                Text(tracker.name).foregroundStyle(nameStyle)
            } icon: {
                Image(systemName: tracker.iconName).foregroundStyle(style)
            }
        } else {
            Label {
                Text("entry.add.tracker.none").foregroundStyle(nameStyle)
            } icon: {
                Image(systemName: "circle").foregroundStyle(style)
            }
        }
    }

    private var bibleStudiesLabel: some View {
        Text("entry.biblestudies.count.label.\(form.bibleStudies)")
    }

    @ViewBuilder
    private var timeLabel: some View {
        if let time = form.time {
            Text(formatTime(time))
                .foregroundStyle(.secondary)
        } else {
            Text("entry.add.time.none")
                .foregroundStyle(.secondary)
        }
    }

    private func formatTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

#Preview {
    AddEntryView().modelContainer(.preview)
}
