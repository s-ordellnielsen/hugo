import SwiftUI

struct MonthlyReportListView: View {
    let entries: [Entry]

    var summaries: [MonthlyReportSummary] {
        MonthlyReportBuilder.summaries(from: entries)
    }

    var body: some View {
        VStack(spacing: 24) {
            ForEach(summaries) { summary in
                MonthlyReportRow(summary: summary)
            }
        }
    }
}
