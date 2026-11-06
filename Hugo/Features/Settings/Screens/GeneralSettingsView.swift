import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(UserDefaultsKeys.durationMinuteInterval) private var durationMinuteInterval = 1
    @AppStorage(UserDefaultsKeys.yearlyGoalPacing) private var pacing: YearlyGoalPacing = .proRated
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""
    @AppStorage(UserDefaultsKeys.plannerTargetBase) private var base: PlannerTargetBase = .monthlyGoal
    @AppStorage(UserDefaultsKeys.plannerExtraHours) private var extraHours = 0

    private var status: PublisherStatus? { PublisherStatus.status(for: statusID) }

    var body: some View {
        List {
            Section {
                NavigationLink(destination: PlannerTargetSettingsView()) {
                    LabeledContent {
                        Text(
                            PlannerTarget.settingSummary(
                                base: base, extraHours: extraHours, status: status)
                        )
                        .foregroundStyle(.secondary)
                    } label: {
                        Label("planner.target.title", systemImage: "calendar")
                    }
                }
            } header: {
                Text("tab.planner")
            }

            if status?.yearlyGoalRule != nil {
                Section {
                    NavigationLink(destination: YearlyGoalPacingSettingsView()) {
                        LabeledContent {
                            Text(pacing.label).foregroundStyle(.secondary)
                        } label: {
                            Label("settings.yearlyGoal.pacing", systemImage: "chart.line.uptrend.xyaxis")
                        }
                    }
                } header: {
                    Text("year.subtitle")
                }
            }

            Section {
                Picker(selection: $durationMinuteInterval) {
                    Text("settings.duration.minute-interval.1").tag(1)
                    Text("settings.duration.minute-interval.5").tag(5)
                    Text("settings.duration.minute-interval.15").tag(15)
                } label: {
                    Label("settings.duration.minute-interval", systemImage: "clock")
                }
                .pickerStyle(.navigationLink)
            }
        }
        .navigationTitle("settings.group.settings.general")
    }
}

#Preview {
    GeneralSettingsView()
}
