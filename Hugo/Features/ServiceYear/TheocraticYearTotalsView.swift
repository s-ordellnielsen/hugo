import SwiftData
import SwiftUI

struct TheocraticYearTotalsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let report: TheocraticYearReport

    var body: some View {
        VStack {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) { totals }
            } else {
                totals
            }
            Divider().padding(.vertical, 8)
            Text("monthlyReport.detail.largeTotal.disclaimer")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 32))
    }

    @ViewBuilder
    private var totals: some View {
        HStack(alignment: .bottom) {
            total(
                ServiceDurationFormatter.string(from: report.mainDuration),
                label: "monthlyReport.detail.largeTotal.main.label", alignment: .leading)
            Spacer()
            total(
                ServiceDurationFormatter.string(from: report.totalSeconds),
                label: "monthlyReport.detail.largeTotal.total.label", alignment: .center, prominent: true)
            Spacer()
            total(
                ServiceDurationFormatter.string(from: report.separateDuration),
                label: "monthlyReport.detail.largeTotal.separate.label", alignment: .trailing)
        }
    }

    @ViewBuilder
    private func total(
        _ value: String, label: LocalizedStringKey, alignment: HorizontalAlignment, prominent: Bool = false
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(value)
                .font(prominent ? .title : .callout)
                .fontDesign(.rounded)
				.fontWeight(prominent ? .bold : .medium)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .bottom))
    }
}

#Preview {
    TheocraticYearTotalsView(report: ReportPreviewFixtures.yearReport)
        .modelContainer(.preview)
}
