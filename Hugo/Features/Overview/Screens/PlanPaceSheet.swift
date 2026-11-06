import SwiftUI

/// The plan pace of the current month in numbers. Opened from the status line
/// under the Overview circle.
struct PlanPaceSheet: View {
    let pace: PlanPace

    @Environment(\.dismiss) private var dismiss

    private var status: MonthlyProgressStatus { .make(pace: pace) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                        Label(status.label, systemImage: status.icon)
                            .font(.system(.title2, design: .serif, weight: .bold))
                        Text(pace.differenceSentence)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .listRowBackground(Color.clear)
                }
                Section {
                    LabeledContent(
                        "overview.pace.planned",
                        value: ServiceDurationFormatter.hoursString(from: pace.expectedSeconds))
                    LabeledContent(
                        "overview.pace.logged",
                        value: ServiceDurationFormatter.hoursString(from: pace.loggedSeconds))
                } footer: {
                    Text("overview.pace.footer")
                }
            }
            .navigationTitle("overview.pace.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("navigation.done") { dismiss() }
                }
            }
        }
    }
}

#Preview("Behind") {
    PlanPaceSheet(pace: PlanPace(expectedSeconds: 15 * 3_600, loggedSeconds: 11 * 3_600 + 30 * 60))
}

#Preview("Ahead") {
    PlanPaceSheet(pace: PlanPace(expectedSeconds: 8 * 3_600, loggedSeconds: 12 * 3_600))
}
