import SwiftData
import SwiftUI

/// The page for a pushed `YearRoute`. It queries what the Year pages query and
/// rebuilds the report, so a pushed page never holds a stale snapshot. A row
/// that CloudKit removed shows an empty state.
struct YearRouteView: View {
    let route: YearRoute
    let transition: Namespace.ID

    var body: some View {
        switch route {
        case .yearDetail(let startYear):
            YearReportRoute(year: TheocraticYear(startYear: startYear), month: nil)
        case .month(let month):
            YearReportRoute(year: TheocraticYear.containing(month.date()), month: month)
                .navigationTransition(.zoom(sourceID: month, in: transition))
        case .entry(let id):
            EntryRoute(id: id)
        }
    }
}

/// One Service Year rebuilt from the database: its totals page, or one month
/// of it when `month` is set.
private struct YearReportRoute: View {
    let year: TheocraticYear
    let month: YearMonth?

    @Query private var entries: [Entry]
    @Query private var submissions: [SubmittedReport]
    @Query private var trackers: [Tracker]
    @Query private var schoolCredits: [SchoolCredit]
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""
    @AppStorage(UserDefaultsKeys.plannerExtraHours) private var extraHours = 0
    @AppStorage(UserDefaultsKeys.bufferInYear) private var includeBuffer = false

    init(year: TheocraticYear, month: YearMonth?) {
        self.year = year
        self.month = month
        let range = year.dateRange()
        let start = range.lowerBound
        let end = range.upperBound
        _entries = Query(
            filter: #Predicate<Entry> { $0.date >= start && $0.date < end },
            sort: \Entry.date
        )
        _submissions = Query(sort: \SubmittedReport.year)
    }

    var body: some View {
        let report = TheocraticYearReportBuilder.report(
            for: year,
            entries: entries,
            submissions: submissions,
            trackers: trackers,
            schoolCredits: schoolCredits
        )
        if let month {
            if let serviceMonth = report.months.first(where: { $0.id == month }) {
                MonthDetailView(
                    month: serviceMonth,
                    schoolCredits: schoolCredits.filter { $0.yearMonth == month })
            } else {
                unavailable
            }
        } else {
            let status = PublisherStatus.status(for: statusID)
            let progress = status.flatMap { status in
                YearlyGoalProgress.make(
                    report: report, status: status,
                    bufferSeconds: includeBuffer ? TimeInterval(extraHours) * 3_600 : 0)
            }
            ServiceYearDetailView(report: report, progress: progress)
        }
    }

    private var unavailable: some View {
        ContentUnavailableView("common.error", systemImage: "exclamationmark.triangle")
    }
}

/// One entry's detail page, looked up again by its identifier.
private struct EntryRoute: View {
    @Query private var entries: [Entry]

    init(id: PersistentIdentifier) {
        let entryID = id
        _entries = Query(filter: #Predicate<Entry> { $0.persistentModelID == entryID })
    }

    var body: some View {
        if let entry = entries.first {
            EntryDetailView(entry: entry)
        } else {
            ContentUnavailableView("common.error", systemImage: "exclamationmark.triangle")
        }
    }
}
