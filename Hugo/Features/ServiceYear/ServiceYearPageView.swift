import SwiftData
import SwiftUI

struct ServiceYearPageView: View {
    let report: TheocraticYearReport

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
        .background(Color(.systemGroupedBackground))
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
                .fontDesign(.rounded)
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
