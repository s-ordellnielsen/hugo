import SwiftData
import SwiftUI

struct AddEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var trackers: [Tracker]

    @State private var form: AddEntryFormModel

    init(seededDate: Date? = nil) {
        _form = State(initialValue: AddEntryFormModel(seededDate: seededDate))
    }

    var body: some View {
        @Bindable var form = form
        NavigationStack {
            Form {
                Section("entry.duration.label") {
                    DatePicker(
                        "entry.duration.label", selection: $form.durationDate, displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                }
                Section {
                    Button {
                        form.isCategoryPickerPresented = true
                    } label: {
                        Label(
                            form.selectedTracker?.name ?? "entry.add.tracker.none",
                            systemImage: form.selectedTracker?.iconName ?? "circle")
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
                Section {
                    Stepper(onIncrement: form.incrementBibleStudies, onDecrement: form.decrementBibleStudies) {
                        bibleStudiesLabel
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
                        .disabled(form.isSubmitDisabled)
                }
            }
            .sheet(isPresented: $form.isCategoryPickerPresented) {
                CategoryPicker(selection: $form.selectedTracker)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $form.isTimePickerPresented) {
                EntryTimePickerView(date: $form.time)
                    .presentationDetents([.height(300)])
            }
            .alert("common.error", isPresented: errorAlertBinding) {
                Button("common.dismiss", role: .cancel) { form.validationMessage = nil }
            } message: {
                Text(form.validationMessage ?? String(localized: "common.error"))
            }
        }
        .task { form.reconcileSelection(with: trackers) }
        .onChange(of: trackers) { _, newTrackers in
            form.reconcileSelection(with: newTrackers)
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(get: { form.validationMessage != nil }, set: { if !$0 { form.validationMessage = nil } })
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
