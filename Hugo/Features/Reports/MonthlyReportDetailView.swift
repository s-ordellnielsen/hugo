import SwiftUI

struct MonthlyReportDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let month: TheocraticYearMonth

    @State private var showingAddEntry = false

    private var summary: MonthlyReportSummary {
        // Presented only from months that have a summary.
        month.summary!
    }

    var body: some View {
        List {
            if month.isSubmitted && month.hasUnreportedEntries {
                Section {
                    Label("report.detail.unreported.banner", systemImage: "exclamationmark.triangle.fill")

                        .font(.subheadline)
                }
            }

            MonthlyReportTotalsView(summary: summary)
            MonthlyReportEntryListView(summary: summary, report: month.submittedReport)
        }
        .navigationTitle(summary.displayName)
        .navigationSubtitle("report.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("navigation.dismiss", systemImage: "xmark", role: .cancel) { dismiss() }
            }
            ToolbarItem {
                Button("common.add", systemImage: "plus") {
                    showingAddEntry.toggle()
                }
            }
        }
        .sheet(isPresented: $showingAddEntry) {
            AddEntryView(seededDate: summary.id.date())
        }
    }
}
