import SwiftData
import SwiftUI

struct ServiceYearPageView: View {
    let year: TheocraticYear
    let entries: [Entry]
    let submissions: [SubmittedReport]

    var isActive: Bool = true
    var onScrolledFromTopChange: ((Bool) -> Void)? = nil

    private var report: TheocraticYearReport {
        TheocraticYearReportBuilder.report(
            for: year,
            entries: entries,
            submissions: submissions
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HugoLayout.Spacing.card) {
                if report.hasEntries {
                    TheocraticYearTotalsView(report: report)
                } else {
                    emptyYearCard
                }

                ForEach(report.months) { month in
                    Group {
                        if month.summary != nil {
                            MonthlyReportRow(month: month)
                        } else {
                            MonthlyReportEmptyRow(month: month)
                        }
                    }
                    .id(month.id)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 0
        } action: { _, isScrolledFromTop in
            guard isActive else { return }
            onScrolledFromTopChange?(isScrolledFromTop)
        }
    }

    private var emptyYearCard: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
            Image(systemName: "calendar")
                .font(.largeTitle)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            Text("year.empty.title")
                .font(.title3)
                .fontWeight(.semibold)
            Text("year.empty.description")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(HugoLayout.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
    }
}

#Preview {
    NavigationStack {
        ServiceYearPageView(
            year: ReportPreviewFixtures.currentYear,
            entries: ReportPreviewFixtures.entries,
            submissions: []
        )
    }
    .modelContainer(.preview)
}
