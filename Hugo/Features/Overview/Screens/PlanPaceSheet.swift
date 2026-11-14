import SwiftUI

/// The plan pace of the current month: a status heading, then a bar whose
/// track is the month's plan, filled with the logged time and marked where
/// the plan expects the user to be today. Opened from the status line under
/// the Overview circle.
struct PlanPaceSheet: View {
    let pace: PlanPace

    private var status: MonthlyProgressStatus { .make(pace: pace) }

    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.card) {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                Label(status.label, systemImage: status.icon)
                    .font(.system(.title2, design: .serif, weight: .bold))
                Text(pace.differenceSentence)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
                MarkedProgressBar(filled: pace.loggedFraction, marker: pace.expectedFraction) {
                    Text("overview.pace.marker")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline) {
                    amount(hours(pace.loggedSeconds), label: "overview.pace.logged", alignment: .leading)
                    Spacer(minLength: HugoLayout.Spacing.regular)
                    amount(hours(pace.expectedSeconds), label: "overview.pace.soFar", alignment: .trailing)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                Text(
                    "overview.pace.a11y.numbers.\(spoken(pace.loggedSeconds)).\(spoken(pace.expectedSeconds)).\(spoken(pace.plannedSeconds))"
                ))
        }
        .padding(HugoLayout.Spacing.card)
        .padding(.top, HugoLayout.Spacing.spacious)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func amount(_ value: String, label: LocalizedStringKey, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: HugoLayout.Spacing.tight) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .bold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func hours(_ seconds: TimeInterval) -> String {
        ServiceDurationFormatter.hoursString(from: seconds)
    }

    private func spoken(_ seconds: TimeInterval) -> String {
        ServiceDurationFormatter.accessibilityString(from: seconds)
    }
}

#Preview("Behind") {
    PlanPaceSheet(
        pace: PlanPace(expectedSeconds: 15 * 3_600, loggedSeconds: 11 * 3_600 + 30 * 60, plannedSeconds: 32 * 3_600))
}

#Preview("Ahead") {
    PlanPaceSheet(pace: PlanPace(expectedSeconds: 8 * 3_600, loggedSeconds: 12 * 3_600, plannedSeconds: 30 * 3_600))
}
