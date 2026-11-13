import SwiftUI

struct MonthlyReportTotalsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let summary: MonthlyReportSummary

    var body: some View {
        // Side by side normally; one under the other at accessibility sizes.
        let isStacked = dynamicTypeSize.isAccessibilitySize
        let layout =
            isStacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: HugoLayout.Spacing.regular))
            : AnyLayout(HStackLayout(alignment: .bottom))
        layout {
            total(
                ServiceDurationFormatter.hoursString(from: summary.mainDuration),
                label: "monthlyReport.detail.largeTotal.main.label", alignment: .leading)
            if !isStacked { Spacer() }
            total(
                ServiceDurationFormatter.hoursString(from: summary.totalSeconds),
                label: "monthlyReport.detail.largeTotal.total.label", alignment: isStacked ? .leading : .center,
                prominent: true)
            if !isStacked { Spacer() }
            total(
                ServiceDurationFormatter.hoursString(from: summary.separateDuration),
                label: "monthlyReport.detail.largeTotal.separate.label", alignment: isStacked ? .leading : .trailing)
        }
        .padding(HugoLayout.Spacing.compact)
    }

    @ViewBuilder
    private func total(
        _ value: String, label: LocalizedStringKey, alignment: HorizontalAlignment, prominent: Bool = false
    ) -> some View {
        VStack(alignment: alignment, spacing: HugoLayout.Spacing.tight) {
            Text(value)
                .font(prominent ? .title : .callout)
                .monospacedDigit()
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .bottom))
    }
}
