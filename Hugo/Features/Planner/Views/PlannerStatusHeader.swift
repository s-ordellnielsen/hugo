import SwiftUI

/// The month's numbers above the Planner calendar: projected time, the monthly target, and how the plan compares.
struct PlannerStatusHeader: View {
    let status: PlannerMonthStatus

    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                Text(ServiceDurationFormatter.hoursString(from: status.projectedSeconds))
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .motion(Motion.value, value: status.projectedSeconds)

                // Side by side when both fit on one line; otherwise stacked.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        projectedLabel
                        Spacer(minLength: HugoLayout.Spacing.regular)
                        targetLabel
                    }
                    VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                        projectedLabel
                        targetLabel
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if let targetSeconds = status.targetSeconds {
                PlannerProgressBar(
                    loggedSeconds: status.loggedSeconds,
                    stillPlannedSeconds: status.stillPlannedSeconds,
                    targetSeconds: targetSeconds
                )
            }

            // Side by side when both fit on one line each; otherwise stacked, so no label breaks mid-value.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: HugoLayout.Spacing.spacious) {
                    legendItems(keepsLabelsOnOneLine: true)
                }
                VStack(alignment: .leading, spacing: HugoLayout.Spacing.small) {
                    legendItems(keepsLabelsOnOneLine: false)
                }
            }

            VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                Text(status.summarySentence)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)

                if let perDaySentence = status.perDaySentence {
                    Text(perDaySentence)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let uncountedSentence = status.uncountedSentence {
                    Text(uncountedSentence)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, HugoLayout.Spacing.compact)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, HugoLayout.Spacing.card)
        .padding(.vertical, HugoLayout.Spacing.roomy)
        .accessibilityElement(children: .combine)
    }

    private var projectedLabel: some View {
        Text("planner.header.projected.label")
    }

    @ViewBuilder
    private var targetLabel: some View {
        if let targetSeconds = status.targetSeconds {
            Text(
                String(
                    localized: "planner.header.target",
                    defaultValue: "Target \(ServiceDurationFormatter.hoursString(from: targetSeconds))",
                    comment: "The monthly target. The argument is a duration such as 50 hours.")
            )
        }
    }

    @ViewBuilder
    private func legendItems(keepsLabelsOnOneLine: Bool) -> some View {
        legendItem(
            fraction: 1,
            text: String(
                localized: "planner.header.logged",
                defaultValue: "Logged \(ServiceDurationFormatter.hoursString(from: status.loggedSeconds))",
                comment: "Time already logged this month. The argument is a duration."),
            keepsLabelOnOneLine: keepsLabelsOnOneLine)
        legendItem(
            fraction: 0,
            text: String(
                localized: "planner.header.stillPlanned",
                defaultValue:
                    "Still planned \(ServiceDurationFormatter.hoursString(from: status.stillPlannedSeconds))",
                comment: "Time planned but not logged yet this month. The argument is a duration."),
            keepsLabelOnOneLine: keepsLabelsOnOneLine)
    }

    private func legendItem(fraction: Double, text: String, keepsLabelOnOneLine: Bool) -> some View {
        HStack(spacing: HugoLayout.Spacing.small) {
            PlannerBarShape(fraction: fraction, color: .hugoAccent)
                .frame(width: 16, height: HugoLayout.Size.calendarBarHeight)
                .accessibilityHidden(true)
            Text(text)
                .fixedSize(horizontal: keepsLabelOnOneLine, vertical: true)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

#Preview("With a shortfall") {
    PlannerStatusHeader(
        status: PlannerMonthStatus(
            targetSeconds: 50 * 3_600, loggedSeconds: 10 * 3_600, stillPlannedSeconds: 36 * 3_600,
            uncountedSeconds: 0, daysLeft: 12)
    )
    .background(Color(.systemGroupedBackground))
}

#Preview("Without a target") {
    PlannerStatusHeader(
        status: PlannerMonthStatus(
            targetSeconds: nil, loggedSeconds: 10 * 3_600, stillPlannedSeconds: 4 * 3_600,
            uncountedSeconds: 0, daysLeft: 12)
    )
    .background(Color(.systemGroupedBackground))
}
