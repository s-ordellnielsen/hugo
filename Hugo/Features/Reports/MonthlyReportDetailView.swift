import SwiftUI

struct MonthlyReportDetailView: View {
    let summary: MonthlyReportSummary

    var body: some View {
        List {
            MonthlyReportTotalsView(summary: summary)
            MonthlyReportEntryListView(summary: summary)
        }
        .navigationTitle(summary.displayName)
        .navigationSubtitle("report.title")
    }
}
