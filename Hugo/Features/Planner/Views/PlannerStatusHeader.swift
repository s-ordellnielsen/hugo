import SwiftUI

/// The month's numbers above the Planner calendar: projected time against the target.
struct PlannerStatusHeader: View {
    let status: PlannerMonthStatus

    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
            HStack {
                Text("planner.header.eyebrow")
                    .font(.caption)
                    .textCase(.uppercase)
                    .tracking(HugoLayout.Typography.eyebrowTracking)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer(minLength: HugoLayout.Spacing.regular)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(ServiceDurationFormatter.hoursString(from: status.projectedSeconds))
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .motion(Motion.value, value: status.projectedSeconds)
                Spacer()
                if let targetSeconds = status.targetSeconds {
                    Text(
                        String(
                            localized: "planner.header.target",
                            defaultValue: "Target \(ServiceDurationFormatter.hoursString(from: targetSeconds))",
                            comment: "The monthly target. The argument is a duration such as 50 hours.")
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            if let targetSeconds = status.targetSeconds {
                PlannerProgressBar(
                    loggedSeconds: status.loggedSeconds,
                    stillPlannedSeconds: status.stillPlannedSeconds,
                    targetSeconds: targetSeconds
                )
                .padding(.vertical, HugoLayout.Spacing.tight)
            }

            HStack(spacing: HugoLayout.Spacing.spacious) {
                legendItem(
                    fraction: 1,
                    text: String(
                        localized: "planner.header.logged",
                        defaultValue: "Logged \(ServiceDurationFormatter.hoursString(from: status.loggedSeconds))",
                        comment: "Time already logged this month. The argument is a duration."))
                legendItem(
                    fraction: 0,
                    text: String(
                        localized: "planner.header.stillPlanned",
                        defaultValue:
                            "Still planned \(ServiceDurationFormatter.hoursString(from: status.stillPlannedSeconds))",
                        comment: "Time planned but not logged yet this month. The argument is a duration."))
            }

            Text(status.summarySentence)
                .font(.subheadline)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, HugoLayout.Spacing.compact)

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, HugoLayout.Spacing.card)
        .padding(.vertical, HugoLayout.Spacing.regular)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("planner.header.a11y.hint"))
    }

    private func legendItem(fraction: Double, text: String) -> some View {
        HStack(spacing: HugoLayout.Spacing.small) {
            PlannerBarShape(fraction: fraction, color: .hugoAccent)
                .frame(width: 16, height: HugoLayout.Size.calendarBarHeight)
                .accessibilityHidden(true)
            Text(text)
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
