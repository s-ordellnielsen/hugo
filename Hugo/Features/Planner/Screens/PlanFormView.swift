import SwiftData
import SwiftUI

/// Adds a plan to a day, or edits or deletes an existing one. The day itself is
/// fixed; to move a plan, delete it and add it again.
struct PlanFormView: View {
    @AppStorage(UserDefaultsKeys.durationMinuteInterval) private var durationMinuteInterval = 1
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var trackers: [Tracker]

    @State private var form: PlanFormModel
    @State private var isDeleteConfirmationShown = false

    private let plan: Plan?

    init(day: CalendarDay, plan: Plan? = nil) {
        self.plan = plan
        _form = State(initialValue: PlanFormModel(day: day, plan: plan))
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
                        if let tracker = form.selectedTracker {
                            Label(tracker.name, systemImage: tracker.iconName)
                        } else {
                            Label("entry.add.tracker.none", systemImage: "circle")
                        }
                    }
                }
                Section {
                    Button {
                        form.isTimePickerPresented = true
                    } label: {
                        HStack {
                            Text("planner.plan.startTime")
                            Spacer()
                            startTimeLabel
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("planner.plan.startTime.footer")
                }
                if plan != nil {
                    Section {
                        Button("planner.plan.delete", role: .destructive) {
                            isDeleteConfirmationShown = true
                        }
                    }
                }
            }
            .navigationTitle(plan == nil ? "planner.plan.add" : "planner.plan.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("navigation.dismiss", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem {
                    Button("planner.plan.save", systemImage: "checkmark", action: save)
                        .buttonStyle(.glassProminent)
                        .tint(.hugoAccent)
                        .disabled(form.isSaveDisabled)
                }
            }
            .sheet(isPresented: $form.isCategoryPickerPresented) {
                CategoryPicker(selection: $form.selectedTracker)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $form.isTimePickerPresented) {
                EntryTimePickerView(date: $form.startTime)
                    .presentationDetents([.height(HugoLayout.Size.addEntryCompactSheetHeight)])
            }
            .confirmationDialog(
                "planner.plan.delete.confirm",
                isPresented: $isDeleteConfirmationShown,
                titleVisibility: .visible
            ) {
                Button("planner.plan.delete", role: .destructive, action: delete)
            }
            .errorAlert(message: $form.validationMessage)
        }
        .task { form.reconcileSelection(with: trackers) }
        .onChange(of: trackers) { _, newTrackers in
            form.reconcileSelection(with: newTrackers)
        }
    }

    @ViewBuilder
    private var startTimeLabel: some View {
        if let time = form.startTime {
            Text(time.formatted(date: .omitted, time: .shortened))
        } else {
            Text("planner.plan.startTime.none")
        }
    }

    private func save() {
        guard let draft = form.draft() else { return }
        do {
            let service = PlanService(context: context)
            if let plan {
                try service.update(plan, with: draft)
            } else {
                try service.add(draft)
            }
            dismiss()
        } catch {
            form.validationMessage = error.localizedDescription
        }
    }

    private func delete() {
        guard let plan else { return }
        do {
            try PlanService(context: context).delete(plan)
            dismiss()
        } catch {
            form.validationMessage = error.localizedDescription
        }
    }
}

#Preview {
    PlanFormView(day: CalendarDay(.now)).modelContainer(.preview)
}
