import SwiftUI

struct MonthlyReportDetailView: View {
	@Environment(\.dismiss) private var dismiss
	
    let summary: MonthlyReportSummary
	
	@State private var showingAddEntry = false

    var body: some View {
        List {
            MonthlyReportTotalsView(summary: summary)
            MonthlyReportEntryListView(summary: summary)
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
