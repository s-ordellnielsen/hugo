import SwiftData
import SwiftUI

struct TheocraticYearTotalsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let report: TheocraticYearReport
    /// Nil when the publisher status has no yearly goal.
    let progress: YearlyGoalProgress?
    let status: PublisherStatus?

    private var primarySeconds: TimeInterval {
        progress?.creditedSeconds ?? report.totalSeconds
    }

    private var monthlyGoalHours: Int {
        status?.monthlyGoal ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
            HStack {
                eyebrow
                Spacer(minLength: HugoLayout.Spacing.regular)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            Text(ServiceDurationFormatter.string(from: primarySeconds))
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .motion(Motion.value, value: primarySeconds)

            if let progress, progress.showsActualTotal {
                Text(
                    String(
                        localized: "year.header.actual",
                        defaultValue: "Actual total \(ServiceDurationFormatter.string(from: progress.actualSeconds))",
                        comment:
                            "Real total of the year, shown when it differs from the counted time. The argument is a duration."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let fraction = progress?.barFraction, let paceSentence = progress?.paceSentence {
                Text(paceSentence)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.top, HugoLayout.Spacing.compact)

                CenteredProgressBar(
                    fraction: fraction,
                    accessibilityLabel: "year.header.counted.eyebrow",
                    accessibilityValue: paceSentence
                )

                endLabels
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HugoLayout.Spacing.card)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint("year.header.a11y.hint")
    }

    private var eyebrow: some View {
        Text(progress == nil ? "year.header.total.eyebrow" : "year.header.counted.eyebrow")
            .font(.caption)
            .textCase(.uppercase)
            .tracking(HugoLayout.Typography.eyebrowTracking)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var endLabels: some View {
        let behind = Text(
            String(
                localized: "year.header.end.behind",
                defaultValue: "-\(monthlyGoalHours) h",
                comment: "Left end of the yearly goal bar: one monthly goal behind. The argument is a number of hours."
            ))
        let ahead = Text(
            String(
                localized: "year.header.end.ahead",
                defaultValue: "+\(monthlyGoalHours) h",
                comment: "Right end of the yearly goal bar: one monthly goal ahead. The argument is a number of hours."
            ))
        let pace = Text("year.header.pace")

        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                    behind
                    pace
                    ahead
                }
            } else {
                HStack {
                    behind
                    Spacer()
                    pace
                    Spacer()
                    ahead
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var accessibilityLabelText: String {
        let spoken = ServiceDurationFormatter.accessibilityString(from: primarySeconds)
        guard let progress else { return spoken }
        return String(
            localized: "year.header.a11y.label",
            defaultValue: "Counted toward yearly goal: \(spoken). \(progress.paceSentence ?? "")",
            comment:
                "Spoken summary of the year header. The first argument is the counted time, the second is whether the user is ahead, behind or on pace."
        )
    }
}

#Preview("Yearly goal") {
    let status = PublisherStatus.status(for: "regular-pioneer")
    let report = ReportPreviewFixtures.yearReport
    let progress = status?.yearlyGoalRule.map {
        YearlyGoalProgress.make(
            report: report, rule: $0, yearlyGoalSeconds: 600 * 3_600, pacing: .proRated)
    }
    TheocraticYearTotalsView(report: report, progress: progress, status: status)
        .padding()
        .modelContainer(.preview)
}

#Preview("No yearly goal") {
    TheocraticYearTotalsView(report: ReportPreviewFixtures.yearReport, progress: nil, status: nil)
        .padding()
        .modelContainer(.preview)
}
