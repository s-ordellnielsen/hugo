import SwiftUI

struct MonthlyReportTotalsView: View {
    let summary: MonthlyReportSummary

    var body: some View {
        HStack(alignment: .bottom) {
            total(
                ServiceDurationFormatter.string(from: summary.mainDuration),
                label: "monthlyReport.detail.largeTotal.main.label", alignment: .leading)
            Spacer()
            total(
                ServiceDurationFormatter.string(from: summary.totalSeconds),
                label: "monthlyReport.detail.largeTotal.total.label", alignment: .center, prominent: true)
            Spacer()
            total(
                ServiceDurationFormatter.string(from: summary.separateDuration),
                label: "monthlyReport.detail.largeTotal.separate.label", alignment: .trailing)
        }
        .padding(8)
    }

    @ViewBuilder
    private func total(
        _ value: String, label: LocalizedStringKey, alignment: HorizontalAlignment, prominent: Bool = false
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(value)
                .font(prominent ? .title : .callout)
                .fontDesign(.monospaced)
                .fontWeight(.medium)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .bottom))
    }
}
