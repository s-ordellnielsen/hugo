import SwiftData
import SwiftUI

struct ServiceYearPageView: View {
    let report: TheocraticYearReport
	
	var isActive: Bool = true
	var onScrolledFromTopChange: ((Bool) -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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
        VStack(alignment: .leading, spacing: 12) {
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
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 32))
    }
}

#Preview {
    NavigationStack {
        ServiceYearPageView(report: ReportPreviewFixtures.yearReport)
    }
    .modelContainer(.preview)
}
