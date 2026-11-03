import SwiftData
import SwiftUI

struct MonthlyReportDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let month: ServiceMonth

    @State private var showingAddEntry = false

    var body: some View {
        Group {
            if let summary = month.summary {
                List {
                    if let change = month.unreportedChange {
                        Section {
                            Label(bannerKey(for: change), systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                        }
                    }

                    MonthlyReportTotalsView(summary: summary)
                    MonthlyReportEntryListView(month: month)
                }
            } else {
                ContentUnavailableView {
                    Label("overview.entries.empty", systemImage: "text.page.badge.magnifyingglass")
                } actions: {
                    Button("entry.add.label") {
                        showingAddEntry = true
                    }
                }
            }
        }
        .navigationTitle(month.displayName)
        .navigationSubtitle("report.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                EditorialNavigationTitle(title: month.displayName)
            }
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
            AddEntryView(seededDate: month.id.date())
        }
    }

    private func bannerKey(for change: ServiceMonth.UnreportedChange) -> LocalizedStringKey {
        switch change {
        case .newEntries: "report.detail.unreported.banner"
        case .changedTotals: "report.detail.changed.banner"
        }
    }
}

#Preview("With entries") {
    NavigationStack {
        MonthlyReportDetailView(month: ReportPreviewFixtures.monthWithActivity)
    }
    .modelContainer(.preview)
}

#Preview("Empty month") {
    NavigationStack {
        MonthlyReportDetailView(month: ReportPreviewFixtures.emptyMonth)
    }
    .modelContainer(.preview)
}
