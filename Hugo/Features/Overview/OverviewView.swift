import SwiftData
import SwiftUI

struct OverviewView: View {
    @Query private var entries: [Entry]
    @Query private var submissions: [SubmittedReport]
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""
    @State private var showingAddEntry = false
    @State private var showingDetails = false
    private let calendar = Calendar.current
    private let now = Date.now

    init() {
        let interval = CurrentMonthInterval.current(now: .now, calendar: .current)
        let start = interval.start
        let end = interval.end
        _entries = Query(
            filter: #Predicate<Entry> { $0.date >= start && $0.date < end }, sort: \Entry.date, order: .reverse)
    }

    private var metrics: OverviewMetrics {
        OverviewMetrics.make(
            entries: entries, status: PublisherStatus.status(for: statusID), now: now, calendar: calendar)
    }

    /// The month whose report reminder should show, if any: a month is due
    /// (per `ReportReminderSchedule`) and has no real submission. Backfill
    /// sentinels (`submittedAt == .distantPast`) count as unsubmitted.
    private var reminderMonth: YearMonth? {
        guard let due = ReportReminderSchedule.dueMonth(now: now, calendar: calendar) else { return nil }
        guard let submission = submissions.first(where: { $0.year == due.year && $0.month == due.month }) else {
            return due
        }
        return (submission.submittedAt ?? .distantPast) == .distantPast ? due : nil
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    if let reminderMonth {
                        ReportReminderCard(month: reminderMonth)
                        Spacer(minLength: 32)
                    }
                    MonthlyProgressCard(
                        value: metrics.progress, monthlyGoal: metrics.monthlyGoal,
                        expectedProgress: metrics.expectedProgress, onAddEntry: { showingAddEntry = true },
                        onShowDetails: { showingDetails = true })
                    Spacer(minLength: 32)
                    EntryListView(entries: entries)
                }.padding()
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("overview.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { SettingsButton() }.sheet(isPresented: $showingAddEntry) { AddEntryView() }.sheet(
                isPresented: $showingDetails
            ) { MonthlyProgressDetailView(month: now.yearMonth()) }
        }
    }
}
