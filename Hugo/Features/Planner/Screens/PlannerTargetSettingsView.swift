import SwiftUI

struct PlannerTargetSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UserDefaultsKeys.plannerTargetBase) private var base: PlannerTargetBase = .monthlyGoal
    @AppStorage(UserDefaultsKeys.plannerExtraHours) private var extraHours = 0
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""

    var showsDone = false

    private var status: PublisherStatus? { PublisherStatus.status(for: statusID) }
    private var hasGoal: Bool { (status?.monthlyGoal ?? 0) > 0 }

    var body: some View {
        List {
            if status?.yearlyGoalRule != nil {
                Section {
                    Picker(selection: $base) {
                        ForEach(PlannerTargetBase.allCases, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    } label: {
                        Text("planner.target.base")
                    }
                    .pickerStyle(.inline)
                } footer: {
                    Text("planner.target.base.footer")
                }
            }
            Section {
                Stepper(value: $extraHours, in: 0...30) {
                    LabeledContent(
                        "planner.target.extra",
                        value: ServiceDurationFormatter.hoursString(from: TimeInterval(extraHours) * 3_600))
                }
            } footer: {
                Text(
                    hasGoal
                        ? LocalizedStringKey("planner.target.extra.footer")
                        : LocalizedStringKey("planner.target.extra.footer.noGoal"))
            }
        }
        .navigationTitle("planner.target.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("navigation.done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PlannerTargetSettingsView()
    }
}
