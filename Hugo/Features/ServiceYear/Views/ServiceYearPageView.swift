import SwiftData
import SwiftUI

struct ServiceYearPageView: View {
    let year: TheocraticYear
    var onScrolledFromTopChange: ((Bool) -> Void)? = nil

    @Query private var entries: [Entry]
    @Query private var submissions: [SubmittedReport]
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""
    @AppStorage(UserDefaultsKeys.yearlyGoalPacing) private var pacing: YearlyGoalPacing = .proRated

    init(year: TheocraticYear, onScrolledFromTopChange: ((Bool) -> Void)? = nil) {
        self.year = year
        self.onScrolledFromTopChange = onScrolledFromTopChange
        let range = year.dateRange()
        let start = range.lowerBound
        let end = range.upperBound
        _entries = Query(
            filter: #Predicate<Entry> { $0.date >= start && $0.date < end },
            sort: \Entry.date
        )
        _submissions = Query(sort: \SubmittedReport.year)
    }

    private var report: TheocraticYearReport {
        TheocraticYearReportBuilder.report(
            for: year,
            entries: entries,
            submissions: submissions
        )
    }

    private var status: PublisherStatus? {
        PublisherStatus.status(for: statusID)
    }

    private func progress(for report: TheocraticYearReport) -> YearlyGoalProgress? {
        guard let status else { return nil }
        return YearlyGoalProgress.make(report: report, status: status, pacing: pacing)
    }

    var body: some View {
        let report = self.report
        let progress = progress(for: report)
        return ScrollView {
            VStack(spacing: HugoLayout.Spacing.card) {
                if report.hasEntries {
                    NavigationLink {
                        ServiceYearDetailView(report: report, progress: progress)
                    } label: {
                        TheocraticYearTotalsView(report: report, progress: progress)
                    }
                    .buttonStyle(.card)
                } else {
                    emptyYearCard
                }

                ForEach(report.months) { month in
                    ServiceYearMonthRow(month: month)
                        .id(month.id)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 0
        } action: { _, isScrolledFromTop in
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
        ServiceYearPageView(year: ReportPreviewFixtures.currentYear)
    }
    .modelContainer(.preview)
}
