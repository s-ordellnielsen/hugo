import SwiftUI

struct CurrentMonthCalculationPreview: View {
    let calculation: CurrentMonthCalculation
    let selected: YearlyGoalPacing
    let locale: Locale

    private var option: CurrentMonthCalculation.Option? {
        calculation.options.first { $0.pacing == selected }
    }

    var body: some View {
        if let option {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
                VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                    Text("settings.yearlyGoal.pacing.currentMonth")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(
                        String(
                            localized: LocalizedStringResource(
                                "settings.yearlyGoal.pacing.monthContribution",
                                defaultValue:
                                    "\(ServiceDurationFormatter.hoursString(from: option.contributionSeconds, locale: locale)) of \(ServiceDurationFormatter.hoursString(from: calculation.monthlyGoalSeconds, locale: locale))",
                                locale: locale))
                    )
                    .font(.title3).fontWeight(.semibold).fixedSize(horizontal: false, vertical: true)
                }

                MarkedProgressBar(filled: option.fraction, marker: calculation.todayFraction) {
                    Text(calculation.todayLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(calculation.firstDayLabel)
                    Spacer(minLength: HugoLayout.Spacing.compact)
                    Text(calculation.lastDayLabel)
                }
                .font(.caption).foregroundStyle(.secondary)
                .padding(.bottom, HugoLayout.Spacing.regular)

                Text("settings.yearlyGoal.pacing.intro")
                    .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                Text(
                    String(
                        localized: LocalizedStringResource(
                            "settings.yearlyGoal.pacing.accessibility",
                            defaultValue:
                                "\(calculation.todayLabel). \(String(localized: selected.label)). Current month: \(ServiceDurationFormatter.accessibilityString(from: option.contributionSeconds, locale: locale)) of \(ServiceDurationFormatter.accessibilityString(from: calculation.monthlyGoalSeconds, locale: locale)). Expected by today: \(ServiceDurationFormatter.accessibilityString(from: option.expectedSeconds, locale: locale)).",
                            locale: locale))))
        }
    }
}
