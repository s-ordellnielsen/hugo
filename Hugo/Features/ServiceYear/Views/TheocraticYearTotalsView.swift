import SwiftData
import SwiftUI

struct TheocraticYearTotalsView: View {
    let report: TheocraticYearReport
    /// Nil when the publisher status has no yearly goal.
    let progress: YearlyGoalProgress?

    private var primarySeconds: TimeInterval {
        progress?.creditedSeconds ?? report.totalSeconds
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
            HStack {
                eyebrow
                Spacer(minLength: HugoLayout.Spacing.regular)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            Text(ServiceDurationFormatter.hoursString(from: primarySeconds))
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())
                .motion(Motion.value, value: primarySeconds)

            if let progress, progress.showsYearTotal {
                Text(
                    String(
                        localized: "year.header.actual",
                        defaultValue:
                            "Actual total \(ServiceDurationFormatter.hoursString(from: progress.yearTotalSeconds))",
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
                    .padding(.top, HugoLayout.Spacing.spacious)

                CenteredProgressBar(
                    fraction: fraction,
                    accessibilityLabel: "year.header.counted.eyebrow",
                    accessibilityValue: paceSentence
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, HugoLayout.Spacing.card)
        .padding(.vertical, HugoLayout.Spacing.regular)
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

    private var accessibilityLabelText: String {
        let spoken = ServiceDurationFormatter.hoursString(from: primarySeconds)
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
    let report = ReportPreviewFixtures.yearReport
    let progress = PublisherStatus.status(for: "regular-pioneer").flatMap {
        YearlyGoalProgress.make(report: report, status: $0, pacing: .proRated)
    }
    TheocraticYearTotalsView(report: report, progress: progress)
        .padding()
        .modelContainer(.preview)
}

#Preview("No yearly goal") {
    TheocraticYearTotalsView(report: ReportPreviewFixtures.yearReport, progress: nil)
        .padding()
        .modelContainer(.preview)
}
